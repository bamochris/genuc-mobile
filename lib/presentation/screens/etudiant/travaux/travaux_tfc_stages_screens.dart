import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/fichiers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../data/services/appel_api.dart';
import '../../../../data/services/etudiant_academique_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/portail_widgets.dart';
import '../../commun/ecran_ressource.dart';

/// Travaux et devoirs, TFC et stage : les trois productions écrites que
/// l'étudiant dépose au cours de son cursus.

// ─────────────────────────────────────────────────────────────
// Travaux et devoirs
// ─────────────────────────────────────────────────────────────

class TravauxScreen extends StatelessWidget {
  const TravauxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<EtudiantAcademiqueService>();
    final inscriptionId =
        context.read<AuthProvider>().user?.inscriptionId ?? '';

    return EcranRessource(
      titre: 'Travaux et devoirs',
      sousTitre: 'À rendre et déjà rendus',
      messageVide: 'Aucun travail demandé pour le moment.',
      charger: () => service.travaux(inscriptionId),
      description: DescriptionFiche(
        icone: Icons.assignment_rounded,
        titre: (f) => f.texte('titre', defaut: 'Travail'),
        sousTitre: (f) => f.texteOuNul('cours', alias: const ['coursTitre']),
        statut: (f) => _statutTravail(f),
        details: (f) => [
          LigneDetail(
            libelle: 'À rendre avant le',
            valeur: formatDate(f.texteOuNul('dateEcheance'), avecHeure: true),
          ),
          if (f.texteOuNul('dateSoumission') != null)
            LigneDetail(
              libelle: 'Rendu le',
              valeur: formatDate(f.texteOuNul('dateSoumission'), avecHeure: true),
            ),
          if (f.decimalOuNul('note') != null)
            LigneDetail(
              libelle: 'Note',
              valeur: '${f.decimal('note').toStringAsFixed(1)} / '
                  '${f.decimalOuNul('coefficient')?.toStringAsFixed(0) ?? '20'}',
            ),
          if (f.texte('commentaireCorrection').isNotEmpty)
            LigneDetail(
              libelle: 'Correction',
              valeur: f.texte('commentaireCorrection'),
            ),
        ],
      ),
      actions: [
        ActionFiche(
          libelle: 'Consignes',
          icone: Icons.description_rounded,
          visiblePour: (f) => f.texte('urlConsignes').isNotEmpty,
          executer: (contexte, fiche) async {
            await Fichiers.ouvrirLien(fiche.texte('urlConsignes'));
          },
        ),
        ActionFiche(
          libelle: 'Déposer',
          icone: Icons.upload_file_rounded,
          couleur: AppTheme.statutVert,
          // Un travail déjà rendu n'est plus déposable : le serveur refuse la
          // seconde soumission, et proposer le bouton laisse croire l'inverse.
          visiblePour: (f) => f.texteOuNul('dateSoumission') == null,
          executer: (contexte, fiche) async {
            final fichier = await Fichiers.choisir();
            if (fichier == null) return;
            if (fichier.taille > Fichiers.tailleMaxOctets) {
              throw ArgumentError(
                'Fichier trop lourd (${fichier.tailleLisible}). '
                'Maximum accepté : 50 Mo.',
              );
            }
            await service.soumettreTravail(
              travailId: fiche.id,
              cheminFichier: fichier.chemin,
              nomFichier: fichier.nom,
            );
          },
        ),
      ],
    );
  }

  static (String, Color)? _statutTravail(Fiche f) {
    if (f.decimalOuNul('note') != null) {
      return ('Corrigé', AppTheme.statutVert);
    }
    if (f.texteOuNul('dateSoumission') != null) {
      return ('Rendu', AppTheme.statutBleu);
    }
    final echeance = f.date('dateEcheance');
    if (echeance != null && echeance.isBefore(DateTime.now())) {
      return ('En retard', AppTheme.statutRouge);
    }
    return ('À rendre', AppTheme.statutOrange);
  }
}

// ─────────────────────────────────────────────────────────────
// TFC / mémoire
// ─────────────────────────────────────────────────────────────

/// Suivi du travail de fin de cycle : sujet, encadreur, progression, dépôt.
///
/// La route rend UN objet (le TFC de l'étudiant), pas une liste : d'où un
/// écran de fiche plutôt qu'un [EcranRessource].
class TfcEtudiantScreen extends StatefulWidget {
  const TfcEtudiantScreen({super.key});

  @override
  State<TfcEtudiantScreen> createState() => _TfcEtudiantScreenState();
}

class _TfcEtudiantScreenState extends State<TfcEtudiantScreen> {
  Fiche? _tfc;
  bool _chargement = true;
  bool _depotEnCours = false;
  String? _erreur;
  String? _message;
  bool _messageSucces = true;

  String get _inscriptionId =>
      context.read<AuthProvider>().user?.inscriptionId ?? '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  Future<void> _charger() async {
    if (_inscriptionId.isEmpty) {
      setState(() {
        _chargement = false;
        _erreur = 'Aucune inscription active : travail de fin de cycle indisponible.';
      });
      return;
    }

    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final tfc =
          await context.read<EtudiantAcademiqueService>().tfc(_inscriptionId);
      if (!mounted) return;
      setState(() {
        _tfc = tfc;
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
    final tfc = _tfc;
    final progression = (tfc?.entier('progression') ?? 0) / 100;

    return PagePortail(
      titre: 'Travail de fin de cycle',
      sousTitre: 'Sujet, encadrement et dépôt',
      onRafraichir: _charger,
      floatingActionButton: tfc == null || tfc.donnees.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _depotEnCours ? null : _deposer,
              icon: _depotEnCours
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.upload_file_rounded),
              label: Text(_depotEnCours ? 'Envoi…' : 'Déposer'),
            ),
      corps: EtatRequete(
        chargement: _chargement,
        erreur: _erreur,
        vide: tfc == null || tfc.donnees.isEmpty,
        onReessayer: _charger,
        messageVide: 'Aucun travail de fin de cycle ne vous est encore attribué.',
        iconeVide: Icons.menu_book_rounded,
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
            CartePortail(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tfc?.texte('titre', alias: const ['sujet'], defaut: 'Travail de fin de cycle') ?? '',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 12),
                  BarreProgression(
                    valeur: progression,
                    libelle: 'Progression',
                  ),
                  const SizedBox(height: 14),
                  LigneDetail(
                    libelle: 'Type',
                    valeur: tfc?.texte('libelleType',
                            alias: const ['type'], defaut: '') ??
                        '',
                  ),
                  LigneDetail(
                    libelle: 'Encadreur',
                    valeur: tfc?.texte(
                          'encadreur',
                          alias: const ['professeurNom', 'promoteur'],
                        ) ??
                        '',
                  ),
                  LigneDetail(
                    libelle: 'Statut',
                    valeur: tfc?.texte('statut').replaceAll('_', ' ') ?? '',
                  ),
                  LigneDetail(
                    libelle: 'Déposé le',
                    valeur: formatDate(tfc?.texteOuNul('dateDepot')),
                  ),
                  LigneDetail(
                    libelle: 'Soutenance',
                    valeur: formatDate(tfc?.texteOuNul('dateSoutenance')),
                  ),
                  if (tfc?.decimalOuNul('note') != null)
                    LigneDetail(
                      libelle: 'Note',
                      valeur: '${tfc!.decimal('note').toStringAsFixed(1)} / 20',
                    ),
                ],
              ),
            ),
            if ((tfc?.liste('commentaires') ?? const <Fiche>[]).isNotEmpty) ...[
              const SizedBox(height: 20),
              const EnteteSection(
                titre: 'Retours de l\'encadreur',
                icone: Icons.forum_rounded,
              ),
              for (final commentaire in tfc!.liste('commentaires')) ...[
                CartePortail(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        commentaire.texte('contenu', alias: const ['commentaire']),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        formatDate(
                          commentaire.texteOuNul('date', alias: const ['creeLe']),
                          avecHeure: true,
                        ),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMutedOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _deposer() async {
    final fichier = await Fichiers.choisir(extensions: const ['pdf', 'doc', 'docx']);
    if (fichier == null || !mounted) return;

    if (fichier.taille > Fichiers.tailleMaxOctets) {
      setState(() {
        _message = 'Fichier trop lourd (${fichier.tailleLisible}). '
            'Maximum accepté : 50 Mo.';
        _messageSucces = false;
      });
      return;
    }

    setState(() => _depotEnCours = true);
    try {
      await context.read<EtudiantAcademiqueService>().deposerTfc(
            inscriptionId: _inscriptionId,
            cheminFichier: fichier.chemin,
            nomFichier: fichier.nom,
            titre: _tfc?.texteOuNul('titre'),
          );
      if (!mounted) return;
      setState(() {
        _message = 'Document déposé.';
        _messageSucces = true;
      });
      await _charger();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = e is ApiException ? e.message : e.toString();
        _messageSucces = false;
      });
    } finally {
      if (mounted) setState(() => _depotEnCours = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Stages
// ─────────────────────────────────────────────────────────────

/// Offres de stage et suivi du stage en cours.
class StagesEtudiantScreen extends StatefulWidget {
  const StagesEtudiantScreen({super.key});

  @override
  State<StagesEtudiantScreen> createState() => _StagesEtudiantScreenState();
}

class _StagesEtudiantScreenState extends State<StagesEtudiantScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _onglets = TabController(length: 2, vsync: this);

  Fiche? _monStage;
  List<Fiche> _offres = const [];
  bool _chargement = true;
  String? _erreur;
  String? _message;
  bool _messageSucces = true;

  String get _inscriptionId =>
      context.read<AuthProvider>().user?.inscriptionId ?? '';

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
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    final service = context.read<EtudiantAcademiqueService>();
    try {
      // Ne pas avoir de stage n'est pas une erreur : c'est le cas de tout
      // étudiant avant sa dernière année.
      final stage = _inscriptionId.isEmpty
          ? const Fiche({})
          : await service
              .stage(_inscriptionId)
              .catchError((_) => const Fiche({}));
      final offres = await service.offresStages().catchError((_) => <Fiche>[]);
      if (!mounted) return;
      setState(() {
        _monStage = stage;
        _offres = offres;
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
      titre: 'Mon stage',
      sousTitre: 'Offres et suivi',
      onRafraichir: _charger,
      bottomAppBar: TabBar(
        controller: _onglets,
        tabs: const [Tab(text: 'Mon stage'), Tab(text: 'Offres')],
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
                children: [_vueMonStage(), _vueOffres()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vueMonStage() {
    final stage = _monStage;
    if (stage == null || stage.donnees.isEmpty) {
      return ListView(
        padding: Responsive.margePage(context),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 60),
          CartePortail(
            child: Column(
              children: [
                Icon(
                  Icons.business_center_rounded,
                  size: 40,
                  color: AppTheme.textMutedOf(context),
                ),
                const SizedBox(height: 12),
                Text(
                  'Aucun stage en cours.',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'Postulez à une offre depuis l\'onglet voisin : votre stage '
                  'apparaîtra ici une fois la convention validée.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryOf(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: Responsive.margePage(context),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        CartePortail(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      stage.texte(
                        'entreprise',
                        alias: const ['organisme', 'titre'],
                        defaut: 'Stage',
                      ),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  if (stage.texte('statut').isNotEmpty)
                    Pastille(
                      texte: stage.texte('statut').replaceAll('_', ' '),
                      couleur: _couleurStatut(stage.texte('statut')),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              LigneDetail(libelle: 'Poste', valeur: stage.texte('poste')),
              LigneDetail(libelle: 'Encadreur', valeur: stage.texte('encadreur')),
              LigneDetail(
                libelle: 'Période',
                valeur: [
                  formatDate(stage.texteOuNul('dateDebut')),
                  formatDate(stage.texteOuNul('dateFin')),
                ].where((d) => d != '—').join(' → '),
              ),
              LigneDetail(libelle: 'Lieu', valeur: stage.texte('lieu')),
              if (stage.decimalOuNul('note') != null)
                LigneDetail(
                  libelle: 'Note du rapport',
                  valeur: '${stage.decimal('note').toStringAsFixed(1)} / 20',
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _deposerRapport,
          icon: const Icon(Icons.upload_file_rounded, size: 18),
          label: const Text('Déposer mon rapport de stage'),
        ),
      ],
    );
  }

  Widget _vueOffres() {
    if (_offres.isEmpty) {
      return ListView(
        padding: Responsive.margePage(context),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Text(
            'Aucune offre de stage publiée.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textMutedOf(context)),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: Responsive.margePage(context),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _offres.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final offre = _offres[i];
        return CartePortail(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                offre.texte('titre', alias: const ['poste'], defaut: 'Offre'),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                offre.texte('entreprise', alias: const ['organisme']),
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondaryOf(context),
                ),
              ),
              if (offre.texte('description').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  offre.texte('description'),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryOf(context),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              LigneDetail(libelle: 'Lieu', valeur: offre.texte('lieu')),
              LigneDetail(libelle: 'Durée', valeur: offre.texte('duree')),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _postuler(offre),
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Postuler'),
                  style: TextButton.styleFrom(
                    foregroundColor:
                        AppTheme.accentLisible(context, AppTheme.statutVert),
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

  static Color _couleurStatut(String code) => switch (code.toUpperCase()) {
        'VALIDE' || 'EN_COURS' => AppTheme.statutVert,
        'TERMINE' => AppTheme.statutNavy,
        'REJETE' || 'REFUSE' => AppTheme.statutRouge,
        _ => AppTheme.statutOrange,
      };

  Future<void> _postuler(Fiche offre) async {
    final controleur = TextEditingController();
    final lettre = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lettre de motivation'),
        content: TextField(
          controller: controleur,
          autofocus: true,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Pourquoi ce stage vous intéresse-t-il ?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controleur.text.trim()),
            child: const Text('Postuler'),
          ),
        ],
      ),
    );
    controleur.dispose();
    if (lettre == null || !mounted) return;

    try {
      await context
          .read<EtudiantAcademiqueService>()
          .postulerStage(offre.id, lettre: lettre.isEmpty ? null : lettre);
      if (!mounted) return;
      setState(() {
        _message = 'Candidature envoyée.';
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

  Future<void> _deposerRapport() async {
    final fichier = await Fichiers.choisir(extensions: const ['pdf', 'doc', 'docx']);
    if (fichier == null || !mounted) return;

    if (fichier.taille > Fichiers.tailleMaxOctets) {
      setState(() {
        _message = 'Fichier trop lourd (${fichier.tailleLisible}). '
            'Maximum accepté : 50 Mo.';
        _messageSucces = false;
      });
      return;
    }

    try {
      await context.read<EtudiantAcademiqueService>().deposerRapportStage(
            inscriptionId: _inscriptionId,
            cheminFichier: fichier.chemin,
            nomFichier: fichier.nom,
          );
      if (!mounted) return;
      setState(() {
        _message = 'Rapport de stage déposé.';
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
