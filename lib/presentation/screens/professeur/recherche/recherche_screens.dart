import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/services/professeur_pedagogie_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/formulaire_dynamique.dart';
import '../../../widgets/portail_widgets.dart';
import '../../commun/ecran_ressource.dart';

/// Module « Recherche » du portail enseignant : publications, projets,
/// conférences et laboratoires.
///
/// Les quatre écrans web (`pages/professeur/recherche/*.jsx`) ont la même
/// forme — liste + formulaire de création — avec des champs différents. Ils
/// reposent donc sur [EcranRessource], et ne déclarent ici que leur contrat :
/// route de lecture, route d'écriture, champs de saisie, colonnes affichées.

class PublicationsScreen extends StatelessWidget {
  const PublicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<ProfesseurPedagogieService>();
    final professeurId = context.read<AuthProvider>().user?.id ?? '';

    return EcranRessource(
      titre: 'Publications',
      sousTitre: 'Articles, livres et chapitres publiés',
      libelleCreation: 'Nouvelle publication',
      messageVide: 'Aucune publication enregistrée.',
      charger: () => service.publications(professeurId),
      description: DescriptionFiche(
        icone: Icons.article_rounded,
        titre: (f) => f.texte('titre', defaut: 'Publication sans titre'),
        sousTitre: (f) => f.texteOuNul('auteurs'),
        statut: (f) {
          final type = f.texte('type');
          return type.isEmpty ? null : (_libelleType(type), AppTheme.statutBleu);
        },
        details: (f) => [
          LigneDetail(libelle: 'Revue / journal', valeur: f.texte('revue')),
          LigneDetail(libelle: 'Année', valeur: f.texte('annee')),
          if (f.texte('doi').isNotEmpty)
            LigneDetail(libelle: 'DOI', valeur: f.texte('doi')),
        ],
      ),
      champsCreation: [
        const ChampFormulaire(
          cle: 'titre',
          libelle: 'Titre',
          obligatoire: true,
        ),
        const ChampFormulaire(
          cle: 'auteurs',
          libelle: 'Auteurs',
          indice: 'Nom1, Nom2, …',
        ),
        const ChampFormulaire(cle: 'revue', libelle: 'Revue / journal'),
        ChampFormulaire(
          cle: 'annee',
          libelle: 'Année',
          type: TypeChamp.nombre,
          valeurInitiale: DateTime.now().year,
          minimum: 1950,
          maximum: DateTime.now().year + 1,
        ),
        const ChampFormulaire(cle: 'doi', libelle: 'DOI'),
        const ChampFormulaire(
          cle: 'type',
          libelle: 'Type',
          type: TypeChamp.liste,
          valeurInitiale: 'ARTICLE',
          options: {
            'ARTICLE': 'Article',
            'LIVRE': 'Livre',
            'CHAPITRE': 'Chapitre',
            'CONFERENCE': 'Conférence',
            'RAPPORT': 'Rapport',
          },
        ),
        const ChampFormulaire(
          cle: 'resume',
          libelle: 'Résumé',
          type: TypeChamp.multiligne,
        ),
      ],
      // `professeurId` retire du corps : le serveur lisait l'auteur de la
      // fiche DANS LA REQUETE, ainsi que son nom d'affichage. Les deux champs
      // de l'attribution etaient donc a la main de l'appelant, et un
      // enseignant pouvait publier au nom d'un collegue. L'auteur vient du
      // jeton depuis le 03/09/2026.
      onCreer: (valeurs) => service.ajouterPublication(valeurs),
    );
  }

  static String _libelleType(String code) => switch (code) {
        'ARTICLE' => 'Article',
        'LIVRE' => 'Livre',
        'CHAPITRE' => 'Chapitre',
        'CONFERENCE' => 'Conférence',
        'RAPPORT' => 'Rapport',
        _ => code,
      };
}

class ProjetsRechercheScreen extends StatelessWidget {
  const ProjetsRechercheScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<ProfesseurPedagogieService>();
    final professeurId = context.read<AuthProvider>().user?.id ?? '';

    return EcranRessource(
      titre: 'Projets de recherche',
      sousTitre: 'Projets financés et en cours',
      libelleCreation: 'Nouveau projet',
      messageVide: 'Aucun projet de recherche enregistré.',
      charger: () => service.projets(professeurId),
      description: DescriptionFiche(
        icone: Icons.science_rounded,
        titre: (f) => f.texte('titre', defaut: 'Projet sans titre'),
        sousTitre: (f) => f.texteOuNul('description'),
        statut: (f) => _statutProjet(f.texte('statut')),
        details: (f) => [
          LigneDetail(libelle: 'Financement', valeur: f.texte('financement')),
          LigneDetail(
            libelle: 'Montant',
            valeur: f.decimalOuNul('montant') == null
                ? ''
                : '${f.decimal('montant').toStringAsFixed(0)} USD',
          ),
          LigneDetail(
            libelle: 'Période',
            valeur: [f.texte('dateDebut'), f.texte('dateFin')]
                .where((d) => d.isNotEmpty)
                .join(' → '),
          ),
        ],
      ),
      champsCreation: const [
        ChampFormulaire(cle: 'titre', libelle: 'Titre', obligatoire: true),
        ChampFormulaire(
          cle: 'description',
          libelle: 'Description',
          type: TypeChamp.multiligne,
        ),
        ChampFormulaire(cle: 'financement', libelle: 'Source de financement'),
        ChampFormulaire(
          cle: 'montant',
          libelle: 'Montant (USD)',
          type: TypeChamp.decimal,
          minimum: 0,
        ),
        ChampFormulaire(
          cle: 'dateDebut',
          libelle: 'Date de début',
          type: TypeChamp.date,
        ),
        ChampFormulaire(
          cle: 'dateFin',
          libelle: 'Date de fin',
          type: TypeChamp.date,
        ),
        ChampFormulaire(
          cle: 'statut',
          libelle: 'Statut',
          type: TypeChamp.liste,
          valeurInitiale: 'EN_COURS',
          options: {
            'EN_COURS': 'En cours',
            'TERMINE': 'Terminé',
            'SUSPENDU': 'Suspendu',
          },
        ),
      ],
      // `professeurId` retire du corps : le serveur lisait l'auteur de la
      // fiche DANS LA REQUETE, ainsi que son nom d'affichage. Les deux champs
      // de l'attribution etaient donc a la main de l'appelant, et un
      // enseignant pouvait publier au nom d'un collegue. L'auteur vient du
      // jeton depuis le 03/09/2026.
      onCreer: (valeurs) => service.ajouterProjet(valeurs),
    );
  }

  static (String, Color)? _statutProjet(String code) => switch (code) {
        'EN_COURS' => ('En cours', AppTheme.statutBleu),
        'TERMINE' => ('Terminé', AppTheme.statutVert),
        'SUSPENDU' => ('Suspendu', AppTheme.statutOrange),
        '' => null,
        _ => (code, AppTheme.statutNavy),
      };
}

class ConferencesScreen extends StatelessWidget {
  const ConferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<ProfesseurPedagogieService>();
    final professeurId = context.read<AuthProvider>().user?.id ?? '';

    return EcranRessource(
      titre: 'Conférences',
      sousTitre: 'Conférences, séminaires, ateliers et colloques',
      libelleCreation: 'Nouvelle conférence',
      messageVide: 'Aucune conférence enregistrée.',
      charger: () => service.conferences(professeurId),
      description: DescriptionFiche(
        icone: Icons.campaign_rounded,
        titre: (f) => f.texte('titre', defaut: 'Conférence sans titre'),
        sousTitre: (f) => f.texteOuNul('description'),
        statut: (f) {
          final type = f.texte('type');
          return type.isEmpty
              ? null
              : (_libelleType(type), AppTheme.statutViolet);
        },
        details: (f) => [
          LigneDetail(libelle: 'Date', valeur: f.texte('date')),
          LigneDetail(libelle: 'Lieu', valeur: f.texte('lieu')),
          LigneDetail(libelle: 'Organisateur', valeur: f.texte('organisateur')),
        ],
      ),
      champsCreation: const [
        ChampFormulaire(cle: 'titre', libelle: 'Titre', obligatoire: true),
        ChampFormulaire(
          cle: 'description',
          libelle: 'Description',
          type: TypeChamp.multiligne,
        ),
        ChampFormulaire(
          cle: 'type',
          libelle: 'Type',
          type: TypeChamp.liste,
          valeurInitiale: 'CONFERENCE',
          options: {
            'CONFERENCE': 'Conférence',
            'SEMINAIRE': 'Séminaire',
            'ATELIER': 'Atelier',
            'COLLOQUE': 'Colloque',
          },
        ),
        ChampFormulaire(cle: 'date', libelle: 'Date', type: TypeChamp.date),
        ChampFormulaire(cle: 'lieu', libelle: 'Lieu'),
        ChampFormulaire(cle: 'organisateur', libelle: 'Organisateur'),
        ChampFormulaire(cle: 'lien', libelle: 'Lien'),
      ],
      // `professeurId` retire du corps : le serveur lisait l'auteur de la
      // fiche DANS LA REQUETE, ainsi que son nom d'affichage. Les deux champs
      // de l'attribution etaient donc a la main de l'appelant, et un
      // enseignant pouvait publier au nom d'un collegue. L'auteur vient du
      // jeton depuis le 03/09/2026.
      onCreer: (valeurs) => service.ajouterConference(valeurs),
    );
  }

  static String _libelleType(String code) => switch (code) {
        'CONFERENCE' => 'Conférence',
        'SEMINAIRE' => 'Séminaire',
        'ATELIER' => 'Atelier',
        'COLLOQUE' => 'Colloque',
        _ => code,
      };
}

class LaboratoiresScreen extends StatelessWidget {
  const LaboratoiresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<ProfesseurPedagogieService>();
    final professeurId = context.read<AuthProvider>().user?.id ?? '';

    return EcranRessource(
      titre: 'Laboratoires',
      sousTitre: 'Laboratoires de recherche rattachés',
      libelleCreation: 'Nouveau laboratoire',
      messageVide: 'Aucun laboratoire enregistré.',
      charger: () => service.laboratoires(professeurId),
      description: DescriptionFiche(
        icone: Icons.biotech_rounded,
        titre: (f) => f.texte('nom', defaut: 'Laboratoire sans nom'),
        sousTitre: (f) => f.texteOuNul('description'),
        statut: (f) => _statutLabo(f.texte('statut')),
        details: (f) => [
          LigneDetail(libelle: 'Domaine', valeur: f.texte('domaine')),
          LigneDetail(libelle: 'Responsable', valeur: f.texte('responsable')),
          LigneDetail(libelle: 'Capacité', valeur: f.texte('capacite')),
          if (f.texte('email').isNotEmpty)
            LigneDetail(libelle: 'Contact', valeur: f.texte('email')),
        ],
      ),
      champsCreation: const [
        ChampFormulaire(cle: 'nom', libelle: 'Nom', obligatoire: true),
        ChampFormulaire(
          cle: 'description',
          libelle: 'Description',
          type: TypeChamp.multiligne,
        ),
        ChampFormulaire(cle: 'domaine', libelle: 'Domaine'),
        ChampFormulaire(cle: 'responsable', libelle: 'Responsable'),
        ChampFormulaire(cle: 'email', libelle: 'Courriel'),
        ChampFormulaire(cle: 'telephone', libelle: 'Téléphone'),
        ChampFormulaire(
          cle: 'capacite',
          libelle: 'Capacité',
          type: TypeChamp.nombre,
          minimum: 0,
        ),
        ChampFormulaire(
          cle: 'equipements',
          libelle: 'Équipements',
          type: TypeChamp.multiligne,
        ),
        ChampFormulaire(
          cle: 'statut',
          libelle: 'Statut',
          type: TypeChamp.liste,
          valeurInitiale: 'ACTIF',
          options: {
            'ACTIF': 'Actif',
            'INACTIF': 'Inactif',
            'EN_CONSTRUCTION': 'En construction',
          },
        ),
      ],
      // `professeurId` retire du corps : le serveur lisait l'auteur de la
      // fiche DANS LA REQUETE, ainsi que son nom d'affichage. Les deux champs
      // de l'attribution etaient donc a la main de l'appelant, et un
      // enseignant pouvait publier au nom d'un collegue. L'auteur vient du
      // jeton depuis le 03/09/2026.
      onCreer: (valeurs) => service.ajouterLaboratoire(valeurs),
    );
  }

  static (String, Color)? _statutLabo(String code) => switch (code) {
        'ACTIF' => ('Actif', AppTheme.statutVert),
        'INACTIF' => ('Inactif', AppTheme.statutRouge),
        'EN_CONSTRUCTION' => ('En construction', AppTheme.statutOrange),
        '' => null,
        _ => (code, AppTheme.statutNavy),
      };
}
