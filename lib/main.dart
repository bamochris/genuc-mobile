import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

// `Provider` (non ChangeNotifier) est importé via provider.dart ci-dessus.

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'core/di/dependencies.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/presence_contexte.dart';
import 'core/utils/responsive.dart';
import 'data/services/api_service.dart';
import 'data/services/commun_service.dart';
import 'data/services/etudiant_academique_service.dart';
import 'data/services/etudiant_service.dart';
import 'data/services/professeur_pedagogie_service.dart';
import 'data/services/professeur_service.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/notification_provider.dart';
import 'presentation/providers/professeur_provider.dart';
import 'presentation/providers/student_provider.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/navigation/portail_shell.dart';
import 'presentation/screens/login/login_screen.dart';
import 'presentation/screens/splash/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // M1 : Initialiser Firebase pour les notifications push.
  //
  // Optionnel : si la configuration Firebase est absente (google-services.json
  // / firebase_options.dart manquants), `Firebase.initializeApp()` lève et —
  // avec un `await` nu — bloquait `main()` avant `runApp()` : l'app restait
  // collée sur l'écran natif (logo). On dégrade proprement : pas de push,
  // tout le reste fonctionne. FCMService.initialize() gère aussi ses propres
  // erreurs, mais on le saute carrément si Firebase n'a pas démarré.
  bool firebaseOk = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseOk = true;
  } catch (e) {
    debugPrint('[Firebase] Échec de l\'initialisation — push désactivés : $e');
  }

  final dependencies = Dependencies.creer();

  // Amorce le cookie XSRF-TOKEN : Spring Security ne l'émet que sur une
  // réponse, donc tant qu'aucun appel n'a eu lieu le pot est vide. Pendant du
  // GET public que fait le portail web à son montage.
  //
  // Volontairement sans `await` : un backend injoignable retiendrait l'écran
  // natif jusqu'au délai de connexion. La connexion elle-même est exemptée de
  // CSRF côté backend, et tout écrit parti trop tôt est rattrapé par
  // l'intercepteur sur 403.
  unawaited(dependencies.dioClient.amorcerCsrf());
  // M1 : Initialiser FCM de manière asynchrone — uniquement si Firebase a démarré
  if (firebaseOk) {
    unawaited(dependencies.fcmService.initialize());
    // Deep-link : une notification tapée (« Nouveau message », « Nouvel
    // événement ») conduit vers l'écran cible. Si l'utilisateur n'est pas
    // authentifié, l'écran cible est précédé de l'écran de connexion —
    // la lecture du contenu exige une session au portail GENUC.
    dependencies.fcmService.onNotificationTap = (route) {
      GenucNavigator.ouvrirDepuisNotification(route);
    };
  }
  // M6 : Vérifier les mises à jour OTA Shorebird au démarrage
  unawaited(dependencies.shorebirdService.checkOnStartup());

  runApp(GenucApp(dependencies: dependencies));
}

/// Clé de navigation globale : permet au service FCM de pousser un écran
/// depuis une notification tapée, sans contexte BuildContext disponible.
class GenucNavigator {
  static final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();

  /// Ouvre l'écran correspondant à la route portée par la notification
  /// (« /messagerie », « /evenements »…). Si l'utilisateur n'est PAS
  /// authentifié, on le conduit vers l'écran de connexion : la lecture du
  /// contenu exige une session valide au portail GENUC.
  static void ouvrirDepuisNotification(String? route) {
    final navigator = key.currentState;
    if (navigator == null) return;
    navigator.pushNamedAndRemoveUntil('/notification-cible',
        arguments: route, (r) => false);
  }
}


class GenucApp extends StatelessWidget {
  final Dependencies dependencies;

  const GenucApp({super.key, required this.dependencies});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(dependencies.authRepository)..initSession(),
        ),
        ChangeNotifierProvider<StudentProvider>(
          create: (_) => StudentProvider(dependencies.studentRepository),
        ),
        ChangeNotifierProvider<NotificationProvider>(
          create: (_) => NotificationProvider(dependencies.notificationRepository),
        ),
        ChangeNotifierProvider<ProfesseurProvider>(
          create: (_) => ProfesseurProvider(dependencies.professeurRepository),
        ),
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
        ),
        Provider<PresenceContexteService>(
          create: (_) => dependencies.presenceContexte,
        ),
        // Services d'API exposés tels quels : les écrans de portail lisent des
        // ressources très diverses (barèmes, clubs, publications…) dont aucune
        // ne justifie un provider dédié à état.
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
        Provider<CommunService>(
          create: (_) => dependencies.communService,
        ),
        // Smart Présence (les deux portails) passe par `ApiService` : ses
        // routes rendent des DTO typés, pas des `Fiche`. L'exposer ici évite
        // qu'un écran enseignant aille le chercher dans `StudentProvider`.
        Provider<ApiService>(
          create: (_) => dependencies.apiService,
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'GENUC',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            debugShowCheckedModeBanner: false,
            // Le portail est intégralement en français : sans ces délégués,
            // les sélecteurs de date et les libellés Material restent en
            // anglais et `showDatePicker(locale: fr)` lève une assertion.
            locale: const Locale('fr'),
            supportedLocales: const [Locale('fr'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            // Le réglage système « taille de police » monte jusqu'à 200 % sur
            // Android : à cette échelle, les cartes du portail tronquent leurs
            // libellés et les grilles débordent. On l'honore jusqu'à 140 %,
            // au-delà duquel la mise en page ne tient plus.
            builder: (context, child) {
              final media = MediaQuery.of(context);
              return MediaQuery(
                data: media.copyWith(
                  textScaler: TextScaler.linear(
                    Responsive.echelleTextePlafonnee(context),
                  ),
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: const _RacineAuthentifiee(),
            navigatorKey: GenucNavigator.key,
            routes: {
              // Cible des notifications tapées. La garde d'authentification
              // vit dans l'écran : non connecté → LoginScreen (le contenu
              // GENUC exige une session), connecté → l'écran demandé.
              '/notification-cible': (context) => const _EcranNotificationCible(),
              // Racine du portail pour un utilisateur authentifié. Le user
              // est lu depuis le AuthProvider par PortailShell lui-même.
              '/portail': (context) {
                final user = context.read<AuthProvider>().user;
                return PortailShell(user: user!);
              },
            },
          );
        },
      ),
    );
  }
}

/// Aiguille entre splash, connexion et portail selon l'état de session.
///
/// Remplace les routes nommées `/login` et `/home` : elles obligeaient chaque
/// écran à pousser lui-même la navigation après un login ou un logout, et
/// `/home` reconstruisait un `HomeScreen` avec un thème figé en dur.
class _RacineAuthentifiee extends StatelessWidget {
  const _RacineAuthentifiee();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        // Splash uniquement le temps de la restauration initiale : une
        // connexion en cours doit laisser le formulaire à l'écran.
        if (!authProvider.sessionRestauree) {
          return const SplashScreen();
        }
        if (authProvider.isAuthenticated) {
          return PortailShell(user: authProvider.user!);
        }
        return const LoginScreen();
      },
    );
  }
}

/// Écran cible d'une notification tapée (« Nouveau message », « Nouvel
/// événement »…). La route demandée arrive en `arguments`.
///
/// Garde d'accès : si l'utilisateur n'a pas de session ouverte, on affiche
/// l'écran de connexion — la lecture du contenu (messages, événements du
/// campus) exige d'être authentifié au portail GENUC. Après connexion,
/// `PortailShell` prend le relais et l'utilisateur retombe sur son accueil ;
/// il peut alors rouvrir depuis la cloche de notifications.
class _EcranNotificationCible extends StatelessWidget {
  const _EcranNotificationCible();

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final route = ModalRoute.of(context)?.settings.arguments as String?;

    // Session non restaurée ou absente → connexion obligatoire.
    if (!authProvider.sessionRestauree || !authProvider.isAuthenticated) {
      return const LoginScreen();
    }

    // Connecté : on remplace cet écran intermédiaire par le portail, puis on
    // pousse l'écran demandé s'il correspond à une destination connue.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = GenucNavigator.key.currentState;
      if (navigator == null) return;
      navigator.pushReplacementNamed('/portail');
      if (route != null && route.isNotEmpty) {
        navigator.pushNamed(route);
      }
    });

    return const SplashScreen();
  }
}
