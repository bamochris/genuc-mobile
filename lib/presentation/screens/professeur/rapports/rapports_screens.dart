import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../data/services/appel_api.dart';
import '../../../../data/services/professeur_pedagogie_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/formulaire_dynamique.dart';
import '../../../widgets/portail_widgets.dart';

/// Module « Rapports » du portail enseignant : réussite, présences, notes.
///
/// Les trois pages web tirent leurs chiffres du même endroit — les notes d'un
/// cours pour une année — et n'en changent que la lecture. Elles partagent
/// donc ce même écran, paramétré par [TypeRapport] : trois copies d'un même
/// calcul auraient divergé au premier ajustement du seuil de réussite.
enum TypeRapport { reussite, presences, notes }

class RapportProfesseurScreen extends StatefulWidget {
  final TypeRapport type;

  const RapportProfesseurScreen({super.key, required this.type});

  @override
  State<RapportProfesseurScreen> createState() =>
      _RapportProfesseurScreenState();
}

class _RapportProfesseurScreenState extends State<RapportProfesseurScreen> {
  Map<String, String> _cours = const {};
  String? _coursId;
  String _annee = anneeAcademiqueCourante();

  List<Fiche> _notes = const [];
  List<Fiche> _seances = const [];
  bool _chargement = true;
  bool _chargementDetail = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  Future<void> _charger() async {
    final professeurId = context.read<AuthProvider>().user?.id ?? '';
    final service = context.read<ProfesseurPedagogieService>();

    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final cours = await service.mesCours(professeurId);
      // Le rapport de présences ne dépend pas d'un cours : il lit
      // l'historique complet de l'enseignant.
      final seances = widget.type == TypeRapport.presences
          ? await service
              .historiquePresences(professeurId)
              .catchError((_) => <Fiche>[])
          : <Fiche>[];
      if (!mounted) return;
      setState(() {
        _cours = {
          for (final c in cours)
            c.id: c.texte('titre', alias: const ['nom'], defaut: '—'),
        };
        _seances = seances;
        _chargement = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = e.message;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = 'Erreur de chargement : ${e.runtimeType}';
        _chargement = false;
      });
    }
  }

  Future<void> _chargerNotes() async {
    final coursId = _coursId;
    if (coursId == null) return;

    setState(() => _chargementDetail = true);
    try {
      final notes = await context
          .read<ProfesseurPedagogieService>()
          .notesDuCours(coursId, _annee);
      if (!mounted) return;
      setState(() {
        _notes = notes;
        _chargementDetail = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _notes = const [];
        _chargementDetail = false;
      });
    }
  }

  String get _titre => switch (widget.type) {
        TypeRapport.reussite => 'Rapport de réussite',
        TypeRapport.presences => 'Rapport de présences',
        TypeRapport.notes => 'Rapport de notes',
      };

  @override
  Widget build(BuildContext context) {
    return PagePortail(
      titre: _titre,
      sousTitre: widget.type == TypeRapport.presences
          ? 'Assiduité par cours'
          : '$_annee · ${_cours[_coursId] ?? 'aucun cours choisi'}',
      onRafraichir: _charger,
      corps: EtatRequete(
        chargement: _chargement,
        erreur: _erreur,
        vide: false,
        onReessayer: _charger,
        enfant: ListView(
          padding: Responsive.margePage(context),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (widget.type != TypeRapport.presences) ...[
              CartePortail(
                child: Column(
                  children: [
                    SelecteurCours(
                      valeur: _coursId,
                      cours: _cours,
                      onChange: (v) {
                        setState(() => _coursId = v);
                        _chargerNotes();
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      initialValue: _annee,
                      decoration: const InputDecoration(
                        labelText: 'Année académique',
                        hintText: '2025-2026',
                      ),
                      onFieldSubmitted: (v) {
                        setState(() => _annee = v.trim());
                        _chargerNotes();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_chargementDetail)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              ...switch (widget.type) {
                TypeRapport.reussite => _rapportReussite(),
                TypeRapport.notes => _rapportNotes(),
                TypeRapport.presences => _rapportPresences(),
              },
          ],
        ),
      ),
    );
  }

  /// Note retenue pour un étudiant : le champ change de nom selon que la
  /// délibération est passée ou non.
  double? _noteDe(Fiche n) => n.decimalOuNul(
        'noteFinale',
        alias: const ['note', 'moyenne', 'total'],
      );

  List<Widget> _rapportReussite() {
    if (_coursId == null) return [_invite()];

    final notes = _notes.map(_noteDe).whereType<double>().toList();
    if (notes.isEmpty) return [_aucuneDonnee()];

    // Seuil de réussite du portail : 10/20, comme la délibération.
    final reussites = notes.where((n) => n >= 10).length;
    final taux = (reussites * 100 / notes.length).round();
    final moyenne = notes.reduce((a, b) => a + b) / notes.length;

    return [
      RangeeKpi(
        tuiles: [
          TuileKpi(
            icone: Icons.percent_rounded,
            valeur: '$taux %',
            libelle: 'Taux de réussite',
            couleur: taux >= 50 ? AppTheme.statutVert : AppTheme.statutRouge,
          ),
          TuileKpi(
            icone: Icons.groups_rounded,
            valeur: '${notes.length}',
            libelle: 'Étudiants notés',
            couleur: AppTheme.statutBleu,
          ),
          TuileKpi(
            icone: Icons.check_circle_rounded,
            valeur: '$reussites',
            libelle: 'Réussites',
            couleur: AppTheme.statutVert,
          ),
          TuileKpi(
            icone: Icons.cancel_rounded,
            valeur: '${notes.length - reussites}',
            libelle: 'Échecs',
            couleur: AppTheme.statutRouge,
          ),
        ],
      ),
      const SizedBox(height: 20),
      const EnteteSection(
        titre: 'Répartition',
        icone: Icons.bar_chart_rounded,
      ),
      ..._tranches(notes),
      const SizedBox(height: 16),
      CartePortail(
        child: LigneDetail(
          libelle: 'Moyenne de la classe',
          valeur: '${moyenne.toStringAsFixed(2)} / 20',
        ),
      ),
    ];
  }

  /// Répartition par tranche de 5 points, comme l'histogramme du web.
  List<Widget> _tranches(List<double> notes) {
    const bornes = [
      ('0 – 4,9', 0.0, 5.0, AppTheme.statutRouge),
      ('5 – 9,9', 5.0, 10.0, AppTheme.statutOrange),
      ('10 – 13,9', 10.0, 14.0, AppTheme.statutBleu),
      ('14 – 20', 14.0, 20.01, AppTheme.statutVert),
    ];

    return [
      for (final (libelle, min, max, couleur) in bornes) ...[
        CartePortail(
          child: Builder(
            builder: (context) {
              final compte =
                  notes.where((n) => n >= min && n < max).length;
              return BarreProgression(
                valeur: notes.isEmpty ? 0 : compte / notes.length,
                libelle: '$libelle — $compte étudiant(s)',
                couleur: couleur,
              );
            },
          ),
        ),
        const SizedBox(height: 10),
      ],
    ];
  }

  List<Widget> _rapportNotes() {
    if (_coursId == null) return [_invite()];
    if (_notes.isEmpty) return [_aucuneDonnee()];

    return [
      TableauDefilant(
        entetes: const ['Étudiant', 'Matricule', 'Note', 'Mention'],
        largeurMin: 520,
        lignes: [
          for (final note in _notes)
            [
              Text(
                note.texte(
                  'etudiantNom',
                  alias: const ['nomComplet', 'etudiant'],
                  defaut: '—',
                ),
              ),
              Text(note.texte('matricule', defaut: '—')),
              Text(
                _noteDe(note)?.toStringAsFixed(1) ?? '—',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accentLisible(
                    context,
                    (_noteDe(note) ?? 0) >= 10
                        ? AppTheme.statutVert
                        : AppTheme.statutRouge,
                  ),
                ),
              ),
              Text(libelleMention(note.texteOuNul('mention'))),
            ],
        ],
      ),
    ];
  }

  List<Widget> _rapportPresences() {
    if (_seances.isEmpty) return [_aucuneDonnee()];

    final parCours = <String, (int, int)>{};
    for (final seance in _seances) {
      final cours = seance.texte(
        'coursTitre',
        alias: const ['cours'],
        defaut: 'Cours',
      );
      final total = seance.entier('total', alias: const ['effectif']);
      final presents = seance.entier('presents');
      final courant = parCours[cours] ?? (0, 0);
      parCours[cours] = (courant.$1 + presents, courant.$2 + total);
    }

    return [
      const EnteteSection(
        titre: 'Assiduité par cours',
        icone: Icons.fact_check_rounded,
      ),
      for (final entree in parCours.entries) ...[
        CartePortail(
          child: BarreProgression(
            valeur: entree.value.$2 == 0 ? 0 : entree.value.$1 / entree.value.$2,
            libelle: '${entree.key} — '
                '${entree.value.$1} présences sur ${entree.value.$2}',
            couleur: AppTheme.statutBleu,
          ),
        ),
        const SizedBox(height: 10),
      ],
    ];
  }

  Widget _invite() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Text(
          'Choisissez un cours pour générer le rapport.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textMutedOf(context)),
        ),
      );

  Widget _aucuneDonnee() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Text(
          'Aucune donnée pour cette sélection.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textMutedOf(context)),
        ),
      );
}
