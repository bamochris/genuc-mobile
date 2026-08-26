/// Modèles Smart Présence, alignés sur les DTOs du backend
/// (`cd.genuc.dto.*`).
library;

/// Révisés après le passage à la version « preuve de proximité » : la réponse
/// de séance porte `retards`, `absents` et `tentativesRefusees` (plus
/// `enAttente`/`refuses`), le scan renvoie un `code` stable, et la demande de
/// preuve attend position + appareil.

/// État d'une séance — correspond à `SessionStatusResponse`.
class AttendanceSessionDto {
  final int sessionId;
  final int coursId;
  final String coursTitre;
  final String? coursCode;
  final String? salleNom;
  final String? professeurNom;
  final String? promotionLibelle;
  final String statut; // ACTIVE, FERMEE, EXPIREE
  final String? dateDebut;
  final String? expiresAt;
  final int totalAttendus;
  final int presents;
  final int retards;
  final int absents;
  final int tentativesRefusees;
  final int verificationsRequises;

  /// Charge utile du QR courant. **Nul pour un étudiant** : le serveur ne la
  /// sert qu'à l'enseignant et à l'encadrement.
  final String? qrPayload;
  final int qrValiditeSecondes;

  AttendanceSessionDto({
    required this.sessionId,
    required this.coursId,
    required this.coursTitre,
    this.coursCode,
    this.salleNom,
    this.professeurNom,
    this.promotionLibelle,
    required this.statut,
    this.dateDebut,
    this.expiresAt,
    required this.totalAttendus,
    required this.presents,
    required this.retards,
    required this.absents,
    required this.tentativesRefusees,
    required this.verificationsRequises,
    this.qrPayload,
    this.qrValiditeSecondes = 15,
  });

  factory AttendanceSessionDto.fromJson(Map<String, dynamic> json) {
    return AttendanceSessionDto(
      sessionId: json['sessionId'] ?? json['id'] ?? 0,
      coursId: json['coursId'] ?? 0,
      coursTitre: json['coursTitre'] ?? '',
      coursCode: json['coursCode'],
      salleNom: json['salleNom'],
      professeurNom: json['professeurNom'],
      promotionLibelle: json['promotionLibelle'],
      statut: json['statut'] ?? 'ACTIVE',
      dateDebut: json['dateDebut'],
      expiresAt: json['expiresAt'],
      totalAttendus: json['totalAttendus'] ?? 0,
      presents: json['presents'] ?? 0,
      retards: json['retards'] ?? 0,
      absents: json['absents'] ?? 0,
      tentativesRefusees: json['tentativesRefusees'] ?? 0,
      verificationsRequises: json['verificationsRequises'] ?? 0,
      qrPayload: json['qrPayload'],
      qrValiditeSecondes: json['qrValiditeSecondes'] ?? 15,
    );
  }

  bool get estOuverte => statut == 'ACTIVE';
  String get dateDebutAffichee => dateDebut ?? '';
}

/// Issue d'un scan — correspond à `ScanQrResponse`.
///
/// Un refus est une réponse normale (HTTP 200) avec `success:false` : l'écran
/// doit lire `success` et `message`, pas lever d'exception.
class ScanQrResponseDto {
  final bool success;
  final String message;

  /// Code stable, pour adapter l'affichage :
  /// `PRESENCE_CONFIRMEE`, `PRESENCE_RETARD`, `PRESENCE_REFUSEE`...
  final String? code;
  final String? statut;
  final String? coursTitre;
  final String? salleNom;
  final String? heureArrivee;

  ScanQrResponseDto({
    required this.success,
    required this.message,
    this.code,
    this.statut,
    this.coursTitre,
    this.salleNom,
    this.heureArrivee,
  });

  factory ScanQrResponseDto.fromJson(Map<String, dynamic> json) {
    return ScanQrResponseDto(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      code: json['code'],
      statut: json['statut'],
      coursTitre: json['coursTitre'],
      salleNom: json['salleNom'],
      heureArrivee: json['heureArrivee'],
    );
  }

  bool get estRetard => code == 'PRESENCE_RETARD';
  bool get dejaEnregistre => code == 'PRESENCE_DEJA_ENREGISTREE';
}

/// Contexte envoyé à `POST /sessions/{id}/verify-proximity` —
/// correspond à `ProximityProofRequest`.
///
/// Tout est facultatif et rien n'y est cru sur parole : le serveur traite ces
/// valeurs comme des indices, jamais comme un verdict. Position et
/// identifiant d'appareil sont récoltés par [PresenceContexteService].
class ProximityProofRequest {
  final double? latitude;
  final double? longitude;
  final double? precisionMetres;
  final String? identifiantAppareil;

  ProximityProofRequest({
    this.latitude,
    this.longitude,
    this.precisionMetres,
    this.identifiantAppareil,
  });

  Map<String, dynamic> toJson() {
    return {
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (precisionMetres != null) 'precisionMetres': precisionMetres,
      if (identifiantAppareil != null) 'identifiantAppareil': identifiantAppareil,
    };
  }
}

/// Réponse de la demande de preuve — correspond à `ProximityProofResponse`.
class ProximityProofResponseDto {
  final String proofToken;
  final int ttlSeconds;

  ProximityProofResponseDto({
    required this.proofToken,
    required this.ttlSeconds,
  });

  factory ProximityProofResponseDto.fromJson(Map<String, dynamic> json) {
    return ProximityProofResponseDto(
      proofToken: json['proofToken'] ?? '',
      ttlSeconds: json['ttlSeconds'] ?? 120,
    );
  }

  bool get valide => proofToken.isNotEmpty;
}

/// Une présence enregistrée — correspond à `AttendanceRecordResponse`.
class AttendanceRecordDto {
  final int id;
  final int sessionId;
  final int etudiantId;
  final String etudiantNom;
  final String etudiantPrenom;
  final String statut;
  final String? verifieA;
  final String? methodeVerification;
  final bool proximiteVerifiee;
  final bool qrVerifie;
  final String? motifRefus;
  final bool verificationRequise;
  final String? motifVerification;
  final double? distanceMetres;

  AttendanceRecordDto({
    required this.id,
    required this.sessionId,
    required this.etudiantId,
    required this.etudiantNom,
    required this.etudiantPrenom,
    required this.statut,
    this.verifieA,
    this.methodeVerification,
    required this.proximiteVerifiee,
    required this.qrVerifie,
    this.motifRefus,
    this.verificationRequise = false,
    this.motifVerification,
    this.distanceMetres,
  });

  factory AttendanceRecordDto.fromJson(Map<String, dynamic> json) {
    return AttendanceRecordDto(
      id: json['id'] ?? 0,
      sessionId: json['sessionId'] ?? 0,
      etudiantId: json['etudiantId'] ?? 0,
      etudiantNom: json['etudiantNom'] ?? '',
      etudiantPrenom: json['etudiantPrenom'] ?? '',
      statut: json['statut'] ?? 'EN_ATTENTE',
      verifieA: json['verifieA'],
      methodeVerification: json['methodeVerification'],
      proximiteVerifiee: json['proximiteVerifiee'] ?? false,
      qrVerifie: json['qrVerifie'] ?? false,
      motifRefus: json['motifRefus'],
      verificationRequise: json['verificationRequise'] ?? false,
      motifVerification: json['motifVerification'],
      distanceMetres: json['distanceMetres']?.toDouble(),
    );
  }
}
