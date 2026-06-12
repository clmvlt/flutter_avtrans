import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../widgets/widgets.dart';

/// Page des notifications — direction *soft & chaleureux*.
///
/// Filtre segmenté en pilules (Toutes / Non lues), cartes [AppCard] et
/// horodatage relatif.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _allNotifications = [];
  bool _isLoading = true;
  String? _error;

  /// `false` = Toutes, `true` = Non lues.
  bool _onlyUnread = false;

  List<AppNotification> get _unreadNotifications =>
      _allNotifications.where((n) => !n.isRead).toList();

  List<AppNotification> get _visibleNotifications =>
      _onlyUnread ? _unreadNotifications : _allNotifications;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final allResult = await sl.notificationRepository.getAllNotifications();

    if (!mounted) return;

    allResult.fold(
      (failure) {
        setState(() {
          _error = failure.message;
          _isLoading = false;
        });
      },
      (notifications) {
        setState(() {
          _allNotifications = notifications;
          _isLoading = false;
        });
      },
    );
  }

  Future<void> _markAsRead(AppNotification notification) async {
    if (notification.isRead) return;

    final result =
        await sl.notificationRepository.markAsRead(notification.uuid);

    if (!mounted) return;

    result.fold(
      (failure) => _showSnack(failure.message, isError: true),
      (updated) {
        setState(() {
          final i = _allNotifications
              .indexWhere((n) => n.uuid == notification.uuid);
          if (i != -1) _allNotifications[i] = updated;
        });
      },
    );
  }

  Future<void> _markAllAsRead() async {
    final result = await sl.notificationRepository.markAllAsRead();

    if (!mounted) return;

    result.fold(
      (failure) => _showSnack(failure.message, isError: true),
      (_) {
        _showSnack('Toutes les notifications marquées comme lues');
        _loadNotifications();
      },
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    final colors = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? colors.destructive : colors.success,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
        backgroundColor: colors.card,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.base),
          side: BorderSide(
            color: isError ? colors.destructive : colors.border,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final unreadCount = _unreadNotifications.length;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unreadCount > 0)
            TextButton.icon(
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: const Text('Tout lire'),
              style: TextButton.styleFrom(foregroundColor: colors.primary),
            ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: Column(
        children: [
          _buildSegmentedFilter(colors, textTheme, unreadCount),
          Expanded(child: _buildBody(colors, textTheme)),
        ],
      ),
    );
  }

  Widget _buildSegmentedFilter(
      AppColors colors, TextTheme textTheme, int unreadCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.sm,
        AppSpacing.screen,
        AppSpacing.sm,
      ),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: colors.surfaceSunken,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Expanded(
              child: _SegmentButton(
                label: 'Toutes',
                count: _allNotifications.length,
                selected: !_onlyUnread,
                onTap: () => setState(() => _onlyUnread = false),
              ),
            ),
            Expanded(
              child: _SegmentButton(
                label: 'Non lues',
                count: unreadCount,
                selected: _onlyUnread,
                onTap: () => setState(() => _onlyUnread = true),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AppColors colors, TextTheme textTheme) {
    if (_isLoading) {
      return const LoadingIndicator(message: 'Chargement...');
    }
    if (_error != null) {
      return AppEmptyState(
        icon: Icons.error_outline,
        title: 'Erreur de chargement',
        subtitle: _error,
        actionText: 'Réessayer',
        onAction: _loadNotifications,
      );
    }

    final notifications = _visibleNotifications;

    if (notifications.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadNotifications,
        color: colors.primary,
        backgroundColor: colors.card,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.18),
            AppEmptyState(
              icon: _onlyUnread
                  ? Icons.mark_email_read_outlined
                  : Icons.notifications_none_rounded,
              title: _onlyUnread
                  ? 'Tout est lu'
                  : 'Aucune notification',
              subtitle: _onlyUnread
                  ? 'Tu es à jour, rien à signaler'
                  : 'Tes notifications apparaîtront ici',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      color: colors.primary,
      backgroundColor: colors.card,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.sm,
          AppSpacing.screen,
          AppSpacing.lg,
        ),
        itemCount: notifications.length,
        separatorBuilder: (_, __) =>
            const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) =>
            _buildNotificationCard(notifications[index], colors, textTheme),
      ),
    );
  }

  Widget _buildNotificationCard(
      AppNotification notification, AppColors colors, TextTheme textTheme) {
    final refColor = _getRefTypeColor(notification.refType, colors);
    final unread = !notification.isRead;

    return AppCard(
      elevation: unread ? AppCardElevation.raised : AppCardElevation.flat,
      border: !unread,
      color: unread ? colors.primarySoft : colors.card,
      onTap: () => _markAsRead(notification),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: refColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              _getRefTypeIcon(notification.refType),
              color: refColor,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight:
                              unread ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (unread) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        width: 9,
                        height: 9,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: colors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                if (notification.description != null &&
                    notification.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    notification.description!,
                    style: textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _formatRelative(notification.createdAt),
                  style: textTheme.labelSmall
                      ?.copyWith(color: colors.mutedForeground),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Horodatage relatif chaleureux ; bascule sur la date au-delà d'une semaine.
  String _formatRelative(DateTime? date) {
    if (date == null) return '';
    final local = date.toLocal();
    final diff = DateTime.now().difference(local);

    if (diff.inMinutes < 1) return "À l'instant";
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
    if (diff.inDays < 7) {
      return diff.inDays == 1 ? 'Hier' : 'Il y a ${diff.inDays} j';
    }
    return DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR').format(local);
  }

  IconData _getRefTypeIcon(String? refType) {
    switch (refType) {
      case 'acompte':
        return Icons.payments_rounded;
      case 'absence':
        return Icons.event_busy_rounded;
      case 'rapportVehicule':
        return Icons.description_rounded;
      case 'todo':
        return Icons.checklist_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getRefTypeColor(String? refType, AppColors colors) {
    switch (refType) {
      case 'acompte':
        return colors.info;
      case 'absence':
        return colors.warning;
      case 'rapportVehicule':
        return colors.chart3;
      case 'todo':
        return colors.success;
      default:
        return colors.primary;
    }
  }
}

/// Pilule d'un sélecteur segmenté (Toutes / Non lues).
class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return AnimatedContainer(
      duration: AppDuration.fast,
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: selected ? colors.card : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        boxShadow: selected ? colors.cardShadow : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: textTheme.labelLarge?.copyWith(
                    color: selected
                        ? colors.foreground
                        : colors.mutedForeground,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '$count',
                    style: textTheme.labelSmall?.copyWith(
                      color: selected
                          ? colors.primary
                          : colors.mutedForeground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
