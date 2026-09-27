import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../widgets/app_list_row.dart';
import '../../../widgets/app_segmented.dart';
import '../../../widgets/app_sheet.dart';
import 'hours_period.dart';

/// Feuilles de choix d'une semaine, d'un mois ou d'une année. Un tap sur un
/// choix l'applique et ferme la feuille.
abstract final class HoursPickers {
  /// Première année proposée (comme l'écran d'origine).
  static const int firstYear = 2020;

  /// Années de [firstYear] à l'année en cours, la plus récente d'abord.
  static List<int> years() {
    final currentYear = DateTime.now().year;
    return List.generate(currentYear - firstYear + 1, (i) => firstYear + i)
        .reversed
        .toList();
  }

  /// Semaine 1 à 53 de [year] ; retourne le numéro choisi.
  static Future<int?> week(
    BuildContext context, {
    required int year,
    required int initialWeek,
    required int currentWeek,
  }) {
    return AppSheet.show<int>(
      context,
      title: 'Choisir une semaine',
      builder: (ctx) => _WeekGrid(
        year: year,
        selected: initialWeek,
        current: currentWeek,
      ),
    );
  }

  /// Mois et année ; retourne `(mois, année)`.
  static Future<(int, int)?> month(
    BuildContext context, {
    required int initialMonth,
    required int initialYear,
  }) {
    return AppSheet.show<(int, int)>(
      context,
      title: 'Choisir un mois',
      builder: (ctx) => _MonthPicker(
        initialMonth: initialMonth,
        initialYear: initialYear,
      ),
    );
  }

  /// Année ; retourne l'année choisie.
  static Future<int?> year(BuildContext context, {required int initialYear}) {
    return AppSheet.show<int>(
      context,
      title: 'Choisir une année',
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        0,
        AppSpacing.sm,
        AppSpacing.lg,
      ),
      builder: (ctx) {
        final colors = ctx.colors;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final y in years())
              AppListRow(
                title: '$y',
                icon: Icons.event_note_rounded,
                iconColor:
                    y == initialYear ? colors.primary : colors.mutedForeground,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                trailing: y == initialYear
                    ? Icon(Icons.check_rounded, color: colors.primary, size: 22)
                    : null,
                showChevron: false,
                onTap: () => Navigator.of(ctx).pop(y),
              ),
          ],
        );
      },
    );
  }
}

/// Grille des 53 semaines : numéro et date du lundi, semaine choisie en
/// pastille pleine, semaine en cours cerclée. S'ouvre sur la semaine choisie.
class _WeekGrid extends StatefulWidget {
  const _WeekGrid({
    required this.year,
    required this.selected,
    required this.current,
  });

  final int year;
  final int selected;
  final int current;

  @override
  State<_WeekGrid> createState() => _WeekGridState();
}

class _WeekGridState extends State<_WeekGrid> {
  final _selectedKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _selectedKey.currentContext;
      if (ctx == null || !mounted) return;
      Scrollable.ensureVisible(ctx, alignment: 0.4);
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final mondayFormat = DateFormat('d MMM', 'fr_FR');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Semaines de ${widget.year}', style: textTheme.bodySmall),
        const SizedBox(height: AppSpacing.md),
        GridView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisExtent: 56,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
          ),
          itemCount: 53,
          itemBuilder: (context, index) {
            final week = index + 1;
            final (monday, _) = HoursWeeks.weekRange(week, widget.year);
            return _ChoiceCell(
              key: week == widget.selected ? _selectedKey : null,
              label: 'S$week',
              detail: mondayFormat.format(monday),
              semanticsLabel: 'Semaine $week, '
                  '${HoursWeeks.formatRange(week, widget.year)}',
              selected: week == widget.selected,
              highlighted: week == widget.current,
              onTap: () => Navigator.of(context).pop(week),
            );
          },
        ),
      ],
    );
  }
}

/// Année en puces, puis les douze mois : un tap sur un mois valide.
class _MonthPicker extends StatefulWidget {
  const _MonthPicker({required this.initialMonth, required this.initialYear});

  final int initialMonth;
  final int initialYear;

  @override
  State<_MonthPicker> createState() => _MonthPickerState();
}

class _MonthPickerState extends State<_MonthPicker> {
  static const _monthNames = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
  ];

  late int _year = widget.initialYear;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Année', style: textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        AppFilterChips<int>(
          segments: [
            for (final y in HoursPickers.years())
              AppSegment(value: y, label: '$y'),
          ],
          selected: _year,
          onChanged: (y) => setState(() => _year = y),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Mois', style: textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        GridView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisExtent: 48,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
          ),
          itemCount: 12,
          itemBuilder: (context, index) {
            final month = index + 1;
            return _ChoiceCell(
              label: _monthNames[index],
              semanticsLabel: '${_monthNames[index]} $_year',
              selected:
                  month == widget.initialMonth && _year == widget.initialYear,
              highlighted: month == now.month && _year == now.year,
              onTap: () => Navigator.of(context).pop((month, _year)),
            );
          },
        ),
      ],
    );
  }
}

/// Case de choix : enfoncée, pleine quand choisie, cerclée pour « en cours ».
class _ChoiceCell extends StatelessWidget {
  const _ChoiceCell({
    super.key,
    required this.label,
    this.detail,
    required this.semanticsLabel,
    required this.selected,
    required this.highlighted,
    required this.onTap,
  });

  final String label;
  final String? detail;
  final String semanticsLabel;
  final bool selected;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final fg = selected ? colors.primaryForeground : colors.foreground;

    return Semantics(
      button: true,
      selected: selected,
      label: semanticsLabel,
      excludeSemantics: true,
      child: Material(
        color: selected ? colors.primary : colors.surfaceSunken,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: highlighted && !selected
              ? BorderSide(color: colors.primary, width: 1.5)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelLarge?.copyWith(color: fg),
              ),
              if (detail != null)
                Text(
                  detail!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall?.copyWith(
                    color: selected
                        ? colors.primaryForeground
                        : colors.mutedForeground,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
