import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/notifications/notification.dart';
import '../../../providers/notification_provider.dart';
import '../../../widgets/etat_widgets.dart';
import '../../../widgets/genuc_scaffold.dart';
import '../../../widgets/portail_widgets.dart';

/// Écran des notifications de l'utilisateur.
///
/// Correspond à `NotificationsEtudiant.jsx` du portail web : liste avec type
/// (INFO, SUCCES, ATTENTION, URGENT, RAPPEL), marquage lu individuel ou
/// global. S'appuie sur [NotificationProvider], déjà alimenté au démarrage.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String? _filtreType;

  @override
  void initState() {
    super.initState();
    // Au cas où l'écran est ouvert sans chargement préalable.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<NotificationProvider>();
      if (provider.notifications.isEmpty) {
        provider.loadNotifications();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();

    final toutes = provider.notifications;
    final filtrees = _filtreType == null
        ? toutes
        : toutes.where((n) => n.type == _filtreType).toList();

    return GenucScaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (provider.unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.done_all_rounded),
              tooltip: 'Tout marquer comme lu',
              onPressed: () => provider.markAllAsRead(),
            ),
        ],
      ),
      body: provider.isLoading
          ? const EtatChargement(message: 'Chargement des notifications…')
          : provider.error != null && toutes.isEmpty
              ? EtatErreur(
                  message: provider.error!,
                  onRetry: provider.loadNotifications,
                )
              : RefreshIndicator(
                  onRefresh: provider.loadNotifications,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _BarreFiltre(
                        filtre: _filtreType,
                        onChanged: (v) => setState(() => _filtreType = v),
                        nbNonLues: provider.unreadCount,
                        nbTotal: toutes.length,
                      ),
                      const SizedBox(height: 12),
                      if (filtrees.isEmpty)
                        const EtatVide(
                          icon: Icons.notifications_off_rounded,
                          titre: 'Aucune notification',
                          message:
                              'Vos notifications importantes apparaîtront ici.',
                        )
                      else
                        ...filtrees.map(
                          (n) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _NotificationTile(
                              notification: n,
                              onMarquerLue: () => provider.markAsRead(n.id),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _BarreFiltre extends StatelessWidget {
  final String? filtre;
  final ValueChanged<String?> onChanged;
  final int nbNonLues;
  final int nbTotal;

  const _BarreFiltre({
    required this.filtre,
    required this.onChanged,
    required this.nbNonLues,
    required this.nbTotal,
  });

  static const _types = <String, String>{
    'INFO': 'Info',
    'SUCCES': 'Succès',
    'ATTENTION': 'Attention',
    'URGENT': 'Urgent',
    'RAPPEL': 'Rappel',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: filtre,
                isExpanded: true,
                hint: const Text('Filtrer par type'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Toutes'),
                  ),
                  ..._types.entries.map(
                    (e) => DropdownMenuItem<String?>(
                      value: e.key,
                      child: Text('${e.key} — ${e.value}'),
                    ),
                  ),
                ],
                onChanged: onChanged,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (nbNonLues > 0)
            PillBadge(label: '$nbNonLues non lue${nbNonLues > 1 ? 's' : ''}', color: AppTheme.error),
          Text(
            '  $nbTotal au total',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondaryOf(context),
                ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationItem notification;
  final VoidCallback onMarquerLue;

  const _NotificationTile({
    required this.notification,
    required this.onMarquerLue,
  });

  Color _couleur() {
    if (notification.estUrgente) return AppTheme.error;
    if (notification.estAttention) return AppTheme.warning;
    if (notification.estSucces) return AppTheme.success;
    if (notification.estRappel) return AppTheme.info;
    return AppTheme.primary;
  }

  IconData _icone() {
    if (notification.estUrgente) return Icons.error_rounded;
    if (notification.estAttention) return Icons.warning_amber_rounded;
    if (notification.estSucces) return Icons.check_circle_rounded;
    if (notification.estRappel) return Icons.notifications_active_rounded;
    return Icons.info_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final couleur = _couleur();
    final nonLue = !notification.lue;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: nonLue
            ? couleur.withValues(alpha: 0.08)
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: nonLue
              ? couleur.withValues(alpha: 0.4)
              : AppTheme.borderOf(context),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconePlaque(icone: _icone(), couleur: couleur, taille: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification.titre,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    if (nonLue)
                      const PillBadge(label: 'Nouveau', color: AppTheme.success),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  notification.message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondaryOf(context),
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  notification.dateAffichee,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondaryOf(context),
                        fontSize: 11,
                      ),
                ),
              ],
            ),
          ),
          if (nonLue)
            IconButton(
              icon: const Icon(Icons.mark_email_read_rounded, size: 20),
              tooltip: 'Marquer comme lu',
              color: AppTheme.accentGraphique(context, AppTheme.primary),
              onPressed: onMarquerLue,
            ),
        ],
      ),
    );
  }
}
