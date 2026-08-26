import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genuc_mobile/core/di/dependencies.dart';
import 'package:genuc_mobile/core/theme/app_theme.dart';
import 'package:genuc_mobile/core/utils/dio_client.dart';
import 'package:genuc_mobile/core/utils/presence_contexte.dart';
import 'package:genuc_mobile/data/services/api_service.dart';
import 'package:genuc_mobile/data/services/commun_service.dart';
import 'package:genuc_mobile/data/services/etudiant_academique_service.dart';
import 'package:genuc_mobile/data/services/etudiant_service.dart';
import 'package:genuc_mobile/data/services/professeur_pedagogie_service.dart';
import 'package:genuc_mobile/data/services/professeur_service.dart';
import 'package:genuc_mobile/domain/entities/user.dart';
import 'package:genuc_mobile/presentation/navigation/portail_shell.dart';
import 'package:genuc_mobile/presentation/providers/auth_provider.dart';
import 'package:genuc_mobile/presentation/providers/notification_provider.dart';
import 'package:genuc_mobile/presentation/providers/professeur_provider.dart';
import 'package:genuc_mobile/presentation/providers/student_provider.dart';
import 'package:genuc_mobile/presentation/providers/theme_provider.dart';
import 'package:provider/provider.dart';

/// Parcours réel du portail : on monte `PortailShell` avec le graphe de
/// dépendances de l'application, puis on clique comme le ferait un
/// utilisateur — tiroir, pastilles de module, barre basse, retour.
///
/// Le réseau est coupé net (adaptateur qui refuse tout) : les écrans affichent
/// donc leur état d'erreur, ce qui est exactement l'intérêt ici. Ce qui est
/// vérifié, c'est que **chaque geste de navigation amène le bon écran** — le
/// défaut d'origine étant un menu qui répondait « écran à venir ».
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Le stockage sécurisé n'a pas d'implémentation native sous test : sans ce
    // bouchon, le pot à cookies lève une MissingPluginException à chaque appel.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => call.method == 'readAll' ? <String, String>{} : null,
    );
    DioClient.reset();
  });

  tearDown(DioClient.reset);

  /// Monte le portail pour [role], sur un écran de téléphone.
  Future<void> monterPortail(WidgetTester tester, String role) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final dependencies = Dependencies.creer();
    // Coupe le réseau : réponses immédiates et déterministes, aucun délai
    // d'attente à traverser dans le test.
    dependencies.dioClient.dio.httpClientAdapter = _AdaptateurHorsLigne();

    final utilisateur = User(
      id: '1',
      nomComplet: 'Utilisateur Test',
      email: 'test@genuc.test',
      role: role,
      universiteId: '1',
      inscriptionId: '1',
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>(
            create: (_) => AuthProvider(dependencies.authRepository),
          ),
          ChangeNotifierProvider<StudentProvider>(
            create: (_) => StudentProvider(dependencies.studentRepository),
          ),
          ChangeNotifierProvider<NotificationProvider>(
            create: (_) =>
                NotificationProvider(dependencies.notificationRepository),
          ),
          ChangeNotifierProvider<ProfesseurProvider>(
            create: (_) =>
                ProfesseurProvider(dependencies.professeurRepository),
          ),
          ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
          Provider<PresenceContexteService>(
            create: (_) => dependencies.presenceContexte,
          ),
          Provider<EtudiantService>(
            create: (_) => dependencies.etudiantService,
          ),
          Provider<EtudiantAcademiqueService>(
            create: (_) => dependencies.etudiantAcademiqueService,
          ),
          Provider<ProfesseurService>(
            create: (_) => dependencies.professeurService,
          ),
          Provider<ProfesseurPedagogieService>(
            create: (_) => dependencies.professeurPedagogieService,
          ),
          Provider<CommunService>(create: (_) => dependencies.communService),
          Provider<ApiService>(create: (_) => dependencies.apiService),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: PortailShell(user: utilisateur),
        ),
      ),
    );

    // `pump` répétés plutôt que `pumpAndSettle` : les écrans rafraîchissent en
    // boucle (minuteurs de Smart Présence), et `pumpAndSettle` n'y trouverait
    // jamais d'état stable.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Ouvre le tiroir depuis la barre de titre.
  Future<void> ouvrirTiroir(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> taperEtAttendre(WidgetTester tester, Finder cible) async {
    await tester.tap(cible);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('Portail étudiant', () {
    testWidgets('s\'ouvre sur le tableau de bord, tiroir et barre basse posés',
        (tester) async {
      await monterPortail(tester, 'ETUDIANT');

      expect(find.text('Tableau de bord'), findsWidgets);
      // Le tiroir est branché : sans lui, l'écran serait un cul-de-sac.
      expect(find.byTooltip('Open navigation menu'), findsOneWidget);
      // Barre basse : les quatre gestes fréquents + « Plus ».
      expect(find.text('Plus'), findsOneWidget);
      expect(find.text('Finance'), findsNothing); // libellés du menu, pas du web
      expect(find.text('Mes paiements'), findsOneWidget);
    });

    testWidgets('le tiroir mène à un lien simple', (tester) async {
      await monterPortail(tester, 'ETUDIANT');
      await ouvrirTiroir(tester);

      // « Mon horaire » figure aussi dans la topbar de raccourcis : le finder
      // vise l'entrée du tiroir.
      final entreeHoraire = find.descendant(
        of: find.byType(Drawer),
        matching: find.text('Mon horaire'),
      );
      expect(entreeHoraire, findsOneWidget);
      await taperEtAttendre(tester, entreeHoraire);

      // Le titre de la page a changé : la destination est bien montée.
      expect(find.text('Mon horaire'), findsWidgets);
      expect(find.text('Cours, examens et événements'), findsOneWidget);
    });

    testWidgets('un module déplie ses volets et les pastilles suivent',
        (tester) async {
      await monterPortail(tester, 'ETUDIANT');
      await ouvrirTiroir(tester);

      await taperEtAttendre(tester, find.text('Résultats'));
      expect(find.text('Mes bulletins'), findsOneWidget);

      await taperEtAttendre(tester, find.text('Mes bulletins'));

      // La page est ouverte ET les pastilles du module l'accompagnent : c'est
      // ce qui remplace les `ModuleTabs` du web.
      expect(find.text('Mes bulletins'), findsWidgets);
      expect(find.text('Mon parcours'), findsOneWidget);
      expect(find.text('Recours'), findsOneWidget);
    });

    testWidgets('une pastille de module change de volet', (tester) async {
      await monterPortail(tester, 'ETUDIANT');
      await ouvrirTiroir(tester);
      await taperEtAttendre(tester, find.text('Résultats'));
      await taperEtAttendre(tester, find.text('Mes bulletins'));

      // Depuis les pastilles, sans repasser par le tiroir. La rangée défile
      // horizontalement : « Mon parcours » déborde de l'écran de test et doit
      // être amené à l'écran avant d'être tapé.
      final pastilleParcours = find.text('Mon parcours');
      await tester.ensureVisible(pastilleParcours);
      await taperEtAttendre(tester, pastilleParcours);
      expect(
        find.text('Année par année, depuis mon inscription'),
        findsOneWidget,
      );
    });

    testWidgets('la barre basse ouvre sa destination', (tester) async {
      await monterPortail(tester, 'ETUDIANT');

      await taperEtAttendre(tester, find.text('Mes paiements'));
      // Le titre de la page porte le libellé : la destination est montée.
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Mes paiements'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('« Mes cours » ne figure plus dans la barre basse',
        (tester) async {
      await monterPortail(tester, 'ETUDIANT');

      // Une seule occurrence : celle de la barre de raccourcis, en haut.
      expect(find.text('Mes cours'), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(cleTopbar), matching: find.text('Mes cours')),
        findsOneWidget,
      );
    });

    testWidgets('la topbar expose les trois raccourcis et les ouvre',
        (tester) async {
      await monterPortail(tester, 'ETUDIANT');

      final topbar = find.byKey(cleTopbar);
      expect(topbar, findsOneWidget);
      for (final libelle in ['Mon horaire', 'Mes cours', 'Messagerie']) {
        expect(
          find.descendant(of: topbar, matching: find.text(libelle)),
          findsOneWidget,
          reason: '« $libelle » doit figurer dans la barre de raccourcis',
        );
      }

      await taperEtAttendre(
        tester,
        find.descendant(of: topbar, matching: find.text('Messagerie')),
      );
      expect(find.text('Échanges avec l\'établissement'), findsOneWidget);

      // La barre reste posée sur la page ouverte : c'est tout son intérêt.
      expect(find.byKey(cleTopbar), findsOneWidget);
    });

    testWidgets('la barre de raccourcis se pose sous la barre de titre',
        (tester) async {
      await monterPortail(tester, 'ETUDIANT');

      final hautTitre = tester.getTopLeft(find.byType(AppBar)).dy;
      final hautRaccourcis = tester.getTopLeft(find.byKey(cleTopbar)).dy;
      expect(
        hautRaccourcis,
        greaterThan(hautTitre),
        reason: 'les raccourcis viennent après le titre, pas au-dessus',
      );
    });

    testWidgets('un écran à onglets s\'affiche avec la barre de raccourcis',
        (tester) async {
      // Régression : tant que la barre de raccourcis était la plus haute, le
      // titre descendait dans une `Column`, donc sans hauteur imposée.
      // L'`AppBar` d'un écran à onglets y plaçait un `Flexible` sous
      // contrainte infinie — assertion de mise en page, et écran rouge sur
      // les sept écrans à onglets.
      await monterPortail(tester, 'ETUDIANT');

      final topbar = find.byKey(cleTopbar);
      await taperEtAttendre(
        tester,
        find.descendant(of: topbar, matching: find.text('Mon horaire')),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Cours, examens et événements'), findsOneWidget);
      // Les onglets de l'écran sont rendus, et la barre de raccourcis reste
      // posée sur la page.
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.byKey(cleTopbar), findsOneWidget);

      // Et ils viennent APRÈS les raccourcis : « Semaine · Examens ·
      // Événements » ne doit pas s'afficher au-dessus de « Mon horaire ».
      expect(
        tester.getTopLeft(find.byType(TabBar)).dy,
        greaterThan(tester.getTopLeft(find.byKey(cleTopbar)).dy),
        reason: 'les onglets de l\'écran se placent sous la barre de raccourcis',
      );
    });

    testWidgets('le retour système recule dans l\'historique du portail',
        (tester) async {
      await monterPortail(tester, 'ETUDIANT');
      await ouvrirTiroir(tester);

      // Même finder scindé que le test du tiroir : « Mon horaire » est aussi
      // dans la topbar, on vise l'entrée du tiroir.
      await taperEtAttendre(
        tester,
        find.descendant(
          of: find.byType(Drawer),
          matching: find.text('Mon horaire'),
        ),
      );
      expect(find.text('Cours, examens et événements'), findsOneWidget);

      // Le portail intercepte le retour : on revient au tableau de bord au
      // lieu de quitter l'application.
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Cours, examens et événements'), findsNothing);
      expect(find.text('Tableau de bord'), findsWidgets);
    });
  });

  group('Portail enseignant', () {
    testWidgets('s\'ouvre sur son tableau de bord et expose ses modules',
        (tester) async {
      await monterPortail(tester, 'PROFESSEUR');
      expect(find.text('Tableau de bord'), findsWidgets);

      await ouvrirTiroir(tester);
      expect(find.text('Encadrement'), findsOneWidget);
      expect(find.text('Délibération'), findsOneWidget);
      expect(find.text('Rapports'), findsOneWidget);
    });

    testWidgets('atteint un écran d\'encadrement par le tiroir',
        (tester) async {
      await monterPortail(tester, 'PROFESSEUR');
      await ouvrirTiroir(tester);

      await taperEtAttendre(tester, find.text('Encadrement'));
      await taperEtAttendre(tester, find.text('Sujets TFC'));

      expect(find.text('Sujets de TFC'), findsOneWidget);
      expect(find.text('Suivi TFC'), findsOneWidget); // pastille du module
    });
  });
}

/// Adaptateur qui refuse toute requête, sans délai.
///
/// Le portail doit rester navigable serveur injoignable : c'est précisément la
/// situation où l'utilisateur a besoin de pouvoir changer d'écran.
class _AdaptateurHorsLigne implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString('{"erreur":"hors ligne"}', 503);
  }
}
