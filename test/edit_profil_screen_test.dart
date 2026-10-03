import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genuc_mobile/data/models/etudiant/etudiant_profile_backend.dart';
import 'package:genuc_mobile/data/repositories/student_repository.dart';
import 'package:genuc_mobile/domain/entities/user.dart';
import 'package:genuc_mobile/domain/repositories/auth_repository.dart';
import 'package:genuc_mobile/presentation/providers/auth_provider.dart';
import 'package:genuc_mobile/presentation/providers/student_provider.dart';
import 'package:genuc_mobile/presentation/screens/etudiant/profil/edit_profil_screen.dart';
import 'package:provider/provider.dart';

/// Écran « Modifier mon profil » aligné sur `PUT /api/etudiant/portal/profil/{id}`.
///
/// - `telephoneSecondaire` n'est lu nulle part par le serveur : l'envoyer faisait
///   annoncer « Profil mis à jour » pour une valeur jamais enregistrée.
/// - Date et lieu de naissance : l'étudiant peut les COMPLÉTER tant qu'ils sont
///   vides (règle serveur 7e77fe5, comme `MonProfil.jsx`), jamais les corriger.
void main() {
  testWidgets('aucun téléphone secondaire, ni affiché ni envoyé', (tester) async {
    final depot = _DepotProfil();
    await _ouvrir(tester, depot, _profil(date: '2001-05-04', lieu: 'Kinshasa'));

    expect(find.textContaining('secondaire'), findsNothing);

    await tester.tap(find.text('Sauvegarder'));
    await tester.pumpAndSettle();

    expect(depot.envois, hasLength(1));
    expect(depot.envois.single.keys, unorderedEquals(['email', 'telephone']));
  });

  testWidgets('date et lieu déjà renseignés : affichés, verrouillés, non envoyés',
      (tester) async {
    final depot = _DepotProfil();
    await _ouvrir(tester, depot, _profil(date: '2001-05-04', lieu: 'Kinshasa'));

    expect(find.text('04/05/2001'), findsOneWidget);
    expect(find.text('Kinshasa'), findsOneWidget);
    expect(find.textContaining('à compléter'), findsNothing);

    await tester.enterText(find.widgetWithText(TextFormField, 'Lieu de naissance'), 'Goma');
    expect(find.text('Goma'), findsNothing, reason: 'champ en lecture seule');
  });

  testWidgets('lieu vide : l\'étudiant le complète et il part au serveur', (tester) async {
    final depot = _DepotProfil();
    await _ouvrir(tester, depot, _profil(date: '2001-05-04', lieu: null));

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Lieu de naissance (à compléter)'), ' Lubumbashi ');
    await tester.tap(find.text('Sauvegarder'));
    await tester.pumpAndSettle();

    expect(depot.envois.single['lieuNaissance'], 'Lubumbashi');
    expect(depot.envois.single.containsKey('dateNaissance'), isFalse);
  });

  testWidgets('date vide : choisie au calendrier, envoyée en yyyy-MM-dd', (tester) async {
    final depot = _DepotProfil();
    await _ouvrir(tester, depot, _profil(date: null, lieu: 'Kinshasa'));

    await tester.tap(find.widgetWithText(TextFormField, 'Date de naissance (à compléter)'));
    await tester.pumpAndSettle();
    // Le calendrier s'ouvre sur l'année « il y a vingt ans » : on valide ce jour.
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sauvegarder'));
    await tester.pumpAndSettle();

    final envoyee = depot.envois.single['dateNaissance'] as String;
    expect(envoyee, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    expect(DateTime.parse(envoyee).year, DateTime.now().year - 20);
    expect(depot.envois.single.containsKey('lieuNaissance'), isFalse);
  });
}

EtudiantProfile _profil({String? date, String? lieu}) => EtudiantProfile(
      id: 7,
      matricule: 'HECKIN202500001',
      nom: 'Mbala',
      prenom: 'Grace',
      email: 'grace@exemple.cd',
      telephone: '+243810000000',
      dateNaissance: date,
      lieuNaissance: lieu,
      bulletin: false,
      photo: false,
      acte: false,
    );

Future<void> _ouvrir(WidgetTester tester, _DepotProfil depot, EtudiantProfile profil) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: _Auth()),
        ChangeNotifierProvider<StudentProvider>.value(value: StudentProvider(depot)),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => EditProfilScreen(profile: profil)),
                ),
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
}

class _Auth extends AuthProvider {
  _Auth() : super(_DepotAuth());

  @override
  User? get user => const User(id: '1', role: 'ETUDIANT', inscriptionId: '7');
}

class _DepotAuth implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DepotProfil implements StudentRepository {
  final List<Map<String, dynamic>> envois = [];

  @override
  Future<EtudiantProfile> updateProfile(String inscriptionId, Map<String, dynamic> data) async {
    envois.add(Map.of(data));
    return _profil();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
