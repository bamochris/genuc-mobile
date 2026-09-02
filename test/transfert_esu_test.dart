import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genuc_mobile/core/di/dependencies.dart';
import 'package:genuc_mobile/core/theme/app_theme.dart';
import 'package:genuc_mobile/core/utils/dio_client.dart';
import 'package:genuc_mobile/data/services/commun_service.dart';
import 'package:genuc_mobile/data/services/etudiant_academique_service.dart';
import 'package:genuc_mobile/domain/entities/user.dart';
import 'package:genuc_mobile/presentation/providers/auth_provider.dart';
import 'package:genuc_mobile/presentation/screens/etudiant/demarches/transfert_demande_screen.dart';
import 'package:provider/provider.dart';

/// Ce que l'ESU exige d'une demande de transfert, vérifié à la saisie.
///
/// <h3>Pourquoi ces trois champs, et pas d'autres</h3>
///
/// Le circuit est : soumission → vérification à l'origine → **examen à
/// destination** → équivalences → décision. L'examen à destination est ROUTÉ
/// par `findByUniversiteDestinationIdAndStatutIn` — sans établissement
/// d'accueil, le dossier n'atteint personne ; et la commission d'équivalences
/// compare les UE d'un programme à celles d'un autre, année par année — sans
/// filière ni promotion d'accueil, il n'y a rien à comparer.
///
/// Le serveur accepte pourtant ces champs nuls, et il le doit : il lui faut
/// rester capable de relire les dossiers anciens. C'est donc à la saisie de les
/// exiger, et c'est précisément ce qu'un test peut tenir.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Le stockage sécurisé n'a pas d'implémentation native sous test : sans ce
    // bouchon, le pot à cookies lève une MissingPluginException.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => call.method == 'readAll' ? <String, String>{} : null,
    );
    DioClient.reset();
  });

  tearDown(DioClient.reset);

  Future<void> monter(WidgetTester tester, {_ServeurCanne? serveur}) async {
    tester.view.physicalSize = const Size(390 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final dependencies = Dependencies.creer();
    // Le minuteur de purge du cache survivrait à l'arbre de widgets et ferait
    // échouer le test sur « A Timer is still pending » — après qu'il se soit
    // déroulé entièrement. Cf. `portail_shell_test.dart`.
    dependencies.cacheService.dispose();
    dependencies.dioClient.dio.httpClientAdapter = serveur ?? _ServeurCanne();

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
          home: const TransfertDemandeScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('la situation actuelle est LUE, pas saisie', (tester) async {
    await monter(tester);

    // L'origine ne se choisit pas : le serveur refuse toute valeur autre que
    // celle de l'inscription (`verifierCoherenceOrigine`). L'afficher en
    // lecture évite une saisie qui ne peut que produire un rejet.
    expect(find.text('Votre situation actuelle'), findsOneWidget);
    expect(find.text('Université de Kinshasa'), findsWidgets);
    expect(find.text('Droit privé'), findsWidgets);
  });

  testWidgets('les trois niveaux de destination sont exigés', (tester) async {
    await monter(tester);

    // Le formulaire dépasse la hauteur de l'écran : le bouton n'est pas
    // construit tant qu'on n'a pas fait défiler jusqu'à lui.
    final bouton = find.text('Enregistrer le brouillon');
    await tester.dragUntilVisible(
      bouton,
      find.byType(ListView),
      const Offset(0, -260),
    );
    await tester.pump();
    await tester.tap(bouton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Le motif est obligatoire lui aussi, mais ce sont les trois niveaux de
    // destination qui font l'exigence ESU : sans eux le dossier n'atteint
    // personne et rien ne peut être mis en équivalence.
    expect(find.text('Indiquez la filière d\'accueil.'), findsOneWidget);
    expect(find.text('Indiquez la promotion d\'accueil.'), findsOneWidget);
    expect(find.text('Le motif est obligatoire.'), findsOneWidget);
  });

  testWidgets('la filière se charge dès l\'établissement connu',
      (tester) async {
    await monter(tester);

    // Un changement de filière reste dans l'établissement : celui-ci est donc
    // posé d'emblée, et ses filières chargées sans attendre un geste que
    // l'étudiant n'a aucune raison de faire.
    await tester.tap(find.text('Filière d\'accueil *').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Sciences économiques'), findsWidgets);
  });

  testWidgets('choisir une filière charge SES promotions', (tester) async {
    await monter(tester);

    await tester.tap(find.text('Filière d\'accueil *').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sciences économiques').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Promotion d\'accueil *').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('L2'), findsWidgets);
  });

  testWidgets('demander la filière déjà suivie est refusé', (tester) async {
    await monter(tester);

    // « Droit privé » est la filière de l'inscription. Le serveur ne recoupe
    // JAMAIS la destination avec l'origine : `verifierCoherenceDestination` ne
    // vérifie que la hiérarchie interne de la destination. Cette demande
    // traverserait donc tout le circuit — quitus, examen à destination,
    // équivalences — pour aboutir à une décision sur une demande qui ne
    // demande rien.
    await tester.tap(find.text('Filière d\'accueil *').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Droit privé').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Promotion d\'accueil *').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('L3').last);
    // `pumpAndSettle` et non `pump` : le menu déroulant se referme par une
    // animation, et tant qu'il est ouvert son propre ListView coexiste avec
    // celui de la page — le défilement ne saurait alors plus lequel viser.
    await tester.pumpAndSettle();

    // On défile AVANT de saisir : le champ « Motif » est en bas d'un ListView,
    // et tant qu'il n'est pas construit, `TextFormField.last` désigne « Année
    // d'accueil ». On remplissait alors l'année et on laissait le motif vide —
    // la validation de forme s'arrêtait là, et la règle de cohérence qu'on
    // veut éprouver n'était jamais atteinte.
    final bouton = find.text('Enregistrer le brouillon');
    await tester.dragUntilVisible(
      bouton,
      find.byType(ListView).first,
      const Offset(0, -260),
    );
    await tester.pump();

    await tester.enterText(
      find.byType(TextFormField).last,
      'Rapprochement familial',
    );
    await tester.pump();

    await tester.tap(bouton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Le bandeau se pose EN TÊTE de la liste, donc hors écran après le
    // défilement : un widget non construit reste introuvable, si présent
    // soit-il dans l'état.
    await tester.drag(find.byType(ListView).first, const Offset(0, 1200));
    await tester.pump();

    expect(find.textContaining('Vous suivez déjà cette filière'), findsOneWidget);
  });

  testWidgets('sans inscription active, le dépôt est refusé d\'entrée',
      (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final dependencies = Dependencies.creer();
    dependencies.cacheService.dispose();
    dependencies.dioClient.dio.httpClientAdapter = _ServeurCanne();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>(
            create: (_) => AuthProvider(dependencies.authRepository)
              ..definirUtilisateurPourTest(
                const User(id: '5', role: 'ETUDIANT', universiteId: '1'),
              ),
          ),
          Provider<EtudiantAcademiqueService>(
            create: (_) => dependencies.etudiantAcademiqueService,
          ),
          Provider<CommunService>(create: (_) => dependencies.communService),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const TransfertDemandeScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Le transfert PART du dossier d'inscription : sans lui, ni `etudiantId`
    // ni établissement d'origine, et le serveur répondrait « Requête
    // invalide » sans dire ce qui manque.
    expect(
      find.textContaining('Aucune inscription active'),
      findsOneWidget,
    );
  });
}

/// Serveur en dur : rend les charges utiles réelles des quatre routes que
/// l'écran appelle, et 404 sur tout le reste.
class _ServeurCanne implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final chemin = options.uri.path;

    // `InscriptionResponse` — la seule route qui rende `etudiantId`.
    if (chemin == '/api/inscriptions/1') {
      return _json({
        'id': 1,
        'etudiantId': 77,
        'universiteId': 1,
        'universiteNom': 'Université de Kinshasa',
        'filiereId': 4,
        'filiereNom': 'Droit privé',
        'promotionId': 8,
        'promotionLibelle': 'L1',
        'anneeAcademiqueLibelle': '2026-2027',
      });
    }
    if (chemin == '/api/universites') {
      return _json([
        {'id': 1, 'nom': 'Université de Kinshasa'},
        {'id': 2, 'nom': 'Université de Lubumbashi'},
      ]);
    }
    // Route PUBLIQUE des filières ouvertes. Le service visait
    // `/api/filieres/universite/{id}`, réservée à l'administration ET bornée à
    // l'établissement de l'appelant : l'étudiant y recevait un 403, et le
    // formulaire de transfert — qui demande les filières de l'établissement
    // d'ACCUEIL — n'aurait de toute façon jamais pu s'en servir.
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
    if (chemin == '/api/promotions/filiere/4') {
      return _json([
        {'id': 8, 'libelle': 'L1'},
        {'id': 12, 'libelle': 'L3'},
      ]);
    }
    return ResponseBody.fromString('{"erreur":"inconnu"}', 404);
  }

  ResponseBody _json(Object corps) => ResponseBody.fromString(
        jsonEncode(corps),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
}
