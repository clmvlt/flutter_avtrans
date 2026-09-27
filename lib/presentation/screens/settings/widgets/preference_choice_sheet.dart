import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/models.dart';
import '../../../widgets/app_list_row.dart';
import '../../../widgets/app_sheet.dart';

/// Icône d'un mode de réception.
IconData preferenceIcon(NotificationPreference p) => switch (p) {
      NotificationPreference.none => Icons.notifications_off_rounded,
      NotificationPreference.site => Icons.notifications_active_rounded,
      NotificationPreference.email => Icons.mail_rounded,
    };

/// Feuille de choix du mode de réception d'un type de notification : la
/// phrase qui dit de quoi il s'agit, puis les modes, le mode actuel coché.
abstract final class PreferenceChoiceSheet {
  /// Retourne le mode choisi, `null` si la feuille est fermée sans choix.
  static Future<NotificationPreference?> show(
    BuildContext context, {
    required String title,
    required String description,
    required NotificationPreference current,
  }) {
    return AppSheet.show<NotificationPreference>(
      context,
      title: title,
      builder: (ctx) => _Body(description: description, current: current),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.description, required this.current});

  final String description;
  final NotificationPreference current;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          description,
          style: textTheme.bodyMedium?.copyWith(color: colors.mutedForeground),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final p in NotificationPreference.values)
          Semantics(
            selected: p == current,
            child: AppListRow(
              icon: preferenceIcon(p),
              iconColor: p == current ? colors.primary : colors.mutedForeground,
              title: p.label,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.sm,
              ),
              trailing: p == current
                  ? Icon(Icons.check_rounded, color: colors.primary, size: 22)
                  : null,
              showChevron: false,
              onTap: () => Navigator.of(context).pop(p),
            ),
          ),
      ],
    );
  }
}
