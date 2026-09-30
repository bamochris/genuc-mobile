/// Modèle de données pour le profil étudiant
/// Correspond exactement à la réponse du backend GENUC EtudiantPortalController
class EtudiantProfile {
  final int id;
  final String matricule;
  final String nom;
  final String prenom;
  final String email;
  final String telephone;
  final String? dateNaissance;
  final String? lieuNaissance;
  final String? sexe;
  final String? adresse;
  final String? universite;
  final String? departement;
  final String? filiere;
  final String? promotion;
  final String? anneeAcademique;
  final bool bulletin;
  final bool photo;
  final bool acte;

  /// Dossier repris des registres sans adresse : le serveur rend `email`
  /// vide et ce drapeau, plutôt que l'adresse fabriquée qui ne reçoit rien.
  final bool emailDeRemplacement;

  EtudiantProfile({
    required this.id,
    required this.matricule,
    required this.nom,
    required this.prenom,
    required this.email,
    required this.telephone,
    this.dateNaissance,
    this.lieuNaissance,
    this.sexe,
    this.adresse,
    this.universite,
    this.departement,
    this.filiere,
    this.promotion,
    this.anneeAcademique,
    required this.bulletin,
    required this.photo,
    required this.acte,
    this.emailDeRemplacement = false,
  });

  factory EtudiantProfile.fromJson(Map<String, dynamic> json) {
    return EtudiantProfile(
      id: json['id'] ?? 0,
      matricule: json['matricule'] ?? '',
      nom: json['nom'] ?? '',
      prenom: json['prenom'] ?? '',
      email: json['email'] ?? '',
      telephone: json['telephone'] ?? '',
      dateNaissance: json['dateNaissance'],
      lieuNaissance: json['lieuNaissance'],
      sexe: json['sexe'],
      adresse: json['adresse'],
      universite: json['universite'],
      departement: json['departement'],
      filiere: json['filiere'],
      promotion: json['promotion'],
      anneeAcademique: json['anneeAcademique'],
      bulletin: json['bulletin'] ?? false,
      photo: json['photo'] ?? false,
      acte: json['acte'] ?? false,
      emailDeRemplacement: json['emailDeRemplacement'] == true,
    );
  }

  String get nomComplet => '$prenom $nom';

  Map<String, dynamic> toJson() {
    return {
      'nom': nom,
      'prenom': prenom,
      'email': email,
      'telephone': telephone,
      'dateNaissance': dateNaissance,
      'lieuNaissance': lieuNaissance,
      'sexe': sexe,
      'adresse': adresse,
    };
  }
}