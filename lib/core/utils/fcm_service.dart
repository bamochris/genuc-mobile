import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../constants/api_endpoints.dart';

/// M1 : Service de notifications push via Firebase Cloud Messaging.
///
/// Le mobile n'avait aucun mécanisme de notification push — l'étudiant devait
/// ouvrir l'application manuellement pour voir les mises à jour (paiements
/// validés, examens planifiés, cours modifiés, messages).
///
/// Ce service :
/// 1. Demande la permission à l'utilisateur
/// 2. Enregistre le token FCM auprès du backend
/// 3. Affiche les notifications locales quand l'app est en arrière-plan
/// 4. Gère les clics sur les notifications (deep linking)
class FCMService {
  final Dio _dio;

  /// Accès paresseux : `FirebaseMessaging.instance` lève `[core/no-app]` si
  /// Firebase n'a pas démarré (config absente). Un champ final évalué au
  /// constructeur plantait donc la création même du service — et avec lui
  /// tout le démarrage de l'app. On ne touche à l'instance qu'au moment
  /// d'initialiser, et seulement si `initialize()` est appelé.
  FirebaseMessaging? _messagingInstance;
  FirebaseMessaging get _messaging =>
      _messagingInstance ??= FirebaseMessaging.instance;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  bool _initialized = false;

  /// Callback appelé quand l'utilisateur clique sur une notification.
  void Function(String route)? onNotificationTap;

  FCMService(this._dio);

  /// Initialise le service complet : permission, token, listeners.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      // 1. Demander la permission
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        debugPrint('[FCM] Permission refusée par l\'utilisateur');
        return;
      }

      // 2. Initialiser les notifications locales
      await _initLocalNotifications();

      // 3. Obtenir et enregistrer le token
      _fcmToken = await _messaging.getToken();
      if (_fcmToken != null) {
        await _registerToken(_fcmToken!);
      }

      // 4. Écouter les changements de token
      _messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        _registerToken(newToken);
      });

      // 5. Écouter les messages en premier plan
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // 6. Écouter les clics sur les notifications
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // 7. Vérifier si l'app a été ouverte via une notification
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      debugPrint('[FCM] Initialisé avec succès. Token: ${_fcmToken?.substring(0, 20)}...');
    } catch (e) {
      debugPrint('[FCM] Erreur d\'initialisation: $e');
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null) {
          _handleNotificationPayload(response.payload!);
        }
      },
    );
  }

  Future<void> _registerToken(String token) async {
    try {
      // Contrat backend : DeviceTokenController — POST /api/notifications/push/
      // enregistrer, champ « plateforme » (pas « platform »). Requiert une
      // session authentifiée (@PreAuthorize isAuthenticated) : appelé après
      // login, sinon le backend répond 403/401 et on retentera au prochain
      // refresh de token.
      await _dio.post(
        '/api/notifications/push/enregistrer',
        data: {'token': token, 'plateforme': 'ANDROID'},
      );
      debugPrint('[FCM] Token enregistré auprès du backend');
    } catch (e) {
      debugPrint('[FCM] Échec de l\'enregistrement du token: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM] Message en premier plan: ${message.messageId}');

    final notification = message.notification;
    if (notification == null) return;

    // Afficher une notification locale pour les messages en premier plan
    _showLocalNotification(
      title: notification.title ?? 'GENUC',
      body: notification.body ?? '',
      payload: jsonEncode(message.data),
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('[FCM] Notification tapée: ${message.messageId}');
    _handleNotificationPayload(jsonEncode(message.data));
  }

  void _handleNotificationPayload(String payload) {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final route = data['route'] as String?;

      if (route != null && onNotificationTap != null) {
        onNotificationTap!(route);
      }
    } catch (e) {
      debugPrint('[FCM] Erreur parsing payload: $e');
    }
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'genuc_notifications',
      'Notifications GENUC',
      channelDescription: 'Notifications de la plateforme GENUC',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const details = NotificationDetails(
      android: androidDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Supprime le token du backend (déconnexion).
  Future<void> unregister() async {
    if (_fcmToken != null) {
      try {
        await _dio.post(
          '/api/notifications/push/desenregistrer',
          data: {'token': _fcmToken},
        );
      } catch (_) {}
    }
    _fcmToken = null;
  }

  String? get token => _fcmToken;
}
