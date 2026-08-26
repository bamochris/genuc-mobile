import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../data/services/appel_api.dart';
import '../../../../data/services/etudiant_academique_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/etat_widgets.dart';
import '../../../widgets/portail_widgets.dart';
import '../../commun/ecran_ressource.dart';

/// Vie universitaire : clubs et événements du campus.
///
/// Transposition de `etudiant/vie-universitaire/VieUniversitaire.jsx`. Les
/// deux listes sont dans deux onglets plutôt que deux colonnes : sur
/// téléphone, la seconde colonne du web tombait sous la ligne de flottaison.
class VieUniversitaireScreen extends StatefulWidget {
  const VieUniversitaireScreen({super.key});

  @override
  State<VieUniversitaireScreen> createState() => _VieUniversitaireScreenState();
}

class _VieUniversitaireScreenState extends State<VieUniversitaireScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _onglets = TabController(length: 2, vsync: this);

  List<Fiche> _clubs = const [];
  List<Fiche> _mesClubs = const [];
  List<Fiche> _evenements = const [];
  bool _chargement = true;
  String? _erreur;
  String? _message;
  bool _messageSucces = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  @override
  void dispose() {
    _onglets.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    final user = context.read<AuthProvider>().user;
    final universiteId = user?.universiteId ?? '';
    final inscriptionId = user?.inscriptionId ?? '';
    if (universiteId.isEmpty) {
      setState(() {
        _chargement = false;
        _erreur = 'Établissement inconnu : vie universitaire indisponible.';
      });
      return;
    }

    setState(() {
      _chargement = true;
      _erreur = null;
    });
    final service = context.read<EtudiantAcademiqueService>();
    try {
      final resultats = await Future.wait([
        service.clubs(universiteId).catchError((_) => <Fiche>[]),
        service.evenementsCampus(universiteId).catchError((_) => <Fiche>[]),
        if (inscriptionId.isNotEmpty)
          service.mesClubs(inscriptionId).catchError((_) => <Fiche>[])
        else
          Future.value(<Fiche>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _clubs = resultats[0];
        _evenements = resultats[1];
        _mesClubs = resultats[2];
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

  /// Identifiants des clubs déjà rejoints : c'est ce qui décide du bouton
  /// affiché (rejoindre ou quitter).
  Set<String> get _idsMesClubs => _mesClubs
      .map((c) => c.texte('id', alias: const ['clubId']))
      .where((id) => id.isNotEmpty)
      .toSet();

  @override
  Widget build(BuildContext context) {
    return PagePortail(
      titre: 'Vie universitaire',
      sousTitre: 'Clubs et événements du campus',
      onRafraichir: _charger,
      bottomAppBar: TabBar(
        controller: _onglets,
        tabs: const [Tab(text: 'Clubs'), Tab(text: 'Événements')],
      ),
      corps: EtatRequete(
        chargement: _chargement,
        erreur: _erreur,
        vide: false,
        onReessayer: _charger,
        enfant: Column(
          children: [
            if (_message != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: BandeauMessage(
                  message: _message!,
                  succes: _messageSucces,
                  onFermer: () => setState(() => _message = null),
                ),
              ),
            Expanded(
              child: TabBarView(
                controller: _onglets,
                children: [_listeClubs(), _listeEvenements()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listeClubs() {
    if (_clubs.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 80),
          EtatVide(
            icon: Icons.groups_rounded,
            titre: 'Aucun club déclaré sur votre campus.',
          ),
        ],
      );
    }

    final mesIds = _idsMesClubs;
    return ListView.separated(
      padding: Responsive.margePage(context),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _clubs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final club = _clubs[i];
        final membre = mesIds.contains(club.id);

        return CartePortail(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      club.texte('nom', defaut: 'Club'),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  if (membre)
                    const Pastille(
                      texte: 'Membre',
                      couleur: AppTheme.statutVert,
                      icone: Icons.check_rounded,
                    ),
                ],
              ),
              if (club.texte('description').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  club.texte('description'),
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondaryOf(context),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 14,
                runSpacing: 4,
                children: [
                  if (club.texte('domaine').isNotEmpty)
                    _Meta(
                      icone: Icons.category_rounded,
                      texte: club.texte('domaine'),
                    ),
                  _Meta(
                    icone: Icons.people_rounded,
                    texte: '${club.entier('membresCount')} membre(s)',
                  ),
                  if (club.texte('responsable').isNotEmpty)
                    _Meta(
                      icone: Icons.person_rounded,
                      texte: club.texte('responsable'),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: membre
                    ? TextButton.icon(
                        onPressed: () => _agirSurClub(club, rejoindre: false),
                        icon: const Icon(Icons.logout_rounded, size: 16),
                        label: const Text('Quitter'),
                        style: TextButton.styleFrom(
                          foregroundColor:
                              AppTheme.accentLisible(context, AppTheme.error),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                    : TextButton.icon(
                        onPressed: () => _agirSurClub(club, rejoindre: true),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Rejoindre'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.accentLisible(
                            context,
                            AppTheme.statutVert,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _listeEvenements() {
    if (_evenements.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 80),
          EtatVide(
            icon: Icons.event_rounded,
            titre: 'Aucun événement programmé.',
          ),
        ],
      );
    }

    return ListView.separated(
      padding: Responsive.margePage(context),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _evenements.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final evenement = _evenements[i];
        return CartePortail(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                evenement.texte('titre', defaut: 'Événement'),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              if (evenement.texte('description').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  evenement.texte('description'),
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondaryOf(context),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 14,
                runSpacing: 4,
                children: [
                  _Meta(
                    icone: Icons.calendar_today_rounded,
                    texte: formatDate(evenement.texteOuNul('date')),
                  ),
                  if (evenement.texte('heure').isNotEmpty)
                    _Meta(
                      icone: Icons.schedule_rounded,
                      texte: evenement.texte('heure'),
                    ),
                  if (evenement.texte('lieu').isNotEmpty)
                    _Meta(
                      icone: Icons.room_rounded,
                      texte: evenement.texte('lieu'),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _sInscrire(evenement),
                  icon: const Icon(Icons.how_to_reg_rounded, size: 16),
                  label: const Text('Je participe'),
                  style: TextButton.styleFrom(
                    foregroundColor:
                        AppTheme.accentLisible(context, AppTheme.statutBleu),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _agirSurClub(Fiche club, {required bool rejoindre}) async {
    final service = context.read<EtudiantAcademiqueService>();
    try {
      if (rejoindre) {
        await service.rejoindreClub(club.id);
      } else {
        await service.quitterClub(club.id);
      }
      if (!mounted) return;
      setState(() {
        _message = rejoindre
            ? 'Vous avez rejoint « ${club.texte('nom')} ».'
            : 'Vous avez quitté « ${club.texte('nom')} ».';
        _messageSucces = true;
      });
      await _charger();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = e is ApiException ? e.message : e.toString();
        _messageSucces = false;
      });
    }
  }

  Future<void> _sInscrire(Fiche evenement) async {
    try {
      await context
          .read<EtudiantAcademiqueService>()
          .sInscrireEvenement(evenement.id);
      if (!mounted) return;
      setState(() {
        _message = 'Inscription enregistrée pour « ${evenement.texte('titre')} ».';
        _messageSucces = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = e is ApiException ? e.message : e.toString();
        _messageSucces = false;
      });
    }
  }
}

class _Meta extends StatelessWidget {
  final IconData icone;
  final String texte;

  const _Meta({required this.icone, required this.texte});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icone, size: 13, color: AppTheme.textMutedOf(context)),
        const SizedBox(width: 4),
        Text(
          texte,
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Jobs universitaires
// ─────────────────────────────────────────────────────────────

/// Offres d'emploi étudiant et suivi des candidatures.
///
/// Transposition de `MesJobsUniversitaires.jsx`.
class JobsUniversitairesScreen extends StatefulWidget {
  const JobsUniversitairesScreen({super.key});

  @override
  State<JobsUniversitairesScreen> createState() =>
      _JobsUniversitairesScreenState();
}

class _JobsUniversitairesScreenState extends State<JobsUniversitairesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _onglets = TabController(length: 3, vsync: this);

  List<Fiche> _offres = const [];
  List<Fiche> _candidatures = const [];
  List<Fiche> _contrats = const [];
  bool _chargement = true;
  String? _erreur;
  String? _message;
  bool _messageSucces = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  @override
  void dispose() {
    _onglets.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    final etudiantId = context.read<AuthProvider>().user?.id ?? '';
    if (etudiantId.isEmpty) {
      setState(() {
        _chargement = false;
        _erreur = 'Compte incomplet : offres indisponibles.';
      });
      return;
    }

    setState(() {
      _chargement = true;
      _erreur = null;
    });
    final service = context.read<EtudiantAcademiqueService>();
    try {
      final resultats = await Future.wait([
        service.offresEmploi(etudiantId).catchError((_) => <Fiche>[]),
        service.mesCandidatures(etudiantId).catchError((_) => <Fiche>[]),
        service.mesContratsEtudiant(etudiantId).catchError((_) => <Fiche>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _offres = resultats[0];
        _candidatures = resultats[1];
        _contrats = resultats[2];
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

  @override
  Widget build(BuildContext context) {
    return PagePortail(
      titre: 'Jobs universitaires',
      sousTitre: 'Travailler pendant mes études',
      onRafraichir: _charger,
      bottomAppBar: TabBar(
        controller: _onglets,
        tabs: const [
          Tab(text: 'Offres'),
          Tab(text: 'Candidatures'),
          Tab(text: 'Contrats'),
        ],
      ),
      corps: EtatRequete(
        chargement: _chargement,
        erreur: _erreur,
        vide: false,
        onReessayer: _charger,
        enfant: Column(
          children: [
            if (_message != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: BandeauMessage(
                  message: _message!,
                  succes: _messageSucces,
                  onFermer: () => setState(() => _message = null),
                ),
              ),
            Expanded(
              child: TabBarView(
                controller: _onglets,
                children: [
                  _liste(
                    fiches: _offres,
                    icone: Icons.work_rounded,
                    vide: 'Aucune offre ouverte pour le moment.',
                    titre: (f) => f.texte('poste', alias: const ['titre'], defaut: 'Offre'),
                    lignes: (f) => [
                      LigneDetail(libelle: 'Département', valeur: f.texte('departement')),
                      LigneDetail(
                        libelle: 'Heures / semaine',
                        valeur: '${f.entier('heuresParSemaine')}',
                      ),
                      LigneDetail(
                        libelle: 'Rémunération',
                        valeur: f.decimalOuNul('salaireNet') == null
                            ? ''
                            : formatMontant(
                                f.decimal('salaireNet'),
                                f.texte('devise', defaut: 'USD'),
                              ),
                      ),
                    ],
                    action: (f) => TextButton.icon(
                      onPressed: () => _postuler(f),
                      icon: const Icon(Icons.send_rounded, size: 16),
                      label: const Text('Postuler'),
                      style: TextButton.styleFrom(
                        foregroundColor:
                            AppTheme.accentLisible(context, AppTheme.statutVert),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                  _liste(
                    fiches: _candidatures,
                    icone: Icons.assignment_turned_in_rounded,
                    vide: 'Vous n\'avez postulé à aucune offre.',
                    titre: (f) => f.texte(
                      'poste',
                      alias: const ['offre'],
                      defaut: 'Candidature',
                    ),
                    statut: (f) => _statutCandidature(f.texte('statut')),
                    lignes: (f) => [
                      LigneDetail(
                        libelle: 'Déposée le',
                        valeur: formatDate(f.texteOuNul('dateCandidature')),
                      ),
                      if (f.texte('motif').isNotEmpty)
                        LigneDetail(libelle: 'Motif', valeur: f.texte('motif')),
                    ],
                  ),
                  _liste(
                    fiches: _contrats,
                    icone: Icons.description_rounded,
                    vide: 'Aucun contrat en cours.',
                    titre: (f) => f.texte('poste', defaut: 'Contrat'),
                    statut: (f) => _statutCandidature(f.texte('statut')),
                    lignes: (f) => [
                      LigneDetail(libelle: 'Département', valeur: f.texte('departement')),
                      LigneDetail(
                        libelle: 'Début',
                        valeur: formatDate(f.texteOuNul('dateDebut')),
                      ),
                      LigneDetail(libelle: 'Durée', valeur: f.texte('duree')),
                      LigneDetail(
                        libelle: 'Rémunération',
                        valeur: f.decimalOuNul('salaireNet') == null
                            ? ''
                            : formatMontant(
                                f.decimal('salaireNet'),
                                f.texte('devise', defaut: 'USD'),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _liste({
    required List<Fiche> fiches,
    required IconData icone,
    required String vide,
    required String Function(Fiche) titre,
    required List<LigneDetail> Function(Fiche) lignes,
    (String, Color)? Function(Fiche)? statut,
    Widget Function(Fiche)? action,
  }) {
    if (fiches.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          EtatVide(icon: icone, titre: vide),
        ],
      );
    }

    return ListView.separated(
      padding: Responsive.margePage(context),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: fiches.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final fiche = fiches[i];
        final pastille = statut?.call(fiche);
        return CartePortail(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      titre(fiche),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  if (pastille != null)
                    Pastille(texte: pastille.$1, couleur: pastille.$2),
                ],
              ),
              const SizedBox(height: 6),
              ...lignes(fiche).where((l) => l.valeur.isNotEmpty),
              if (action != null) ...[
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerLeft, child: action(fiche)),
              ],
            ],
          ),
        );
      },
    );
  }

  static (String, Color)? _statutCandidature(String code) =>
      switch (code.toUpperCase()) {
        'EN_ATTENTE' || 'SOUMISE' => ('En attente', AppTheme.statutOrange),
        'ACCEPTEE' || 'ACCEPTE' || 'ACTIF' => ('Acceptée', AppTheme.statutVert),
        'REFUSEE' || 'REJETEE' => ('Refusée', AppTheme.statutRouge),
        'TERMINE' || 'TERMINEE' => ('Terminé', AppTheme.statutNavy),
        '' => null,
        _ => (code.replaceAll('_', ' '), AppTheme.statutNavy),
      };

  Future<void> _postuler(Fiche offre) async {
    final etudiantId = context.read<AuthProvider>().user?.id ?? '';
    final service = context.read<EtudiantAcademiqueService>();
    try {
      await service.postulerEmploi({
        'offreId': offre.id,
        'etudiantId': etudiantId,
      });
      if (!mounted) return;
      setState(() {
        _message = 'Candidature envoyée pour « ${offre.texte('poste')} ».';
        _messageSucces = true;
      });
      await _charger();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = e is ApiException ? e.message : e.toString();
        _messageSucces = false;
      });
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Évaluation des enseignants
// ─────────────────────────────────────────────────────────────

/// L'étudiant note ses enseignants. Une évaluation déjà remise n'est plus
/// modifiable — c'est la règle du web, et la rendre modifiable ici fausserait
/// des moyennes déjà agrégées côté serveur.
class EvaluationEnseignantsScreen extends StatelessWidget {
  const EvaluationEnseignantsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<EtudiantAcademiqueService>();
    final inscriptionId =
        context.read<AuthProvider>().user?.inscriptionId ?? '';

    return EcranRessource(
      titre: 'Évaluation des enseignements',
      sousTitre: 'Votre avis sur les cours suivis',
      messageVide: 'Aucune évaluation ouverte pour le moment.',
      charger: () => service.evaluationsAFaire(inscriptionId),
      description: DescriptionFiche(
        icone: Icons.star_rounded,
        titre: (f) => f.texte(
          'coursTitre',
          alias: const ['cours', 'titre'],
          defaut: 'Évaluation',
        ),
        sousTitre: (f) => f.texteOuNul('professeurNom', alias: const ['professeur']),
        statut: (f) => f.booleen('complete', alias: const ['soumise'])
            ? ('Remise', AppTheme.statutVert)
            : ('À remplir', AppTheme.statutOrange),
        details: (f) => [
          if (f.texteOuNul('dateLimite') != null)
            LigneDetail(
              libelle: 'À remettre avant le',
              valeur: formatDate(f.texteOuNul('dateLimite')),
            ),
        ],
      ),
      actions: [
        ActionFiche(
          libelle: 'Évaluer',
          icone: Icons.rate_review_rounded,
          visiblePour: (f) => !f.booleen('complete', alias: const ['soumise']),
          executer: (contexte, fiche) async {
            final valeurs = await _formulaireEvaluation(contexte);
            if (valeurs == null) return;
            await service.soumettreEvaluation({
              ...valeurs,
              'coursId': fiche.texte('coursId', alias: const ['id']),
              'professeurId': fiche.texte('professeurId'),
              'inscriptionId': inscriptionId,
            });
          },
        ),
      ],
    );
  }

  static Future<Map<String, dynamic>?> _formulaireEvaluation(
    BuildContext context,
  ) {
    return DialogueFormulaireEvaluation.ouvrir(context);
  }
}

/// Grille d'évaluation : quatre critères notés de 1 à 5, plus un commentaire
/// libre — la même que le formulaire web.
class DialogueFormulaireEvaluation {
  DialogueFormulaireEvaluation._();

  static Future<Map<String, dynamic>?> ouvrir(BuildContext context) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _DialogueEvaluation(),
    );
  }
}

class _DialogueEvaluation extends StatefulWidget {
  const _DialogueEvaluation();

  @override
  State<_DialogueEvaluation> createState() => _DialogueEvaluationState();
}

class _DialogueEvaluationState extends State<_DialogueEvaluation> {
  static const Map<String, String> _criteres = {
    'noteContenu': 'Contenu du cours',
    'notePedagogie': 'Qualité pédagogique',
    'noteDisponibilite': 'Disponibilité',
    'noteEvaluation': 'Équité de l\'évaluation',
  };

  final Map<String, int> _notes = {
    for (final cle in _criteres.keys) cle: 3,
  };
  final _commentaire = TextEditingController();

  @override
  void dispose() {
    _commentaire.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contenu = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entree in _criteres.entries) ...[
          Text(
            entree.value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryOf(context),
            ),
          ),
          Row(
            children: [
              for (var note = 1; note <= 5; note++)
                IconButton(
                  icon: Icon(
                    (_notes[entree.key] ?? 0) >= note
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: AppTheme.accentLisible(context, AppTheme.warning),
                  ),
                  visualDensity: VisualDensity.compact,
                  tooltip: '$note / 5',
                  onPressed: () => setState(() => _notes[entree.key] = note),
                ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: _commentaire,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Commentaire (facultatif)',
            alignLabelWithHint: true,
          ),
        ),
      ],
    );

    return AlertDialog(
      title: const Text('Évaluer cet enseignement'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(child: contenu),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, {
            ..._notes,
            'commentaire': _commentaire.text.trim(),
          }),
          child: const Text('Envoyer'),
        ),
      ],
    );
  }
}
