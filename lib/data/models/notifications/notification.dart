/// Modèle d'une notification.
///
/// Correspond exactement à `NotificationResponse` du backend
/// (`NotificationController.getMesNotifications`) :
/// `{id, titre, message, type, universiteId, coursId, inscriptionId, lue,
/// dateEnvoi, dateLecture, lienAction}`.
class NotificationItem {
  final int id;
  final String titre;
  final String message;
  final String type; // INFO, SUCCES, ATTENTION, URGENT, RAPPEL
  final bool lue;
  final String dateEnvoi;
  final String? lienAction;
  final int? universiteId;
  final int? coursId;
  final int? inscriptionId;

  NotificationItem({
    required this.id,
    required this.titre,
    required this.message,
    required this.type,
    required this.lue,
    required this.dateEnvoi,
    this.lienAction,
    this.universiteId,
    this.coursId,
    this.inscriptionId,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] ?? 0,
      titre: json['titre'] ?? 'Notification',
      message: json['message'] ?? '',
      type: json['type'] ?? 'INFO',
      lue: json['lue'] ?? false,
      dateEnvoi: json['dateEnvoi'] ?? '',
      lienAction: json['lienAction'],
      universiteId: json['universiteId'],
      coursId: json['coursId'],
      inscriptionId: json['inscriptionId'],
    );
  }

  bool get estUrgente => type == 'URGENT';
  bool get estAttention => type == 'ATTENTION';
  bool get estSucces => type == 'SUCCES';
  bool get estRappel => type == 'RAPPEL';

  String get dateAffichee {
    if (dateEnvoi.isEmpty) return '';
    final date = DateTime.tryParse(dateEnvoi);
    if (date == null) return dateEnvoi;
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return "à l'instant";
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'il y a ${diff.inDays} j';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
