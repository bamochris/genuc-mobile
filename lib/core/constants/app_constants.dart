import 'package:flutter/foundation.dart';

class AppConstants {
  static const String appName = 'GENUC';
  static const String appVersion = '1.0.0';

  // M4 CORRIGÉ : timeouts augmentés pour les appels lourds
  // (stats, rapports, import/export notes, bibliothèque, etc.)
  static const int connectTimeout = 20000;  // 20s connexion
  static const int receiveTimeout = 45000;  // 45s réception (appels lourds)
  static const int uploadTimeout = 60000;   // 60s upload (documents, TFC)

  static const String loginEndpoint = '/api/auth/login';
  static const String refreshEndpoint = '/api/auth/refresh';
  static const String logoutEndpoint = '/api/auth/logout';
  static const String meEndpoint = '/api/auth/moi';
  static const String twoFactorVerifyEndpoint = '/api/auth/2fa/login-verify';

  /// Endpoint public appelé au démarrage pour obtenir le cookie `XSRF-TOKEN`.
  static const String csrfBootstrapEndpoint = '/api/universites/public';

  static const String csrfCookieName = 'XSRF-TOKEN';
  static const String accessTokenCookieName = 'genuc_token';
  static const String refreshTokenCookieName = 'genuc_refresh_token';
  static const String csrfHeaderName = 'X-XSRF-TOKEN';

  /// URL du backend, injectée au build. Déploiement de production (Railway) :
  /// `flutter build apk --dart-define=API_BASE_URL=https://genuc.up.railway.app`.
  static const String _configuredBaseUrl =
      String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) return _configuredBaseUrl;

    // Aucune URL de repli en release : livrer un APK qui pointe sur
    // localhost échoue silencieusement chez l'utilisateur.
    //
    // Un `assert` ne suffit pas — il est retiré des builds release, si bien
    // qu'un APK construit sans `--dart-define` retombait quand même sur
    // `10.0.2.2`, adresse qui n'existe que dans l'émulateur, en clair de
    // surcroît (donc refusée par Android). L'utilisateur n'y voyait qu'un
    // « serveur injoignable » sur chaque écran. On échoue donc franchement,
    // au démarrage, avec la commande à taper.
    if (!kDebugMode && !kProfileMode) {
      throw StateError(
        'API_BASE_URL manquant. Reconstruire avec :\n'
        '  flutter build apk --release '
        '--dart-define=API_BASE_URL=https://genuc.up.railway.app',
      );
    }

    // L'émulateur Android atteint la machine hôte par 10.0.2.2, jamais par
    // localhost (qui désigne l'émulateur lui-même).
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8082';
    }
    return 'http://localhost:8082';
  }
}
