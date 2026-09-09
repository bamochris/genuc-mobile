import 'package:dio/dio.dart';

import '../../core/constants/api_endpoints.dart';
import 'appel_api.dart';

/// Toutes les routes pédagogiques du portail enseignant.
///
/// `ProfesseurService` couvre le tableau de bord (`/api/professeur/**`) ; ce
/// service couvre ce que le portail web appelle depuis les 45 autres pages :
/// cours et supports, notes, présences, évaluations, barèmes, encadrement,
/// recherche et rapports. Les chemins sont ceux relevés dans
/// `genuc-frontend/src/pages/professeur/**`.
class ProfesseurPedagogieService extends ServiceApi {
  ProfesseurPedagogieService(super.client);

  // ─── Cours et supports ─────────────────────────────────────

  Future<List<Fiche>> mesCours(String professeurId) => listeDe(
        ApiEndpoints.coursProfesseur(Uri.encodeComponent(professeurId)),
        contexte: 'Vos cours n\'ont pas pu être chargés.',
      );

  Future<Fiche> cours(String coursId) => ficheDe(ApiEndpoints.coursDetail(coursId));

  /// Rend un cours visible aux étudiants : BROUILLON → PUBLIE.
  ///
  /// `PATCH /api/cours/{id}/publier`, réservé côté serveur à PROFESSEUR et
  /// ADMIN_UNIVERSITE. Le geste n'existait que sur le web : sur mobile,
  /// l'enseignant voyait la pastille « Brouillon » sans aucun moyen d'en
  /// sortir, et son cours restait invisible à sa promotion.
  Future<Fiche> publierCours(String coursId) => corriger(
        ApiEndpoints.coursPublier(coursId),
        contexte: 'La publication du cours a échoué.',
      );

  Future<List<Fiche>> etudiantsDuCours(String coursId) =>
      listeDe(ApiEndpoints.coursEtudiants(coursId));

  Future<List<Fiche>> supports(String coursId) =>
      listeDe(ApiEndpoints.coursSupports(coursId));

  /// Publication d'un support. Le backend attend un `multipart/form-data`
  /// portant `coursId` en plus du fichier (voir `SupportsCours.jsx`).
  Future<Fiche> publierSupport({
    required String coursId,
    required String titre,
    required String description,
    required String type,
    required String cheminFichier,
    required String nomFichier,
  }) async {
    final formulaire = FormData.fromMap({
      'titre': titre,
      'description': description,
      'type': type,
      'coursId': coursId,
      'fichier': await MultipartFile.fromFile(
        cheminFichier,
        filename: nomFichier,
      ),
    });

    return poster(
      ApiEndpoints.coursSupports(coursId),
      corps: formulaire,
      contexte: 'Le support n\'a pas pu être publié.',
    );
  }

  Future<void> supprimerSupport(String supportId) =>
      supprimer(ApiEndpoints.support(supportId));

  // ─── Travaux et devoirs ────────────────────────────────────
  //
  // Les quatre routes existaient côté serveur sans qu'aucun client ne les
  // appelle : le circuit était instrumenté du côté qui REND — l'étudiant
  // dépose sa copie — et muet du côté qui demande et qui corrige.

  /// Les travaux publiés par l'enseignant, avec leur cours et l'état des copies.
  Future<List<Fiche>> travaux(String professeurId) => listeDe(
        ApiEndpoints.travauxDuProfesseur(professeurId),
        contexte: 'Vos travaux n\'ont pas pu être chargés.',
      );

  Future<Fiche> creerTravail({
    required String coursId,
    required String professeurId,
    required String titre,
    required String description,
    required String type,
    required String dateEcheance,
    double? coefficient,
    String? professeurNom,
  }) =>
      poster(
        ApiEndpoints.travaux,
        corps: {
          'coursId': coursId,
          'professeurId': professeurId,
          'professeurNom': ?professeurNom,
          'titre': titre,
          'description': description,
          'type': type,
          'dateEcheance': dateEcheance,
          'coefficient': ?coefficient,
        },
        contexte: 'Le travail n\'a pas pu être publié.',
      );

  /// Attache le fichier de consignes. Il remplace celui déjà joint, s'il y en a.
  Future<Fiche> joindreConsignes({
    required String travailId,
    required String cheminFichier,
    required String nomFichier,
  }) async {
    final formulaire = FormData.fromMap({
      'fichier': await MultipartFile.fromFile(cheminFichier, filename: nomFichier),
    });
    return poster(
      ApiEndpoints.travailConsignes(travailId),
      corps: formulaire,
      contexte: 'Les consignes n\'ont pas pu être jointes.',
    );
  }

  Future<List<Fiche>> soumissions(String travailId) => listeDe(
        ApiEndpoints.travailSoumissions(travailId),
        contexte: 'Les copies de ce travail n\'ont pas pu être chargées.',
      );

  /// Corrige une copie.
  ///
  /// [cheminFichier] est la copie annotée, facultative : sans elle, celle déjà
  /// rendue est conservée — reprendre une note ne doit pas effacer un document
  /// que l'étudiant a peut-être déjà lu.
  Future<Fiche> corrigerCopie({
    required String soumissionId,
    required double note,
    String? commentaire,
    String? cheminFichier,
    String? nomFichier,
  }) async {
    final formulaire = FormData.fromMap({
      'note': note,
      'commentaireCorrection': ?commentaire,
      if (cheminFichier != null)
        'fichier': await MultipartFile.fromFile(
          cheminFichier,
          filename: nomFichier,
        ),
    });
    return poster(
      ApiEndpoints.soumissionCorriger(soumissionId),
      corps: formulaire,
      contexte: 'La correction n\'a pas pu être enregistrée.',
    );
  }

  Future<List<Fiche>> mesEtudiants(String professeurId) => listeDe(
        ApiEndpoints.professeurEtudiantsDisponibles(professeurId),
        contexte: 'La liste des étudiants n\'a pas pu être chargée.',
      );

  Future<List<Fiche>> mesPromotions(String professeurId) =>
      listeDe(ApiEndpoints.professeurPromotions(professeurId));

  // ─── Notes ─────────────────────────────────────────────────

  Future<List<Fiche>> notesDuCours(String coursId, String annee) => listeDe(
        ApiEndpoints.notesCours(coursId, Uri.encodeComponent(annee)),
        contexte: 'Les notes n\'ont pas pu être chargées.',
      );

  Future<Fiche> statistiquesNotes(String coursId, String annee) => ficheDe(
        ApiEndpoints.notesCoursStats(coursId, Uri.encodeComponent(annee)),
      );

  /// Enregistrement en lot d'une session d'encodage.
  Future<Fiche> enregistrerNotes({
    required String coursId,
    required String annee,
    required List<Map<String, dynamic>> notes,
  }) =>
      poster(
        ApiEndpoints.notesLot(coursId, Uri.encodeComponent(annee)),
        corps: notes,
        contexte: 'Les notes n\'ont pas pu être enregistrées.',
      );

  Future<Fiche> lancerCalcul(String coursId, {String? annee}) => poster(
        ApiEndpoints.notesCalcul(coursId),
        parametres: annee != null ? {'annee': annee} : null,
        contexte: 'Le calcul n\'a pas pu être lancé.',
      );

  Future<List<Fiche>> historiqueNotes(String professeurId) =>
      listeDe(ApiEndpoints.professeurNotesHistorique(professeurId));

  Future<List<int>> exporterNotes(String coursId, String annee) => octetsDe(
        ApiEndpoints.notesExport(coursId, annee),
        contexte: 'L\'export des notes a échoué.',
      );

  Future<List<int>> modeleImportNotes() => octetsDe(
        ApiEndpoints.notesModele,
        contexte: 'Le modèle d\'import n\'a pas pu être téléchargé.',
      );

  Future<Fiche> importerNotes({
    required String coursId,
    required String annee,
    required String cheminFichier,
    required String nomFichier,
  }) async {
    // Le serveur lit `anneeAcademique` et `file` — ce formulaire envoyait
    // `annee` et `fichier` : l'import repartait en 400 à chaque tentative,
    // alors que l'analyse (juste en dessous) nommait les deux correctement.
    // Défaut antérieur aux corrections du 03/09/2026, révélé en alignant le
    // contrat. `professeurId` n'y figure plus : l'auteur de l'import est lu
    // dans le jeton depuis que la route est bornée au cours.
    final formulaire = FormData.fromMap({
      'coursId': coursId,
      'anneeAcademique': annee,
      'file': await MultipartFile.fromFile(
        cheminFichier,
        filename: nomFichier,
      ),
    });

    return poster(
      ApiEndpoints.notesImport,
      corps: formulaire,
      contexte: 'L\'import des notes a échoué.',
    );
  }

  /// Analyse un fichier de notes sans rien enregistrer.
  ///
  /// À jouer AVANT [importerNotes] : l'import écrit les lignes valides même
  /// quand d'autres échouent, et l'enseignant découvre les erreurs une fois
  /// les notes déjà passées en statut « soumise ».
  Future<Fiche> analyserFichierNotes({
    required String coursId,
    required String annee,
    required String cheminFichier,
    required String nomFichier,
  }) async {
    // `professeurId` retiré : le serveur ne le lit plus. Il désignait l'auteur
    // de l'import et arrivait du client, sur une route qui n'avait par ailleurs
    // AUCUNE borne — un enseignant importait les notes de n'importe quel cours
    // du pays. Elle est bornée au cours depuis le 03/09/2026, et l'auteur vient
    // du jeton.
    final formulaire = FormData.fromMap({
      'coursId': coursId,
      'anneeAcademique': annee,
      'file': await MultipartFile.fromFile(cheminFichier, filename: nomFichier),
    });

    return poster(
      ApiEndpoints.notesAnalyser,
      corps: formulaire,
      contexte: 'Le fichier n\'a pas pu être analysé.',
    );
  }

  // ─── Présences ─────────────────────────────────────────────

  /// Feuille de présence d'une séance : le serveur rend
  /// `{presences: [{etudiantId, nom, prenom, present, justifie, presenceId}]}`.
  Future<Fiche> tableauPresences(String coursId, String date) => ficheDe(
        ApiEndpoints.presencesTableau(coursId),
        parametres: {'date': date},
        contexte: 'Le tableau des présences n\'a pas pu être chargé.',
      );

  /// QR de présence imprimable, rendu en image PNG.
  Future<List<int>> genererQrPresence(String coursId, {String? seanceId}) =>
      octetsDe(
        ApiEndpoints.presenceGenererQr,
        parametres: {'coursId': coursId, 'seanceId': seanceId ?? ''},
        contexte: 'Le QR code n\'a pas pu être généré.',
      );

  // ─── Vacations (jour / soir) ───────────────────────────────

  Future<List<Fiche>> coursParVacation(String professeurId) =>
      listeDe(ApiEndpoints.vacationsCoursProfesseur(professeurId));

  // La liste des vacations d'un établissement est un référentiel partagé :
  // elle vit dans `CommunService.vacationsActives`, l'étudiant s'en servant
  // aussi pour demander un changement de vacation.

  Future<Fiche> saisirPresences({
    required String coursId,
    required List<Map<String, dynamic>> presences,
  }) =>
      poster(
        ApiEndpoints.presencesSaisie(coursId),
        corps: presences,
        contexte: 'Les présences n\'ont pas pu être enregistrées.',
      );

  Future<List<Fiche>> historiquePresences(String professeurId) =>
      listeDe(ApiEndpoints.professeurPresencesHistorique(professeurId));

  /// Marque une absence comme justifiée.
  ///
  /// `PATCH` sans corps, et non `POST` : c'est la signature du contrôleur
  /// (`PresenceController.justifierPresence`), qui n'accepte que le rôle
  /// enseignant — d'où sa place ici et non dans le service étudiant.
  Future<Fiche> justifierPresence(String presenceId) => corriger(
        ApiEndpoints.presenceJustifier(presenceId),
        contexte: 'L\'absence n\'a pas pu être justifiée.',
      );

  // ─── Évaluations ───────────────────────────────────────────

  Future<List<Fiche>> interrogations(String professeurId) =>
      listeDe(ApiEndpoints.evaluationsInterrogationsDe(professeurId));

  Future<Fiche> creerInterrogation(Map<String, dynamic> donnees) =>
      poster(ApiEndpoints.evaluationsInterrogations, corps: donnees);

  Future<List<Fiche>> travauxPratiques(String professeurId) =>
      listeDe(ApiEndpoints.evaluationsTpDe(professeurId));

  Future<Fiche> creerTravailPratique(Map<String, dynamic> donnees) =>
      poster(ApiEndpoints.evaluationsTp, corps: donnees);

  Future<List<Fiche>> examens(String professeurId) =>
      listeDe(ApiEndpoints.evaluationsExamensDe(professeurId));

  Future<Fiche> creerExamen(Map<String, dynamic> donnees) =>
      poster(ApiEndpoints.evaluationsExamens, corps: donnees);

  /// Évaluation de l'enseignant par ses étudiants (« Mon évaluation »).
  Future<List<Fiche>> monEvaluation(String professeurId) =>
      listeDe(ApiEndpoints.evaluationsProfesseur(professeurId));

  // ─── Barèmes ───────────────────────────────────────────────

  Future<List<Fiche>> baremes(String professeurId) =>
      listeDe(ApiEndpoints.baremesProfesseur(professeurId));

  Future<List<Fiche>> baremesDuCours(String coursId) =>
      listeDe(ApiEndpoints.baremesCours(coursId));

  Future<Fiche> creerBareme(Map<String, dynamic> donnees) =>
      poster(ApiEndpoints.baremes, corps: donnees);

  Future<Fiche> modifierBareme(String id, Map<String, dynamic> donnees) =>
      mettreAJour(ApiEndpoints.bareme(id), corps: donnees);

  Future<void> supprimerBareme(String id) => supprimer(ApiEndpoints.bareme(id));

  // ─── TFC et mémoires ───────────────────────────────────────

  Future<List<Fiche>> sujetsTfc(String professeurId) =>
      listeDe(ApiEndpoints.tfcSujetsDe(professeurId));

  Future<Fiche> proposerSujet(Map<String, dynamic> donnees) =>
      poster(ApiEndpoints.tfcSujets, corps: donnees);

  Future<Fiche> validerSujet(String id) =>
      corriger(ApiEndpoints.tfcSujetValider(id));

  Future<List<Fiche>> encadrements(String professeurId) =>
      listeDe(ApiEndpoints.tfcEncadrementsDe(professeurId));

  Future<Fiche> changerStatutEncadrement(String id, String statut) =>
      corriger(
        ApiEndpoints.tfcEncadrementStatut(id),
        corps: {'statut': statut},
      );

  Future<List<Fiche>> suiviMemoires(String professeurId) =>
      listeDe(ApiEndpoints.tfcMemoiresSuivi(professeurId));

  Future<Fiche> majProgressionMemoire(String id, int progression) =>
      corriger(
        ApiEndpoints.tfcMemoireProgression(id),
        corps: {'progression': progression},
      );

  Future<Fiche> commenterMemoire(String id, String commentaire) => poster(
        ApiEndpoints.tfcMemoireCommentaire(id),
        corps: {'commentaire': commentaire},
      );

  // ─── Stages ────────────────────────────────────────────────

  Future<List<Fiche>> stagesAValider(String professeurId) =>
      listeDe(ApiEndpoints.stagesValidation(professeurId));

  Future<Fiche> validerStage(String id) => corriger(ApiEndpoints.stageValider(id));

  Future<Fiche> rejeterStage(String id, String motif) => corriger(
        ApiEndpoints.stageRejeter(id),
        corps: {'motif': motif},
      );

  Future<List<Fiche>> suiviStages(String professeurId) =>
      listeDe(ApiEndpoints.stagesSuivi(professeurId));

  Future<Fiche> rapportDeStage(String stageId) =>
      ficheDe(ApiEndpoints.stageRapport(stageId));

  Future<List<Fiche>> rapportsStages(String professeurId) =>
      listeDe(ApiEndpoints.stagesRapports(professeurId));

  Future<Fiche> validerRapportStage(String id, {String? commentaire, num? note}) =>
      corriger(
        ApiEndpoints.stageRapportValider(id),
        corps: {
          'commentaire': ?commentaire,
          'note': ?note,
        },
      );

  // ─── Recherche scientifique ────────────────────────────────

  Future<List<Fiche>> publications(String professeurId) =>
      listeDe(ApiEndpoints.publicationsDe(professeurId));

  Future<Fiche> ajouterPublication(Map<String, dynamic> donnees) =>
      poster(ApiEndpoints.publications, corps: donnees);

  Future<List<Fiche>> projets(String professeurId) =>
      listeDe(ApiEndpoints.projetsDe(professeurId));

  Future<Fiche> ajouterProjet(Map<String, dynamic> donnees) =>
      poster(ApiEndpoints.projetsRecherche, corps: donnees);

  Future<List<Fiche>> conferences(String professeurId) =>
      listeDe(ApiEndpoints.conferencesDe(professeurId));

  Future<Fiche> ajouterConference(Map<String, dynamic> donnees) =>
      poster(ApiEndpoints.conferences, corps: donnees);

  Future<List<Fiche>> laboratoires(String professeurId) =>
      listeDe(ApiEndpoints.laboratoiresDe(professeurId));

  Future<Fiche> ajouterLaboratoire(Map<String, dynamic> donnees) =>
      poster(ApiEndpoints.laboratoires, corps: donnees);

  // ─── Calendrier et compte ──────────────────────────────────

  Future<List<Fiche>> calendrier(String universiteId) =>
      listeDe(ApiEndpoints.calendrierUniversite(universiteId));

  Future<List<Fiche>> mesContrats() => listeDe(ApiEndpoints.mesContrats);

  Future<Fiche> monCompte(String utilisateurId) =>
      ficheDe(ApiEndpoints.utilisateur(utilisateurId));

  Future<Fiche> majMonCompte(String utilisateurId, Map<String, dynamic> donnees) =>
      mettreAJour(ApiEndpoints.utilisateur(utilisateurId), corps: donnees);

  // ─── Contenu du cours : les leçons ─────────────────────────
  //
  // Ces trois méthodes remplacent les six anciennes de `/api/lms/…`
  // (`chapitres`, `ajouterChapitre`, `modifierChapitre`, `supprimerChapitre`,
  // `devoirs`, `ajouterDevoir`) et `statistiquesApprentissage`.
  //
  // L'enseignant déposait son contenu dans une façade qui ne persiste rien :
  // la liste revenait vide au rechargement, et l'ajout se soldait par une
  // erreur. Les leçons, elles, sont bien enregistrées — et c'est ce que
  // l'étudiant lit sur la fiche du cours.

  Future<List<Fiche>> lecons(String coursId) =>
      listeDe(
        ApiEndpoints.coursLecons(coursId),
        contexte: 'Les leçons de ce cours n\'ont pas pu être chargées.',
      );

  /// `POST /api/cours/{id}/lecons` attend du JSON, pas un multipart : un
  /// fichier se dépose ensuite comme SUPPORT du cours, pas ici.
  Future<Fiche> ajouterLecon(String coursId, Map<String, dynamic> donnees) =>
      poster(
        ApiEndpoints.coursLecons(coursId),
        corps: donnees,
        contexte: 'La leçon n\'a pas pu être ajoutée.',
      );

  Future<void> supprimerLecon(String leconId) => supprimer(
        ApiEndpoints.lecon(leconId),
        contexte: 'La leçon n\'a pas pu être supprimée.',
      );
}
