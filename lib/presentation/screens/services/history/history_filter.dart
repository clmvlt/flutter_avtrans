import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../widgets/app_list_row.dart';
import '../../../widgets/app_sheet.dart';

/// Filtre par type de pointage de l'historique.
enum HistoryTypeFilter {
  all('Tout', 'Services et pauses', Icons.list_rounded),
  services('Services', 'Temps de travail seulement', Icons.work_rounded),
  breaks('Pauses', 'Pauses seulement', Icons.coffee_rounded);

  const HistoryTypeFilter(this.label, this.description, this.icon);

  final String label;
  final String description;
  final IconData icon;

  /// Valeur attendue de `Service.isBreak`, `null` = pas de filtre.
  bool? get isBreak => switch (this) {
        HistoryTypeFilter.all => null,
        HistoryTypeFilter.services => false,
        HistoryTypeFilter.breaks => true,
      };

  Color accent(AppColors colors) => switch (this) {
        HistoryTypeFilter.all => colors.primary,
        HistoryTypeFilter.services => colors.success,
        HistoryTypeFilter.breaks => colors.warning,
      };
}

/// Feuille « Filtrer » : trois choix, un tap applique et ferme.
abstract final class HistoryFilterSheet {
  /// Retourne le filtre choisi, `null` si la feuille est fermée sans choix.
  static Future<HistoryTypeFilter?> show(
    BuildContext context, {
    required HistoryTypeFilter current,
  }) {
    return AppSheet.show<HistoryTypeFilter>(
      context,
      title: 'Filtrer',
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
            for (final f in HistoryTypeFilter.values)
              AppListRow(
                title: f.label,
                subtitle: f.description,
                icon: f.icon,
                iconColor: f.accent(colors),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                trailing: f == current
                    ? Icon(Icons.check_rounded, color: colors.primary, size: 22)
                    : null,
                showChevron: false,
                onTap: () => Navigator.of(ctx).pop(f),
              ),
          ],
        );
      },
    );
  }
}

/// Action « Filtrer » de la barre de titre, avec un compteur quand un filtre
/// est actif.
class HistoryFilterButton extends StatelessWidget {
  const HistoryFilterButton({
    super.key,
    required this.active,
    required this.onPressed,
  });

  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return IconButton(
      tooltip: active ? 'Filtrer (1 filtre actif)' : 'Filtrer',
      onPressed: onPressed,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      icon: Badge(
        isLabelVisible: active,
        backgroundColor: colors.primary,
        textColor: colors.primaryForeground,
        label: const Text('1'),
        child: Icon(Icons.tune_rounded, size: 22, color: colors.foreground),
      ),
    );
  }
}
