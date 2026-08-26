import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/entities/user.dart';

/// Stockage chiffré du profil utilisateur (Keystore Android / Keychain iOS).
///
/// Les jetons eux-mêmes ne transitent jamais par ici : ils restent dans les
/// cookies HttpOnly posés par le backend, comme sur le portail web. Seul le
/// profil est conservé, parce que `GET /api/auth/moi` ne renvoie qu'un profil
/// minimal (email + authorities) — sans `role`, `inscriptionId` ni
/// `nomComplet`, qui ne sont présents que dans la réponse de connexion.
class SessionStorage {
  static const _userKey = 'genuc_user_profile';

  final FlutterSecureStorage _storage;

  SessionStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  Future<void> saveUser(User user) async {
    await _storage.write(key: _userKey, value: jsonEncode(user.toJson()));
  }

  Future<User?> readUser() async {
    try {
      final raw = await _storage.read(key: _userKey);
      if (raw == null || raw.isEmpty) return null;
      return User.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Donnée illisible (clé rotée, format obsolète) : on repart propre.
      await clear();
      return null;
    }
  }

  Future<void> clear() async {
    await _storage.delete(key: _userKey);
  }
}
