import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/time_format.dart';

/// Libellé d'une journée : « Aujourd'hui » ou « Mardi 12 mars ».
String ypsiumDayLabel(DateTime date) =>
    DateUtils.isSameDay(date, DateTime.now())
        ? 'Aujourd\'hui'
        : TimeFormat.dateLong(date);

/// Sélecteur de journée sous le titre : jour précédent, date (tap =
/// calendrier), jour suivant. Même piste enfoncée qu'`AppSegmented`.
class YpsiumDateBar extends StatelessWidget {
  const YpsiumDateBar({
    super.key,
    required this.date,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
  });

  final DateTime date;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final label = ypsiumDayLabel(date);

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppRadius.md + 4),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrevious,
            tooltip: 'Jour précédent',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: Icon(
              Icons.chevron_left_rounded,
              size: 24,
              color: colors.foreground,
            ),
          ),
          Expanded(
            child: Semantics(
              button: true,
              label: 'Journée affichée : $label. Choisir une autre date',
              excludeSemantics: true,
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: onPick,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: SizedBox(
                    height: 48,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 16,
                          color: colors.mutedForeground,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            label,
                            style: textTheme.labelLarge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onNext,
            tooltip: 'Jour suivant',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: Icon(
              Icons.chevron_right_rounded,
              size: 24,
              color: colors.foreground,
            ),
          ),
        ],
      ),
    );
  }
}
