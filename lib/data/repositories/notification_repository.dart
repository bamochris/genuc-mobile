import '../models/notifications/notification.dart';
import '../services/api_service.dart';

class NotificationRepository {
  final ApiService api;

  NotificationRepository(this.api);

  Future<List<NotificationItem>> getNotifications() async {
    final data = await api.getNotifications();
    return data
        .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<NotificationItem>> getUnreadNotifications() async {
    final data = await api.getUnreadNotifications();
    return data
        .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> getUnreadCount() => api.getUnreadNotificationsCount();

  Future<void> markAsRead(int id) => api.markNotificationAsRead(id);

  Future<void> markAllAsRead() => api.markAllNotificationsAsRead();
}
