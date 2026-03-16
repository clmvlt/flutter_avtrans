import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../widgets/widgets.dart';

/// Page des notifications
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<AppNotification> _allNotifications = [];
  List<AppNotification> _unreadNotifications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadNotifications();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          _unreadNotifications =
              notifications.where((n) => !n.isRead).toList();
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
      (failure) => _showError(failure.message),
      (updated) {
        setState(() {
          final allIndex = _allNotifications
              .indexWhere((n) => n.uuid == notification.uuid);
          if (allIndex != -1) _allNotifications[allIndex] = updated;
          _unreadNotifications.removeWhere((n) => n.uuid == notification.uuid);
        });
      },
    );
  }

  Future<void> _markAllAsRead() async {
    final result = await sl.notificationRepository.markAllAsRead();

    if (!mounted) return;

    result.fold(
      (failure) => _showError(failure.message),
      (_) {
        _showSuccess('Toutes les notifications marquées comme lues');
        _loadNotifications();
      },
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (_unreadNotifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.done_all, size: 22),
              onPressed: _markAllAsRead,
              tooltip: 'Tout marquer comme lu',
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: colors.primary,
          unselectedLabelColor: colors.mutedForeground,
          indicatorColor: colors.primary,
          tabs: [
            Tab(text: 'Toutes (${_allNotifications.length})'),
            Tab(text: 'Non lues (${_unreadNotifications.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const LoadingIndicator(message: 'Chargement...')
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: colors.destructive),
                      const SizedBox(height: AppSpacing.base),
                      Text(_error!,
                          style: TextStyle(color: colors.mutedForeground)),
                      const SizedBox(height: AppSpacing.base),
                      AppButton(
                        text: 'Réessayer',
                        onPressed: _loadNotifications,
                        backgroundColor: colors.primary,
                        foregroundColor: colors.primaryForeground,
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildNotificationList(_allNotifications, colors),
                    _buildNotificationList(_unreadNotifications, colors),
                  ],
                ),
    );
  }

  Widget _buildNotificationList(
      List<AppNotification> notifications, AppColors colors) {
    if (notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none,
                size: 64, color: colors.mutedForeground),
            const SizedBox(height: AppSpacing.base),
            Text(
              'Aucune notification',
              style: TextStyle(fontSize: 16, color: colors.mutedForeground),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      color: colors.primary,
      backgroundColor: colors.card,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.base),
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          return _buildNotificationCard(notifications[index], colors);
        },
      ),
    );
  }

  Widget _buildNotificationCard(
      AppNotification notification, AppColors colors) {
    final dateFormat = DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR');

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      color: notification.isRead ? colors.card : colors.primary.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.base),
        side: notification.isRead
            ? BorderSide.none
            : BorderSide(color: colors.primary.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.base),
        onTap: () => _markAsRead(notification),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _getRefTypeColor(notification.refType, colors)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.base),
                ),
                child: Icon(
                  _getRefTypeIcon(notification.refType),
                  color: _getRefTypeColor(notification.refType, colors),
                  size: 20,
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
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: notification.isRead
                                  ? FontWeight.w400
                                  : FontWeight.w600,
                              color: colors.foreground,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: colors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    if (notification.description != null &&
                        notification.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        notification.description!,
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.mutedForeground,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      notification.createdAt != null
                          ? dateFormat.format(notification.createdAt!)
                          : '',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getRefTypeIcon(String? refType) {
    switch (refType) {
      case 'acompte':
        return Icons.payments;
      case 'absence':
        return Icons.event_busy;
      case 'rapportVehicule':
        return Icons.description;
      case 'todo':
        return Icons.checklist;
      default:
        return Icons.notifications;
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
