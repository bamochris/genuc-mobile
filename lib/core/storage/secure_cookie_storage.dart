import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Backend de persistance chiffré pour [PersistCookieJar].
///
/// L'implémentation par défaut de `cookie_jar` (`FileStorage`) écrit les
/// cookies en clair dans le répertoire de l'application. Comme le cookie
/// `genuc_token` porte le JWT de session, on les range dans le Keystore
/// Android / Keychain iOS.
class SecureCookieStorage implements Storage {
  static const _prefix = 'genuc_cookie_';

  final FlutterSecureStorage _storage;

  SecureCookieStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  @override
  Future<void> init(bool persistSession, bool ignoreExpires) async {}

  @override
  Future<String?> read(String key) => _storage.read(key: '$_prefix$key');

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: '$_prefix$key', value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: '$_prefix$key');

  @override
  Future<void> deleteAll(List<String> keys) async {
    for (final key in keys) {
      await delete(key);
    }
  }
}
