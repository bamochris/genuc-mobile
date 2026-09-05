/// Modèle de données pour les cours.
///
/// La liste `GET /api/etudiant/portal/{id}/cours` (`mesCoursAvecProgression`)
/// renvoie `{id, titre, code, description, niveau, promotion, professeur,
/// thumbnail, nbLecons, progression, estComplete, dateDernierAcces}`. Les
/// champs de progression sont absents de l'entité brute `Cours` du backend :
/// ils sont donc optionnels ici.
///
/// ⚠ Cette liste est désormais BORNÉE à la promotion de l'inscription côté
/// serveur. Elle rendait auparavant tout le catalogue de l'établissement — un
/// étudiant de L1 y lisait les cours de L3 — et l'application n'avait, ici,
/// aucun moyen de faire la différence.
///
/// `niveau` et `promotion` viennent de cette correction. Le champ `filiere`
/// retombait sur `niveau` faute de mieux : il annonçait une filière en
/// affichant un niveau, deux notions que la hiérarchie ESU distingue.
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
  final String? niveau;
  final String? promotion;
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
    this.niveau,
    this.promotion,
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
      filiere: json['filiere'],
      niveau: json['niveau'],
      promotion: json['promotion'],
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

  /// Le professeur a-t-il ouvert cette lecon ?
  ///
  /// Une lecon fermee reste LISIBLE — l'etudiant peut prendre de l'avance —
  /// mais elle ne compte pas dans sa progression. Absent de la reponse
  /// (serveur pas encore a jour) vaut « ouverte » : on n'invente pas une
  /// restriction que le serveur n'a pas exprimee.
  final bool ouverte;

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
    this.ouverte = true,
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
      ouverte: json['ouverte'] ?? true,
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

/// Ou en est le COURS : les seances tenues par l'enseignant.
///
/// Rien n'est saisi pour produire ces chiffres, ni par le professeur ni par
/// l'etudiant. Le professeur prend les presences a chaque seance ; le nombre de
/// jours distincts ou il l'a fait est l'avancement du cours.
///
/// Cela remplace la barre calculee sur les lecons cochees : elle exigeait que
/// l'enseignant saisisse une liste de lecons, deplace un curseur d'ouverture,
/// et que l'etudiant coche chaque lecon. Personne ne le faisait, donc elle
/// restait a zero.
class AvancementCours {
  /// Seances deja tenues, tous etudiants confondus.
  final int seancesTenues;

  /// Seances prevues. `null` quand le volume horaire ne permet pas de le dire :
  /// on affiche alors un compte, jamais un pourcentage invente.
  final int? seancesPrevues;

  /// Avancement en pourcentage, plafonne a 100. `null` si indeterminable.
  final int? pourcentage;

  /// Seances ou CET etudiant a ete porte present.
  final int? seancesSuivies;

  /// Date de la derniere seance tenue, telle que le serveur l'envoie.
  final String? derniereSeance;

  const AvancementCours({
    required this.seancesTenues,
    this.seancesPrevues,
    this.pourcentage,
    this.seancesSuivies,
    this.derniereSeance,
  });

  static int? _entier(dynamic v) => v is num ? v.toInt() : null;

  factory AvancementCours.fromJson(Map<String, dynamic> json) => AvancementCours(
        seancesTenues: _entier(json['seancesTenues']) ?? 0,
        seancesPrevues: _entier(json['seancesPrevues']),
        pourcentage: _entier(json['pourcentage']),
        seancesSuivies: _entier(json['seancesSuivies']),
        derniereSeance: json['derniereSeance'] as String?,
      );

  /// Le cours a-t-il commence ?
  bool get aCommence => seancesTenues > 0;
}

class CoursDetail {
  final Cours cours;
  final List<Lecon> lecons;
  final double progression;
  final String? descriptionComplete;
  final List<String> prerequis;
  final List<String> objectifs;

  /// Ou en est le cours. `null` si le serveur ne l'envoie pas encore : on
  /// n'invente pas un avancement que personne n'a calcule.
  final AvancementCours? avancement;

  CoursDetail({
    this.avancement,
    this.leconsOuvertesServeur,
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
      leconsOuvertesServeur: json['leconsOuvertes'] is num
          ? (json['leconsOuvertes'] as num).toInt()
          : null,
      avancement: json['avancement'] is Map<String, dynamic>
          ? AvancementCours.fromJson(json['avancement'] as Map<String, dynamic>)
          : null,
      descriptionComplete: json['descriptionComplete'],
      prerequis: (json['prerequis'] as List?)?.cast<String>() ?? [],
      objectifs: (json['objectifs'] as List?)?.cast<String>() ?? [],
    );
  }

  /// Lecons OUVERTES par le professeur — le denominateur de la barre.
  ///
  /// Le serveur le renvoie deja calcule ; a defaut, on retombe sur les lecons
  /// marquees ouvertes, puis sur leur totalite.
  final int? leconsOuvertesServeur;

  int get leconsOuvertes =>
      leconsOuvertesServeur ?? lecons.where((l) => l.ouverte).length;

  /// Lecons ouvertes deja terminees — le numerateur.
  ///
  /// Ce qui est lu en avance ne compte ni ici ni au denominateur : la barre
  /// mesure ce qu'on demande a l'etudiant, pas ce que le cours contiendra.
  int get leconsCompletees =>
      lecons.where((l) => l.ouverte && l.estComplete).length;

  int get totalLecons => lecons.length;
}
