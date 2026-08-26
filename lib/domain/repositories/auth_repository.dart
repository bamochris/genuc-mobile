import '../entities/login_result.dart';
import '../entities/two_factor_setup.dart';
import '../entities/user.dart';

abstract class AuthRepository {
  /// [identifiant] : email ou matricule étudiant.
  Future<LoginResult> login({
    required String identifiant,
    required String password,
  });

  Future<User> verifyMfaAndLogin({
    required String mfaChallengeToken,
    required String code,
  });

  Future<void> logout();

  /// Restaure la session au démarrage : profil chiffré sur l'appareil,
  /// recoupé avec `/api/auth/moi` pour vérifier que les cookies sont valides.
  /// Renvoie `null` si aucune session exploitable.
  Future<User?> restaurerSession();

  /// Change le mot de passe de l'utilisateur connecté.
  ///
  /// Lève une [ApiException] avec le message du backend (politique non
  /// respectée, mot de passe actuel incorrect, …). Le backend révoque alors
  /// toutes les autres sessions.
  Future<void> changerMotDePasse({
    required String ancienMotDePasse,
    required String nouveauMotDePasse,
  });

  /// État de l'authentification à deux facteurs (TOTP) du compte connecté.
  Future<bool> statut2fa();

  /// Démarre l'activation 2FA : génère un secret côté serveur et renvoie le
  /// QR code à scanner dans l'application d'authentification. La 2FA n'est
  /// effective qu'après [confirmerActivation2fa].
  Future<TwoFactorSetup> demarrerActivation2fa();

  /// Valide le code saisi dans l'application d'authentification et active la 2FA.
  Future<void> confirmerActivation2fa(String code);

  /// Désactive la 2FA après vérification d'un code valide.
  Future<void> desactiver2fa(String code);
}
