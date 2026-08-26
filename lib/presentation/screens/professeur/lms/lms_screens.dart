import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../data/services/appel_api.dart';
import '../../../../data/services/professeur_pedagogie_service.dart';
import '../../../widgets/formulaire_dynamique.dart';
import '../../../widgets/portail_widgets.dart';
import '../../commun/ecran_ressource.dart';

/// LMS côté enseignant : le contenu qu'il publie, et ce que les étudiants en
/// font.
///
/// Ces deux écrans s'ouvrent depuis un cours (`cours/:id/contenu` et
/// `cours/:id/statistiques-apprentissage` sur le web) : ils ne figurent pas au
/// menu, un contenu de cours n'ayant pas de sens hors du cours.

// ─────────────────────────────────────────────────────────────
// Contenu du cours
// ─────────────────────────────────────────────────────────────

class ContenuCoursScreen extends StatelessWidget {
  final String coursId;
  final String? coursTitre;

  const ContenuCoursScreen({
    super.key,
    required this.coursId,
    this.coursTitre,
  });

  @override
  Widget build(BuildContext context) {
    final service = context.read<ProfesseurPedagogieService>();

    return EcranRessource(
      titre: 'Contenu du cours',
      sousTitre: coursTitre,
      libelleCreation: 'Nouveau chapitre',
      messageVide: 'Aucun chapitre publié.',
      charger: () => service.chapitres(coursId),
      description: DescriptionFiche(
        icone: Icons.auto_stories_rounded,
        titre: (f) => f.texte('titre', defaut: 'Chapitre'),
        sousTitre: (f) => f.texteOuNul('description'),
        statut: (f) => f.booleen('publie', defaut: true)
            ? ('Publié', AppTheme.statutVert)
            : ('Brouillon', AppTheme.statutNavy),
        details: (f) => [
          if (f.contient('ordre'))
            LigneDetail(libelle: 'Ordre', valeur: '${f.entier('ordre')}'),
          if (f.texte('url', alias: const ['lien']).isNotEmpty)
            LigneDetail(
              libelle: 'Ressource',
              valeur: f.texte('url', alias: const ['lien']),
            ),
        ],
      ),
      onSupprimer: (fiche) => service.supprimerChapitre(fiche.id),
      champsCreation: const [
        ChampFormulaire(cle: 'titre', libelle: 'Titre', obligatoire: true),
        ChampFormulaire(
          cle: 'description',
          libelle: 'Description',
          type: TypeChamp.multiligne,
        ),
        ChampFormulaire(
          cle: 'url',
          libelle: 'Lien de la ressource',
          indice: 'https://…',
        ),
        ChampFormulaire(
          cle: 'ordre',
          libelle: 'Ordre d\'affichage',
          type: TypeChamp.nombre,
          minimum: 1,
        ),
        ChampFormulaire(
          cle: 'publie',
          libelle: 'Publier immédiatement',
          type: TypeChamp.bascule,
          valeurInitiale: true,
        ),
      ],
      onCreer: (valeurs) => service.ajouterChapitre(coursId, valeurs),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Statistiques d'apprentissage
// ─────────────────────────────────────────────────────────────

class StatistiquesApprentissageScreen extends StatefulWidget {
  final String coursId;
  final String? coursTitre;

  const StatistiquesApprentissageScreen({
    super.key,
    required this.coursId,
    this.coursTitre,
  });

  @override
  State<StatistiquesApprentissageScreen> createState() =>
      _StatistiquesApprentissageScreenState();
}

class _StatistiquesApprentissageScreenState
    extends State<StatistiquesApprentissageScreen> {
  Fiche _stats = const Fiche({});
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final stats = await context
          .read<ProfesseurPedagogieService>()
          .statistiquesApprentissage(widget.coursId);
      if (!mounted) return;
      setState(() {
        _stats = stats;
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
    final inscrits = _stats.entier('totalEtudiants', alias: const ['inscrits']);
    final actifs = _stats.entier('etudiantsActifs', alias: const ['actifs']);
    final progressionMoyenne =
        _stats.decimalOuNul('progressionMoyenne') ?? 0;
    final parEtudiant = _stats.liste('etudiants');

    return PagePortail(
      titre: 'Statistiques d\'apprentissage',
      sousTitre: widget.coursTitre,
      onRafraichir: _charger,
      corps: EtatRequete(
        chargement: _chargement,
        erreur: _erreur,
        vide: _stats.donnees.isEmpty,
        onReessayer: _charger,
        messageVide: 'Aucune donnée d\'apprentissage pour ce cours.',
        iconeVide: Icons.insights_rounded,
        enfant: ListView(
          padding: Responsive.margePage(context),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            RangeeKpi(
              tuiles: [
                TuileKpi(
                  icone: Icons.groups_rounded,
                  valeur: '$inscrits',
                  libelle: 'Étudiants inscrits',
                  couleur: AppTheme.statutBleu,
                ),
                TuileKpi(
                  icone: Icons.bolt_rounded,
                  valeur: '$actifs',
                  libelle: 'Actifs',
                  detail: inscrits == 0
                      ? null
                      : '${(actifs * 100 / inscrits).round()} %',
                  couleur: AppTheme.statutVert,
                ),
                TuileKpi(
                  icone: Icons.trending_up_rounded,
                  valeur: '${progressionMoyenne.round()} %',
                  libelle: 'Progression moyenne',
                  couleur: AppTheme.statutViolet,
                ),
                TuileKpi(
                  icone: Icons.auto_stories_rounded,
                  valeur: '${_stats.entier('totalChapitres')}',
                  libelle: 'Chapitres publiés',
                  couleur: AppTheme.statutOrange,
                ),
              ],
            ),
            if (parEtudiant.isNotEmpty) ...[
              const SizedBox(height: 20),
              const EnteteSection(
                titre: 'Par étudiant',
                icone: Icons.person_rounded,
              ),
              for (final etudiant in parEtudiant) ...[
                CartePortail(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BarreProgression(
                        valeur: (etudiant.decimalOuNul('progression') ?? 0) / 100,
                        libelle: etudiant.texte(
                          'nomComplet',
                          alias: const ['etudiantNom', 'nom'],
                          defaut: 'Étudiant',
                        ),
                        couleur: AppTheme.statutBleu,
                      ),
                      if (etudiant.texteOuNul('derniereActivite') != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Dernière activité : '
                          '${formatDate(etudiant.texteOuNul('derniereActivite'), avecHeure: true)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textMutedOf(context),
                          ),
                        ),
                      ],
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
}
