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
import '../../../widgets/formulaire_dynamique.dart';
import '../../../widgets/portail_widgets.dart';
import '../../commun/ecran_ressource.dart';

/// Module « Résultats » du portail étudiant : bulletins, parcours et recours.
///
/// Les trois pages web (`bulletins/Bulletins.jsx`,
/// `parcours/ParcoursAcademique.jsx`, `recours/RecoursAcademiques.jsx`)
/// partagent la même source — la délibération — mais répondent à trois
/// questions différentes : qu'ai-je obtenu, où en suis-je, et comment
/// contester.

// ─────────────────────────────────────────────────────────────
// Bulletins
// ─────────────────────────────────────────────────────────────

class BulletinsScreen extends StatefulWidget {
  const BulletinsScreen({super.key});

  @override
  State<BulletinsScreen> createState() => _BulletinsScreenState();
}

class _BulletinsScreenState extends State<BulletinsScreen> {
  List<String> _annees = const [];
  String? _annee;
  List<Fiche> _bulletins = const [];
  bool _chargement = true;
  String? _erreur;
  String? _message;
  bool _messageSucces = true;
  bool _telechargementEnCours = false;

  String get _inscriptionId =>
      context.read<AuthProvider>().user?.inscriptionId ?? '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  Future<void> _charger() async {
    final inscriptionId = _inscriptionId;
    if (inscriptionId.isEmpty) {
      setState(() {
        _chargement = false;
        _erreur = 'Aucune inscription active : bulletins indisponibles.';
      });
      return;
    }

    setState(() {
      _chargement = true;
      _erreur = null;
    });
    final service = context.read<EtudiantAcademiqueService>();
    try {
      // Les années disponibles ne sont chargées qu'une fois : elles ne
      // changent pas d'un rafraîchissement à l'autre, et l'échec de cette
      // route ne doit pas empêcher d'afficher les bulletins.
      if (_annees.isEmpty) {
        _annees = await service
            .anneesDisponibles(inscriptionId)
            .catchError((_) => <String>[]);
        _annee ??= _annees.isNotEmpty ? _annees.first : null;
      }
      final bulletins = await service.bulletins(inscriptionId, annee: _annee);
      if (!mounted) return;
      setState(() {
        _bulletins = bulletins;
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
      titre: 'Mes bulletins',
      sousTitre: _annee ?? 'Toutes années',
      onRafraichir: _charger,
      actions: [
        IconButton(
          icon: _telechargementEnCours
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.download_rounded),
          tooltip: 'Télécharger mon relevé',
          onPressed: _telechargementEnCours ? null : _telechargerReleve,
        ),
      ],
      corps: EtatRequete(
        chargement: _chargement,
        erreur: _erreur,
        vide: _bulletins.isEmpty && _annees.isEmpty,
        onReessayer: _charger,
        messageVide: 'Aucun bulletin publié pour le moment.',
        iconeVide: Icons.description_rounded,
        enfant: ListView(
          padding: Responsive.margePage(context),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (_message != null)
              BandeauMessage(
                message: _message!,
                succes: _messageSucces,
                onFermer: () => setState(() => _message = null),
              ),
            if (_annees.isNotEmpty)
              BarreFiltres(
                filtres: [
                  FiltreDeroulant<String>(
                    libelle: 'Année académique',
                    valeur: _annee,
                    options: _annees
                        .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                        .toList(),
                    onChange: (v) {
                      setState(() => _annee = v);
                      _charger();
                    },
                  ),
                ],
              ),
            if (_bulletins.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  'Aucun bulletin pour cette année.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textMutedOf(context)),
                ),
              )
            else
              for (final bulletin in _bulletins) ...[
                _CarteBulletin(bulletin: bulletin),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }

  Future<void> _telechargerReleve() async {
    setState(() => _telechargementEnCours = true);
    try {
      final octets = await context
          .read<EtudiantAcademiqueService>()
          .telechargerReleve(_inscriptionId, annee: _annee);
      final suffixe = (_annee ?? 'complet').replaceAll('/', '-');
      await Fichiers.enregistrerEtOuvrir(octets, 'releve-$suffixe.pdf');
      if (!mounted) return;
      setState(() {
        _message = 'Relevé téléchargé.';
        _messageSucces = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = e is ApiException ? e.message : e.toString();
        _messageSucces = false;
      });
    } finally {
      if (mounted) setState(() => _telechargementEnCours = false);
    }
  }
}

class _CarteBulletin extends StatelessWidget {
  final Fiche bulletin;

  const _CarteBulletin({required this.bulletin});

  @override
  Widget build(BuildContext context) {
    final mention = bulletin.texte('mention');
    final moyenne = bulletin.decimalOuNul('moyenne', alias: const ['moyenneGenerale']);

    return CartePortail(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  bulletin.texte(
                    'annee',
                    alias: const ['anneeAcademique', 'type'],
                    defaut: 'Bulletin',
                  ),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              if (mention.isNotEmpty)
                Pastille(
                  texte: libelleMention(mention),
                  couleur: estAjourne(mention)
                      ? AppTheme.statutRouge
                      : AppTheme.statutVert,
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (moyenne != null)
            LigneDetail(
              libelle: 'Moyenne',
              valeur: '${moyenne.toStringAsFixed(2)} / 20',
            ),
          if (bulletin.texte('promotion').isNotEmpty)
            LigneDetail(libelle: 'Promotion', valeur: bulletin.texte('promotion')),
          if (bulletin.texteOuNul('date') != null)
            LigneDetail(
              libelle: 'Publié le',
              valeur: formatDate(bulletin.texteOuNul('date')),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Parcours académique
// ─────────────────────────────────────────────────────────────

class ParcoursScreen extends StatefulWidget {
  const ParcoursScreen({super.key});

  @override
  State<ParcoursScreen> createState() => _ParcoursScreenState();
}

class _ParcoursScreenState extends State<ParcoursScreen> {
  Fiche? _donnees;
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  Future<void> _charger() async {
    final inscriptionId = context.read<AuthProvider>().user?.inscriptionId;
    if (inscriptionId == null || inscriptionId.isEmpty) {
      setState(() {
        _chargement = false;
        _erreur = 'Aucune inscription active : parcours indisponible.';
      });
      return;
    }

    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final donnees = await context
          .read<EtudiantAcademiqueService>()
          .parcours(inscriptionId);
      if (!mounted) return;
      setState(() {
        _donnees = donnees;
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
    // La route rend `{parcours: [...], stats: {...}, evolution: [...]}`.
    final annees = _donnees?.liste('parcours') ?? const <Fiche>[];
    final stats = _donnees?.sousFiche('stats') ?? const Fiche({});

    return PagePortail(
      titre: 'Mon parcours',
      sousTitre: 'Année par année, depuis mon inscription',
      onRafraichir: _charger,
      corps: EtatRequete(
        chargement: _chargement,
        erreur: _erreur,
        vide: annees.isEmpty && stats.donnees.isEmpty,
        onReessayer: _charger,
        messageVide: 'Votre parcours n\'a pas encore de donnée délibérée.',
        iconeVide: Icons.route_rounded,
        enfant: ListView(
          padding: Responsive.margePage(context),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            RangeeKpi(
              tuiles: [
                TuileKpi(
                  icone: Icons.timeline_rounded,
                  valeur: '${stats.entier('nbAnnees')}',
                  libelle: 'Années suivies',
                  detail: _periode(stats),
                  couleur: AppTheme.statutBleu,
                ),
                TuileKpi(
                  icone: Icons.star_rounded,
                  valeur: stats.decimalOuNul('moyenneGenerale') == null
                      ? '—'
                      : stats.decimal('moyenneGenerale').toStringAsFixed(2),
                  libelle: 'Moyenne générale',
                  couleur: AppTheme.statutVert,
                ),
                TuileKpi(
                  icone: Icons.workspace_premium_rounded,
                  valeur: '${stats.entier('totalCredits')}',
                  libelle: 'Crédits validés',
                  couleur: AppTheme.statutViolet,
                ),
                TuileKpi(
                  icone: Icons.military_tech_rounded,
                  valeur: libelleMention(stats.texteOuNul('meilleureMention')),
                  libelle: 'Meilleure mention',
                  couleur: AppTheme.statutOrange,
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (stats.texte('statutActuel').isNotEmpty) ...[
              CartePortail(
                child: Row(
                  children: [
                    Icon(
                      Icons.info_rounded,
                      size: 18,
                      color: AppTheme.iconAccent(context),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Statut actuel : ${stats.texte('statutActuel')}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            const EnteteSection(
              titre: 'Historique',
              icone: Icons.history_rounded,
            ),
            for (final annee in annees) ...[
              _CarteAnnee(annee: annee),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  static String? _periode(Fiche stats) {
    final debut = stats.texte('anneeDebut');
    final fin = stats.texte('anneeFin');
    if (debut.isEmpty && fin.isEmpty) return null;
    return [debut, fin].where((a) => a.isNotEmpty).join(' → ');
  }
}

class _CarteAnnee extends StatelessWidget {
  final Fiche annee;

  const _CarteAnnee({required this.annee});

  @override
  Widget build(BuildContext context) {
    final decision = annee.texte('decision');
    final mention = annee.texte('mention');
    final moyenne = annee.decimalOuNul('moyenne');
    final commentaire = annee.texte('commentaireJury');

    return CartePortail(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      annee.texte('anneeAcademique', defaut: 'Année'),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    if (annee.texte('promotion').isNotEmpty ||
                        annee.texte('filiere').isNotEmpty)
                      Text(
                        [annee.texte('promotion'), annee.texte('filiere')]
                            .where((v) => v.isNotEmpty)
                            .join(' · '),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryOf(context),
                        ),
                      ),
                  ],
                ),
              ),
              if (decision.isNotEmpty)
                Pastille(
                  texte: decision.replaceAll('_', ' '),
                  couleur: _couleurDecision(decision),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (moyenne != null)
            LigneDetail(
              libelle: 'Moyenne',
              valeur: '${moyenne.toStringAsFixed(2)} / 20',
            ),
          if (mention.isNotEmpty)
            LigneDetail(libelle: 'Mention', valeur: libelleMention(mention)),
          if (annee.contient('creditsValides'))
            LigneDetail(
              libelle: 'Crédits validés',
              valeur: '${annee.entier('creditsValides')}',
            ),
          if (annee.contient('rang'))
            LigneDetail(libelle: 'Rang', valeur: '${annee.entier('rang')}'),
          if (commentaire.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              commentaire,
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: AppTheme.textSecondaryOf(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Color _couleurDecision(String decision) {
    final code = decision.toUpperCase();
    if (code.contains('ADMIS') || code.contains('REUSSI')) {
      return AppTheme.statutVert;
    }
    if (code.contains('AJOURNE') || code.contains('ECHEC')) {
      return AppTheme.statutRouge;
    }
    return AppTheme.statutOrange;
  }
}

// ─────────────────────────────────────────────────────────────
// Recours
// ─────────────────────────────────────────────────────────────

/// Contestation d'une note ou d'une décision de jury.
///
/// Le formulaire web accepte une pièce jointe ; la route mobile poste du JSON
/// et la référence du justificatif reste textuelle — le dépôt de fichier passe
/// par « Mes documents », qui est la voie prévue par le backend.
class RecoursScreen extends StatelessWidget {
  const RecoursScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<EtudiantAcademiqueService>();
    final utilisateurId = context.read<AuthProvider>().user?.id ?? '';

    return EcranRessource(
      titre: 'Mes recours',
      sousTitre: 'Contestation d\'une note ou d\'une décision',
      libelleCreation: 'Nouveau recours',
      messageVide: 'Aucun recours déposé.',
      charger: () => service.recours(utilisateurId),
      description: DescriptionFiche(
        icone: Icons.gavel_rounded,
        titre: (f) => _libelleType(f.texte('type', defaut: 'Recours')),
        sousTitre: (f) => f.texteOuNul('cours', alias: const ['coursTitre']),
        statut: (f) => _statut(f.texte('statut')),
        details: (f) => [
          LigneDetail(
            libelle: 'Déposé le',
            valeur: formatDate(f.texteOuNul('dateSoumission')),
          ),
          if (f.texteOuNul('dateReponse') != null)
            LigneDetail(
              libelle: 'Réponse le',
              valeur: formatDate(f.texteOuNul('dateReponse')),
            ),
          if (f.texte('reponse').isNotEmpty)
            LigneDetail(libelle: 'Réponse', valeur: f.texte('reponse')),
        ],
      ),
      optionsDynamiques: {
        'coursId': () async {
          final cours = await service.coursParUtilisateur(utilisateurId);
          return {
            for (final c in cours)
              c.id: c.texte('nom', alias: const ['titre', 'intitule']),
          };
        },
      },
      champsCreation: [
        const ChampFormulaire(
          cle: 'type',
          libelle: 'Type de recours',
          type: TypeChamp.liste,
          obligatoire: true,
          valeurInitiale: 'NOTE',
          options: {
            'NOTE': 'Contestation de note',
            'DELIBERATION': 'Décision de délibération',
            'ABSENCE': 'Absence à une évaluation',
            'AUTRE': 'Autre',
          },
        ),
        const ChampFormulaire(
          cle: 'coursId',
          libelle: 'Cours concerné',
          type: TypeChamp.liste,
        ),
        ChampFormulaire(
          cle: 'anneeAcademique',
          libelle: 'Année académique',
          valeurInitiale: anneeAcademiqueCourante(),
        ),
        const ChampFormulaire(
          cle: 'description',
          libelle: 'Motif détaillé',
          type: TypeChamp.multiligne,
          obligatoire: true,
          indice: 'Exposez précisément les faits contestés.',
        ),
      ],
      onCreer: (valeurs) =>
          service.deposerRecoursDeliberation(utilisateurId, valeurs),
    );
  }

  static String _libelleType(String code) => switch (code) {
        'NOTE' => 'Contestation de note',
        'DELIBERATION' => 'Décision de délibération',
        'ABSENCE' => 'Absence à une évaluation',
        'AUTRE' => 'Autre',
        _ => code.replaceAll('_', ' '),
      };

  static (String, Color)? _statut(String code) => switch (code.toUpperCase()) {
        'EN_ATTENTE' || 'SOUMIS' => ('En attente', AppTheme.statutOrange),
        'EN_COURS' || 'EN_EXAMEN' => ('En examen', AppTheme.statutBleu),
        'ACCEPTE' || 'FAVORABLE' => ('Accepté', AppTheme.statutVert),
        'REJETE' || 'DEFAVORABLE' => ('Rejeté', AppTheme.statutRouge),
        '' => null,
        _ => (code.replaceAll('_', ' '), AppTheme.statutNavy),
      };
}
