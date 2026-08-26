import 'user.dart';

/// Issue d'une tentative de connexion.
///
/// `POST /api/auth/login` répond 200 dans deux cas distincts : session ouverte
/// (profil complet + cookies posés) ou second facteur requis (`mfaRequired`
/// + `mfaChallengeToken`, aucun cookie). Les confondre faisait passer un
/// compte protégé par 2FA pour un mot de passe erroné.
sealed class LoginResult {
  const LoginResult();
}

class LoginSuccess extends LoginResult {
  final User user;
  const LoginSuccess(this.user);
}

class LoginMfaRequired extends LoginResult {
  final String challengeToken;
  const LoginMfaRequired(this.challengeToken);
}
