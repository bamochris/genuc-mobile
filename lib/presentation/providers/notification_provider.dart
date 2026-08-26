import 'package:flutter/foundation.dart';

import '../../core/errors/api_exception.dart';
import '../../data/models/notifications/notification.dart';
import '../../data/repositories/notification_repository.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationRepository repository;

  NotificationProvider(this.repository);

  bool _isLoading = false;
  String? _error;
  List<NotificationItem> _notifications = [];
  List<NotificationItem> _unreadNotifications = [];
  int _unreadCount = 0;

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<NotificationItem> get notifications => _notifications;
  List<NotificationItem> get unreadNotifications => _unreadNotifications;
  int get unreadCount => _unreadCount;

  Future<void> loadNotifications() async {
    _setLoading(true);
    _error = null;
    try {
      // En parallèle : trois allers-retours séquentiels retardaient
      // l'affichage du tableau de bord d'autant.
      final resultats = await Future.wait([
        repository.getNotifications(),
        repository.getUnreadNotifications(),
        repository.getUnreadCount(),
      ]);
      _notifications = resultats[0] as List<NotificationItem>;
      _unreadNotifications = resultats[1] as List<NotificationItem>;
      _unreadCount = resultats[2] as int;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Erreur de chargement des notifications : ${e.runtimeType}';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refreshCount() async {
    try {
      _unreadCount = await repository.getUnreadCount();
      notifyListeners();
    } catch (_) {
      // Compteur secondaire : un échec ne doit pas perturber l'écran.
    }
  }

  Future<bool> markAsRead(int id) async {
    try {
      await repository.markAsRead(id);
      _unreadNotifications =
          _unreadNotifications.where((n) => n.id != id).toList();
      _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
      // La notification reste dans _notifications : elle n'est pas supprimée,
      // seulement marquée comme lue. On met à jour son drapeau pour que la
      // liste réflète l'état sans rechargement.
      _notifications = _notifications
          .map((n) => n.id == id ? _copierLue(n) : n)
          .toList();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await repository.markAllAsRead();
      _unreadNotifications = [];
      _unreadCount = 0;
      _notifications =
          _notifications.map(_copierLue).toList();
      notifyListeners();
    } catch (_) {
      // Idem : l'état serveur fait foi au prochain chargement.
    }
  }

  NotificationItem _copierLue(NotificationItem n) {
    if (n.lue) return n;
    return NotificationItem(
      id: n.id,
      titre: n.titre,
      message: n.message,
      type: n.type,
      lue: true,
      dateEnvoi: n.dateEnvoi,
      lienAction: n.lienAction,
      universiteId: n.universiteId,
      coursId: n.coursId,
      inscriptionId: n.inscriptionId,
    );
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
