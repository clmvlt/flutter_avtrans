import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../data/models/models.dart';
import '../../../widgets/app_list_row.dart';
import 'notification_visual.dart';

/// Une notification : boîte d'icône du type, titre (gras si non lue),
/// description, heure et point « non lue » à droite.
///
/// Seule une notification non lue est tapable : le tap la marque comme lue.
class NotificationRow extends StatelessWidget {
  const NotificationRow({
    super.key,
    required this.notification,
    required this.now,
    required this.onTap,
  });

  final AppNotification notification;
  final DateTime now;
  final VoidCallback onTap;

  /// « À l'instant », « Il y a 12 min » dans l'heure, sinon « 08:30 » (le
  /// jour est donné par l'en-tête du groupe).
  static String timeLabel(DateTime? date, DateTime now) {
    if (date == null) return '';
    final diff = now.difference(date.toLocal());
    if (!diff.isNegative && diff.inMinutes < 1) return 'À l\'instant';
    if (!diff.isNegative && diff.inMinutes < 60) {
      return 'Il y a ${diff.inMinutes} min';
    }
    return TimeFormat.hm(date);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final n = notification;
    final unread = !n.isRead;
    final (icon, accent) = notificationVisual(n.refType, colors);
    final time = timeLabel(n.createdAt, now);

    return AppListRow(
      icon: icon,
      iconColor: accent,
      title: n.title,
      titleStyle: textTheme.titleSmall?.copyWith(
        fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
      ),
      subtitle: n.description,
      showChevron: false,
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (time.isNotEmpty)
            Text(
              time,
              style: textTheme.bodySmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          if (unread) ...[
            const SizedBox(height: AppSpacing.xs),
            Semantics(
              label: 'Non lue',
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: colors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ],
      ),
      onTap: unread ? onTap : null,
    );
  }
}
