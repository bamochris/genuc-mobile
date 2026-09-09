import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genuc_mobile/core/di/dependencies.dart';
import 'package:genuc_mobile/core/utils/presence_contexte.dart';
import 'package:genuc_mobile/data/services/api_service.dart';
import 'package:genuc_mobile/data/services/commun_service.dart';
import 'package:genuc_mobile/data/services/etudiant_academique_service.dart';
import 'package:genuc_mobile/data/services/etudiant_service.dart';
import 'package:genuc_mobile/data/services/professeur_pedagogie_service.dart';
import 'package:genuc_mobile/data/services/professeur_service.dart';
import 'package:genuc_mobile/domain/entities/user.dart';
import 'package:genuc_mobile/presentation/config/destinations.dart';
import 'package:genuc_mobile/presentation/navigation/portail_shell.dart';
import 'package:genuc_mobile/presentation/providers/annees_academiques_provider.dart';
import 'package:genuc_mobile/presentation/providers/auth_provider.dart';
import 'package:genuc_mobile/presentation/providers/notification_provider.dart';
import 'package:genuc_mobile/presentation/providers/professeur_provider.dart';
import 'package:genuc_mobile/presentation/providers/student_provider.dart';
import 'package:genuc_mobile/presentation/providers/theme_provider.dart';
import 'package:provider/provider.dart';

/// Montage d'un écran de portail dans un test, réseau maîtrisé.
///
/// Extrait de `mode_sombre_test.dart`, qui en était le seul usager, pour que
/// l'audit « avec données » monte les écrans EXACTEMENT de la même façon —
/// mêmes providers, même taille d'écran, même utilisateur. Deux montages qui
/// divergent, ce sont deux audits qui ne mesurent pas la même application.
class MontagePortail {
  /// Le mock du coffre-fort de jetons, à poser dans le `setUp` de chaque suite.
  static void simulerStockageSecurise() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => call.method == 'readAll' ? <String, String>{} : null,
    );
  }

  static User utilisateur(String role) => User(
        id: '1',
        nomComplet: 'Utilisateur Test',
        email: 'test@genuc.test',
        role: role,
        universiteId: '1',
        inscriptionId: '1',
      );

  /// Monte [destination] sous [theme], le réseau étant servi par [adaptateur].
  static Future<void> monter(
    WidgetTester tester,
    Destination destination,
    String role, {
    required ThemeData theme,
    required HttpClientAdapter adaptateur,
  }) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    _ignorerDebordements();

    final dependencies = Dependencies.creer();
    // Cf. `portail_shell_test.dart` : le minuteur de purge du cache survivrait
    // à l'arbre et ferait échouer le test bien après son déroulement.
    dependencies.cacheService.dispose();
    dependencies.dioClient.dio.httpClientAdapter = adaptateur;

    final user = utilisateur(role);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>(
            create: (_) => AuthProvider(dependencies.authRepository)
              ..definirUtilisateurPourTest(user),
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
          ChangeNotifierProvider<AnneesAcademiquesProvider>(
            create: (_) => AnneesAcademiquesProvider(dependencies.communService),
          ),
          Provider<PresenceContexteService>(
            create: (_) => dependencies.presenceContexte,
          ),
          Provider<EtudiantService>(create: (_) => dependencies.etudiantService),
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
          theme: theme,
          home: Builder(builder: destination.construire),
        ),
      ),
    );

    // `pump` répétés plutôt que `pumpAndSettle` : plusieurs écrans rafraîchissent
    // en boucle (minuteurs de Smart Présence) et n'atteignent jamais le repos.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // Une troisième passe : les écrans qui enchaînent deux appels (la liste des
    // cours, PUIS le détail du cours choisi) n'ont pas fini d'afficher leurs
    // données après la seconde.
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Écarte les débordements de `RenderFlex` pendant le montage.
  ///
  /// Non par complaisance : parce qu'ils ne veulent rien dire ICI. GENUC Mobile
  /// n'embarque aucune police — `pubspec.yaml` ne déclare que des images, et
  /// Inter est téléchargée à l'exécution par `google_fonts`. Sous `flutter
  /// test`, la fonte de substitution a des métriques ARBITRAIRES, sans rapport
  /// avec celles d'Inter : un « débordement de 5,6 pixels » y mesure la police
  /// de test, pas la mise en page de l'application. Faire échouer l'audit
  /// là-dessus reviendrait à signaler des défauts qui n'existent pas, et à
  /// masquer ceux qu'on cherche vraiment.
  ///
  /// La suite ne relâche donc RIEN sur son objet — le contraste, qui ne dépend
  /// pas de la fonte. Toute autre exception continue de faire échouer le test.
  static void _ignorerDebordements() {
    final originale = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('A RenderFlex overflowed')) {
        return;
      }
      originale?.call(details);
    };
    addTearDown(() => FlutterError.onError = originale);
  }

  /// Le portail complet, présenté comme une destination pour réutiliser tel
  /// quel le montage ci-dessus.
  static Destination coqueComme(String role) => Destination(
        chemin: '/coque/$role',
        libelle: 'Coque $role',
        icone: Icons.dashboard_rounded,
        couleur: const Color(0xFF185FA5),
        construire: (_) => PortailShell(user: utilisateur(role)),
      );
}

/// Réseau coupé net : chaque écran montre son état de chargement ou d'erreur,
/// sans délai d'attente à traverser.
class AdaptateurHorsLigne implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options,
          Stream<List<int>>? requestStream, Future<void>? cancelFuture) async =>
      ResponseBody.fromString('{"erreur":"hors ligne"}', 503);
}
