/// Chemins exposés par `genuc-backend`.
///
/// Les routes du portail étudiant portent l'identifiant d'inscription AVANT le
/// nom de la ressource (`/portal/{id}/cours`) — sauf `dashboard` et `profil`
/// qui le portent après. Cet ordre vient de `EtudiantPortalController` : il
/// n'est pas uniforme, d'où les constructeurs dédiés plutôt que des constantes
/// concaténées à l'appel.
class ApiEndpoints {
  // ─── Auth ──────────────────────────────────────────────────
  static const String login = '/api/auth/login';
  static const String connecter = '/api/auth/connecter';
  static const String refresh = '/api/auth/refresh';
  static const String logout = '/api/auth/logout';
  static const String moi = '/api/auth/moi';
  static const String motDePasseOublie = '/api/auth/mot-de-passe-oublie';
  static const String changerMotDePasse = '/api/auth/changer-mot-de-passe';
  static const String ajouterEmail = '/api/auth/ajouter-email';
  static const String photo = '/api/auth/photo';
  static const String mesPhotos = '/api/auth/mes-photos';
  static const String twoFactorSetup = '/api/auth/2fa/setup';
  static const String twoFactorConfirm = '/api/auth/2fa/confirm';
  static const String twoFactorDisable = '/api/auth/2fa/disable';
  static const String twoFactorStatus = '/api/auth/2fa/status';
  static const String twoFactorLoginVerify = '/api/auth/2fa/login-verify';

  // ─── Portail étudiant ──────────────────────────────────────
  static const String _portal = '/api/etudiant/portal';

  static String etudiantDashboard(String inscriptionId) =>
      '$_portal/dashboard/$inscriptionId';
  static String etudiantProfil(String inscriptionId) =>
      '$_portal/profil/$inscriptionId';
  static String etudiantCours(String inscriptionId) =>
      '$_portal/$inscriptionId/cours';
  static String etudiantCoursDetail(String inscriptionId, String coursId) =>
      '$_portal/$inscriptionId/cours/$coursId';
  static String etudiantNotes(String inscriptionId) =>
      '$_portal/$inscriptionId/notes';
  static String etudiantReleve(String inscriptionId) =>
      '$_portal/$inscriptionId/releve';
  static String etudiantTravaux(String inscriptionId) =>
      '$_portal/$inscriptionId/travaux';
  static String etudiantDocuments(String inscriptionId) =>
      '$_portal/$inscriptionId/documents-officiels';
  static String etudiantStage(String inscriptionId) =>
      '$_portal/$inscriptionId/stage';
  static String etudiantTfc(String inscriptionId) =>
      '$_portal/$inscriptionId/tfc';
  static String etudiantTfcDepot(String inscriptionId) =>
      '$_portal/$inscriptionId/tfc/depot';
  static String etudiantStageRapport(String inscriptionId) =>
      '$_portal/$inscriptionId/stage/rapport';
  // L'horaire étudiant n'est PAS servi par `EtudiantPortalController` : la
  // route `$_portal/{id}/horaire` n'existe dans aucun contrôleur (le portail
  // web le documente, cf. `Horaire.jsx`). C'est `HoraireController` qui rend la
  // semaine type de l'inscription.
  static String etudiantHoraire(String inscriptionId) =>
      '/api/horaires/etudiant/$inscriptionId';
  static String etudiantPresences(String inscriptionId) =>
      '$_portal/$inscriptionId/presences';
  static String etudiantExamens(String inscriptionId) =>
      '$_portal/$inscriptionId/examens';
  // `etudiantEvaluations` retiré le 03/09/2026 : `/portal/{id}/evaluations`
  // n'a JAMAIS existé côté serveur — le portail n'expose que `/examens`. Le
  // web appelait la même route inexistante et avalait le 404 dans un
  // `.catch(() => ({ data: [] }))` : son écran « Évaluations » annonçait
  // « aucune évaluation » indéfiniment. Utiliser [etudiantExamens].
  static String etudiantEvenements(String inscriptionId) =>
      '$_portal/$inscriptionId/evenements';
  static String etudiantParcours(String inscriptionId) =>
      '$_portal/$inscriptionId/parcours';
  static String etudiantBulletins(String inscriptionId) =>
      '$_portal/$inscriptionId/bulletins';
  static String etudiantAnneesDisponibles(String inscriptionId) =>
      '$_portal/$inscriptionId/annees-disponibles';
  static String etudiantPreferences(String inscriptionId) =>
      '$_portal/$inscriptionId/preferences';
  static String etudiantReleveTelecharger(String inscriptionId) =>
      '$_portal/$inscriptionId/releve/telecharger';
  static String etudiantNotesExport(String inscriptionId) =>
      '$_portal/$inscriptionId/notes/export';
  static String etudiantDocumentDemander(String inscriptionId) =>
      '$_portal/$inscriptionId/documents/demander';
  static String etudiantDocumentGenerer(String inscriptionId) =>
      '$_portal/$inscriptionId/documents/generer';
  static const String stagesOffres = '$_portal/stages/offres';
  static String stagesPostuler(String offreId) =>
      '$_portal/stages/postuler/$offreId';

  /// Dossier d'inscription en cours de complétion (portail restreint).
  static const String monDossier = '/api/etudiant/mon-dossier';
  static const String monDossierDocuments = '/api/etudiant/mon-dossier/documents';

  static String etudiantRecours(String utilisateurId) =>
      '/api/etudiant/$utilisateurId/recours';
  static String etudiantCoursParUtilisateur(String utilisateurId) =>
      '/api/etudiant/$utilisateurId/cours';

  // ─── Résultats, délibération, bulletins ────────────────────
  static String deliberationBulletin(String inscriptionId) =>
      '/api/deliberation/bulletin/$inscriptionId';
  static const String deliberationEtudiantPdf = '/api/deliberation/etudiant/pdf';
  static String deliberationEtudiant(String inscriptionId, String annee) =>
      '/api/deliberations/etudiant/$inscriptionId/$annee';

  // ─── Démarches académiques ─────────────────────────────────
  static const String demandesAcademiques = '/api/demandes-academiques';
  static const String mesDemandesAcademiques =
      '/api/demandes-academiques/mes-demandes';
  static String demandeSoumettre(String demandeId) =>
      '/api/demandes-academiques/$demandeId/soumettre';
  // `TransfertController` est monté sur `/api/transfert` (singulier), pas
  // `/api/transferts` : les demandes vivent sous `/demandes`.
  //
  // Le POST de création est ouvert à l'étudiant, mais la LISTE ne l'est pas :
  // `GET /api/transfert/demandes` porte
  // `hasAnyRole('ADMIN_UNIVERSITE','DOYEN','CHEF_DEPARTEMENT','SECRETAIRE_ACADEMIQUE')`
  // — un étudiant y recevait un 403, et l'écran de suivi restait donc vide
  // quoi qu'il ait déposé. Son dossier à lui vit sous `/mon-dossier`, qui
  // résout l'inscription depuis le jeton (aucun identifiant à passer).
  static const String transferts = '/api/transfert/demandes';
  static const String transfertsMonDossier =
      '/api/transfert/demandes/mon-dossier';
  static String transfertSuivi(String id) => '/api/transfert/demandes/$id';
  static String transfertSoumettre(String id) =>
      '/api/transfert/demandes/$id/soumettre';

  // ─── Attestations et documents personnels ──────────────────
  static const String attestationDemander = '/api/attestations/demander';
  static String attestationPdf(String id) => '/api/attestations/$id/pdf';
  static String attestationsEtudiant(String inscriptionId) =>
      '/api/attestations/etudiant/$inscriptionId';
  /// Dépôt d'une pièce par l'ADMINISTRATION : attend un `etudiantId`, que le
  /// portail étudiant ne connaît pas — le jeton ne porte que l'inscription.
  /// Le dépôt par l'étudiant lui-même passe par [documentsInscription].
  static const String documentsUpload = '/api/documents/upload';

  /// Lecture ET dépôt des pièces d'une inscription.
  ///
  /// Le POST a été ajouté au serveur le 03/09/2026 : jusque-là, l'étudiant
  /// n'avait aucune route pour téléverser. L'application envoyait son
  /// `inscriptionId` au paramètre `etudiantId` de [documentsUpload], réservé à
  /// l'administration — refusé deux fois, sur le rôle puis sur le paramètre.
  static String documentsInscription(String inscriptionId) =>
      '/api/documents/inscription/$inscriptionId';
  static String document(String id) => '/api/documents/$id';
  static String carteEtudiantDe(String inscriptionId) =>
      '/api/carte-etudiant/$inscriptionId';

  /// Données de la carte, pour l'afficher. La route sans suffixe rend le PDF
  /// en pièce jointe : la lire comme du JSON faisait conclure « carte non
  /// émise » à un écran qui n'avait jamais reçu le bon contrat.
  static String carteEtudiantDonnees(String inscriptionId) =>
      '/api/carte-etudiant/$inscriptionId/donnees';

  // ─── Dossier social et bourses ─────────────────────────────
  static const String socialDossiers = '/api/social/dossiers';
  static const String socialCalculBourse = '/api/social/calcul-bourse';
  static String socialDossiersEtudiant(String etudiantId) =>
      '/api/social/dossiers/etudiant/$etudiantId';
  static String socialDossier(String id) => '/api/social/dossiers/$id';

  // ─── Vie universitaire ─────────────────────────────────────
  static String clubs(String universiteId) =>
      '/api/vie-universitaire/clubs/$universiteId';
  static String evenementsCampus(String universiteId) =>
      '/api/vie-universitaire/evenements/$universiteId';
  static String clubsEtudiant(String inscriptionId) =>
      '/api/vie-universitaire/etudiant/$inscriptionId/clubs';
  static String clubRejoindre(String clubId) =>
      '/api/vie-universitaire/clubs/$clubId/rejoindre';
  static String clubQuitter(String clubId) =>
      '/api/vie-universitaire/clubs/$clubId/quitter';
  static String evenementInscrire(String eventId) =>
      '/api/vie-universitaire/evenements/$eventId/inscrire';

  // ─── Jobs universitaires ───────────────────────────────────
  static const String emploiOffres = '/api/emploi/offres';
  static const String emploiCandidature = '/api/emploi/candidature';
  static String emploiCandidaturesEtudiant(String etudiantId) =>
      '/api/emploi-universitaire/candidatures/etudiant/$etudiantId';
  static String emploiMesContrats(String etudiantId) =>
      '/api/emploi-universitaire/mes-contrats/$etudiantId';
  static String emploiMesHeures(String etudiantId) =>
      '/api/emploi-universitaire/mes-heures/$etudiantId';

  // ─── Évaluation des enseignants ────────────────────────────
  static const String mesEvaluations = '/api/evaluations/mes-evaluations';
  static const String evaluationSoumettre = '/api/evaluations/soumettre';

  // ─── Travaux ───────────────────────────────────────────────
  static const String travauxSoumettre = '/api/travaux/soumettre';

  // ─── Présences (justification) ─────────────────────────────
  /// L'ENSEIGNANT accorde la justification. Accepte depuis le 03/09/2026 un
  /// corps `{motif}` — il était jusque-là purement ignoré, alors que
  /// `motifAbsence` existe sur l'entité.
  static String presenceJustifier(String id) => '/api/presences/$id/justifier';

  /// L'ÉTUDIANT motive son absence — il ne l'excuse pas.
  ///
  /// Route ajoutée au serveur le 03/09/2026. Jusque-là l'étudiant n'avait
  /// aucun moyen de déposer un motif : le portail web appelait `/justifier`,
  /// réservé à l'enseignant, et recevait un 403 après avoir imposé la saisie.
  static String presenceJustification(String id) =>
      '/api/presences/$id/justification';

  // ─── Équivalences de diplômes ──────────────────────────────
  static const String equivalences = '/api/equivalences';

  // ─── Référentiel ───────────────────────────────────────────
  static const String universites = '/api/universites';
  static const String anneesAcademiques = '/api/annees-academiques';
  /// Filières d'un établissement, pour l'ADMINISTRATION de cet établissement.
  ///
  /// Réservée à ADMIN_UNIVERSITE, CHEF_DEPARTEMENT et SECRETAIRE_ACADEMIQUE,
  /// ET bornée à l'université de l'appelant par un contrôle explicite. Elle ne
  /// peut donc pas servir à choisir un établissement d'ACCUEIL : voir
  /// [filieresDisponibles].
  static String filieresUniversite(String universiteId) =>
      '/api/filieres/universite/$universiteId';

  /// Filières OUVERTES d'un établissement quelconque (route publique).
  ///
  /// C'est celle qu'il faut pour un transfert ou un changement de filière :
  /// la destination n'est par définition pas l'établissement de l'étudiant.
  /// L'appel précédent partait sur [filieresUniversite] et recevait un 403 —
  /// et l'ouvrir au rôle ÉTUDIANT n'y aurait rien changé, le contrôle
  /// d'établissement de cette route l'aurait refusé ensuite.
  static const String filieresDisponibles = '/api/filieres/public/disponibles';
  static String promotionsFiliere(String filiereId) =>
      '/api/promotions/filiere/$filiereId';
  static String promotionsUniversite(String universiteId) =>
      '/api/promotions/universite/$universiteId';

  // ─── LMS ───────────────────────────────────────────────────
  static String lmsChapitres(String coursId) => '/api/lms/cours/$coursId/chapitres';
  static String lmsDevoirs(String coursId) => '/api/lms/cours/$coursId/devoirs';
  static String lmsProgression(String coursId) =>
      '/api/lms/cours/$coursId/ma-progression';
  static String lmsStatistiques(String coursId) =>
      '/api/lms/cours/$coursId/statistiques';
  static String lmsChapitreMarquerVu(String chapitreId) =>
      '/api/lms/chapitres/$chapitreId/marquer-vu';
  static String lmsChapitre(String chapitreId) => '/api/lms/chapitres/$chapitreId';
  static String lmsDevoirSoumettre(String devoirId) =>
      '/api/lms/devoirs/$devoirId/soumettre';

  // ─── Bibliothèque ──────────────────────────────────────────
  static String bibliothequeOuvrages(String universiteId) =>
      '/api/bibliotheque/ouvrages/$universiteId';
  static String bibliothequeCategories(String universiteId) =>
      '/api/bibliotheque/categories/$universiteId';
  static const String bibliothequeReserver = '/api/bibliotheque/reserver';

  // ─── Notifications ─────────────────────────────────────────
  static const String notificationsList = '/api/notifications/mes-notifications';
  static const String notificationsNonLues =
      '/api/notifications/mes-notifications/non-lues';
  static const String notificationsCount = '/api/notifications/non-lues/count';
  static const String notificationsToutLire = '/api/notifications/tout-lire';

  static String notificationMarquerLue(int notificationId) =>
      '/api/notifications/$notificationId/lue';

  // ─── Frais et paiements ────────────────────────────────────
  // Côté étudiant, les frais sont servis par `/api/etudiant/frais`
  // (`FraisEtudiantController`) — `/api/frais-etudiant` n'existe pas.
  // Le chemin nu `/api/etudiant/frais` n'a aucun mapping : il faut toujours
  // la sous-route (`/situation`, `/a-payer`, `/historique`).
  static const String paiements = '/api/paiements';
  static const String fraisSituation = '/api/etudiant/frais/situation';
  static const String fraisAPayer = '/api/etudiant/frais/a-payer';
  static const String historiquePaiements = '/api/etudiant/frais/historique';

  static String recuPaiement(int paiementId) =>
      '/api/etudiant/frais/recu/$paiementId';

  // ─── TachPay (paiement mobile money) ───────────────────────
  // Mêmes endpoints que le portail web : aucun nouveau mapping backend.
  // `checkoutContext` renvoie étudiant + frais + total en un appel.
  // `moyensPaiement` liste les opérateurs ACTIFS de l'université
  // (M-Pesa, Orange Money, Airtel Money, AfriMoney — configuration admin).
  static const String tachpayCheckoutContext =
      '/api/tachpay/etudiant/checkout-context';
  static const String tachpayPayerMobile = '/api/tachpay/etudiant/payer-mobile';
  static const String tachpayBonPaiement = '/api/tachpay/etudiant/bon-paiement';

  /// Statut d'un paiement initié (polling jusqu'à SUCCESS).
  static String tachpayStatutPaiement(String reference) =>
      '/api/tachpay/etudiant/paiement/$reference/statut';

  /// PDF du bon de paiement (réponse binaire ; téléchargé via dio bytes).
  static String tachpayBonPdf(String numero) =>
      '/api/tachpay/etudiant/bon-paiement/$numero/pdf';

  /// Opérateurs mobile money actifs de l'université.
  static String moyensPaiementUniversite(String universiteId) =>
      '/api/universites/$universiteId/moyens-paiement';

  // ─── Cours ─────────────────────────────────────────────────
  static const String cours = '/api/cours';

  // ─── Documents ─────────────────────────────────────────────
  static const String attestations = '/api/attestations';
  static const String carteEtudiant = '/api/carte-etudiant';

  // ─── Messagerie ────────────────────────────────────────────
  static const String messagerie = '/api/messagerie';
  static const String messagerieEnvoyer = '/api/messagerie/envoyer';

  static String messagesNonLus(String destinataireId) =>
      '/api/messagerie/non-lus/$destinataireId';
  static String messagerieEtudiant(String inscriptionId) =>
      '/api/messagerie/etudiant/$inscriptionId';
  static String messagerieAdmin(String utilisateurId) =>
      '/api/messagerie/admin/$utilisateurId';
  static String messagerieContacts(String universiteId) =>
      '/api/messagerie/contacts/$universiteId';
  static String messagerieCibles(String universiteId) =>
      '/api/messagerie/admin/cibles/$universiteId';
  static String messageMarquerLu(String messageId) =>
      '/api/messagerie/$messageId/lu';
  static String messageRepondre(String messageId) =>
      '/api/messagerie/$messageId/repondre';
  static String messageSupprimer(String messageId) => '/api/messagerie/$messageId';

  // ─── Portail professeur ───────────────────────────────────
  // Routes servies par `ProfesseurController` (genuc-backend). Le professeur
  // est identifié par son `id` utilisateur (et non par une inscription).
  static String professeurStats(String professeurId) =>
      '/api/professeur/stats/$professeurId';
  static String professeurPresences(String professeurId) =>
      '/api/professeur/presences/$professeurId';
  static String professeurScheduleToday(String professeurId) =>
      '/api/professeur/schedule/today/$professeurId';
  static String professeurAlertes(String professeurId) =>
      '/api/professeur/alertes/$professeurId';
  static String professeurPlanning(String professeurId) =>
      '/api/professeur/planning/$professeurId';
  static String professeurEtudiantsDisponibles(String professeurId) =>
      '/api/professeur/etudiants/disponibles/$professeurId';
  static String professeurPromotions(String professeurId) =>
      '/api/professeur/promotions/$professeurId';
  static String professeurNotesHistorique(String professeurId) =>
      '/api/professeur/notes/historique/$professeurId';
  static String professeurPresencesHistorique(String professeurId) =>
      '/api/professeur/presences/historique/$professeurId';

  // ─── Cours (professeur) ────────────────────────────────────
  static String coursProfesseur(String professeurId) =>
      '/api/cours/professeur/$professeurId';
  static String coursDetail(String coursId) => '/api/cours/$coursId';
  static String coursPublier(String coursId) =>
      '/api/cours/$coursId/publier';
  static String coursEtudiants(String coursId) => '/api/cours/$coursId/etudiants';
  static String coursSupports(String coursId) => '/api/cours/$coursId/supports';
  static String support(String supportId) => '/api/cours/supports/$supportId';

  // ─── Notes (professeur) ────────────────────────────────────
  static String notesCours(String coursId, String annee) =>
      '/api/notes/cours/$coursId/$annee';
  static String notesCoursStats(String coursId, String annee) =>
      '/api/notes/cours/$coursId/$annee/stats';
  static String notesCalcul(String coursId) => '/api/notes/cours/$coursId/calcul';
  static String notesLot(String coursId, String annee) =>
      '/api/notes/lot/$coursId/$annee';
  static String notesExport(String coursId, String annee) =>
      '/api/notes/import-export/export/$coursId/$annee';
  static const String notesImport = '/api/notes/import-export/import';
  static const String notesModele = '/api/notes/import-export/modele';

  // ─── Présences (professeur) ────────────────────────────────
  static String presencesSaisie(String coursId) =>
      '/api/presences/cours/$coursId/saisie';
  static String presencesTableau(String coursId) =>
      '/api/presences/cours/$coursId/tableau';

  // ─── Évaluations (professeur) ──────────────────────────────
  static const String evaluationsInterrogations =
      '/api/evaluations/interrogations';
  static const String evaluationsTp = '/api/evaluations/tp';
  static const String evaluationsExamens = '/api/evaluations/examens';
  static String evaluationsInterrogationsDe(String professeurId) =>
      '/api/evaluations/interrogations/$professeurId';
  static String evaluationsTpDe(String professeurId) =>
      '/api/evaluations/tp/$professeurId';
  static String evaluationsExamensDe(String professeurId) =>
      '/api/evaluations/examens/$professeurId';
  static String evaluationsProfesseur(String professeurId) =>
      '/api/evaluations/professeur/$professeurId';

  // ─── Barèmes ───────────────────────────────────────────────
  static const String baremes = '/api/baremes';
  static String bareme(String id) => '/api/baremes/$id';
  static String baremesCours(String coursId) => '/api/baremes/cours/$coursId';
  static String baremesProfesseur(String professeurId) =>
      '/api/baremes/professeur/$professeurId';

  // ─── TFC / mémoires (professeur) ───────────────────────────
  static const String tfcSujets = '/api/tfc/sujets';
  static String tfcSujetsDe(String professeurId) =>
      '/api/tfc/sujets/$professeurId';
  static String tfcSujetValider(String id) => '/api/tfc/sujets/$id/valider';
  static const String tfcEncadrements = '/api/tfc/encadrements';
  static String tfcEncadrementsDe(String professeurId) =>
      '/api/tfc/encadrements/$professeurId';
  static String tfcEncadrementStatut(String id) =>
      '/api/tfc/encadrements/$id/statut';
  static String tfcMemoiresSuivi(String professeurId) =>
      '/api/tfc/memoires/suivi/$professeurId';
  static String tfcMemoireProgression(String id) =>
      '/api/tfc/memoires/$id/progression';
  static String tfcMemoireCommentaire(String id) =>
      '/api/tfc/memoires/$id/commentaire';

  // ─── Stages (professeur) ───────────────────────────────────
  static String stagesValidation(String professeurId) =>
      '/api/stages/validation/$professeurId';
  static String stagesSuivi(String professeurId) =>
      '/api/stages/suivi/$professeurId';
  static String stagesRapports(String professeurId) =>
      '/api/stages/rapports/$professeurId';
  static String stageValider(String id) => '/api/stages/$id/valider';
  static String stageRejeter(String id) => '/api/stages/$id/rejeter';
  static String stageRapport(String stageId) => '/api/stages/$stageId/rapport';
  static String stageRapportValider(String id) =>
      '/api/stages/rapports/$id/valider';

  // ─── Recherche scientifique ────────────────────────────────
  static const String publications = '/api/recherche/publications';
  static const String projetsRecherche = '/api/recherche/projets';
  static const String conferences = '/api/recherche/conferences';
  static const String laboratoires = '/api/recherche/laboratoires';
  static String publicationsDe(String professeurId) =>
      '/api/recherche/publications/$professeurId';
  static String projetsDe(String professeurId) =>
      '/api/recherche/projets/$professeurId';
  static String conferencesDe(String professeurId) =>
      '/api/recherche/conferences/$professeurId';
  static String laboratoiresDe(String professeurId) =>
      '/api/recherche/laboratoires/$professeurId';

  // ─── Calendrier, contrats, compte ──────────────────────────
  static String calendrierUniversite(String universiteId) =>
      '/api/calendrier/universite/$universiteId';
  static const String mesContrats = '/api/rh/mes-contrats';
  static String utilisateur(String id) => '/api/utilisateurs/$id';
  static String inscriptionsUniversite(String universiteId) =>
      '/api/inscriptions/universite/$universiteId';

  /// Dossier d'inscription complet — la seule route qui rende `etudiantId`.
  ///
  /// Ni la réponse de connexion ni `GET /api/auth/moi` ne le portent : elles
  /// s'arrêtent à `inscriptionId`. Or `POST /api/transfert/demandes` exige
  /// `etudiantId` ET `inscriptionId`, et son garde vérifie les deux. Cette
  /// route est ouverte à l'ÉTUDIANT sous `peutAccederInscription` : il ne lit
  /// que la sienne.
  static String inscription(String inscriptionId) =>
      '/api/inscriptions/$inscriptionId';

  // ─── Smart Presence ────────────────────────────────────────
  // La séance de l'étudiant se cherche par sa promotion (`/sessions/mienne`),
  // plus par cours (`/sessions/active?coursId=`) : l'emploi du temps étudiant
  // était vide et l'ancienne route a été supprimée du backend.
  static const String attendanceSessionsStart = '/api/attendance/sessions/start';
  static const String attendanceSessionsClose = '/api/attendance/sessions';
  static const String attendanceSessionMienne = '/api/attendance/sessions/mienne';
  static String attendanceSession(int sessionId) =>
      '/api/attendance/sessions/$sessionId';
  static String attendanceVerifyProximity(int sessionId) =>
      '/api/attendance/sessions/$sessionId/verify-proximity';
  static String attendanceScan(int sessionId) =>
      '/api/attendance/sessions/$sessionId/scan';
  static String attendanceRecords(int sessionId) =>
      '/api/attendance/sessions/$sessionId/records';
  static String attendanceFermer(int sessionId) =>
      '/api/attendance/sessions/$sessionId/close';
  static const String attendanceSessionCourante =
      '/api/attendance/sessions/courante';
  static const String attendanceSeancesDuJour =
      '/api/attendance/professeur/seances-du-jour';

  // ─── Présences classiques (QR imprimé, saisie) ─────────────
  static const String presenceGenererQr = '/api/presences/generer-qr';
  static const String presenceScanner = '/api/presences/scanner';
  static String presencesCours(String coursId) => '/api/presences/cours/$coursId';

  /// Analyse d'un fichier de notes SANS écriture. À appeler avant
  /// `notesImport` : l'import enregistre les lignes valides même quand
  /// d'autres échouent, ce qui est irréversible (cf. `ImportNotes.jsx`).
  static const String notesAnalyser = '/api/notes/import-export/analyser';

  // ─── Vacations (jour / soir) ───────────────────────────────
  static String vacationsUniversite(String universiteId) =>
      '/api/vacations/universite/$universiteId';
  static String vacationsActives(String universiteId) =>
      '/api/vacations/universite/$universiteId/actives';
  static String vacationsCoursProfesseur(String professeurId) =>
      '/api/vacations/professeur/$professeurId/cours';
  static String vacationsInscriptionsEtudiant(String etudiantId) =>
      '/api/vacations/etudiant/$etudiantId/inscriptions';

  /// Configuration publique de l'université, dont `modulesActifs` : le portail
  /// web y lit quels modules masquer dans le menu.
  static String universitePublique(String universiteId) =>
      '/api/universites/public/$universiteId';

  // ─── Bibliothèque : emprunts ───────────────────────────────
  static String bibliothequeLivres(String universiteId) =>
      '/api/bibliotheque/livres/$universiteId';
  static const String bibliothequeEmprunter = '/api/bibliotheque/emprunter';
  static String bibliothequeMesEmprunts(String etudiantId) =>
      '/api/bibliotheque/mes-emprunts/$etudiantId';
  static String bibliothequeProlonger(String empruntId) =>
      '/api/bibliotheque/prolonger/$empruntId';

  // ─── Recours de délibération ───────────────────────────────
  static String recoursEtudiant(String etudiantId) =>
      '/api/deliberation/recours/etudiant/$etudiantId';

  // ─── Équivalences de diplômes (détail) ─────────────────────
  static String equivalencesEtudiant(String utilisateurId) =>
      '/api/equivalences/etudiant/$utilisateurId';
  static String equivalence(String id) => '/api/equivalences/$id';

  // ─── Démarches : pièces jointes et éligibilité ─────────────
  static String demandePiecesJointes(String id) =>
      '/api/demandes-academiques/$id/pieces-jointes';
  static String demande(String id) => '/api/demandes-academiques/$id';
  static const String demandeEligibilite = '/api/demandes-academiques/eligibilite';
  static const String demandeTypes = '/api/demandes-academiques/types';
  static String demandeHistorique(String id) =>
      '/api/demandes-academiques/$id/historique';
}
