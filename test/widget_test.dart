import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genuc_mobile/core/constants/api_endpoints.dart';
import 'package:genuc_mobile/domain/entities/login_result.dart';
import 'package:genuc_mobile/domain/entities/two_factor_setup.dart';
import 'package:genuc_mobile/domain/entities/user.dart';
import 'package:genuc_mobile/domain/repositories/auth_repository.dart';
import 'package:genuc_mobile/presentation/providers/auth_provider.dart';
import 'package:genuc_mobile/presentation/screens/login/login_screen.dart';
import 'package:provider/provider.dart';

/// Dépôt d'authentification en double : ni réseau, ni stockage sécurisé
/// (indisponible sous `flutter test`).
class _FakeAuthRepository implements AuthRepository {
  @override
  Future<LoginResult> login({
    required String identifiant,
    required String password,
  }) async =>
      const LoginSuccess(User(email: 'test@genuc.cd'));

  @override
  Future<User> verifyMfaAndLogin({
    required String mfaChallengeToken,
    required String code,
  }) async =>
      const User(email: 'test@genuc.cd');

  @override
  Future<void> logout() async {}

  @override
  Future<User?> restaurerSession() async => null;

  @override
  Future<void> changerMotDePasse({
    required String ancienMotDePasse,
    required String nouveauMotDePasse,
  }) async {}

  @override
  Future<bool> statut2fa() async => false;

  @override
  Future<TwoFactorSetup> demarrerActivation2fa() async =>
      const TwoFactorSetup(secret: 'SECRET', otpAuthUrl: 'otpauth://totp/GENUC');

  @override
  Future<void> confirmerActivation2fa(String code) async {}

  @override
  Future<void> desactiver2fa(String code) async {}
}

void main() {
  group('ApiEndpoints', () {
    test('interpole réellement les constantes du portail', () {
      // Régression : `'$ApiEndpoints.etudiantProfil/$id'` produisait la chaîne
      // littérale « ApiEndpoints.etudiantProfil/42 ».
      expect(
        ApiEndpoints.etudiantProfil('42'),
        '/api/etudiant/portal/profil/42',
      );
      expect(
        ApiEndpoints.etudiantDashboard('42'),
        '/api/etudiant/portal/dashboard/42',
      );
    });

    test('place l\'inscriptionId avant la ressource là où le backend l\'attend',
        () {
      expect(ApiEndpoints.etudiantCours('42'), '/api/etudiant/portal/42/cours');
      expect(ApiEndpoints.etudiantNotes('42'), '/api/etudiant/portal/42/notes');
      expect(
        ApiEndpoints.etudiantDocuments('42'),
        '/api/etudiant/portal/42/documents-officiels',
      );
      expect(ApiEndpoints.etudiantStage('42'), '/api/etudiant/portal/42/stage');
      expect(
        ApiEndpoints.etudiantTravaux('42'),
        '/api/etudiant/portal/42/travaux',
      );
    });
  });

  group('User', () {
    test('lit le rôle de la réponse de connexion', () {
      final user = User.fromJson({'email': 'a@b.cd', 'role': 'ETUDIANT'});
      expect(user.role, 'ETUDIANT');
    });

    test('dérive le rôle des authorities de /api/auth/moi', () {
      final user = User.fromJson({
        'email': 'a@b.cd',
        'roles': [
          {'authority': 'ROLE_ETUDIANT'},
        ],
      });
      expect(user.role, 'ETUDIANT');
    });

    test('fusionner complète sans écraser par du vide', () {
      const memorise = User(
        email: 'a@b.cd',
        nomComplet: 'Jean Kabila',
        role: 'ETUDIANT',
        inscriptionId: '42',
      );
      const minimal = User(email: 'a@b.cd', role: 'ETUDIANT');

      final fusionne = memorise.fusionner(minimal);
      expect(fusionne.inscriptionId, '42');
      expect(fusionne.nomComplet, 'Jean Kabila');
    });
  });

  testWidgets('l\'écran de connexion s\'affiche sans identifiants en dur',
      (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => AuthProvider(_FakeAuthRepository()),
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('GENUC'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    // Le sélecteur de comptes de test embarquait 8 mots de passe en clair.
    expect(find.text('Compte de test'), findsNothing);
  });
}
