import 'package:flutter_test/flutter_test.dart';
import 'package:genuc_mobile/core/constants/app_constants.dart';

/// Garde-fou sur l'URL injectée au build (`--dart-define=API_BASE_URL`).
///
/// Contexte : le 26/08/2026, un APK release a été livré sur
/// `genucapplication-production.up.railway.app`, le domaine public du service
/// backend. L'edge Railway le rend en 429 sur toutes les routes ; l'application
/// traduisant tout 429 en « Trop de tentatives », la connexion paraissait
/// refusée alors qu'aucune requête n'atteignait le serveur.
void main() {
  group('AppConstants.verifierUrlApi', () {
    test('laisse passer le domaine de production', () {
      expect(
        AppConstants.verifierUrlApi('https://genuc.up.railway.app'),
        'https://genuc.up.railway.app',
      );
    });

    test('laisse passer une adresse de développement', () {
      expect(
        AppConstants.verifierUrlApi('http://192.168.1.12:8082'),
        'http://192.168.1.12:8082',
      );
    });

    test('refuse le domaine du service backend (429 permanent)', () {
      expect(
        () => AppConstants.verifierUrlApi(
          'https://genucapplication-production.up.railway.app',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('genucapplication-production.up.railway.app'),
              contains('429'),
              contains('https://genuc.up.railway.app'),
            ),
          ),
        ),
      );
    });

    test('refuse le domaine interdit quelle que soit la casse', () {
      expect(
        () => AppConstants.verifierUrlApi(
          'https://GenucApplication-Production.up.railway.app',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('refuse une URL sans schéma', () {
      expect(
        () => AppConstants.verifierUrlApi('genuc.up.railway.app'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
