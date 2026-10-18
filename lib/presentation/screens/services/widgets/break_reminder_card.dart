import 'package:flutter/material.dart';

import '../../../../core/services/break_reminder_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/time_format.dart';
import '../../../widgets/app_callout_card.dart';
import '../../../widgets/app_list_row.dart';

/// Carte « Pause conseillée » : 6 h de travail sans pause. N'apparaît que
/// dans ce cas ; la ligne met le service en pause, comme le bouton du dock.
class BreakReminderCard extends StatelessWidget {
  const BreakReminderCard({super.key, required this.onPause});

  /// `null` pendant qu'une action de pointage est en vol.
  final VoidCallback? onPause;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final threshold = TimeFormat.durationShort(BreakReminderService.threshold);

    return AppCalloutCard(
      title: 'Pause conseillée',
      tone: AppCalloutTone.warning,
      icon: Icons.coffee_rounded,
      children: [
        AppListRow(
          icon: Icons.coffee_rounded,
          iconColor: colors.warning,
          title: 'Prends une pause',
          subtitle: 'Ça fait $threshold que tu travailles sans pause',
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          showChevron: true,
          onTap: onPause,
        ),
      ],
    );
  }
}
