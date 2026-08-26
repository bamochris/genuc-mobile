import '../../core/errors/api_exception.dart';
import '../../core/storage/session_storage.dart';
import '../../domain/entities/login_result.dart';
import '../../domain/entities/two_factor_setup.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../services/api_service.dart';

class AuthRepositoryImpl implements AuthRepository {
  final ApiService api;
  final SessionStorage sessionStorage;

  AuthRepositoryImpl({required this.api, required this.sessionStorage});

  @override
  Future<LoginResult> login({
    required String identifiant,
    required String password,
  }) async {
    final reponse = await api.login(identifiant: identifiant, password: password);

    // Compte protégé par 2FA : aucun cookie n'a été posé, la connexion
    // s'achève par /api/auth/2fa/login-verify.
    if (reponse['mfaRequired'] == true) {
      final challenge = reponse['mfaChallengeToken'] as String?;
      if (challenge == null || challenge.isEmpty) {
        throw const ApiException(
          'Vérification en deux étapes indisponible. Contactez l\'administration.',
        );
      }
      return LoginMfaRequired(challenge);
    }

    return LoginSuccess(await _memoriser(reponse));
  }

  @override
  Future<User> verifyMfaAndLogin({
    required String mfaChallengeToken,
    required String code,
  }) async {
    final reponse = await api.verifyMfaAndLogin(
      mfaChallengeToken: mfaChallengeToken,
      code: code,
    );
    return _memoriser(reponse);
  }

  @override
  Future<void> logout() async {
    await api.logout();
    await sessionStorage.clear();
  }

  @override
  @override
  Future<void> changerMotDePasse({
    required String ancienMotDePasse,
    required String nouveauMotDePasse,
  }) {
    return api.changePassword(
      oldPassword: ancienMotDePasse,
      newPassword: nouveauMotDePasse,
    );
  }

  @override
  Future<bool> statut2fa() => api.getTwoFactorStatus();

  @override
  Future<TwoFactorSetup> demarrerActivation2fa() async {
    return TwoFactorSetup.fromJson(await api.demarrerActivation2fa());
  }

  @override
  Future<void> confirmerActivation2fa(String code) =>
      api.confirmerActivation2fa(code);

  @override
  Future<void> desactiver2fa(String code) => api.desactiver2fa(code);

  @override
  Future<User?> restaurerSession() async {
    final memorise = await sessionStorage.readUser();

    try {
      // Cet appel échoue en 401 si les cookies ont expiré ; l'intercepteur
      // tente alors un rafraîchissement avant de propager l'erreur.
      final profilMinimal = User.fromJson(await api.getMe());
      if (profilMinimal.email == null) {
        await sessionStorage.clear();
        return null;
      }

      // /api/auth/moi ne renvoie ni inscriptionId ni nomComplet : on complète
      // avec le profil mémorisé à la connexion.
      final complet = memorise?.fusionner(profilMinimal) ?? profilMinimal;
      await sessionStorage.saveUser(complet);
      return complet;
    } on ApiException {
      await sessionStorage.clear();
      return null;
    }
  }

  Future<User> _memoriser(Map<String, dynamic> reponse) async {
    final user = User.fromJson(reponse);
    await sessionStorage.saveUser(user);
    return user;
  }
}
