class User {
  final String? id;
  final String? nomComplet;
  final String? email;
  final String? role;
  final String? universiteId;
  final String? departementId;
  final bool? compteActive;
  final String? inscriptionId;
  final String? photoProfil;
  final bool? twoFactorEnabled;

  const User({
    this.id,
    this.nomComplet,
    this.email,
    this.role,
    this.universiteId,
    this.departementId,
    this.compteActive,
    this.inscriptionId,
    this.photoProfil,
    this.twoFactorEnabled,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString(),
      nomComplet: json['nomComplet'] as String?,
      email: json['email'] as String?,
      role: _lireRole(json),
      universiteId: json['universiteId']?.toString(),
      departementId: json['departementId']?.toString(),
      compteActive: json['compteActive'] as bool?,
      inscriptionId: json['inscriptionId']?.toString(),
      photoProfil: json['photoProfil'] as String?,
      twoFactorEnabled: json['twoFactorEnabled'] as bool?,
    );
  }

  /// La réponse de connexion porte `role` (chaîne). `GET /api/auth/moi` porte
  /// `roles` : une liste d'authorities Spring (`[{authority: ROLE_ETUDIANT}]`).
  /// On accepte les deux, préfixe `ROLE_` retiré.
  static String? _lireRole(Map<String, dynamic> json) {
    final role = json['role'];
    if (role is String && role.isNotEmpty) return role;

    final roles = json['roles'];
    if (roles is List && roles.isNotEmpty) {
      final premier = roles.first;
      final valeur = premier is Map
          ? premier['authority']?.toString()
          : premier?.toString();
      if (valeur != null && valeur.isNotEmpty) {
        return valeur.startsWith('ROLE_') ? valeur.substring(5) : valeur;
      }
    }
    return null;
  }

  /// Fusionne un profil partiel dans celui-ci sans écraser par du vide.
  ///
  /// Sert à recouper le profil complet mémorisé à la connexion avec le profil
  /// minimal renvoyé par `/api/auth/moi` au redémarrage.
  User fusionner(User autre) {
    return User(
      id: autre.id ?? id,
      nomComplet: autre.nomComplet ?? nomComplet,
      email: autre.email ?? email,
      role: autre.role ?? role,
      universiteId: autre.universiteId ?? universiteId,
      departementId: autre.departementId ?? departementId,
      compteActive: autre.compteActive ?? compteActive,
      inscriptionId: autre.inscriptionId ?? inscriptionId,
      photoProfil: autre.photoProfil ?? photoProfil,
      twoFactorEnabled: autre.twoFactorEnabled ?? twoFactorEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (nomComplet != null) 'nomComplet': nomComplet,
      if (email != null) 'email': email,
      if (role != null) 'role': role,
      if (universiteId != null) 'universiteId': universiteId,
      if (departementId != null) 'departementId': departementId,
      if (compteActive != null) 'compteActive': compteActive,
      if (inscriptionId != null) 'inscriptionId': inscriptionId,
      if (photoProfil != null) 'photoProfil': photoProfil,
      if (twoFactorEnabled != null) 'twoFactorEnabled': twoFactorEnabled,
    };
  }
}
