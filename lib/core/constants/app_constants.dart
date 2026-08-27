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

  /// Hôtes qui répondent — mais jamais l'application. Un APK bâti dessus
  /// s'installe, démarre, affiche l'écran de connexion : rien ne signale
  /// l'erreur avant que l'utilisateur ne tape son mot de passe.
  ///
  /// La valeur est le motif du refus, repris dans le message d'échec.
  static const Map<String, String> _hotesRefuses = {
    'genucapplication-production.up.railway.app':
        "domaine public du service backend, que l'edge Railway rend en « 429 "
            'rate limited » sur toutes les routes, en permanence',
  };

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      return verifierUrlApi(_configuredBaseUrl);
    }

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

  /// Contrôle l'URL injectée au build et la renvoie telle quelle si elle tient.
  ///
  /// Le 26/08/2026, un APK release a été livré avec
  /// `API_BASE_URL=https://genucapplication-production.up.railway.app`. Ce
  /// domaine répond — en 429, toujours, avant même d'atteindre l'application.
  /// Or `ApiException.fromDio` traduit tout 429 en « Trop de tentatives » :
  /// l'écran de connexion accusait donc l'utilisateur d'insister, alors
  /// qu'aucune de ses requêtes n'arrivait au serveur. Les journaux du backend
  /// étaient muets, ce qui a coûté une demi-journée avant qu'on soupçonne
  /// l'URL. Un domaine connu pour ne pas fonctionner doit échouer au
  /// démarrage, bruyamment, pas se déguiser en compte bloqué.
  ///
  /// Extrait du getter pour rester testable : `String.fromEnvironment` est figé
  /// à la compilation, aucun test ne peut le piloter.
  @visibleForTesting
  static String verifierUrlApi(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw StateError(
        'API_BASE_URL invalide : « $url ». Attendu une URL absolue, par exemple '
        'https://genuc.up.railway.app',
      );
    }

    final motif = _hotesRefuses[uri.host.toLowerCase()];
    if (motif != null) {
      throw StateError(
        'API_BASE_URL pointe sur ${uri.host} : $motif.\n'
        "Toute requête revient en 429, que l'application affiche « Trop de "
        'tentatives » — la connexion paraît refusée alors qu\'elle n\'atteint '
        'jamais le serveur.\n'
        'Reconstruire avec :\n'
        '  flutter build apk --release '
        '--dart-define=API_BASE_URL=https://genuc.up.railway.app\n'
        '(ou lancer build-release.ps1, qui fige cette URL et vérifie le binaire)',
      );
    }

    return url;
  }
}
