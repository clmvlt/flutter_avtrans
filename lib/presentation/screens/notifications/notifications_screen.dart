import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../widgets/widgets.dart';
import 'widgets/notification_day_group.dart';

/// Page des notifications : filtre « Toutes / Non lues » sous le titre,
/// notifications regroupées par jour, « Tout marquer comme lu » dans le dock.
///
/// Taper une notification non lue la marque comme lue. Les erreurs d'action
/// s'affichent dans le dock ; un succès se voit au changement de la liste.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with DockNoticeMixin {
  List<AppNotification> _allNotifications = [];
  bool _isLoading = true;
  String? _error;

  /// Une liste a déjà été affichée : un rafraîchissement raté ne la
  /// remplace pas par l'erreur (notice du dock à la place).
  bool _loaded = false;

  /// `false` = Toutes, `true` = Non lues.
  bool _onlyUnread = false;
  bool _markingAll = false;

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
    if (!_loaded && !_isLoading) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    final allResult = await sl.notificationRepository.getAllNotifications();

    if (!mounted) return;

    allResult.fold(
      (failure) {
        if (_loaded) {
          showDockError(failure.message);
        } else {
          setState(() {
            _error = failure.message;
            _isLoading = false;
          });
        }
      },
      (notifications) {
        setState(() {
          _allNotifications = notifications;
          _isLoading = false;
          _error = null;
          _loaded = true;
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
      (failure) => showDockError(failure.message),
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
    if (_markingAll) return;
    clearDockNotice();
    setState(() => _markingAll = true);

    final result = await sl.notificationRepository.markAllAsRead();

    if (!mounted) return;
    setState(() => _markingAll = false);

    result.fold(
      (failure) => showDockError(failure.message),
      (_) => _loadNotifications(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _unreadNotifications.length;

    return AppPage(
      title: 'Notifications',
      bottom: AppPageBar(
        child: AppSegmented<bool>(
          segments: [
            AppSegment(
              value: false,
              label: 'Toutes',
              count: _allNotifications.length,
            ),
            AppSegment(value: true, label: 'Non lues', count: unreadCount),
          ],
          selected: _onlyUnread,
          onChanged: (v) => setState(() => _onlyUnread = v),
        ),
      ),
      body: _buildBody(),
      dock: AppDock(
        actions: [
          if (unreadCount > 0)
            DockAction(
              label: 'Tout marquer comme lu',
              icon: Icons.done_all_rounded,
              tone: DockTone.secondary,
              isLoading: _markingAll,
              onPressed: _markingAll ? null : _markAllAsRead,
            ),
        ],
        notice: dockNotice,
        onDismissNotice: clearDockNotice,
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const AppScrollView(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xs,
              0,
              AppSpacing.xs,
              AppSpacing.md,
            ),
            child: AppSkeleton(width: 110, height: 16),
          ),
          AppListSkeleton(rows: 5),
        ],
      );
    }

    final error = _error;
    if (error != null) {
      return AppScrollView(
        onRefresh: _loadNotifications,
        children: [
          AppErrorState(message: error, onRetry: _loadNotifications),
        ],
      );
    }

    final notifications = _visibleNotifications;

    if (notifications.isEmpty) {
      return AppScrollView(
        onRefresh: _loadNotifications,
        children: [
          const SizedBox(height: AppSpacing.xl),
          AppEmptyState(
            icon: _onlyUnread
                ? Icons.mark_email_read_outlined
                : Icons.notifications_none_rounded,
            title: _onlyUnread ? 'Tout est lu' : 'Aucune notification',
            subtitle: _onlyUnread
                ? 'Tu es à jour, rien à signaler'
                : 'Tes notifications apparaîtront ici',
          ),
        ],
      );
    }

    final now = DateTime.now();
    final days = NotificationDay.group(notifications, now);

    return AppListView(
      onRefresh: _loadNotifications,
      itemCount: days.length,
      itemSpacing: AppSpacing.lg,
      itemBuilder: (context, i) => NotificationDayGroup(
        day: days[i],
        now: now,
        onTap: _markAsRead,
      ),
    );
  }
}
