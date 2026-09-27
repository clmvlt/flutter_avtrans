import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/display_format.dart';
import '../../../../data/models/models.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_list_row.dart';
import 'notification_row.dart';

/// Notifications d'un même jour.
class NotificationDay {
  const NotificationDay({required this.label, required this.items});

  /// « Aujourd'hui », « Hier », « 12 mars »… ou « Sans date ».
  final String label;
  final List<AppNotification> items;

  int get unreadCount => items.where((n) => !n.isRead).length;

  /// Regroupe par jour local en gardant l'ordre reçu de l'API (le plus
  /// récent d'abord).
  static List<NotificationDay> group(
    List<AppNotification> notifications,
    DateTime now,
  ) {
    final byDay = <DateTime?, List<AppNotification>>{};
    for (final n in notifications) {
      final d = n.createdAt?.toLocal();
      final key = d == null ? null : DateTime(d.year, d.month, d.day);
      byDay.putIfAbsent(key, () => []).add(n);
    }
    return [
      for (final entry in byDay.entries)
        NotificationDay(
          label: entry.key == null
              ? 'Sans date'
              : DisplayFormat.relativeDay(entry.key!, now: now),
          items: entry.value,
        ),
    ];
  }
}

/// En-tête du jour (avec le nombre de non lues) puis une carte de lignes.
class NotificationDayGroup extends StatelessWidget {
  const NotificationDayGroup({
    super.key,
    required this.day,
    required this.now,
    required this.onTap,
  });

  final NotificationDay day;
  final DateTime now;
  final ValueChanged<AppNotification> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final unread = day.unreadCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(
          title: day.label,
          summary: unread > 0 ? DisplayFormat.plural(unread, 'non lue') : null,
        ),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            children: [
              for (var i = 0; i < day.items.length; i++) ...[
                if (i > 0)
                  // Aligné sur le texte : marge 16 + boîte d'icône 40 + 12.
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: colors.border,
                    indent: 68,
                  ),
                NotificationRow(
                  key: ValueKey(day.items[i].uuid),
                  notification: day.items[i],
                  now: now,
                  onTap: () => onTap(day.items[i]),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
