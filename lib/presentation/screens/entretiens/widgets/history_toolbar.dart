import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/display_format.dart';
import '../../../../data/models/entretien_model.dart';

/// En-tête de l'historique : compteur à gauche, bouton « Filtrer » (avec le
/// nombre de filtres actifs) à droite, et le tri en rappel discret.
class HistoryToolbar extends StatelessWidget {
  const HistoryToolbar({
    super.key,
    required this.title,
    required this.total,
    required this.loaded,
    required this.query,
    required this.onFilters,
    this.extraFilterCount = 0,
  });

  final String title;
  final int total;

  /// Le compteur n'est affiché qu'une fois la première page reçue.
  final bool loaded;
  final EntretienHistoryQuery query;
  final VoidCallback onFilters;

  /// Filtres comptés en plus de ceux de la requête (ex. véhicule choisi).
  final int extraFilterCount;

  String get _sortLabel {
    final (desc, asc) = switch (query.sort) {
      EntretienSort.date => ('récents d\'abord', 'anciens d\'abord'),
      EntretienSort.kilometrage => ('km élevé d\'abord', 'km bas d\'abord'),
      EntretienSort.cout => ('plus chers d\'abord', 'moins chers d\'abord'),
    };
    return query.ascending ? asc : desc;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final count = query.activeFilterCount + extraFilterCount;

    final summary = [
      if (loaded) DisplayFormat.plural(total, 'entretien'),
      _sortLabel,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xs,
        bottom: AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(title, style: textTheme.titleMedium),
                ),
                Text(summary, style: textTheme.bodySmall),
              ],
            ),
          ),
          Material(
            color: count > 0 ? colors.primarySoft : colors.surfaceSunken,
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: InkWell(
              onTap: onFilters,
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: Container(
                constraints: const BoxConstraints(minHeight: 40),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 18,
                      color: count > 0 ? colors.primary : colors.foreground,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      count > 0 ? 'Filtres · $count' : 'Filtrer',
                      style: textTheme.labelLarge?.copyWith(
                        color: count > 0 ? colors.primary : colors.foreground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
