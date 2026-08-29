import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genuc_mobile/core/utils/fcm_service.dart';
import 'package:genuc_mobile/domain/entities/login_result.dart';
import 'package:genuc_mobile/domain/entities/user.dart';
import 'package:genuc_mobile/domain/repositories/auth_repository.dart';
import 'package:genuc_mobile/presentation/providers/auth_provider.dart';

/// Pourquoi aucune notification push n'atteignait jamais un téléphone.
///
/// <h3>Le défaut, en une phrase</h3>
///
/// `FCMService.initialize()` s'exécute au DÉMARRAGE de l'application et
/// enregistre aussitôt le jeton de l'appareil. Or
/// `POST /api/notifications/push/enregistrer` porte `@PreAuthorize("isAuthenticated()")` :
/// l'appel partait sans session, recevait un 401, et l'échec n'était que
/// journalisé. Le seul rattrapage prévu — `onTokenRefresh` — ne se produit
/// pratiquement jamais.
///
/// **Aucun appareil n'était donc enregistré.** Le serveur envoyait ses
/// notifications sans la moindre erreur, à une liste vide : le défaut ne se
/// voyait ni dans les journaux du serveur, ni dans l'application.
///
/// <h3>Ce que ces cas tiennent</h3>
///
/// Les trois moments où une session s'ouvre (connexion, second facteur,
/// restauration au démarrage) déclenchent l'enregistrement ; la déconnexion
/// détache l'appareil ; et le détachement emploie le bon verbe HTTP.
void main() {
  group('Le jeton est enregistré quand une session s\'ouvre', () {
    test('à la connexion', () async {
      final depot = _DepotFactice(utilisateur: _etudiant);
      var enregistrements = 0;
      final provider = AuthProvider(depot)
        ..onSessionOuverte = () => enregistrements++;

      final ouverte = await provider.login(
          identifiant: 'etudiant@unikin.cd', password: 'secret');

      expect(ouverte, isTrue);
      expect(enregistrements, 1);
    });

    test('après le second facteur', () async {
      final depot = _DepotFactice(utilisateur: _etudiant, exige2fa: true);
      var enregistrements = 0;
      final provider = AuthProvider(depot)
        ..onSessionOuverte = () => enregistrements++;

      await provider.login(identifiant: 'etudiant@unikin.cd', password: 'x');
      // La connexion s'est arrêtée sur le second facteur : rien n'est encore
      // ouvert, donc rien ne doit être enregistré.
      expect(enregistrements, 0);

      final ouverte = await provider.verifyMfa('123456');
      expect(ouverte, isTrue);
      expect(enregistrements, 1);
    });

    test('à la restauration de session au démarrage', () async {
      // Le cas le plus fréquent : l'utilisateur rouvre l'application, sa
      // session est restaurée sans qu'il se reconnecte. Sans ce déclenchement,
      // seul le tout premier lancement aurait une chance d'enregistrer.
      final depot = _DepotFactice(utilisateur: _etudiant, sessionRestaurable: true);
      var enregistrements = 0;
      final provider = AuthProvider(depot)
        ..onSessionOuverte = () => enregistrements++;

      await provider.initSession();

      expect(enregistrements, 1);
    });

    test('mais pas quand il n\'y a aucune session à restaurer', () async {
      final depot = _DepotFactice(sessionRestaurable: false);
      var enregistrements = 0;
      final provider = AuthProvider(depot)
        ..onSessionOuverte = () => enregistrements++;

      await provider.initSession();

      // Enregistrer ici renverrait le 401 d'origine, et ferait croire à une
      // panne là où il n'y a simplement personne de connecté.
      expect(enregistrements, 0);
    });
  });

  group('L\'appareil est détaché à la déconnexion', () {
    test('la déconnexion déclenche le détachement', () async {
      final depot = _DepotFactice(utilisateur: _etudiant);
      var detachements = 0;
      final provider = AuthProvider(depot)
        ..onSessionFermee = () => detachements++;

      await provider.logout();

      expect(detachements, 1);
    });

    test('le détachement part en DELETE, pas en POST', () async {
      // `DeviceTokenController.desenregistrer` est un `@DeleteMapping`. L'appel
      // partait en POST : 405, et l'appareil restait rattaché au compte qui
      // venait de se déconnecter — il continuait donc de recevoir SES
      // notifications. L'erreur était avalée par un `catch (_) {}` muet.
      final espion = _EspionHttp();
      final service = FCMService(_dioVers(espion))
        ..definirJetonPourTest('jeton-appareil');

      await service.unregister();

      expect(espion.methode, 'DELETE');
      expect(espion.chemin, '/api/notifications/push/desenregistrer');
      expect(espion.corps, {'token': 'jeton-appareil'});
    });

    test('le jeton survit au détachement : c\'est le même appareil', () async {
      // Il était mis à `null`. La connexion suivante n'avait alors plus rien à
      // réenregistrer, et l'appareil restait muet jusqu'à une réinstallation.
      final service = FCMService(_dioVers(_EspionHttp()))
        ..definirJetonPourTest('jeton-appareil');

      await service.unregister();

      expect(service.token, 'jeton-appareil');
    });

    test('sans jeton, rien n\'est appelé', () async {
      final espion = _EspionHttp();
      final service = FCMService(_dioVers(espion));

      await service.unregister();

      expect(espion.methode, isNull);
    });
  });
}

const _etudiant = User(
  id: '1',
  nomComplet: 'Utilisateur Test',
  email: 'etudiant@unikin.cd',
  role: 'ETUDIANT',
  universiteId: '1',
  inscriptionId: '1',
);

Dio _dioVers(_EspionHttp espion) =>
    Dio(BaseOptions(baseUrl: 'http://test.invalid'))
      ..httpClientAdapter = espion;

/// Retient la requête sortante au lieu de l'émettre.
class _EspionHttp implements HttpClientAdapter {
  String? methode;
  String? chemin;
  Map<String, dynamic>? corps;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    methode = options.method;
    chemin = options.uri.path;
    final data = options.data;
    corps = data is Map ? Map<String, dynamic>.from(data) : null;
    return ResponseBody.fromString('{"message":"ok"}', 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }
}

/// Dépôt d'authentification en dur — `noSuchMethod` couvre les méthodes que
/// ces cas n'exercent pas (2FA, mot de passe, profil).
class _DepotFactice implements AuthRepository {
  final User? utilisateur;
  final bool exige2fa;
  final bool sessionRestaurable;

  _DepotFactice({
    this.utilisateur,
    this.exige2fa = false,
    this.sessionRestaurable = false,
  });

  @override
  Future<LoginResult> login({
    required String identifiant,
    required String password,
  }) async =>
      exige2fa
          ? const LoginMfaRequired('challenge-token')
          : LoginSuccess(utilisateur!);

  @override
  Future<User> verifyMfaAndLogin({
    required String mfaChallengeToken,
    required String code,
  }) async =>
      utilisateur!;

  @override
  Future<void> logout() async {}

  @override
  Future<User?> restaurerSession() async =>
      sessionRestaurable ? utilisateur : null;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} non utilisée ici');
}
