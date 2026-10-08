import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genuc_mobile/core/di/dependencies.dart';
import 'package:genuc_mobile/core/theme/app_theme.dart';
import 'package:genuc_mobile/core/utils/dio_client.dart';
import 'package:genuc_mobile/data/models/etudiant/paiement.dart';
import 'package:genuc_mobile/data/services/commun_service.dart';
import 'package:genuc_mobile/data/services/etudiant_academique_service.dart';
import 'package:genuc_mobile/domain/entities/user.dart';
import 'package:genuc_mobile/presentation/providers/auth_provider.dart';
import 'package:genuc_mobile/presentation/screens/etudiant/demarches/demarches_screens.dart';
import 'package:provider/provider.dart';

/// Alignement sur l'audit serveur du 08/10/2026 (main 86eabad).
///
/// - « Mot de passe oublié » n'accepte plus d'adresse de contact : le corps ne
///   porte que l'identifiant.
/// - Un changement de filière exige la promotion d'accueil.
/// - La situation financière rend ses totaux par devise.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => call.method == 'readAll' ? <String, String>{} : null,
    );
    DioClient.reset();
  });

  tearDown(DioClient.reset);

  test('mot de passe oublié : seul l\'identifiant part au serveur', () async {
    final serveur = _ServeurEnregistreur();
    final dependencies = Dependencies.creer();
    dependencies.cacheService.dispose();
    dependencies.dioClient.dio.httpClientAdapter = serveur;

    await dependencies.apiService.forgotPassword(identifiant: 'HEC2025000123');

    final corps = serveur.corpsDe('/api/auth/mot-de-passe-oublie');
    expect(corps, {'identifiant': 'HEC2025000123'});
  });

  test('la situation financière lit ses totaux par devise', () {
    final situation = SituationFinanciere.fromJson(const {
      'totalAttendu': 50500,
      'parDevise': {
        'CDF': {'attendu': 50000, 'paye': 0, 'reste': 50000},
        'USD': {'attendu': 500, 'paye': 200, 'reste': 300},
      },
    });

    expect(situation.devisesMultiples, isTrue);
    expect(situation.parDevise['USD']!.paye, 200);
    expect(situation.parDevise['CDF']!.reste, 50000);
    expect(SituationFinanciere.fromJson(const {}).devisesMultiples, isFalse);
  });

  group('changement de filière', () {
    Future<_ServeurEnregistreur> monter(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 3, 1100 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final serveur = _ServeurEnregistreur();
      final dependencies = Dependencies.creer();
      dependencies.cacheService.dispose();
      dependencies.dioClient.dio.httpClientAdapter = serveur;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(
              create: (_) => AuthProvider(dependencies.authRepository)
                ..definirUtilisateurPourTest(const User(
                  id: '5',
                  role: 'ETUDIANT',
                  universiteId: '1',
                  inscriptionId: '1',
                )),
            ),
            Provider<EtudiantAcademiqueService>(
              create: (_) => dependencies.etudiantAcademiqueService,
            ),
            Provider<CommunService>(create: (_) => dependencies.communService),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const NouvelleDemandeScreen(type: 'CHANGEMENT_FILIERE'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      return serveur;
    }

    Future<void> choisir(WidgetTester tester, String champ, String valeur) async {
      await tester.tap(find.text(champ).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(valeur).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('la promotion d\'accueil est exigée', (tester) async {
      await monter(tester);
      await choisir(tester, 'Filière actuelle *', 'Droit privé');
      await choisir(tester, 'Filière souhaitée *', 'Sciences économiques');
      await tester.enterText(find.byType(TextFormField).last, 'Projet professionnel');

      await tester.tap(find.text('Soumettre ma demande'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('La promotion d\'accueil est obligatoire'), findsOneWidget);
    });

    testWidgets('la promotion choisie part avec la demande', (tester) async {
      final serveur = await monter(tester);
      await choisir(tester, 'Filière actuelle *', 'Droit privé');
      await choisir(tester, 'Filière souhaitée *', 'Sciences économiques');
      await choisir(tester, 'Promotion d\'accueil *', 'L2');
      await tester.enterText(find.byType(TextFormField).last, 'Projet professionnel');

      await tester.tap(find.text('Soumettre ma demande'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final corps = serveur.corpsDe('/api/demandes-academiques');
      expect(corps?['filiereSouhaiteeId'], '9');
      expect(corps?['promotionSouhaiteeId'], '22');
    });
  });
}

/// Serveur simulé qui garde le corps de chaque requête.
class _ServeurEnregistreur implements HttpClientAdapter {
  final Map<String, Map<String, dynamic>> _corps = {};

  Map<String, dynamic>? corpsDe(String chemin) => _corps[chemin];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final chemin = options.uri.path;
    if (options.data is Map) {
      _corps[chemin] = Map<String, dynamic>.from(options.data as Map);
    } else if (options.data is String && (options.data as String).isNotEmpty) {
      final decode = jsonDecode(options.data as String);
      if (decode is Map) _corps[chemin] = Map<String, dynamic>.from(decode);
    }

    if (chemin == '/api/filieres/public/disponibles') {
      return _json([
        {'id': 4, 'nom': 'Droit privé'},
        {'id': 9, 'nom': 'Sciences économiques'},
      ]);
    }
    if (chemin == '/api/promotions/filiere/9') {
      return _json([
        {'id': 21, 'libelle': 'L1'},
        {'id': 22, 'libelle': 'L2'},
      ]);
    }
    if (chemin == '/api/demandes-academiques') {
      return _json({'id': 31, 'statut': 'BROUILLON'});
    }
    return _json(<String, dynamic>{'message': 'ok'});
  }

  ResponseBody _json(Object corps) => ResponseBody.fromString(
        jsonEncode(corps),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
}
