import 'package:flutter/foundation.dart';

import '../../core/errors/api_exception.dart';
import '../../domain/entities/login_result.dart';
import '../../domain/entities/two_factor_setup.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthProvider extends ChangeNotifier {
  final AuthRepository repository;

  AuthProvider(this.repository);

  User? _user;
  bool _isLoading = false;
  bool _sessionRestauree = false;
  String? _error;
  String? _mfaChallengeToken;

  /// Appelé dès qu'une session s'ouvre — connexion, second facteur validé, ou
  /// session restaurée au démarrage.
  ///
  /// <h3>Ce que cela répare</h3>
  ///
  /// Le service FCM enregistre le jeton de l'appareil au DÉMARRAGE de
  /// l'application, donc AVANT toute connexion. Or
  /// `POST /api/notifications/push/enregistrer` exige une session : l'appel
  /// partait, recevait un 401, et l'échec était simplement journalisé. Rien ne
  /// réessayait ensuite, sinon une rotation de jeton FCM — qui n'arrive
  /// pratiquement jamais. **Aucun appareil n'était donc enregistré, et aucune
  /// notification push ne pouvait atteindre qui que ce soit.**
  ///
  /// Le défaut ne se voyait nulle part : le serveur envoyait ses notifications
  /// sans erreur, à une liste d'appareils vide.
  void Function()? onSessionOuverte;

  /// Appelé à la déconnexion.
  ///
  /// Sans cela, le jeton de l'appareil reste rattaché au compte précédent :
  /// le téléphone continue de recevoir SES notifications — notes, paiements,
  /// changements d'horaire — après que son propriétaire s'est déconnecté.
  void Function()? onSessionFermee;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  /// Pose la session sans passer par le réseau. **Réservé aux tests.**
  ///
  /// Les écrans lisent l'utilisateur ici — `inscriptionId` surtout, dont
  /// dépendent presque toutes les routes du portail étudiant. Les monter dans
  /// un test exigeait sinon de simuler une connexion complète, jetons et
  /// stockage sécurisé compris, pour vérifier un formulaire. Même intention
  /// que `DioClient.reset()`, déjà exposé de la sorte.
  @visibleForTesting
  void definirUtilisateurPourTest(User? utilisateur) {
    _user = utilisateur;
    _sessionRestauree = true;
  }

  /// Faux tant que la restauration de session au démarrage n'a pas abouti.
  /// À distinguer de [isLoading], vrai aussi pendant une connexion : sans
  /// cette distinction, appuyer sur « Se connecter » renvoyait l'utilisateur
  /// sur l'écran de démarrage et démontait le formulaire.
  bool get sessionRestauree => _sessionRestauree;

  /// Renseigné quand la connexion attend le code du second facteur.
  String? get mfaChallengeToken => _mfaChallengeToken;
  bool get mfaRequired => _mfaChallengeToken != null;

  /// Renvoie `true` si la session est ouverte, `false` si un code 2FA est
  /// attendu. Toute autre issue lève et alimente [error].
  Future<bool> login({
    required String identifiant,
    required String password,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      final resultat = await repository.login(
        identifiant: identifiant,
        password: password,
      );

      switch (resultat) {
        case LoginSuccess(user: final user):
          _user = user;
          onSessionOuverte?.call();
          _mfaChallengeToken = null;
          return true;
        case LoginMfaRequired(challengeToken: final token):
          _mfaChallengeToken = token;
          return false;
      }
    } on ApiException catch (e) {
      _error = e.message;
      _user = null;
      return false;
    } catch (e) {
      _error = 'Erreur de connexion au serveur : ${e.runtimeType}';
      _user = null;
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> verifyMfa(String code) async {
    final challenge = _mfaChallengeToken;
    if (challenge == null) {
      _error = 'Session de vérification expirée, reconnectez-vous';
      notifyListeners();
      return false;
    }

    _setLoading(true);
    _error = null;

    try {
      _user = await repository.verifyMfaAndLogin(
        mfaChallengeToken: challenge,
        code: code,
      );
      _mfaChallengeToken = null;
      onSessionOuverte?.call();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = 'Erreur de vérification 2FA : ${e.runtimeType}';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void annulerMfa() {
    _mfaChallengeToken = null;
    _error = null;
    notifyListeners();
  }

  Future<void> logout() async {
    _setLoading(true);
    try {
      await repository.logout();
    } catch (_) {
      // Au mieux : la session locale est effacée quoi qu'il arrive.
    } finally {
      _user = null;
      _mfaChallengeToken = null;
      _error = null;
      onSessionFermee?.call();
      _setLoading(false);
    }
  }

  /// Change le mot de passe. Lève [ApiException] (message backend) en cas
  /// d'échec ; l'écran d'origine affiche le message.
  Future<void> changerMotDePasse({
    required String ancien,
    required String nouveau,
  }) {
    return repository.changerMotDePasse(
      ancienMotDePasse: ancien,
      nouveauMotDePasse: nouveau,
    );
  }

  /// État 2FA du compte connecté.
  Future<bool> statut2fa() => repository.statut2fa();

  /// Démarre l'activation 2FA (secret + QR code à associer).
  Future<TwoFactorSetup> demarrerActivation2fa() =>
      repository.demarrerActivation2fa();

  /// Valide le code saisi et active la 2FA.
  Future<void> confirmerActivation2fa(String code) =>
      repository.confirmerActivation2fa(code);

  /// Désactive la 2FA après vérification du code.
  Future<void> desactiver2fa(String code) =>
      repository.desactiver2fa(code);

  Future<void> initSession() async {
    _isLoading = true;
    try {
      _user = await repository.restaurerSession();
    } catch (_) {
      _user = null;
    } finally {
      _sessionRestauree = true;
      if (_user != null) onSessionOuverte?.call();
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
