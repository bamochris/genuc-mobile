/// Modèle de données pour les notes et résultats.
///
/// Correspond à la réponse de `EtudiantPortalService.mesNotes` :
/// chaque note porte `cours` (titre), `code`, `credits`, `noteTP`,
/// `noteInterrogation`, `noteExamen`, `noteFinale`, `noteMax`, `mention`
/// et `session`. Les champs `semestre`/`anneeAcademique` restent optionnels
/// (le wrapper [NotesResultat] porte l'année).
class Note {
  final int id;
  final String coursCode;
  final String coursTitre;
  final double? note;
  final double? noteTP;
  final double? noteInterrogation;
  final double? noteExamen;
  final double? noteMax;
  final String? mention;
  final int credits;
  final String? semestre;
  final String? anneeAcademique;
  final bool estValide;

  Note({
    required this.id,
    required this.coursCode,
    required this.coursTitre,
    this.note,
    this.noteTP,
    this.noteInterrogation,
    this.noteExamen,
    this.noteMax,
    this.mention,
    required this.credits,
    this.semestre,
    this.anneeAcademique,
    required this.estValide,
  });

  factory Note.fromJson(Map<String, dynamic> json) {
    final finale = json['noteFinale']?.toDouble();
    final max = json['noteMax']?.toDouble() ?? 20.0;
    // Toute mention sauf AJOURNE est une réussite : écrire la règle plutôt
    // qu'énumérer les mentions valides évite qu'une nouvelle valeur ajoutée
    // au backend retombe silencieusement sur « échec ».
    final mention = json['mention']?.toString();
    final estAjourne = mention != null && mention.toUpperCase() == 'AJOURNE';

    return Note(
      id: json['id'] ?? 0,
      coursCode: json['code'] ?? '',
      coursTitre: json['cours'] ?? json['coursTitre'] ?? json['titre'] ?? '',
      note: finale,
      noteTP: json['noteTP']?.toDouble(),
      noteInterrogation: json['noteInterrogation']?.toDouble(),
      noteExamen: json['noteExamen']?.toDouble(),
      noteMax: max,
      mention: mention,
      credits: json['credits'] ?? 0,
      semestre: json['semestre'] ?? json['session'],
      anneeAcademique: json['anneeAcademique'],
      estValide: (finale ?? 0) >= 10 && !estAjourne,
    );
  }

  String get noteAffichee => note?.toStringAsFixed(2) ?? '—';
}

/// Wrapper de `GET /api/etudiant/portal/{id}/notes` : le backend renvoie un
/// objet `{anneeAcademique, moyenneGenerale, creditsValides, notes: [...]}`,
/// pas une liste nue.
class NotesResultat {
  final String anneeAcademique;
  final double moyenneGenerale;
  final int creditsValides;
  final List<Note> notes;

  NotesResultat({
    required this.anneeAcademique,
    required this.moyenneGenerale,
    required this.creditsValides,
    required this.notes,
  });

  factory NotesResultat.fromJson(Map<String, dynamic> json) {
    return NotesResultat(
      anneeAcademique: json['anneeAcademique'] ?? '',
      moyenneGenerale: (json['moyenneGenerale'] ?? 0).toDouble(),
      creditsValides: json['creditsValides'] ?? 0,
      notes: (json['notes'] as List?)
              ?.map((e) => Note.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  bool get estReussi => moyenneGenerale >= 10;
  int get reussites => notes.where((n) => n.estValide).length;
}

class ReleveNotes {
  final String inscriptionId;
  final String etudiantNom;
  final String etudiantPrenom;
  final String matricule;
  final String filiere;
  final String promotion;
  final List<Note> notes;
  final double moyenneGenerale;
  final double moyenneSemestre;
  final int creditsValides;
  final int creditsTotal;
  final String? mentionGenerale;
  final String? mentionSemestre;
  final String dateEmission;

  ReleveNotes({
    required this.inscriptionId,
    required this.etudiantNom,
    required this.etudiantPrenom,
    required this.matricule,
    required this.filiere,
    required this.promotion,
    required this.notes,
    required this.moyenneGenerale,
    required this.moyenneSemestre,
    required this.creditsValides,
    required this.creditsTotal,
    this.mentionGenerale,
    this.mentionSemestre,
    required this.dateEmission,
  });

  factory ReleveNotes.fromJson(Map<String, dynamic> json) {
    final notesList = (json['notes'] as List?)
            ?.map((e) => Note.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return ReleveNotes(
      inscriptionId: json['inscriptionId']?.toString() ?? '',
      etudiantNom: json['etudiantNom'] ?? json['nom'] ?? '',
      etudiantPrenom: json['etudiantPrenom'] ?? json['prenom'] ?? '',
      matricule: json['matricule'] ?? '',
      filiere: json['filiere'] ?? '',
      promotion: json['promotion'] ?? '',
      notes: notesList,
      moyenneGenerale: (json['moyenneGenerale'] ?? 0).toDouble(),
      moyenneSemestre: (json['moyenneSemestre'] ?? 0).toDouble(),
      creditsValides: json['creditsValides'] ?? 0,
      creditsTotal: json['creditsTotal'] ?? 0,
      mentionGenerale: json['mentionGenerale'],
      mentionSemestre: json['mentionSemestre'],
      dateEmission: json['dateEmission'] ?? '',
    );
  }

  double get pourcentageCredits {
    if (creditsTotal == 0) return 0.0;
    return (creditsValides / creditsTotal) * 100;
  }
}

class Deliberation {
  final int id;
  final String titre;
  final String anneeAcademique;
  final String semestre;
  final String dateDeliberation;
  final String? mention;
  final double moyenne;
  final int credits;
  final String decision; // ADMIS, AJOURNE, EXCLU

  Deliberation({
    required this.id,
    required this.titre,
    required this.anneeAcademique,
    required this.semestre,
    required this.dateDeliberation,
    this.mention,
    required this.moyenne,
    required this.credits,
    required this.decision,
  });

  factory Deliberation.fromJson(Map<String, dynamic> json) {
    return Deliberation(
      id: json['id'] ?? 0,
      titre: json['titre'] ?? '',
      anneeAcademique: json['anneeAcademique'] ?? '',
      semestre: json['semestre'] ?? '',
      dateDeliberation: json['dateDeliberation'] ?? '',
      mention: json['mention'],
      moyenne: (json['moyenne'] ?? 0).toDouble(),
      credits: json['credits'] ?? 0,
      decision: json['decision'] ?? 'EN_ATTENTE',
    );
  }

  bool get estAdmis => decision == 'ADMIS';
  bool get estAjourne => decision == 'AJOURNE';
  bool get estExclu => decision == 'EXCLU';
}
