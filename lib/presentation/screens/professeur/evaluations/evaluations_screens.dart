import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/services/appel_api.dart';
import '../../../../data/services/professeur_pedagogie_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/formulaire_dynamique.dart';
import '../../../widgets/portail_widgets.dart';
import '../../commun/ecran_ressource.dart';

/// Charge les cours de l'enseignant sous forme d'options « id → CODE – titre »
/// pour les listes déroulantes des formulaires.
Future<Map<String, String>> optionsCours(
  ProfesseurPedagogieService service,
  String professeurId,
) async {
  final cours = await service.mesCours(professeurId);
  return {
    for (final c in cours)
      c.id: [c.texte('code'), c.texte('titre')]
          .where((v) => v.isNotEmpty)
          .join(' – '),
  };
}

/// Statut d'une évaluation, avec les mêmes libellés que les badges du web.
(String, Color)? statutEvaluation(String code) => switch (code) {
      'TERMINE' => ('Terminé', AppTheme.statutVert),
      'EN_COURS' => ('En cours', AppTheme.statutOrange),
      'PLANIFIE' => ('Planifié', AppTheme.statutBleu),
      '' => null,
      _ => (code, AppTheme.statutNavy),
    };

class InterrogationsScreen extends StatelessWidget {
  const InterrogationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<ProfesseurPedagogieService>();
    final professeurId = context.read<AuthProvider>().user?.id ?? '';

    return EcranRessource(
      titre: 'Interrogations',
      sousTitre: 'Interrogations planifiées sur vos cours',
      libelleCreation: 'Nouvelle interrogation',
      messageVide: 'Aucune interrogation planifiée.',
      charger: () => service.interrogations(professeurId),
      optionsDynamiques: {
        'coursId': () => optionsCours(service, professeurId),
      },
      description: DescriptionFiche(
        icone: Icons.edit_note_rounded,
        titre: (f) => f.texte('titre', defaut: 'Interrogation'),
        sousTitre: (f) => f.texteOuNul('coursCode', alias: const ['coursTitre']),
        statut: (f) => statutEvaluation(f.texte('statut')),
        details: (f) => [
          LigneDetail(libelle: 'Date', valeur: f.texte('date')),
          LigneDetail(libelle: 'Durée', valeur: '${f.entier('duree')} min'),
          LigneDetail(libelle: 'Coefficient', valeur: f.texte('coefficient')),
          LigneDetail(libelle: 'Questions', valeur: f.texte('questions')),
        ],
      ),
      champsCreation: const [
        ChampFormulaire(
          cle: 'coursId',
          libelle: 'Cours',
          type: TypeChamp.liste,
          obligatoire: true,
        ),
        ChampFormulaire(cle: 'titre', libelle: 'Titre', obligatoire: true),
        ChampFormulaire(
          cle: 'date',
          libelle: 'Date',
          type: TypeChamp.date,
          obligatoire: true,
        ),
        ChampFormulaire(
          cle: 'duree',
          libelle: 'Durée (minutes)',
          type: TypeChamp.nombre,
          valeurInitiale: 30,
          minimum: 5,
          maximum: 180,
        ),
        ChampFormulaire(
          cle: 'coefficient',
          libelle: 'Coefficient',
          type: TypeChamp.decimal,
          valeurInitiale: 1,
          minimum: 0.5,
          maximum: 5,
        ),
        ChampFormulaire(
          cle: 'questions',
          libelle: 'Nombre de questions',
          type: TypeChamp.nombre,
          valeurInitiale: 3,
          minimum: 1,
          maximum: 30,
        ),
      ],
      onCreer: (valeurs) => service.creerInterrogation({
        ...valeurs,
        'professeurId': professeurId,
      }),
    );
  }
}

class TravauxPratiquesScreen extends StatelessWidget {
  const TravauxPratiquesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<ProfesseurPedagogieService>();
    final professeurId = context.read<AuthProvider>().user?.id ?? '';

    return EcranRessource(
      titre: 'TP / TD',
      sousTitre: 'Travaux pratiques et dirigés',
      libelleCreation: 'Nouveau TP / TD',
      messageVide: 'Aucun TP ou TD planifié.',
      charger: () => service.travauxPratiques(professeurId),
      optionsDynamiques: {
        'coursId': () => optionsCours(service, professeurId),
      },
      description: DescriptionFiche(
        icone: Icons.science_rounded,
        titre: (f) => f.texte('titre', defaut: 'TP / TD'),
        sousTitre: (f) => f.texteOuNul('coursCode', alias: const ['coursTitre']),
        statut: (f) => statutEvaluation(f.texte('statut')),
        details: (f) => [
          LigneDetail(libelle: 'Date', valeur: f.texte('date')),
          LigneDetail(libelle: 'Coefficient', valeur: f.texte('coefficient')),
          LigneDetail(libelle: 'Groupes', valeur: f.texte('nbGroupes')),
        ],
      ),
      champsCreation: const [
        ChampFormulaire(
          cle: 'coursId',
          libelle: 'Cours',
          type: TypeChamp.liste,
          obligatoire: true,
        ),
        ChampFormulaire(cle: 'titre', libelle: 'Titre', obligatoire: true),
        ChampFormulaire(
          cle: 'date',
          libelle: 'Date',
          type: TypeChamp.date,
          obligatoire: true,
        ),
        ChampFormulaire(
          cle: 'coefficient',
          libelle: 'Coefficient',
          type: TypeChamp.decimal,
          valeurInitiale: 1,
          minimum: 0.5,
          maximum: 5,
        ),
        ChampFormulaire(
          cle: 'nbGroupes',
          libelle: 'Nombre de groupes',
          type: TypeChamp.nombre,
          valeurInitiale: 1,
          minimum: 1,
        ),
      ],
      onCreer: (valeurs) => service.creerTravailPratique({
        ...valeurs,
        'professeurId': professeurId,
      }),
    );
  }
}

class ExamensScreen extends StatelessWidget {
  const ExamensScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<ProfesseurPedagogieService>();
    final professeurId = context.read<AuthProvider>().user?.id ?? '';

    return EcranRessource(
      titre: 'Examens',
      sousTitre: 'Sessions, rattrapages et examens de diplôme',
      libelleCreation: 'Nouvel examen',
      messageVide: 'Aucun examen planifié.',
      charger: () => service.examens(professeurId),
      optionsDynamiques: {
        'coursId': () => optionsCours(service, professeurId),
      },
      description: DescriptionFiche(
        icone: Icons.assignment_rounded,
        titre: (f) => f.texte('titre', defaut: 'Examen'),
        sousTitre: (f) => f.texteOuNul('coursCode', alias: const ['coursTitre']),
        statut: (f) => statutEvaluation(f.texte('statut')),
        details: (f) => [
          LigneDetail(libelle: 'Date', valeur: f.texte('date')),
          LigneDetail(libelle: 'Durée', valeur: '${f.entier('duree')} min'),
          LigneDetail(libelle: 'Salle', valeur: f.texte('salle')),
          LigneDetail(libelle: 'Type', valeur: _libelleType(f.texte('type'))),
        ],
      ),
      champsCreation: const [
        ChampFormulaire(
          cle: 'coursId',
          libelle: 'Cours',
          type: TypeChamp.liste,
          obligatoire: true,
        ),
        ChampFormulaire(cle: 'titre', libelle: 'Titre', obligatoire: true),
        ChampFormulaire(
          cle: 'date',
          libelle: 'Date',
          type: TypeChamp.date,
          obligatoire: true,
        ),
        ChampFormulaire(
          cle: 'duree',
          libelle: 'Durée (minutes)',
          type: TypeChamp.nombre,
          valeurInitiale: 120,
          minimum: 15,
          maximum: 360,
        ),
        ChampFormulaire(
          cle: 'coefficient',
          libelle: 'Coefficient',
          type: TypeChamp.decimal,
          valeurInitiale: 1,
          minimum: 0.5,
          maximum: 5,
        ),
        ChampFormulaire(cle: 'salle', libelle: 'Salle'),
        ChampFormulaire(
          cle: 'type',
          libelle: 'Type',
          type: TypeChamp.liste,
          valeurInitiale: 'EXAMEN_SESSION',
          options: {
            'EXAMEN_SESSION': 'Examen de session',
            'RATTRAPAGE': 'Rattrapage',
            'EXAMEN_DIPLO': 'Examen de diplôme',
          },
        ),
      ],
      onCreer: (valeurs) => service.creerExamen({
        ...valeurs,
        'professeurId': professeurId,
      }),
    );
  }

  static String _libelleType(String code) => switch (code) {
        'EXAMEN_SESSION' => 'Examen de session',
        'RATTRAPAGE' => 'Rattrapage',
        'EXAMEN_DIPLO' => 'Examen de diplôme',
        _ => code,
      };
}

/// Barème de référence LMD (RDC), affiché en tête de l'écran des barèmes —
/// comme sur le web, où il sert de repère avant toute personnalisation.
const List<(String, int, int, String)> baremeLmd = [
  ('Excellent', 18, 20, 'A'),
  ('Très Bien', 15, 17, 'B'),
  ('Bien', 12, 14, 'C'),
  ('Assez Bien', 10, 11, 'D'),
  ('Passable', 5, 9, 'E'),
];

Color couleurMention(String mention) => switch (mention) {
      'Excellent' => AppTheme.statutVert,
      'Très Bien' => AppTheme.statutBleu,
      'Bien' => AppTheme.statutViolet,
      'Assez Bien' => AppTheme.statutOrange,
      _ => AppTheme.statutRouge,
    };

class BaremesScreen extends StatelessWidget {
  const BaremesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<ProfesseurPedagogieService>();
    final professeurId = context.read<AuthProvider>().user?.id ?? '';

    return EcranRessource(
      titre: 'Barèmes de notation',
      sousTitre: 'Pondérations appliquées à vos évaluations',
      libelleCreation: 'Nouveau barème',
      messageVide: 'Aucun barème personnalisé.',
      charger: () => service.baremes(professeurId),
      optionsDynamiques: {
        'coursId': () => optionsCours(service, professeurId),
      },
      entete: (context) => const _CarteBaremeLmd(),
      description: DescriptionFiche(
        icone: Icons.balance_rounded,
        titre: (f) => f.texte('nom', defaut: 'Barème'),
        sousTitre: (f) {
          final cours = f.texte('coursNom', alias: const ['coursTitre']);
          return cours.isEmpty ? 'Tous vos cours' : 'Cours : $cours';
        },
        details: (f) => [
          LigneDetail(
            libelle: 'Pondération',
            valeur: 'TP ${f.entier('ponderationTP', defaut: 30)} % · '
                'Interro ${f.entier('ponderationInterro', defaut: 20)} % · '
                'Examen ${f.entier('ponderationExamen', defaut: 50)} %',
          ),
        ],
      ),
      champsCreation: const [
        ChampFormulaire(cle: 'nom', libelle: 'Nom du barème', obligatoire: true),
        ChampFormulaire(cle: 'coursId', libelle: 'Cours', type: TypeChamp.liste),
        ChampFormulaire(
          cle: 'ponderationTP',
          libelle: 'Pondération TP (%)',
          type: TypeChamp.nombre,
          valeurInitiale: 30,
          minimum: 0,
          maximum: 100,
        ),
        ChampFormulaire(
          cle: 'ponderationInterro',
          libelle: 'Pondération interrogation (%)',
          type: TypeChamp.nombre,
          valeurInitiale: 20,
          minimum: 0,
          maximum: 100,
        ),
        ChampFormulaire(
          cle: 'ponderationExamen',
          libelle: 'Pondération examen (%)',
          type: TypeChamp.nombre,
          valeurInitiale: 50,
          minimum: 0,
          maximum: 100,
        ),
      ],
      onCreer: (valeurs) => _creerBareme(service, professeurId, valeurs),
      onSupprimer: (fiche) => service.supprimerBareme(fiche.id),
      actions: [
        ActionFiche(
          libelle: 'Modifier',
          icone: Icons.edit_rounded,
          executer: (context, fiche) => _modifier(context, service, fiche),
        ),
      ],
    );
  }

  /// La somme des trois pondérations doit faire 100 : le serveur l'exige, et
  /// un barème à 90 % fausse silencieusement toutes les notes calculées.
  static Future<void> _creerBareme(
    ProfesseurPedagogieService service,
    String professeurId,
    Map<String, dynamic> valeurs,
  ) {
    _verifierPonderations(valeurs);
    return service.creerBareme({...valeurs, 'professeurId': professeurId});
  }

  static void _verifierPonderations(Map<String, dynamic> valeurs) {
    final total = (valeurs['ponderationTP'] as num? ?? 0) +
        (valeurs['ponderationInterro'] as num? ?? 0) +
        (valeurs['ponderationExamen'] as num? ?? 0);
    if (total != 100) {
      throw ArgumentError(
        'La somme des pondérations doit être égale à 100 % (actuellement $total %).',
      );
    }
  }

  static Future<void> _modifier(
    BuildContext context,
    ProfesseurPedagogieService service,
    Fiche fiche,
  ) async {
    // Lu AVANT l'attente : après un `await`, le contexte peut avoir été démonté
    // et `context.read` lèverait.
    final professeurId = context.read<AuthProvider>().user?.id ?? '';
    final coursDisponibles = await optionsCours(service, professeurId);
    if (!context.mounted) return;

    final valeurs = await DialogueFormulaire.ouvrir(
      context,
      titre: 'Modifier le barème',
      champs: [
        const ChampFormulaire(
          cle: 'nom',
          libelle: 'Nom du barème',
          obligatoire: true,
        ),
        ChampFormulaire(
          cle: 'coursId',
          libelle: 'Cours',
          type: TypeChamp.liste,
          options: coursDisponibles,
        ),
        const ChampFormulaire(
          cle: 'ponderationTP',
          libelle: 'Pondération TP (%)',
          type: TypeChamp.nombre,
          minimum: 0,
          maximum: 100,
        ),
        const ChampFormulaire(
          cle: 'ponderationInterro',
          libelle: 'Pondération interrogation (%)',
          type: TypeChamp.nombre,
          minimum: 0,
          maximum: 100,
        ),
        const ChampFormulaire(
          cle: 'ponderationExamen',
          libelle: 'Pondération examen (%)',
          type: TypeChamp.nombre,
          minimum: 0,
          maximum: 100,
        ),
      ],
      valeurs: {
        'nom': fiche.texte('nom'),
        'coursId': fiche.texte('coursId'),
        'ponderationTP': fiche.entier('ponderationTP', defaut: 30),
        'ponderationInterro': fiche.entier('ponderationInterro', defaut: 20),
        'ponderationExamen': fiche.entier('ponderationExamen', defaut: 50),
      },
    );
    if (valeurs == null) return;

    _verifierPonderations(valeurs);
    await service.modifierBareme(fiche.id, valeurs);
  }
}

class _CarteBaremeLmd extends StatelessWidget {
  const _CarteBaremeLmd();

  @override
  Widget build(BuildContext context) {
    return CartePortail(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EnteteSection(
            titre: 'Barème LMD officiel (référence)',
            icone: Icons.school_rounded,
          ),
          Text(
            'Échelle nationale RDC — sur 20 points',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textMutedOf(context),
            ),
          ),
          const SizedBox(height: 12),
          GridViewMentions(),
        ],
      ),
    );
  }
}

/// Les cinq mentions du barème LMD, en grille adaptative.
class GridViewMentions extends StatelessWidget {
  const GridViewMentions({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (mention, min, max, grade) in baremeLmd)
          Container(
            width: 148,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.fondPastille(
                context,
                AppTheme.accentLisible(context, couleurMention(mention)),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  '$min–$max',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.accentLisible(
                      context,
                      couleurMention(mention),
                    ),
                  ),
                ),
                Text(
                  mention,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accentLisible(
                      context,
                      couleurMention(mention),
                    ),
                  ),
                ),
                Text(
                  'Grade $grade',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMutedOf(context),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
