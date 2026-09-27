import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/display_format.dart';
import '../../../../data/models/models.dart';
import '../../../widgets/widgets.dart';

/// Filtre de statut de la liste (paramètre `isDone` de la recherche).
enum TodoStatusFilter {
  all(null, 'Toutes'),
  open(false, 'À faire'),
  done(true, 'Terminées');

  const TodoStatusFilter(this.isDone, this.label);

  final bool? isDone;
  final String label;
}

/// Carte hero de la page Tâches : le nombre de tâches à faire (dans la
/// catégorie choisie, le cas échéant).
class TodosHero extends StatelessWidget {
  const TodosHero({super.key, required this.openCount, this.category});

  /// `null` tant que le décompte n'est pas connu (ou s'il a échoué).
  final int? openCount;
  final TodoCategory? category;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final count = openCount;
    final scope = category == null
        ? 'Toutes catégories confondues'
        : 'Catégorie « ${category!.name} »';

    if (count == null) {
      return AppHeroCard(
        icon: Icons.checklist_rounded,
        accent: colors.domainAbsence,
        title: 'Tâches de l\'atelier',
        subtitle: 'Coche une tâche dès qu\'elle est faite',
      );
    }
    if (count == 0) {
      return AppHeroCard(
        icon: Icons.task_alt_rounded,
        accent: colors.success,
        title: 'Tout est fait',
        subtitle: category == null
            ? 'Aucune tâche à faire'
            : 'Aucune tâche à faire · ${category!.name}',
      );
    }
    return AppHeroCard(
      icon: Icons.checklist_rounded,
      accent: colors.domainAbsence,
      title: DisplayFormat.plural(count, 'tâche à faire', 'tâches à faire'),
      subtitle: scope,
    );
  }
}

/// Filtres de la liste : statut (segments) puis catégories (puces).
class TodosFilters extends StatelessWidget {
  const TodosFilters({
    super.key,
    required this.status,
    required this.onStatusChanged,
    required this.categories,
    required this.categoryUuid,
    required this.onCategoryChanged,
  });

  final TodoStatusFilter status;
  final ValueChanged<TodoStatusFilter> onStatusChanged;
  final List<TodoCategory> categories;
  final String? categoryUuid;
  final ValueChanged<String?> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSegmented<TodoStatusFilter>(
          segments: [
            for (final s in TodoStatusFilter.values)
              AppSegment(value: s, label: s.label),
          ],
          selected: status,
          onChanged: onStatusChanged,
        ),
        if (categories.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          AppFilterChips<String?>(
            segments: [
              const AppSegment<String?>(
                value: null,
                label: 'Toutes catégories',
              ),
              for (final category in categories)
                AppSegment<String?>(
                  value: category.uuid,
                  label: category.name,
                ),
            ],
            selected: categoryUuid,
            onChanged: onCategoryChanged,
          ),
        ],
      ],
    );
  }
}

/// Squelette du premier chargement : hero, filtres, lignes.
class TodosSkeleton extends StatelessWidget {
  const TodosSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppHeroSkeleton(showFigure: false),
        SizedBox(height: AppSpacing.lg),
        AppSkeleton(height: 48, borderRadius: AppRadius.md + 4),
        SizedBox(height: AppSpacing.md),
        Row(
          children: [
            AppSkeleton(width: 120, height: 40, borderRadius: AppRadius.full),
            SizedBox(width: AppSpacing.sm),
            AppSkeleton(width: 90, height: 40, borderRadius: AppRadius.full),
          ],
        ),
        SizedBox(height: AppSpacing.lg),
        AppListSkeleton(rows: 4),
      ],
    );
  }
}
