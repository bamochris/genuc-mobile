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

/// Calcul de la note finale à partir des composantes et du barème du cours.
///
/// La pondération vient du barème enregistré pour le cours ; à défaut, du
/// 30 / 20 / 50 utilisé par le portail web. Elle est affichée en clair :
/// appliquer une pondération invisible fausse toutes les notes sans que
/// l'enseignant puisse s'en apercevoir.
class CalculsNotesScreen extends StatefulWidget {
  const CalculsNotesScreen({super.key});

  @override
  State<CalculsNotesScreen> createState() => _CalculsNotesScreenState();
}

class _CalculsNotesScreenState extends State<CalculsNotesScreen> {
  Map<String, String> _cours = const {};
  Map<String, String> _anneeParCours = const {};
  String? _coursId;

  List<_LigneCalcul> _lignes = [];
  int _ponderationTp = 30;
  int _ponderationInterro = 20;
  int _ponderationExamen = 50;
  bool _baremePersonnalise = false;

  bool _chargement = true;
  bool _chargementDonnees = false;
  String? _erreur;
  String? _message;
  bool _messageSucces = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _chargerCours());
  }

  ProfesseurPedagogieService get _service =>
      context.read<ProfesseurPedagogieService>();

  Future<void> _chargerCours() async {
    final professeurId = context.read<AuthProvider>().user?.id ?? '';
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final cours = await _service.mesCours(professeurId);
      if (!mounted) return;
      setState(() {
        _cours = {
          for (final c in cours)
            c.id: [c.texte('code'), c.texte('titre')]
                .where((v) => v.isNotEmpty)
                .join(' – '),
        };
        _anneeParCours = {
          for (final c in cours)
            c.id: c.texte('anneeAcademique', defaut: anneeAcademiqueCourante()),
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

  Future<void> _chargerDonnees(String coursId) async {
    setState(() {
      _chargementDonnees = true;
      _message = null;
    });

    final annee = _anneeParCours[coursId] ?? anneeAcademiqueCourante();

    try {
      final inscrits = await _service.etudiantsDuCours(coursId);
      final notes = await _service.notesDuCours(coursId, annee);

      // Le barème est facultatif : son absence n'empêche pas le calcul, elle
      // ramène simplement à la pondération par défaut.
      List<Fiche> baremes = const [];
      try {
        baremes = await _service.baremesDuCours(coursId);
      } catch (_) {
        baremes = const [];
      }

      final parInscription = <String, Fiche>{
        for (final n in notes) n.texte('inscriptionId'): n,
      };

      if (!mounted) return;
      setState(() {
        final bareme = baremes.isEmpty ? null : baremes.first;
        _baremePersonnalise = bareme != null;
        _ponderationTp = bareme?.entier('ponderationTP', defaut: 30) ?? 30;
        _ponderationInterro =
            bareme?.entier('ponderationInterro', defaut: 20) ?? 20;
        _ponderationExamen = bareme?.entier('ponderationExamen', defaut: 50) ?? 50;

        _lignes = inscrits.map((e) {
          final note = parInscription[e.id];
          return _LigneCalcul(
            inscriptionId: e.id,
            nom: [e.texte('prenom'), e.texte('nom')]
                .where((v) => v.isNotEmpty)
                .join(' '),
            matricule: e.texte('matricule'),
            tp: note?.decimal('noteTP') ?? 0,
            interrogation: note?.decimal('noteInterrogation') ?? 0,
            examen: note?.decimal('noteExamen') ?? 0,
          );
        }).toList();
        _chargementDonnees = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _lignes = [];
        _chargementDonnees = false;
        _message = e.message;
        _messageSucces = false;
      });
    }
  }

  double _finale(_LigneCalcul ligne) {
    final total = ligne.tp * _ponderationTp +
        ligne.interrogation * _ponderationInterro +
        ligne.examen * _ponderationExamen;
    return (total / 100 * 100).round() / 100;
  }

  @override
  Widget build(BuildContext context) {
    return PagePortail(
      titre: 'Calcul des notes',
      sousTitre: 'Note finale à partir des composantes',
      onRafraichir: _chargerCours,
      floatingActionButton: _lignes.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _enregistrer,
              icon: const Icon(Icons.calculate_rounded),
              label: const Text('Calculer et enregistrer'),
            ),
      corps: EtatRequete(
        chargement: _chargement,
        erreur: _erreur,
        vide: _cours.isEmpty,
        onReessayer: _chargerCours,
        iconeVide: Icons.menu_book_rounded,
        messageVide: 'Aucun cours ne vous est attribué.',
        enfant: ListView(
          padding: Responsive.margePage(context).copyWith(bottom: 96),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (_message != null)
              BandeauMessage(
                message: _message!,
                succes: _messageSucces,
                onFermer: () => setState(() => _message = null),
              ),
            SelecteurCours(
              valeur: _coursId,
              cours: _cours,
              onChange: (v) {
                setState(() {
                  _coursId = v;
                  _lignes = [];
                });
                if (v != null) _chargerDonnees(v);
              },
            ),
            const SizedBox(height: 16),
            if (_coursId != null)
              CartePortail(
                child: Row(
                  children: [
                    Icon(
                      Icons.balance_rounded,
                      size: 18,
                      color: AppTheme.iconAccent(context),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Barème ${_baremePersonnalise ? 'du cours' : 'par défaut'} : '
                        'TP $_ponderationTp % · '
                        'Interro $_ponderationInterro % · '
                        'Examen $_ponderationExamen %',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondaryOf(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            if (_chargementDonnees)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_lignes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  _coursId == null
                      ? 'Sélectionnez un cours.'
                      : 'Aucun étudiant inscrit à ce cours.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textMutedOf(context)),
                ),
              )
            else
              TableauDefilant(
                entetes: const [
                  'Étudiant',
                  'Matricule',
                  'TP',
                  'Interro',
                  'Examen',
                  'Finale',
                ],
                largeurMin: 640,
                lignes: [
                  for (final ligne in _lignes)
                    [
                      Text(ligne.nom),
                      Text(ligne.matricule),
                      Text(ligne.tp.toStringAsFixed(2)),
                      Text(ligne.interrogation.toStringAsFixed(2)),
                      Text(ligne.examen.toStringAsFixed(2)),
                      Text(
                        _finale(ligne).toStringAsFixed(2),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.accentLisible(
                            context,
                            _finale(ligne) >= 10
                                ? AppTheme.statutVert
                                : AppTheme.statutRouge,
                          ),
                        ),
                      ),
                    ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _enregistrer() async {
    final coursId = _coursId;
    if (coursId == null || _lignes.isEmpty) return;

    final annee = _anneeParCours[coursId] ?? anneeAcademiqueCourante();
    try {
      await _service.lancerCalcul(coursId, annee: annee);
      if (!mounted) return;
      setState(() {
        _message = 'Les notes ont été calculées et enregistrées.';
        _messageSucces = true;
      });
      await _chargerDonnees(coursId);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _message = e.message;
        _messageSucces = false;
      });
    }
  }
}

class _LigneCalcul {
  final String inscriptionId;
  final String nom;
  final String matricule;
  final double tp;
  final double interrogation;
  final double examen;

  const _LigneCalcul({
    required this.inscriptionId,
    required this.nom,
    required this.matricule,
    required this.tp,
    required this.interrogation,
    required this.examen,
  });
}

/// Historique des notes encodées par l'enseignant, filtrable par cours et par
/// statut.
class HistoriqueNotesScreen extends StatefulWidget {
  const HistoriqueNotesScreen({super.key});

  @override
  State<HistoriqueNotesScreen> createState() => _HistoriqueNotesScreenState();
}

class _HistoriqueNotesScreenState extends State<HistoriqueNotesScreen> {
  List<Fiche> _historique = const [];
  Map<String, String> _cours = const {};
  String? _filtreCours;
  String? _filtreStatut;

  bool _chargement = true;
  String? _erreur;

  // Circuit ESU de validation : le professeur soumet, le chef de département
  // vise, le doyen valide, l'administration publie. `VALIDEE_CHEF` est l'étape
  // intermédiaire — elle n'existait pas côté serveur, où le chef et le doyen se
  // partageaient une transition unique. Sans cette entrée, le repli affiche la
  // valeur brute de l'énumération au professeur.
  static const Map<String, (String, Color)> _statuts = {
    'EN_COURS': ('En cours', AppTheme.statutOrange),
    'SOUMISE': ('Soumise', AppTheme.statutBleu),
    'VALIDEE_CHEF': ('Visée par le département', AppTheme.statutBleu),
    'VALIDEE': ('Validée par le doyen', AppTheme.statutViolet),
    'PUBLIEE': ('Publiée', AppTheme.statutVert),
  };

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
      final historique = await service.historiqueNotes(professeurId);
      if (!mounted) return;
      setState(() {
        _cours = {for (final c in cours) c.id: c.texte('code')};
        _historique = historique;
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

  List<Fiche> get _filtrees => _historique.where((n) {
        final cours = _filtreCours == null ||
            n.texte('coursId') == _filtreCours;
        final statut =
            _filtreStatut == null || n.texte('statut') == _filtreStatut;
        return cours && statut;
      }).toList();

  @override
  Widget build(BuildContext context) {
    return PagePortail(
      titre: 'Historique des notes',
      sousTitre: 'Notes encodées, tous cours confondus',
      onRafraichir: _charger,
      corps: EtatRequete(
        chargement: _chargement,
        erreur: _erreur,
        vide: _historique.isEmpty,
        onReessayer: _charger,
        iconeVide: Icons.history_rounded,
        messageVide: 'Aucune note encodée.',
        enfant: ListView(
          padding: Responsive.margePage(context),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            BarreFiltres(
              filtres: [
                FiltreDeroulant<String>(
                  libelle: 'Cours',
                  valeur: _filtreCours,
                  options: [
                    const DropdownMenuItem(value: null, child: Text('Tous')),
                    for (final entree in _cours.entries)
                      DropdownMenuItem(
                        value: entree.key,
                        child: Text(entree.value),
                      ),
                  ],
                  onChange: (v) => setState(() => _filtreCours = v),
                ),
                FiltreDeroulant<String>(
                  libelle: 'Statut',
                  valeur: _filtreStatut,
                  options: [
                    const DropdownMenuItem(value: null, child: Text('Tous')),
                    for (final entree in _statuts.entries)
                      DropdownMenuItem(
                        value: entree.key,
                        child: Text(entree.value.$1),
                      ),
                  ],
                  onChange: (v) => setState(() => _filtreStatut = v),
                ),
              ],
            ),
            if (_filtrees.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  'Aucune note ne correspond à ces filtres.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textMutedOf(context)),
                ),
              )
            else
              for (final note in _filtrees) ...[
                _CarteNoteHistorique(note: note, statuts: _statuts),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}

class _CarteNoteHistorique extends StatelessWidget {
  final Fiche note;
  final Map<String, (String, Color)> statuts;

  const _CarteNoteHistorique({required this.note, required this.statuts});

  @override
  Widget build(BuildContext context) {
    // `noteRetenue` prime sur `noteFinale` : c'est elle qui compte après
    // rattrapage.
    final valeur =
        note.decimalOuNul('noteRetenue') ?? note.decimalOuNul('noteFinale');
    final statut = statuts[note.texte('statut')] ??
        (note.texte('statut'), AppTheme.statutNavy);

    return CartePortail(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  [note.texte('etudiantPrenom'), note.texte('etudiantNom')]
                          .where((v) => v.isNotEmpty)
                          .join(' ')
                          .trim()
                          .isEmpty
                      ? '—'
                      : [note.texte('etudiantPrenom'), note.texte('etudiantNom')]
                          .where((v) => v.isNotEmpty)
                          .join(' '),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Pastille(texte: statut.$1, couleur: statut.$2),
            ],
          ),
          const SizedBox(height: 6),
          LigneDetail(libelle: 'Cours', valeur: note.texte('coursCode')),
          LigneDetail(
            libelle: 'Note',
            valeur: valeur == null ? '—' : '${valeur.toStringAsFixed(2)}/20',
          ),
          LigneDetail(
            libelle: 'Année',
            valeur: note.texte('anneeAcademique', defaut: '—'),
          ),
          LigneDetail(
            libelle: 'Encodée le',
            valeur: formatDateObjet(note.date('creeLe')),
          ),
        ],
      ),
    );
  }
}
