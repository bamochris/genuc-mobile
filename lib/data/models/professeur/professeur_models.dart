/// Modèles du portail professeur.
///
/// Correspondent exactement aux réponses de `ProfesseurController`
/// (genuc-backend) — aucune donnée n'est inventée, chaque champ est servi par
/// `ProfesseurService` :
/// - `GET /api/professeur/stats/{id}` → [StatsProfesseur] ;
/// - `GET /api/professeur/presences/{id}` → [ResumePresences] ;
/// - `GET /api/professeur/schedule/today/{id}` → liste [SeanceProfesseur] ;
/// - `GET /api/professeur/alertes/{id}` → liste [AlerteProfesseur] ;
/// - `GET /api/professeur/planning/{id}` → liste [JourPlanning].
class StatsProfesseur {
  final int totalCours;
  final int coursAujourdhui;
  final int totalEtudiants;
  final int tauxPresence;
  final int notesACorriger;
  final int notesEnAttente;

  StatsProfesseur({
    required this.totalCours,
    required this.coursAujourdhui,
    required this.totalEtudiants,
    required this.tauxPresence,
    required this.notesACorriger,
    required this.notesEnAttente,
  });

  factory StatsProfesseur.fromJson(Map<String, dynamic> json) {
    return StatsProfesseur(
      totalCours: (json['totalCours'] ?? 0).toInt(),
      coursAujourdhui: (json['coursAujourdhui'] ?? 0).toInt(),
      totalEtudiants: (json['totalEtudiants'] ?? 0).toInt(),
      tauxPresence: (json['tauxPresence'] ?? 0).toInt(),
      notesACorriger: (json['notesACorriger'] ?? 0).toInt(),
      notesEnAttente: (json['notesEnAttente'] ?? 0).toInt(),
    );
  }
}

/// Résumé des présences, avec le détail par cours.
/// `GET /api/professeur/presences/{id}`.
class ResumePresences {
  final int total;
  final int presents;
  final int tauxPresence;
  final int totalEtudiants;
  final int totalSeances;
  final int absencesJustifiees;
  final List<PresenceParCours> parCours;

  ResumePresences({
    required this.total,
    required this.presents,
    required this.tauxPresence,
    required this.totalEtudiants,
    required this.totalSeances,
    required this.absencesJustifiees,
    required this.parCours,
  });

  factory ResumePresences.fromJson(Map<String, dynamic> json) {
    return ResumePresences(
      total: (json['total'] ?? 0).toInt(),
      presents: (json['presents'] ?? 0).toInt(),
      tauxPresence: (json['tauxPresence'] ?? 0).toInt(),
      totalEtudiants: (json['totalEtudiants'] ?? 0).toInt(),
      totalSeances: (json['totalSeances'] ?? 0).toInt(),
      absencesJustifiees: (json['absencesJustifiees'] ?? 0).toInt(),
      parCours: (json['parCours'] as List?)
              ?.map((e) => PresenceParCours.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class PresenceParCours {
  final int coursId;
  final String titre;
  final String code;
  final int total;
  final int presents;
  final int absencesJustifiees;
  final int nbSeances;
  final int tauxPresence;

  PresenceParCours({
    required this.coursId,
    required this.titre,
    required this.code,
    required this.total,
    required this.presents,
    required this.absencesJustifiees,
    required this.nbSeances,
    required this.tauxPresence,
  });

  factory PresenceParCours.fromJson(Map<String, dynamic> json) {
    return PresenceParCours(
      coursId: (json['coursId'] ?? 0).toInt(),
      titre: json['titre'] ?? '',
      code: json['code'] ?? '',
      total: (json['total'] ?? 0).toInt(),
      presents: (json['presents'] ?? 0).toInt(),
      absencesJustifiees: (json['absencesJustifiees'] ?? 0).toInt(),
      nbSeances: (json['nbSeances'] ?? 0).toInt(),
      tauxPresence: (json['tauxPresence'] ?? 0).toInt(),
    );
  }
}

/// Une séance de l'emploi du temps du jour.
/// `GET /api/professeur/schedule/today/{id}` — statut : `done`, `active` ou
/// `upcoming`.
class SeanceProfesseur {
  final int id;

  /// Le cours dont cette séance est un créneau.
  ///
  /// Nul sur un horaire orphelin (le cours a été supprimé). C'est la clé qui
  /// permet de rapprocher l'emploi du temps de la liste « Mes cours » : sans
  /// elle, les deux vues parlaient du même cours sans pouvoir se rejoindre.
  final int? coursId;

  final String titre;

  /// Code du cours. Servi par `/planning` (où la grille web affiche
  /// `code || titre`) mais absent de `/schedule/today` — d'où le type nullable.
  final String? code;
  final String? heureDebut;
  final String? heureFin;
  final String salle;
  final int nbEtudiants;
  final String statut;

  /// `S1`, `S2`, `ANNUEL` — ou nul : le créneau ne déclare pas de semestre.
  ///
  /// Nul est le cas de toutes les grilles antérieures à la V66 : on n'affiche
  /// alors aucune étiquette, plutôt que d'affirmer « Annuel » par défaut.
  final String? semestre;

  /// Promotion et vacation du créneau.
  ///
  /// « L1 Droit Jour » et « L1 Droit Soir » se donnent au même créneau, dans
  /// deux salles, devant deux cohortes : sans elles, la semaine affichait deux
  /// lignes qu'aucun œil ne pouvait départager.
  final String? promotionLibelle;
  final String? vacationNom;

  SeanceProfesseur({
    required this.id,
    this.coursId,
    required this.titre,
    this.code,
    this.heureDebut,
    this.heureFin,
    required this.salle,
    required this.nbEtudiants,
    required this.statut,
    this.semestre,
    this.promotionLibelle,
    this.vacationNom,
  });

  factory SeanceProfesseur.fromJson(Map<String, dynamic> json) {
    return SeanceProfesseur(
      id: (json['id'] ?? 0).toInt(),
      coursId: (json['coursId'] as num?)?.toInt(),
      titre: json['titre'] ?? 'Cours',
      code: json['code'],
      heureDebut: json['heureDebut'],
      heureFin: json['heureFin'],
      salle: json['salle'] ?? '',
      nbEtudiants: (json['nbEtudiants'] ?? 0).toInt(),
      statut: json['statut'] ?? 'upcoming',
      semestre: json['semestre'],
      promotionLibelle: json['promotionLibelle'],
      vacationNom: json['vacationNom'],
    );
  }

  /// Étiquette courte du semestre, ou nul s'il n'est pas déclaré.
  String? get libelleSemestre => switch (semestre) {
        'S1' => 'S1',
        'S2' => 'S2',
        'ANNUEL' => 'Annuel',
        _ => null,
      };

  /// « L1 · Jour », ou ce qui est connu des deux.
  String get libelleClasse =>
      [promotionLibelle, vacationNom].where((v) => v != null && v.isNotEmpty).join(' · ');

  bool get estTermine => statut == 'done';
  bool get estEnCours => statut == 'active';

  String get libelleStatut {
    switch (statut) {
      case 'done':
        return '✓ Enseigné';
      case 'active':
        return '● En cours';
      default:
        return '◯ À venir';
    }
  }

  String get plageHoraire {
    if (heureDebut == null && heureFin == null) return '';
    if (heureFin == null) return heureDebut!;
    return '$heureDebut - $heureFin';
  }
}

/// Une alerte du tableau de bord professeur.
/// `GET /api/professeur/alertes/{id}` — type : `info` ou `warning`.
class AlerteProfesseur {
  final String type;
  final String titre;
  final String message;
  final String date;
  final String lien;
  final String action;

  AlerteProfesseur({
    required this.type,
    required this.titre,
    required this.message,
    required this.date,
    required this.lien,
    required this.action,
  });

  factory AlerteProfesseur.fromJson(Map<String, dynamic> json) {
    return AlerteProfesseur(
      type: json['type'] ?? 'info',
      titre: json['titre'] ?? '',
      message: json['message'] ?? '',
      date: json['date'] ?? '',
      lien: json['lien'] ?? '',
      action: json['action'] ?? '',
    );
  }

  bool get estUrgente => type == 'warning';
}

/// Emploi du temps hebdomadaire, groupé par jour.
/// `GET /api/professeur/planning/{id}` — `jour` est le nom anglais du jour
/// (`MONDAY`, `TUESDAY`…), les jours sans séance sont présents avec une liste
/// vide.
class JourPlanning {
  final String jour;
  final List<SeanceProfesseur> seances;

  JourPlanning({
    required this.jour,
    required this.seances,
  });

  factory JourPlanning.fromJson(Map<String, dynamic> json) {
    return JourPlanning(
      jour: json['jour'] ?? '',
      seances: (json['seances'] as List?)
              ?.map((e) => SeanceProfesseur.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
