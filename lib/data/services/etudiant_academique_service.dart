import 'package:dio/dio.dart';

import '../../core/constants/api_endpoints.dart';
import '../../core/utils/fichiers.dart';
import 'appel_api.dart';

/// Toutes les routes du portail étudiant hors dashboard / profil / cours /
/// notes / frais (couverts par `EtudiantService`).
///
/// Chemins relevés page par page dans `genuc-frontend/src/pages/etudiant/**`.
/// Attention à l'ordre des segments : `EtudiantPortalController` porte
/// l'identifiant d'inscription APRÈS la ressource pour `dashboard` et `profil`,
/// AVANT pour tout le reste.
class EtudiantAcademiqueService extends ServiceApi {
  EtudiantAcademiqueService(super.client);

  // ─── Emploi du temps, présences, examens ───────────────────

  Future<List<Fiche>> horaire(String inscriptionId) => listeDe(
        ApiEndpoints.etudiantHoraire(inscriptionId),
        contexte: 'Votre horaire n\'a pas pu être chargé.',
      );

  Future<List<Fiche>> presences(String inscriptionId) => listeDe(
        ApiEndpoints.etudiantPresences(inscriptionId),
        contexte: 'Vos présences n\'ont pas pu être chargées.',
      );

  // Pas de `justifierAbsence` ici : `PATCH /api/presences/{id}/justifier` est
  // gardé `hasAnyRole('PROFESSEUR','CHEF_DEPARTEMENT','ADMIN_UNIVERSITE')`.
  // Le portail web l'appelle pourtant depuis la page étudiant — l'étudiant y
  // reçoit donc toujours un 403. La justification appartient à l'enseignant :
  // voir `ProfesseurPedagogieService.justifierPresence`.

  Future<List<Fiche>> examens(String inscriptionId) =>
      listeDe(ApiEndpoints.etudiantExamens(inscriptionId));

  Future<List<Fiche>> evenements(String inscriptionId) =>
      listeDe(ApiEndpoints.etudiantEvenements(inscriptionId));

  // ─── Résultats, bulletins, parcours ────────────────────────

  Future<List<String>> anneesDisponibles(String inscriptionId) async {
    final fiches = await listeDe(
      ApiEndpoints.etudiantAnneesDisponibles(inscriptionId),
    );
    // La route rend soit des chaînes, soit des objets `{annee: ...}`.
    return fiches
        .map((f) => f.texte('annee', alias: const ['libelle', 'valeur']))
        .where((a) => a.isNotEmpty)
        .toList();
  }

  Future<List<Fiche>> bulletins(String inscriptionId, {String? annee}) => listeDe(
        ApiEndpoints.etudiantBulletins(inscriptionId),
        parametres: annee != null ? {'annee': annee} : null,
        contexte: 'Vos bulletins n\'ont pas pu être chargés.',
      );

  Future<Fiche> bulletinDeliberation(String inscriptionId) =>
      ficheDe(ApiEndpoints.deliberationBulletin(inscriptionId));

  Future<Fiche> deliberation(String inscriptionId, String annee) =>
      ficheDe(ApiEndpoints.deliberationEtudiant(inscriptionId, annee));

  Future<List<int>> telechargerDeliberation(String annee) => octetsDe(
        ApiEndpoints.deliberationEtudiantPdf,
        parametres: {'anneeAcademique': annee},
        contexte: 'Le PDF de délibération n\'a pas pu être téléchargé.',
      );

  Future<List<int>> telechargerReleve(String inscriptionId, {String? annee}) =>
      octetsDe(
        ApiEndpoints.etudiantReleveTelecharger(inscriptionId),
        parametres: annee != null ? {'annee': annee} : null,
        contexte: 'Le relevé n\'a pas pu être téléchargé.',
      );

  Future<Fiche> parcours(String inscriptionId) => ficheDe(
        ApiEndpoints.etudiantParcours(inscriptionId),
        contexte: 'Votre parcours n\'a pas pu être chargé.',
      );

  Future<List<Fiche>> recours(String utilisateurId) => listeDe(
        ApiEndpoints.etudiantRecours(utilisateurId),
        contexte: 'Vos recours n\'ont pas pu être chargés.',
      );

  /// Cours de l'étudiant vus depuis son identifiant UTILISATEUR (et non son
  /// inscription) : c'est la route qu'appelle le formulaire de recours pour
  /// remplir sa liste déroulante.
  Future<List<Fiche>> coursParUtilisateur(String utilisateurId) =>
      listeDe(ApiEndpoints.etudiantCoursParUtilisateur(utilisateurId));

  // ─── Travaux, TFC, stages ──────────────────────────────────

  Future<List<Fiche>> travaux(String inscriptionId) => listeDe(
        ApiEndpoints.etudiantTravaux(inscriptionId),
        contexte: 'Vos travaux n\'ont pas pu être chargés.',
      );

  Future<Fiche> soumettreTravail({
    required String travailId,
    required String cheminFichier,
    required String nomFichier,
    String? commentaire,
  }) async {
    final formulaire = FormData.fromMap({
      'travailId': travailId,
      'commentaire': ?commentaire,
      'fichier': await MultipartFile.fromFile(
        cheminFichier,
        filename: nomFichier,
      ),
    });

    return poster(
      ApiEndpoints.travauxSoumettre,
      corps: formulaire,
      contexte: 'Votre travail n\'a pas pu être déposé.',
    );
  }

  Future<Fiche> tfc(String inscriptionId) => ficheDe(
        ApiEndpoints.etudiantTfc(inscriptionId),
        contexte: 'Votre TFC n\'a pas pu être chargé.',
      );

  Future<Fiche> deposerTfc({
    required String inscriptionId,
    required String cheminFichier,
    required String nomFichier,
    String? titre,
  }) async {
    final formulaire = FormData.fromMap({
      'titre': ?titre,
      'fichier': await MultipartFile.fromFile(
        cheminFichier,
        filename: nomFichier,
      ),
    });

    return poster(
      ApiEndpoints.etudiantTfcDepot(inscriptionId),
      corps: formulaire,
      contexte: 'Le dépôt du TFC a échoué.',
    );
  }

  Future<Fiche> stage(String inscriptionId) => ficheDe(
        ApiEndpoints.etudiantStage(inscriptionId),
        contexte: 'Votre stage n\'a pas pu être chargé.',
      );

  Future<List<Fiche>> offresStages() => listeDe(ApiEndpoints.stagesOffres);

  Future<Fiche> postulerStage(String offreId, {String? lettre}) => poster(
        ApiEndpoints.stagesPostuler(offreId),
        corps: lettre != null ? {'lettreMotivation': lettre} : null,
        contexte: 'Votre candidature n\'a pas pu être envoyée.',
      );

  Future<Fiche> deposerRapportStage({
    required String inscriptionId,
    required String cheminFichier,
    required String nomFichier,
  }) async {
    final formulaire = FormData.fromMap({
      'fichier': await MultipartFile.fromFile(
        cheminFichier,
        filename: nomFichier,
      ),
    });

    return poster(
      ApiEndpoints.etudiantStageRapport(inscriptionId),
      corps: formulaire,
      contexte: 'Le rapport de stage n\'a pas pu être déposé.',
    );
  }

  // ─── Évaluation des enseignants ────────────────────────────

  // Le backend n'expose pas de route « évaluations à faire » : seul
  // `/api/evaluations/mes-evaluations` existe (encore un stub qui rend une
  // liste vide). On le consomme pour ne plus viser une route inexistante ;
  // l'écran affiche l'état vide tant que le module d'évaluation n'est pas
  // implémenté côté serveur.
  Future<List<Fiche>> evaluationsAFaire(String inscriptionId) => mesEvaluations();

  Future<List<Fiche>> mesEvaluations() =>
      listeDe(ApiEndpoints.mesEvaluations);

  Future<Fiche> soumettreEvaluation(Map<String, dynamic> donnees) => poster(
        ApiEndpoints.evaluationSoumettre,
        corps: donnees,
        contexte: 'Votre évaluation n\'a pas pu être envoyée.',
      );

  // ─── Documents officiels et attestations ───────────────────

  Future<List<Fiche>> documentsOfficiels(String inscriptionId) => listeDe(
        ApiEndpoints.etudiantDocuments(inscriptionId),
        contexte: 'Vos documents n\'ont pas pu être chargés.',
      );

  Future<Fiche> demanderDocument(String inscriptionId, String type) => poster(
        ApiEndpoints.etudiantDocumentDemander(inscriptionId),
        corps: {'type': type},
      );

  Future<List<int>> genererDocument(String inscriptionId, String type) =>
      octetsDe(
        ApiEndpoints.etudiantDocumentGenerer(inscriptionId),
        parametres: {'type': type},
      );

  Future<List<Fiche>> attestations(String inscriptionId) =>
      listeDe(ApiEndpoints.attestationsEtudiant(inscriptionId));

  Future<Fiche> demanderAttestation(Map<String, dynamic> donnees) => poster(
        ApiEndpoints.attestationDemander,
        corps: donnees,
        contexte: 'La demande d\'attestation a échoué.',
      );

  Future<List<int>> attestationPdf(String id) =>
      octetsDe(ApiEndpoints.attestationPdf(id));

  Future<List<Fiche>> documentsPersonnels(String inscriptionId) =>
      listeDe(ApiEndpoints.documentsInscription(inscriptionId));

  Future<Fiche> televerserDocument({
    required String inscriptionId,
    required String type,
    required String cheminFichier,
    required String nomFichier,
  }) async {
    final formulaire = FormData.fromMap({
      'inscriptionId': inscriptionId,
      'type': type,
      'fichier': await MultipartFile.fromFile(
        cheminFichier,
        filename: nomFichier,
      ),
    });

    return poster(
      ApiEndpoints.documentsUpload,
      corps: formulaire,
      contexte: 'Le document n\'a pas pu être téléversé.',
    );
  }

  Future<void> supprimerDocument(String id) =>
      supprimer(ApiEndpoints.document(id));

  /// Supports deposes par l'enseignant sur un cours.
  ///
  /// Ouvert a tout compte de l'etablissement : c'est le meme endpoint que le
  /// portail professeur, en lecture.
  Future<List<Fiche>> supportsDuCours(String coursId) => listeDe(
        ApiEndpoints.coursSupports(coursId),
        contexte: 'Les supports de ce cours n\'ont pas pu être chargés.',
      );

  Future<Fiche> carteEtudiant(String inscriptionId) => ficheDe(
        ApiEndpoints.carteEtudiantDonnees(inscriptionId),
        contexte: 'Votre carte étudiant n\'a pas pu être chargée.',
      );

  // ─── Démarches académiques ─────────────────────────────────

  Future<List<Fiche>> mesDemandes() => listeDe(
        ApiEndpoints.mesDemandesAcademiques,
        contexte: 'Vos demandes n\'ont pas pu être chargées.',
      );

  Future<Fiche> creerDemande(Map<String, dynamic> donnees) => poster(
        ApiEndpoints.demandesAcademiques,
        corps: donnees,
        contexte: 'La demande n\'a pas pu être créée.',
      );

  Future<Fiche> soumettreDemande(String demandeId) =>
      poster(ApiEndpoints.demandeSoumettre(demandeId));

  Future<List<Fiche>> mesTransferts() => listeDe(ApiEndpoints.transferts);

  Future<Fiche> demanderTransfert(Map<String, dynamic> donnees) =>
      poster(ApiEndpoints.transferts, corps: donnees);

  Future<Fiche> suiviTransfert(String id) =>
      ficheDe(ApiEndpoints.transfertSuivi(id));

  Future<List<Fiche>> equivalences(String utilisateurId) =>
      listeDe(ApiEndpoints.equivalencesEtudiant(utilisateurId));

  /// Dépôt d'une demande d'équivalence. Le backend attend un
  /// `multipart/form-data` portant `userId`, `universiteId`, les coordonnées du
  /// diplôme d'origine et le fichier `diplome` (obligatoire).
  Future<Fiche> demanderEquivalence(Map<String, dynamic> donnees) async {
    final diplome = donnees['diplome'];
    if (diplome is! FichierChoisi) {
      throw ArgumentError('Le diplôme scanné est requis.');
    }
    final formulaire = FormData.fromMap({
      'userId': donnees['userId'],
      'universiteId': donnees['universiteId'],
      'etablissementOrigine': donnees['etablissementOrigine'],
      'paysOrigine': donnees['paysOrigine'],
      'diplomeObtenu': donnees['diplomeObtenu'],
      if (donnees['domaineEtude'] != null)
        'domaineEtude': donnees['domaineEtude'],
      if (donnees['anneeObtention'] != null)
        'anneeObtention': donnees['anneeObtention'],
      if (donnees['niveauDemande'] != null)
        'niveauDemande': donnees['niveauDemande'],
      'diplome': await MultipartFile.fromFile(
        diplome.chemin,
        filename: diplome.nom,
      ),
    });
    return poster(
      ApiEndpoints.equivalences,
      corps: formulaire,
      contexte: 'La demande d\'équivalence n\'a pas pu être déposée.',
    );
  }

  // `DELETE /api/equivalences/{id}` exige `userId` en paramètre de requête :
  // sans lui, la garde `peutAccederUtilisateur` ne peut pas s'appliquer et le
  // contrôleur renvoie 400.
  Future<void> annulerEquivalence(String id, {required String utilisateurId}) =>
      supprimer(
        ApiEndpoints.equivalence(id),
        parametres: {'userId': utilisateurId},
      );

  /// Recours contre une délibération. Distinct de [recours] : celui-ci porte
  /// sur une décision de jury, l'autre sur une note.
  Future<List<Fiche>> recoursDeliberation(String etudiantId) =>
      listeDe(ApiEndpoints.recoursEtudiant(etudiantId));

  Future<Fiche> deposerRecoursDeliberation(
    String etudiantId,
    Map<String, dynamic> donnees,
  ) =>
      poster(
        ApiEndpoints.recoursEtudiant(etudiantId),
        corps: donnees,
        contexte: 'Le recours n\'a pas pu être déposé.',
      );

  // ─── Dossier social et bourse ──────────────────────────────

  Future<List<Fiche>> dossiersSociaux(String etudiantId) =>
      listeDe(ApiEndpoints.socialDossiersEtudiant(etudiantId));

  Future<Fiche> deposerDossierSocial(Map<String, dynamic> donnees) => poster(
        ApiEndpoints.socialDossiers,
        corps: donnees,
        contexte: 'Le dossier social n\'a pas pu être déposé.',
      );

  Future<Fiche> majDossierSocial(String id, Map<String, dynamic> donnees) =>
      mettreAJour(ApiEndpoints.socialDossier(id), corps: donnees);

  Future<Fiche> simulerBourse(Map<String, dynamic> donnees) =>
      poster(ApiEndpoints.socialCalculBourse, corps: donnees);

  // ─── Vie universitaire ─────────────────────────────────────

  Future<List<Fiche>> clubs(String universiteId) =>
      listeDe(ApiEndpoints.clubs(universiteId));

  Future<List<Fiche>> mesClubs(String inscriptionId) =>
      listeDe(ApiEndpoints.clubsEtudiant(inscriptionId));

  Future<List<Fiche>> evenementsCampus(String universiteId) =>
      listeDe(ApiEndpoints.evenementsCampus(universiteId));

  Future<Fiche> rejoindreClub(String clubId) =>
      poster(ApiEndpoints.clubRejoindre(clubId));

  // `DELETE /api/vie-universitaire/clubs/{id}/quitter` : le contrôleur expose
  // bien un DELETE, pas un POST.
  Future<void> quitterClub(String clubId) =>
      supprimer(ApiEndpoints.clubQuitter(clubId));

  Future<Fiche> sInscrireEvenement(String eventId) =>
      poster(ApiEndpoints.evenementInscrire(eventId));

  // ─── Jobs universitaires ───────────────────────────────────

  Future<List<Fiche>> offresEmploi(String etudiantId) => listeDe(
        ApiEndpoints.emploiOffres,
        parametres: {'etudiantId': etudiantId},
      );

  Future<Fiche> postulerEmploi(Map<String, dynamic> donnees) =>
      poster(ApiEndpoints.emploiCandidature, corps: donnees);

  Future<List<Fiche>> mesCandidatures(String etudiantId) =>
      listeDe(ApiEndpoints.emploiCandidaturesEtudiant(etudiantId));

  Future<List<Fiche>> mesContratsEtudiant(String etudiantId) =>
      listeDe(ApiEndpoints.emploiMesContrats(etudiantId));

  Future<List<Fiche>> mesHeures(String etudiantId, String mois) => listeDe(
        ApiEndpoints.emploiMesHeures(etudiantId),
        parametres: {'mois': mois},
      );

  // ─── Paramètres et dossier d'inscription ───────────────────

  Future<Fiche> preferences(String inscriptionId) =>
      ficheDe(ApiEndpoints.etudiantPreferences(inscriptionId));

  Future<Fiche> majPreferences(String inscriptionId, Map<String, dynamic> valeurs) =>
      mettreAJour(
        ApiEndpoints.etudiantPreferences(inscriptionId),
        corps: valeurs,
        contexte: 'Vos préférences n\'ont pas pu être enregistrées.',
      );

  Future<Fiche> monDossier() => ficheDe(ApiEndpoints.monDossier);

  Future<Fiche> deposerPieceDossier({
    required String type,
    required String cheminFichier,
    required String nomFichier,
  }) async {
    final formulaire = FormData.fromMap({
      'type': type,
      'fichier': await MultipartFile.fromFile(
        cheminFichier,
        filename: nomFichier,
      ),
    });

    return poster(
      ApiEndpoints.monDossierDocuments,
      corps: formulaire,
      contexte: 'La pièce n\'a pas pu être déposée.',
    );
  }

  // ─── LMS (côté étudiant) ───────────────────────────────────

  Future<List<Fiche>> chapitres(String coursId) =>
      listeDe(ApiEndpoints.lmsChapitres(coursId));

  Future<Fiche> maProgression(String coursId) =>
      ficheDe(ApiEndpoints.lmsProgression(coursId));

  Future<Fiche> marquerChapitreVu(String chapitreId) =>
      poster(ApiEndpoints.lmsChapitreMarquerVu(chapitreId));

  Future<List<Fiche>> devoirsDuCours(String coursId) =>
      listeDe(ApiEndpoints.lmsDevoirs(coursId));

  Future<Fiche> soumettreDevoir({
    required String devoirId,
    required String cheminFichier,
    required String nomFichier,
    String? commentaire,
  }) async {
    final formulaire = FormData.fromMap({
      'commentaire': ?commentaire,
      'fichier': await MultipartFile.fromFile(
        cheminFichier,
        filename: nomFichier,
      ),
    });

    return poster(
      ApiEndpoints.lmsDevoirSoumettre(devoirId),
      corps: formulaire,
      contexte: 'Le devoir n\'a pas pu être soumis.',
    );
  }
}
