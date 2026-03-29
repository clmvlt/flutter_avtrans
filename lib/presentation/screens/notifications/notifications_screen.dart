import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../widgets/widgets.dart';

/// Page des notifications — tabs, cartes accessibles
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
        _showSuccess('Toutes les notifications marquees comme lues');
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
    final textTheme = Theme.of(context).textTheme;

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
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: colors.primary,
          unselectedLabelColor: colors.mutedForeground,
          indicatorColor: colors.primary,
          labelStyle: textTheme.labelLarge,
          unselectedLabelStyle: textTheme.bodyMedium,
          tabs: [
            Tab(text: 'Toutes (${_allNotifications.length})'),
            Tab(text: 'Non lues (${_unreadNotifications.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const LoadingIndicator(message: 'Chargement...')
          : _error != null
              ? AppEmptyState(
                  icon: Icons.error_outline,
                  title: 'Erreur de chargement',
                  subtitle: _error,
                  actionText: 'Reessayer',
                  onAction: _loadNotifications,
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildNotificationList(_allNotifications, colors, textTheme),
                    _buildNotificationList(_unreadNotifications, colors, textTheme),
                  ],
                ),
    );
  }

  Widget _buildNotificationList(
      List<AppNotification> notifications, AppColors colors, TextTheme textTheme) {
    if (notifications.isEmpty) {
      return const AppEmptyState(
        icon: Icons.notifications_none,
        title: 'Aucune notification',
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
          return _buildNotificationCard(notifications[index], colors, textTheme);
        },
      ),
    );
  }

  Widget _buildNotificationCard(
      AppNotification notification, AppColors colors, TextTheme textTheme) {
    final dateFormat = DateFormat('dd/MM/yyyy a HH:mm', 'fr_FR');
    final refColor = _getRefTypeColor(notification.refType, colors);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      color: notification.isRead ? colors.card : colors.primary.withValues(alpha: 0.04),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: notification.isRead
            ? BorderSide(color: colors.border)
            : BorderSide(color: colors.primary.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => _markAsRead(notification),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icone type — avec couleur semantique + icone (pas couleur seule)
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: refColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
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
                              fontWeight: notification.isRead
                                  ? FontWeight.w400
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 10,
                            height: 10,
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
                        style: textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      notification.createdAt != null
                          ? dateFormat.format(notification.createdAt!)
                          : '',
                      style: textTheme.labelSmall,
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
