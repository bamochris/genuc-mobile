import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../data/services/appel_api.dart';
import '../../../../data/services/professeur_pedagogie_service.dart';
import '../../../providers/annees_academiques_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/formulaire_dynamique.dart';
import '../../../widgets/portail_widgets.dart';

/// Vue de délibération de l'enseignant : les notes d'un cours, décomposées,
/// avec la mention retenue.
///
/// Transposition de `professeur/deliberation/Deliberation.jsx` — écran de
/// consultation. L'enseignant ne décide pas ici : la décision appartient au
/// jury (portail `admin/deliberation`). Ajouter un bouton de validation aurait
/// été refusé par le serveur et aurait suggéré un pouvoir que le rôle n'a pas.
class DeliberationProfesseurScreen extends StatefulWidget {
  const DeliberationProfesseurScreen({super.key});

  @override
  State<DeliberationProfesseurScreen> createState() =>
      _DeliberationProfesseurScreenState();
}

class _DeliberationProfesseurScreenState
    extends State<DeliberationProfesseurScreen> {
  Map<String, String> _cours = const {};
  String? _coursId;
  /// Lue dans le référentiel de l'établissement, jamais déduite de
  /// l'horloge : `/api/notes/cours/{coursId}/{annee}` filtre sur l'ÉGALITÉ
  /// du libellé, et une année inventée rend « aucune note » sans rien dire.
  String? _annee;

  List<Fiche> _notes = const [];
  Fiche _stats = const Fiche({});
  bool _chargement = true;
  bool _chargementNotes = false;
  String? _erreur;
  String _filtreStatut = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  Future<void> _charger() async {
    final auth = context.read<AuthProvider>();
    final professeurId = auth.user?.id ?? '';
    setState(() {
      _chargement = true;
      _erreur = null;
    });

    final referentiel = context.read<AnneesAcademiquesProvider>();
    await referentiel.charger(role: auth.user?.role);
    if (!mounted) return;
    setState(() => _annee ??= referentiel.anneeParDefaut);

    try {
      final cours = await context
          .read<ProfesseurPedagogieService>()
          .mesCours(professeurId);
      if (!mounted) return;
      setState(() {
        _cours = {
          for (final c in cours)
            c.id: c.texte('titre', alias: const ['nom'], defaut: '—'),
        };
        _chargement = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = e.message;
        _chargement = false;
      });
    }
  }

  Future<void> _chargerNotes() async {
    final coursId = _coursId;
    final annee = _annee;
    if (coursId == null) return;
    if (annee == null) {
      setState(() {
        _notes = const [];
        _stats = const Fiche({});
        _erreur = 'Aucune année académique n\'est ouverte pour votre '
            'établissement.';
      });
      return;
    }

    setState(() => _chargementNotes = true);
    final service = context.read<ProfesseurPedagogieService>();
    // Les statistiques sont accessoires : leur absence ne doit pas priver
    // l'enseignant du tableau des notes, qui est l'objet de l'écran.
    try {
      final notes = await service.notesDuCours(coursId, annee);
      final stats = await service
          .statistiquesNotes(coursId, annee)
          .catchError((_) => const Fiche({}));
      if (!mounted) return;
      setState(() {
        _notes = notes;
        _stats = stats;
        _chargementNotes = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _notes = const [];
        _stats = const Fiche({});
        _chargementNotes = false;
        _erreur = e is ApiException ? e.message : e.toString();
      });
    }
  }

  List<Fiche> get _notesFiltrees => _filtreStatut.isEmpty
      ? _notes
      : _notes.where((n) => n.texte('statut') == _filtreStatut).toList();

  /// Note retenue : `noteRetenue` quand la délibération l'a fixée, sinon la
  /// note finale calculée.
  static double? _retenue(Fiche n) =>
      n.decimalOuNul('noteRetenue', alias: const ['noteFinale']);

  @override
  Widget build(BuildContext context) {
    final notes = _notesFiltrees;
    final valeurs = _notes.map(_retenue).whereType<double>().toList();
    final admis = valeurs.where((v) => v >= 10).length;

    return PagePortail(
      titre: 'Délibération',
      sousTitre: '${_annee ?? 'aucune année ouverte'} · ${_cours[_coursId] ?? 'aucun cours choisi'}',
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
                  Builder(builder: (context) {
                    final referentiel =
                        context.watch<AnneesAcademiquesProvider>();
                    return SelecteurAnnee(
                      valeur: _annee,
                      annees: referentiel.annees,
                      anneeActive: referentiel.anneeActive,
                      chargement: referentiel.chargement,
                      onChange: (v) {
                        setState(() => _annee = v);
                        _chargerNotes();
                      },
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_chargementNotes)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_coursId == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  'Choisissez un cours pour ouvrir sa délibération.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textMutedOf(context)),
                ),
              )
            else if (_notes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  'Aucune note enregistrée pour ce cours et cette année.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textMutedOf(context)),
                ),
              )
            else ...[
              RangeeKpi(
                tuiles: [
                  TuileKpi(
                    icone: Icons.groups_rounded,
                    valeur: '${_notes.length}',
                    libelle: 'Étudiants',
                    couleur: AppTheme.statutBleu,
                  ),
                  TuileKpi(
                    icone: Icons.functions_rounded,
                    valeur: _stats.decimalOuNul('moyenne') != null
                        ? _stats.decimal('moyenne').toStringAsFixed(2)
                        : (valeurs.isEmpty
                            ? '—'
                            : (valeurs.reduce((a, b) => a + b) / valeurs.length)
                                .toStringAsFixed(2)),
                    libelle: 'Moyenne',
                    couleur: AppTheme.statutViolet,
                  ),
                  TuileKpi(
                    icone: Icons.check_circle_rounded,
                    valeur: '$admis',
                    libelle: 'Admis',
                    detail: valeurs.isEmpty
                        ? null
                        : '${(admis * 100 / valeurs.length).round()} %',
                    couleur: AppTheme.statutVert,
                  ),
                  TuileKpi(
                    icone: Icons.cancel_rounded,
                    valeur: '${valeurs.length - admis}',
                    libelle: 'Ajournés',
                    couleur: AppTheme.statutRouge,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              BarreFiltres(
                filtres: [
                  FiltreDeroulant<String>(
                    libelle: 'Statut de la note',
                    valeur: _filtreStatut.isEmpty ? null : _filtreStatut,
                    options: const [
                      DropdownMenuItem(value: '', child: Text('Tous')),
                      DropdownMenuItem(
                        value: 'BROUILLON',
                        child: Text('Brouillon'),
                      ),
                      DropdownMenuItem(value: 'SOUMISE', child: Text('Soumise')),
                      DropdownMenuItem(
                        value: 'VALIDEE',
                        child: Text('Validée'),
                      ),
                    ],
                    onChange: (v) => setState(() => _filtreStatut = v ?? ''),
                  ),
                ],
              ),
              TableauDefilant(
                entetes: const [
                  'Étudiant',
                  'Matricule',
                  'Interro.',
                  'TP',
                  'Examen',
                  'Retenue',
                  'Mention',
                ],
                largeurMin: 760,
                lignes: [
                  for (final note in notes)
                    [
                      Text(
                        [note.texte('etudiantPrenom'), note.texte('etudiantNom')]
                            .where((v) => v.isNotEmpty)
                            .join(' '),
                      ),
                      Text(note.texte('matricule', defaut: '—')),
                      Text(_valeur(note, 'noteInterrogation')),
                      Text(_valeur(note, 'noteTP')),
                      Text(_valeur(note, 'noteExamen')),
                      Text(
                        _retenue(note)?.toStringAsFixed(1) ?? '—',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.accentLisible(
                            context,
                            (_retenue(note) ?? 0) >= 10
                                ? AppTheme.statutVert
                                : AppTheme.statutRouge,
                          ),
                        ),
                      ),
                      Text(
                        note.texte(
                          'mentionLibelle',
                          defaut: libelleMention(note.texteOuNul('mention')),
                        ),
                      ),
                    ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _valeur(Fiche note, String cle) {
    final v = note.decimalOuNul(cle);
    return v == null ? '—' : v.toStringAsFixed(1);
  }
}
