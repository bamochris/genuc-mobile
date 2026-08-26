/// Modèle de données pour le dashboard étudiant
/// Correspond exactement à EtudiantDashboardDto du backend GENUC
class DashboardData {
  // Informations personnelles
  final String matricule;
  final String nomComplet;
  final String email;
  final String? photo;
  
  // Informations académiques
  final String universite;
  final String departement;
  final String filiere;
  final String promotion;
  final String? niveau;
  final String anneeAcademique;
  
  // Vacation académique (Jour / Soir)
  final int? vacationId;
  final String? vacationNom;
  final String? typeVacation;
  final bool vacationChoisie;
  final List<VacationOptionDto> vacationsDisponibles;
  
  // Résultats académiques
  final double moyenneGenerale;
  final int creditsValides;
  
  // Situation financière
  final double soldeAPayer;
  
  // Progression
  final int progressionGlobale;
  
  // Listes
  final List<NotificationDto> notifications;
  final List<CoursSimpleDto> prochainsCours;
  final List<ExamenSimpleDto> prochainsExamens;
  final StatsDto stats;
  
  // Champs additionnels
  final List<NoteSimpleDto>? notes;
  final List<EmploiTempsDto>? emploiTemps;
  final List<MessageSimpleDto>? messages;

  DashboardData({
    required this.matricule,
    required this.nomComplet,
    required this.email,
    this.photo,
    required this.universite,
    required this.departement,
    required this.filiere,
    required this.promotion,
    this.niveau,
    required this.anneeAcademique,
    this.vacationId,
    this.vacationNom,
    this.typeVacation,
    this.vacationChoisie = false,
    this.vacationsDisponibles = const [],
    required this.moyenneGenerale,
    required this.creditsValides,
    required this.soldeAPayer,
    required this.progressionGlobale,
    required this.notifications,
    required this.prochainsCours,
    required this.prochainsExamens,
    required this.stats,
    this.notes,
    this.emploiTemps,
    this.messages,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      matricule: json['matricule'] ?? '',
      nomComplet: json['nomComplet'] ?? '',
      email: json['email'] ?? '',
      photo: json['photo'],
      universite: json['universite'] ?? '',
      departement: json['departement'] ?? '',
      filiere: json['filiere'] ?? '',
      promotion: json['promotion'] ?? '',
      niveau: json['niveau'],
      anneeAcademique: json['anneeAcademique'] ?? '',
      vacationId: json['vacationId'],
      vacationNom: json['vacationNom'],
      typeVacation: json['typeVacation'],
      vacationChoisie: json['vacationChoisie'] ?? false,
      vacationsDisponibles: (json['vacationsDisponibles'] as List?)
              ?.map((e) => VacationOptionDto.fromJson(e))
              .toList() ??
          [],
      moyenneGenerale: (json['moyenneGenerale'] ?? 0).toDouble(),
      creditsValides: json['creditsValides'] ?? 0,
      soldeAPayer: (json['soldeAPayer'] ?? 0).toDouble(),
      progressionGlobale: json['progressionGlobale'] ?? 0,
      notifications: (json['notifications'] as List?)
              ?.map((e) => NotificationDto.fromJson(e))
              .toList() ??
          [],
      prochainsCours: (json['prochainsCours'] as List?)
              ?.map((e) => CoursSimpleDto.fromJson(e))
              .toList() ??
          [],
      prochainsExamens: (json['prochainsExamens'] as List?)
              ?.map((e) => ExamenSimpleDto.fromJson(e))
              .toList() ??
          [],
      stats: StatsDto.fromJson(json['stats'] ?? {}),
      notes: (json['notes'] as List?)
              ?.map((e) => NoteSimpleDto.fromJson(e))
              .toList(),
      emploiTemps: (json['emploiTemps'] as List?)
              ?.map((e) => EmploiTempsDto.fromJson(e))
              .toList(),
      messages: (json['messages'] as List?)
              ?.map((e) => MessageSimpleDto.fromJson(e))
              .toList(),
    );
  }

  bool get hasDebts => soldeAPayer > 0;
  bool get isReussi => moyenneGenerale >= 10;
  String get progressionFormatted => '$progressionGlobale%';
}

class NotificationDto {
  final int? id;
  final String message;
  final String type;
  final String date;
  final bool lu;

  NotificationDto({
    this.id,
    required this.message,
    required this.type,
    required this.date,
    required this.lu,
  });

  factory NotificationDto.fromJson(Map<String, dynamic> json) {
    return NotificationDto(
      id: json['id'],
      message: json['message'] ?? '',
      type: json['type'] ?? 'INFO',
      date: json['date'] ?? '',
      lu: json['lu'] ?? false,
    );
  }
}

class CoursSimpleDto {
  final int? id;
  final String titre;
  final String code;
  final String? professeur;
  final String? thumbnail;
  final int? progression;

  CoursSimpleDto({
    this.id,
    required this.titre,
    required this.code,
    this.professeur,
    this.thumbnail,
    this.progression,
  });

  factory CoursSimpleDto.fromJson(Map<String, dynamic> json) {
    return CoursSimpleDto(
      id: json['id'],
      titre: json['titre'] ?? '',
      code: json['code'] ?? '',
      professeur: json['professeur'],
      thumbnail: json['thumbnail'],
      progression: json['progression'],
    );
  }
}

class ExamenSimpleDto {
  final int? id;
  final String titre;
  final String? date;
  final String? salle;
  final int? nbJoursRestant;

  ExamenSimpleDto({
    this.id,
    required this.titre,
    this.date,
    this.salle,
    this.nbJoursRestant,
  });

  factory ExamenSimpleDto.fromJson(Map<String, dynamic> json) {
    return ExamenSimpleDto(
      id: json['id'],
      titre: json['titre'] ?? '',
      date: json['date'],
      salle: json['salle'],
      nbJoursRestant: json['nbJoursRestant'],
    );
  }
}

class StatsDto {
  final int totalCours;
  final int coursCompletes;
  final int totalSeances;
  final int seancesSuivies;
  final int messagesNonLus;

  StatsDto({
    required this.totalCours,
    required this.coursCompletes,
    required this.totalSeances,
    required this.seancesSuivies,
    required this.messagesNonLus,
  });

  factory StatsDto.fromJson(Map<String, dynamic> json) {
    return StatsDto(
      totalCours: json['totalCours'] ?? 0,
      coursCompletes: json['coursCompletes'] ?? 0,
      totalSeances: json['totalSeances'] ?? 0,
      seancesSuivies: json['seancesSuivies'] ?? 0,
      messagesNonLus: json['messagesNonLus'] ?? 0,
    );
  }
}

class NoteSimpleDto {
  final String cours;
  final double? noteFinale;
  final String? mention;

  NoteSimpleDto({
    required this.cours,
    this.noteFinale,
    this.mention,
  });

  factory NoteSimpleDto.fromJson(Map<String, dynamic> json) {
    return NoteSimpleDto(
      cours: json['cours'] ?? '',
      noteFinale: json['noteFinale']?.toDouble(),
      mention: json['mention'],
    );
  }
}

class EmploiTempsDto {
  final String titre;
  final String jour;
  final String heureDebut;
  final String heureFin;
  final String salle;

  EmploiTempsDto({
    required this.titre,
    required this.jour,
    required this.heureDebut,
    required this.heureFin,
    required this.salle,
  });

  factory EmploiTempsDto.fromJson(Map<String, dynamic> json) {
    return EmploiTempsDto(
      titre: json['titre'] ?? '',
      jour: json['jour'] ?? '',
      heureDebut: json['heureDebut'] ?? '',
      heureFin: json['heureFin'] ?? '',
      salle: json['salle'] ?? '',
    );
  }
}

class MessageSimpleDto {
  final String sujet;
  final String contenu;
  final String dateEnvoi;
  final bool lu;

  MessageSimpleDto({
    required this.sujet,
    required this.contenu,
    required this.dateEnvoi,
    required this.lu,
  });

  factory MessageSimpleDto.fromJson(Map<String, dynamic> json) {
    return MessageSimpleDto(
      sujet: json['sujet'] ?? '',
      contenu: json['contenu'] ?? '',
      dateEnvoi: json['dateEnvoi'] ?? '',
      lu: json['lu'] ?? false,
    );
  }
}

class VacationOptionDto {
  final int id;
  final String nom;
  final String type;
  final double? fraisInscription;
  final String? deviseFrais;

  VacationOptionDto({
    required this.id,
    required this.nom,
    required this.type,
    this.fraisInscription,
    this.deviseFrais,
  });

  factory VacationOptionDto.fromJson(Map<String, dynamic> json) {
    return VacationOptionDto(
      id: json['id'] ?? 0,
      nom: json['nom'] ?? '',
      type: json['type'] ?? 'JOUR',
      fraisInscription: json['fraisInscription'] != null
          ? (json['fraisInscription'] as num).toDouble()
          : null,
      deviseFrais: json['deviseFrais'],
    );
  }
}