import 'dart:convert';

import 'package:dio/dio.dart';

/// Serveur de test qui répond des données PLAUSIBLES à toutes les routes.
///
/// <h3>Pourquoi il fallait l'écrire</h3>
///
/// L'audit de contraste existant coupe le réseau : chaque écran montre alors
/// son état d'erreur, et c'est cet état-là — quatre lignes de texte gris — qui
/// était mesuré. Tout ce qui ne s'affiche qu'avec des données restait donc hors
/// de portée : les cartes de statistiques, les pastilles de statut, les
/// tableaux, les grilles horaires. C'est très exactement là que se logeaient
/// les couleurs de marque posées en dur, et c'est pourquoi le portail
/// professeur pouvait être illisible en thème sombre pendant que la suite
/// restait verte.
///
/// <h3>Comment il couvre autant de routes sans les lister toutes</h3>
///
/// Les écrans lisent le serveur de deux manières :
/// - typée (`StatsProfesseur.fromJson`, `SeanceProfesseur.fromJson`…), qui
///   exige la forme exacte — ces routes-là sont déclarées une par une ;
/// - tolérante (`Fiche`), qui accepte n'importe quel objet et cherche ses
///   champs par alias — un enregistrement générique riche suffit.
///
/// D'où la réponse par défaut : un objet qui porte À LA FOIS `content` (la
/// liste, pour `listeDe`) et les champs d'un enregistrement au premier niveau
/// (pour `ficheDe`). Une seule charge utile satisfait les deux lectures, et
/// une route ajoutée demain rend du contenu sans qu'on ait à y toucher.
class ServeurSimule implements HttpClientAdapter {
  /// Routes dont la FORME compte, parce qu'un modèle typé les analyse.
  ///
  /// L'ordre est significatif : la première expression qui accroche répond.
  /// `/api/professeur/presences/historique/{id}` doit donc précéder
  /// `/api/professeur/presences/{id}`, qui l'accrocherait sinon.
  static final List<(RegExp, dynamic)> _routes = [
    // ─── Tableau de bord professeur ───
    (
      RegExp(r'/api/professeur/stats/'),
      {
        'totalCours': 6,
        'coursAujourdhui': 2,
        'totalEtudiants': 184,
        'tauxPresence': 87,
        'notesACorriger': 23,
        'notesEnAttente': 9,
      }
    ),
    (
      RegExp(r'/api/professeur/presences/historique/'),
      _listeGenerique,
    ),
    (
      RegExp(r'/api/professeur/presences/'),
      {
        'total': 412,
        'presents': 358,
        'tauxPresence': 87,
        'totalEtudiants': 184,
        'totalSeances': 24,
        'absencesJustifiees': 12,
        'parCours': [
          {
            'coursId': 1,
            'titre': 'Algorithmique et structures de données',
            'code': 'INFO-201',
            'total': 210,
            'presents': 188,
            'absencesJustifiees': 7,
            'nbSeances': 12,
            'tauxPresence': 89,
          },
          {
            'coursId': 2,
            'titre': 'Bases de données relationnelles',
            'code': 'INFO-204',
            'total': 202,
            'presents': 170,
            'absencesJustifiees': 5,
            'nbSeances': 12,
            'tauxPresence': 84,
          },
        ],
      }
    ),
    // Les trois statuts (`done`, `active`, `upcoming`) sont représentés : chacun
    // porte sa propre couleur, et un statut absent de la simulation serait un
    // trou dans l'audit.
    (
      RegExp(r'/api/professeur/schedule/today/'),
      [
        _seance(1, 'Algorithmique', 'INFO-201', '08:00', '10:00', 'done'),
        _seance(2, 'Bases de données', 'INFO-204', '10:15', '12:15', 'active'),
        _seance(3, 'Génie logiciel', 'INFO-301', '14:00', '16:00', 'upcoming'),
      ]
    ),
    // Les deux types d'alerte (`warning`, `info`), pour la même raison.
    (
      RegExp(r'/api/professeur/alertes/'),
      [
        {
          'type': 'warning',
          'titre': 'Notes non encodées',
          'message': '23 copies restent à corriger pour INFO-201.',
          'date': '30/08/2026',
          'lien': '/professeur/notes/saisie',
          'action': 'Encoder',
        },
        {
          'type': 'info',
          'titre': 'Délibération ouverte',
          'message': 'Le jury de L2 Informatique siège le 5 septembre.',
          'date': '29/08/2026',
          'lien': '/professeur/deliberation',
          'action': 'Ouvrir',
        },
      ]
    ),
    (
      RegExp(r'/api/professeur/planning/'),
      [
        {
          'jour': 'MONDAY',
          'seances': [
            _seance(1, 'Algorithmique', 'INFO-201', '08:00', '10:00', 'done',
                semestre: 'S1'),
            _seance(4, 'Bases de données', 'INFO-204', '13:00', '15:00',
                'upcoming',
                semestre: 'ANNUEL'),
          ],
        },
        {
          'jour': 'TUESDAY',
          'seances': [
            _seance(2, 'Génie logiciel', 'INFO-301', '10:00', '12:00', 'active',
                semestre: 'S2'),
          ],
        },
        {'jour': 'WEDNESDAY', 'seances': <dynamic>[]},
        {
          'jour': 'THURSDAY',
          'seances': [
            _seance(5, 'Réseaux', 'INFO-305', '08:00', '11:00', 'upcoming'),
          ],
        },
        {'jour': 'FRIDAY', 'seances': <dynamic>[]},
      ]
    ),

    // ─── Portail étudiant : les quatre lectures dont la FORME compte ───
    //
    // Ces routes ne rendent PAS un tableau nu, ou portent des clés que le
    // générique n'a pas. Servies par la réponse par défaut, elles remplissaient
    // l'écran d'éléments plausibles — et masquaient donc exactement ce qu'il
    // fallait mesurer : l'écran des travaux paraissait rempli en test alors
    // qu'il est vide en production (le serveur rend `{travaux: […]}`, jamais
    // `content`), et les pastilles de statut des documents officiels ne
    // s'affichaient sur aucune ligne.

    // `TravauxService.mesTravaux` : un OBJET à deux clés, pas une liste.
    (
      RegExp(r'/api/etudiant/portal/\d+/travaux'),
      {
        'travaux': [
          _travail(1, 'A_SOUMETTRE'),
          _travail(2, 'EN_RETARD'),
          _travail(3, 'SOUMIS'),
          _travail(4, 'CORRIGE'),
        ],
        'coursList': [
          {'id': 1, 'code': 'INFO-201', 'titre': 'Algorithmique'},
        ],
      }
    ),

    // Les copies rendues pour un travail, vues par l'enseignant.
    (
      RegExp(r'/api/travaux/\d+/soumissions'),
      [
        _copie(1, 'MUKENDI Espoir', '20260001', note: null),
        _copie(2, 'KABILA Grâce', '20260002', note: 15.5),
        _copie(3, 'ILUNGA Josué', '20260003', note: 8.0),
      ]
    ),

    // Les travaux publiés par l'enseignant : leur cours, leur échéance et
    // l'état des copies décident de ce que la carte affiche.
    (
      RegExp(r'/api/travaux/professeur/'),
      [
        _travailProfesseur(1, 'Devoir 1 — complexité', 'DEVOIR',
            soumissions: 12, corrigees: 4, avecConsignes: true),
        _travailProfesseur(2, 'TP 2 — tables de hachage', 'TP',
            soumissions: 9, corrigees: 9, avecConsignes: false),
      ]
    ),

    // `DocumentsOfficielsService.mapperDocument` : un catalogue, où chaque
    // ligne porte son statut et ce que l'étudiant peut en faire.
    (
      RegExp(r'/api/etudiant/portal/\d+/documents-officiels'),
      [
        _documentOfficiel('CERTIFICAT_SCOLARITE', 'Certificat de scolarité',
            'DISPONIBLE'),
        _documentOfficiel('RELEVE_NOTES', 'Relevé de notes officiel',
            'PAIEMENT_REQUIS'),
        _documentOfficiel('ATTESTATION_REUSSITE', 'Attestation de réussite',
            'DEMANDE_EN_COURS'),
        _documentOfficiel('CERTIFICAT_INSCRIPTION', 'Certificat d\'inscription',
            'A_DEMANDER'),
      ]
    ),

    // Les supports, groupés par cours de l'emploi du temps.
    (
      RegExp(r'/api/etudiant/portal/\d+/supports'),
      [
        {
          'coursId': 1,
          'coursCode': 'INFO-201',
          'coursTitre': 'Algorithmique et structures de données',
          'professeurNom': 'Prof. KABEYA',
          'nombreSupports': 2,
          'seances': [
            {
              'id': 11,
              'jour': 'MONDAY',
              'heureDebut': '08:00:00',
              'heureFin': '10:00:00',
              'salleNom': 'Amphi B1',
              'semestre': 'S1',
            },
            {
              'id': 12,
              'jour': 'THURSDAY',
              'heureDebut': '14:00:00',
              'heureFin': '16:00:00',
              'salleNom': 'Labo 3',
              'semestre': 'S1',
            },
          ],
          'supports': [
            _support(1, 'Chapitre 1 — Complexité', 'PDF'),
            _support(2, 'Séance 3 — Tris', 'PPT'),
          ],
        },
        {
          'coursId': 2,
          'coursCode': 'INFO-204',
          'coursTitre': 'Bases de données relationnelles',
          'professeurNom': 'Prof. MULUMBA',
          'nombreSupports': 0,
          'seances': [
            {
              'id': 21,
              'jour': 'TUESDAY',
              'heureDebut': '10:00:00',
              'heureFin': '12:00:00',
              'salleNom': 'Amphi A',
            },
          ],
          'supports': <dynamic>[],
        },
      ]
    ),

    // Les pièces du dossier : c'est leur `url` de stockage qui décide si
    // l'action « Ouvrir » s'affiche.
    (
      RegExp(r'/api/documents/inscription/\d+'),
      [
        _piece(1, 'CARTE_IDENTITE', 'carte_identite.pdf', 'VALIDE'),
        _piece(2, 'DIPLOME', 'diplome_etat.pdf', 'EN_ATTENTE'),
        _piece(3, 'PHOTO', 'photo.jpg', 'REJETE'),
      ]
    ),

    // ─── Compteurs de notification (badge de la barre du haut) ───
    (RegExp(r'/api/notifications/.*(count|non-lues)'), {'count': 3, 'total': 3}),
  ];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    final chemin = options.uri.path;
    for (final (motif, charge) in _routes) {
      if (motif.hasMatch(chemin)) return _repondre(charge);
    }
    return _repondre(_parDefaut);
  }

  static ResponseBody _repondre(dynamic charge) => ResponseBody.fromString(
        jsonEncode(charge),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  static Map<String, dynamic> _seance(
    int id,
    String titre,
    String code,
    String debut,
    String fin,
    String statut, {
    String? semestre,
  }) =>
      {
        'id': id,
        'titre': titre,
        'code': code,
        'heureDebut': debut,
        'heureFin': fin,
        'salle': 'Amphi B$id',
        'nbEtudiants': 42 + id,
        'statut': statut,
        'semestre': ?semestre,
        'promotionLibelle': 'L2 Informatique',
        'vacationNom': 'Jour',
      };

  /// Un travail, avec la correction quand il est corrigé.
  static Map<String, dynamic> _travail(int id, String statut) => {
        'id': id,
        'titre': 'Devoir $id — arbres équilibrés',
        'description': 'Rendre un mémoire de quatre pages, exemples compris.',
        'type': 'DEVOIR',
        'cours': 'Algorithmique et structures de données',
        'coursId': 1,
        'professeur': 'Prof. KABEYA',
        'dateEcheance': '2026-09-1${id % 10}T23:59:00',
        'coefficient': 2.0,
        'urlConsignes': '/uploads/travaux/consignes-$id.pdf',
        'nomFichierConsignes': 'enonce-$id.pdf',
        'urlTelechargementConsignes': '/api/fichiers/travaux/consignes-$id.pdf',
        'statut': statut,
        if (statut == 'SOUMIS' || statut == 'CORRIGE')
          'dateSoumission': '2026-09-0${id % 10}T18:30:00',
        if (statut == 'CORRIGE') ...{
          'note': 15.5,
          'urlCorrection': '/uploads/travaux/correction-$id.pdf',
          'nomFichierCorrection': 'correction-$id.pdf',
          'urlTelechargementCorrection': '/api/fichiers/travaux/correction-$id.pdf',
          'commentaireCorrection':
              'Raisonnement juste, rédaction à resserrer sur la partie 2.',
        },
      };

  /// Un travail vu par l'enseignant qui l'a publié.
  static Map<String, dynamic> _travailProfesseur(
    int id,
    String titre,
    String type, {
    required int soumissions,
    required int corrigees,
    required bool avecConsignes,
  }) =>
      {
        'id': id,
        'titre': titre,
        'description': 'Rendre un mémoire de quatre pages, exemples compris.',
        'type': type,
        'dateEcheance': '2026-09-1$id' 'T23:59:00',
        'coefficient': 2.0,
        'anneeAcademique': '2026-2027',
        'annule': false,
        'coursId': 1,
        'coursCode': 'INFO-201',
        'coursTitre': 'Algorithmique et structures de données',
        'professeurId': 1,
        'professeurNom': 'Prof. KABEYA',
        if (avecConsignes) ...{
          'urlConsignes': '/uploads/travaux/consignes-$id.pdf',
          'nomFichierConsignes': 'enonce-$id.pdf',
          'urlTelechargementConsignes':
              '/api/fichiers/travaux/consignes-$id.pdf',
        },
        'nombreSoumissions': soumissions,
        'nombreCorrigees': corrigees,
      };

  /// Une copie rendue, corrigée ou non.
  static Map<String, dynamic> _copie(
    int id,
    String etudiant,
    String matricule, {
    double? note,
  }) =>
      {
        'id': id,
        'etudiant': etudiant,
        'matricule': matricule,
        'fichierUrl': '/uploads/travaux/copie-$id.pdf',
        'nomFichier': 'copie-$id.pdf',
        'dateSoumission': '2026-09-0$id' 'T18:30:00',
        'statut': note == null ? 'SOUMIS' : 'CORRIGE',
        'note': ?note,
        if (note != null) ...{
          'commentaireCorrection':
              'Raisonnement juste, rédaction à resserrer sur la partie 2.',
          'urlCorrection': '/uploads/travaux/correction-$id.pdf',
          'nomFichierCorrection': 'correction-$id.pdf',
          'urlTelechargementCorrection':
              '/api/fichiers/travaux/correction-$id.pdf',
          'dateCorrection': '2026-09-1$id' 'T09:00:00',
        },
      };

  /// Une ligne du catalogue des documents officiels.
  static Map<String, dynamic> _documentOfficiel(
    String code,
    String libelle,
    String statut,
  ) =>
      {
        'type': code,
        'label': libelle,
        'description': 'Document officiel délivré par l\'établissement.',
        'typeSource': code == 'RELEVE_NOTES' ? 'RELEVE' : 'ATTESTATION',
        'fraisCodeRequis': 'FRAIS_DOC',
        'statut': statut,
        'canDownload': statut == 'DISPONIBLE',
        'canRequest': statut == 'A_DEMANDER',
        if (statut == 'DISPONIBLE') 'dateGeneration': '2026-08-28T09:00:00',
        if (statut != 'DISPONIBLE')
          'motif': switch (statut) {
            'PAIEMENT_REQUIS' =>
              'Paiement du frais documentaire requis avant téléchargement.',
            'DEMANDE_EN_COURS' =>
              'Votre demande est en cours de traitement par l\'administration.',
            _ => 'Vous pouvez soumettre une demande.',
          },
      };

  /// Une pièce du dossier de l'étudiant.
  static Map<String, dynamic> _piece(
    int id,
    String type,
    String nomFichier,
    String statut,
  ) =>
      {
        'id': id,
        'type': type,
        'nomFichier': nomFichier,
        'url': '/uploads/documents/$id-$nomFichier',
        'statut': statut,
        'dateDepot': '2026-08-2${id % 10}T09:00:00',
      };

  /// Un support de cours.
  static Map<String, dynamic> _support(int id, String titre, String type) => {
        'id': id,
        'titre': titre,
        'description': 'Déposé pour la séance, à lire avant le cours.',
        'type': type,
        'url': '/uploads/supports/$id.pdf',
        'urlTelechargement': '/api/cours/supports/$id/fichier',
        'nomFichierOriginal': '$titre.pdf',
        'tailleOctets': 1_540_000 + id,
        'creeLe': '2026-08-2${id % 10}T09:00:00',
      };

  /// L'enregistrement générique, servi à toute route non déclarée.
  ///
  /// Il porte volontairement BEAUCOUP d'alias — `titre`/`nom`/`libelle`,
  /// `statut`/`etat`… — parce que les écrans les cherchent par
  /// `Fiche.texte('titre', alias: ['nom'])` et que la valeur trouvée décide de
  /// ce qui s'affiche. Un champ manquant ne casse rien : il masque simplement
  /// un widget, et ce widget échapperait alors à l'audit.
  static Map<String, dynamic> _enregistrement(
    int i,
    String statut, {
    String? mention,
  }) =>
      {
        'id': i,
        'titre': 'Élément de démonstration $i',
        'nom': 'Élément de démonstration $i',
        'libelle': 'Élément de démonstration $i',
        'code': 'REF-00$i',
        'description': 'Description complète du dossier numéro $i, '
            'servie pour éprouver la lisibilité de la fiche.',
        'sousTitre': 'L2 Informatique · Jour',
        'statut': statut,
        'etat': statut,
        'type': statut,
        'niveau': 'L2',
        'promotion': 'L2 Informatique',
        'promotionLibelle': 'L2 Informatique',
        'vacationNom': 'Jour',
        'semestre': 'S1',
        'anneeAcademique': '2026-2027',
        'annee': '2026-2027',
        'date': '2026-08-2${i % 10}T09:00:00',
        'dateCreation': '2026-08-2${i % 10}T09:00:00',
        'dateDebut': '2026-08-2${i % 10}T09:00:00',
        'dateFin': '2026-09-2${i % 10}T09:00:00',
        'dateRetour': '2026-09-2${i % 10}T09:00:00',
        'heureDebut': '08:00',
        'heureFin': '10:00',
        'salle': 'Amphi B$i',
        'note': 12.5 + i,
        'noteFinale': 12.5 + i,
        'moyenne': 12.5 + i,
        'pourcentage': 60 + i,
        'progression': 60 + i,
        'montant': 25000 + i * 1000,
        'total': 40 + i,
        'nombre': 40 + i,
        'nbEtudiants': 40 + i,
        'effectif': 40 + i,
        'credits': 6,
        'volumeHoraire': 60,
        'matricule': '20260$i',
        'nomComplet': 'MUKENDI Étudiant $i',
        'prenom': 'Étudiant',
        'email': 'etudiant$i@genuc.test',
        'telephone': '+243 810 000 00$i',
        'professeur': 'Prof. KABEYA',
        'cours': 'Algorithmique et structures de données',
        'coursTitre': 'Algorithmique et structures de données',
        'auteur': 'KABEYA J.',
        'titreOuvrage': 'Algorithmique appliquée',
        'publie': i.isEven,
        'actif': true,
        'valide': i.isEven,
        'present': i.isEven,
        'mention': ?mention,
        'appreciation': ?mention,
      };

  static final List<Map<String, dynamic>> _echantillon = [
    _enregistrement(1, 'EN_COURS', mention: 'Excellent'),
    _enregistrement(2, 'VALIDE', mention: 'Très Bien'),
    _enregistrement(3, 'EN_ATTENTE', mention: 'Bien'),
    _enregistrement(4, 'REJETE', mention: 'Assez Bien'),
    _enregistrement(5, 'TERMINE', mention: 'Insuffisant'),
  ];

  static final List<dynamic> _listeGenerique = _echantillon;

  /// Objet ET liste à la fois — cf. l'en-tête de classe.
  ///
  /// Aucune clé `data` : `deballerReponse` ne doit PAS déballer cette
  /// enveloppe, sans quoi `ficheDe` recevrait une liste au lieu d'un objet et
  /// rendrait une fiche vide.
  static final Map<String, dynamic> _parDefaut = {
    ..._enregistrement(1, 'EN_COURS', mention: 'Excellent'),
    'content': _echantillon,
    'items': _echantillon,
    'resultats': _echantillon,
    'liste': _echantillon,
    'totalElements': _echantillon.length,
  };
}
