/// Modèle de données pour les cours.
///
/// La liste `GET /api/etudiant/portal/{id}/cours` (`mesCoursAvecProgression`)
/// renvoie `{id, titre, code, description, professeur, thumbnail, nbLecons,
/// progression, estComplete, dateDernierAcces}`. Les champs de progression
/// sont absents de l'entité brute `Cours` du backend : ils sont donc
/// optionnels ici.
class Cours {
  final int id;
  final String code;
  final String titre;
  final String? description;
  final int credits;
  final String? enseignant;
  final String? semestre;
  final String? anneeAcademique;
  final String? filiere;
  final int? ueId;
  final String? ueCode;

  // Portés par la réponse « avec progression » du portail.
  final int? nbLecons;
  final int? leconsCompletees;
  final int? progression;
  final bool estComplete;

  Cours({
    required this.id,
    required this.code,
    required this.titre,
    this.description,
    required this.credits,
    this.enseignant,
    this.semestre,
    this.anneeAcademique,
    this.filiere,
    this.ueId,
    this.ueCode,
    this.nbLecons,
    this.leconsCompletees,
    this.progression,
    this.estComplete = false,
  });

  factory Cours.fromJson(Map<String, dynamic> json) {
    return Cours(
      id: json['id'] ?? 0,
      code: json['code'] ?? '',
      titre: json['titre'] ?? json['intitule'] ?? '',
      description: json['description'],
      credits: json['credits'] ?? json['credit'] ?? 0,
      enseignant: json['enseignant'] ?? json['professeur'],
      semestre: json['semestre'],
      anneeAcademique: json['anneeAcademique'],
      filiere: json['filiere'] ?? json['niveau'],
      ueId: json['ueId'],
      ueCode: json['ueCode'],
      nbLecons: json['nbLecons'],
      leconsCompletees: json['leconsCompletees'],
      progression: json['progression'],
      estComplete: json['estComplete'] ?? false,
    );
  }

  String get libelleProgression => progression != null ? '$progression%' : '—';

  ColorProgression get couleurProgression {
    final p = progression ?? 0;
    if (p >= 80) return ColorProgression.excellent;
    if (p >= 50) return ColorProgression.bon;
    if (p >= 30) return ColorProgression.enCours;
    return ColorProgression.aCommencer;
  }
}

/// Palette sémantique de progression, calquée sur le portail web
/// (`getProgressionColor` dans MesCours.jsx).
enum ColorProgression {
  excellent,
  bon,
  enCours,
  aCommencer;

  String get libelle {
    switch (this) {
      case ColorProgression.excellent:
        return 'Excellent';
      case ColorProgression.bon:
        return 'Bon';
      case ColorProgression.enCours:
        return 'En cours';
      case ColorProgression.aCommencer:
        return 'À commencer';
    }
  }
}

class Lecon {
  final int id;
  final String titre;
  final String type; // TEXTE, VIDEO, DOCUMENT, QUIZ, MIXTE
  final String? description;
  final String? contenuHtml;
  final String? videoUrl;
  final String? videoExterneUrl;
  final String? documentUrl;
  final int ordre;
  final bool estComplete;
  final int? dureeMinutes;
  final int? dureeSecondes;
  final bool apercuGratuit;

  Lecon({
    required this.id,
    required this.titre,
    required this.type,
    this.description,
    this.contenuHtml,
    this.videoUrl,
    this.videoExterneUrl,
    this.documentUrl,
    required this.ordre,
    this.estComplete = false,
    this.dureeMinutes,
    this.dureeSecondes,
    this.apercuGratuit = false,
  });

  factory Lecon.fromJson(Map<String, dynamic> json) {
    return Lecon(
      id: json['id'] ?? 0,
      titre: json['titre'] ?? '',
      type: json['type'] ?? 'TEXTE',
      description: json['description'],
      contenuHtml: json['contenuHtml'],
      videoUrl: json['videoUrl'],
      videoExterneUrl: json['videoExterneUrl'],
      documentUrl: json['documentUrl'],
      ordre: json['ordre'] ?? 0,
      // Le portail renvoie `estCompletee` (accord féminin), l'entité brute
      // `complete`/`estComplete`. On accepte les trois.
      estComplete: json['estCompletee'] ??
          json['estComplete'] ??
          json['complete'] ??
          false,
      dureeMinutes: json['dureeMinutes'],
      dureeSecondes: json['dureeSecondes'],
      apercuGratuit: json['apercuGratuit'] ?? false,
    );
  }

  String get dureeAffichee {
    final minutes = dureeMinutes ??
        (dureeSecondes != null ? (dureeSecondes! / 60).ceil() : null);
    if (minutes == null) return '';
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h$m';
  }
}

class CoursDetail {
  final Cours cours;
  final List<Lecon> lecons;
  final double progression;
  final String? descriptionComplete;
  final List<String> prerequis;
  final List<String> objectifs;

  CoursDetail({
    required this.cours,
    required this.lecons,
    required this.progression,
    this.descriptionComplete,
    this.prerequis = const [],
    this.objectifs = const [],
  });

  factory CoursDetail.fromJson(Map<String, dynamic> json) {
    final cours = Cours.fromJson(
      json['cours'] is Map<String, dynamic>
          ? json['cours'] as Map<String, dynamic>
          : json,
    );
    final leconsList = (json['lecons'] as List?)
            ?.map((e) => Lecon.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return CoursDetail(
      cours: cours,
      lecons: leconsList,
      progression: (json['progression'] ?? 0).toDouble(),
      descriptionComplete: json['descriptionComplete'],
      prerequis: (json['prerequis'] as List?)?.cast<String>() ?? [],
      objectifs: (json['objectifs'] as List?)?.cast<String>() ?? [],
    );
  }

  int get leconsCompletees => lecons.where((l) => l.estComplete).length;
  int get totalLecons => lecons.length;
}
