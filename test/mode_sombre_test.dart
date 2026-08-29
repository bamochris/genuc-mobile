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
import 'package:genuc_mobile/presentation/config/destinations.dart';
import 'package:genuc_mobile/presentation/navigation/portail_shell.dart';
import 'package:genuc_mobile/presentation/providers/auth_provider.dart';
import 'package:genuc_mobile/presentation/providers/notification_provider.dart';
import 'package:genuc_mobile/presentation/providers/professeur_provider.dart';
import 'package:genuc_mobile/presentation/providers/student_provider.dart';
import 'package:genuc_mobile/presentation/providers/theme_provider.dart';
import 'package:provider/provider.dart';

import 'support/audit_contraste.dart';

/// Lisibilité en thème sombre, mesurée écran par écran.
///
/// <h3>Ce que ce test remplace</h3>
///
/// Le thème sombre s'était dégradé sans que rien ne le signale : le bleu nuit
/// de la marque (`#0B1F4A`) est **plus sombre que le fond ardoise** du thème
/// (`#0F172A`), si bien qu'une icône ou un titre peints avec la couleur de
/// marque disparaissent purement et simplement. Aucun test ne pouvait le voir,
/// et aucune relecture de code non plus : il faut composer le premier plan sur
/// le fond effectif, ce que seul l'arbre monté permet.
///
/// <h3>Comment il balaie « partout »</h3>
///
/// Les écrans ne sont pas listés à la main — ils sont tirés de
/// [MenuPortail.toutes], la table qui décrit les deux portails. Un écran
/// ajouté au menu entre donc automatiquement dans l'audit, et ne peut plus
/// arriver illisible sans qu'on le sache.
///
/// Le réseau est coupé : les écrans montrent leur squelette, leur état de
/// chargement ou leur état d'erreur. C'est suffisant — et même souhaitable,
/// puisque ces états-là sont ceux qu'on oublie le plus souvent d'habiller.
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

  Future<void> monterEcran(WidgetTester tester, Destination destination,
      String role) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final dependencies = Dependencies.creer();
    // Cf. `portail_shell_test.dart` : le minuteur de purge du cache survivrait
    // à l'arbre et ferait échouer le test bien après son déroulement.
    dependencies.cacheService.dispose();
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
            create: (_) => AuthProvider(dependencies.authRepository)
              ..definirUtilisateurPourTest(utilisateur),
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
          // LE point du test : le thème sombre, et lui seul.
          theme: AppTheme.darkTheme,
          home: Builder(builder: destination.construire),
        ),
      ),
    );

    // `pump` répétés plutôt que `pumpAndSettle` : plusieurs écrans rafraîchissent
    // en boucle (minuteurs de Smart Présence) et n'atteignent jamais le repos.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Même graphe de dépendances, mais on monte le PORTAIL entier plutôt qu'un
  /// écran isolé : c'est le seul moyen d'atteindre le tiroir et les barres.
  Future<void> monterCoque(WidgetTester tester, String role) =>
      monterEcran(tester, _coqueComme(role), role);

  void verifier(RapportContraste rapport, String ou) {
    // L'audit doit avoir MESURÉ quelque chose. Sans ce garde-fou, un écran qui
    // ne monte plus — rendu vide, exception avalée, provider manquant —
    // passerait au vert en ne protégeant plus rien, et le test deviendrait une
    // décoration sans que personne s'en aperçoive.
    expect(rapport.examines, greaterThan(0),
        reason: 'Aucun texte ni icône mesurable sur « $ou » : '
            "l'écran ne s'est pas monté, l'audit ne prouve rien.");
    expect(
      rapport.defauts,
      isEmpty,
      reason: 'Illisible en thème sombre sur « $ou » :\n  '
          '${rapport.defauts.join('\n  ')}',
    );
  }

  /// Un cas par écran : un échec nomme l'écran fautif, au lieu d'un seul test
  /// rouge qui dirait « quelque part dans l'application ».
  for (final role in const ['ETUDIANT', 'PROFESSEUR']) {
    group('Thème sombre — portail ${role.toLowerCase()}', () {
      for (final destination in MenuPortail.toutes(role)) {
        testWidgets('${destination.libelle} est lisible', (tester) async {
          await monterEcran(tester, destination, role);
          verifier(AuditContraste.auditer(tester),
              '${destination.libelle} (${destination.chemin})');
        });
      }
    });
  }

  /// La coque du portail : barre du haut, raccourcis, barre du bas — et le
  /// tiroir, qui porte à lui seul tout le menu.
  ///
  /// C'est là que l'utilisateur passe le plus de temps, et c'est la seule
  /// partie de l'application qu'aucun écran ne contient : elle serait sortie
  /// de l'audit sans ce groupe.
  group('Thème sombre — coque du portail', () {
    for (final role in const ['ETUDIANT', 'PROFESSEUR']) {
      testWidgets('la coque ${role.toLowerCase()} est lisible', (tester) async {
        await monterCoque(tester, role);
        verifier(AuditContraste.auditer(tester), 'coque $role');
      });

      testWidgets('le tiroir ${role.toLowerCase()} est lisible', (tester) async {
        await monterCoque(tester, role);
        await tester.tap(find.byTooltip('Open navigation menu'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        verifier(AuditContraste.auditer(tester), 'tiroir $role');
      });
    }
  });

  /// Les écrans atteignables SANS passer par le menu — notifications, carte
  /// d'étudiant, paramètres… Ils ne figurent dans aucune liste de navigation,
  /// et c'est précisément pour cela qu'ils échappent aux relectures.
  group('Thème sombre — écrans hors menu', () {
    for (final destination in MenuPortail.horsMenu) {
      testWidgets('${destination.libelle} est lisible', (tester) async {
        await monterEcran(tester, destination, 'ETUDIANT');
        verifier(AuditContraste.auditer(tester),
            '${destination.libelle} (${destination.chemin})');
      });
    }
  });
}

/// Réseau coupé net : chaque écran montre son état de chargement ou d'erreur,
/// sans délai d'attente à traverser.
class _AdaptateurHorsLigne implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options,
          Stream<List<int>>? requestStream, Future<void>? cancelFuture) async =>
      ResponseBody.fromString('{"erreur":"hors ligne"}', 503);
}

/// Le portail complet, présenté comme une destination pour réutiliser tel quel
/// le montage des écrans (providers, réseau coupé, taille d'écran).
Destination _coqueComme(String role) => Destination(
      chemin: '/coque/$role',
      libelle: 'Coque $role',
      icone: Icons.dashboard_rounded,
      couleur: const Color(0xFF185FA5),
      construire: (_) => PortailShell(
        user: User(
          id: '1',
          nomComplet: 'Utilisateur Test',
          email: 'test@genuc.test',
          role: role,
          universiteId: '1',
          inscriptionId: '1',
        ),
      ),
    );
