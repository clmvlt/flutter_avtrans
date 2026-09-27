import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/display_format.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../data/models/models.dart';
import '../../../widgets/widgets.dart';

/// Couleur d'une catégorie (hexadécimal `#RRGGBB` venu de l'API), ou `null`
/// si absente ou illisible.
Color? parseTodoCategoryColor(String? hexColor) {
  if (hexColor == null || hexColor.isEmpty) return null;
  final value = int.tryParse('FF${hexColor.replaceAll('#', '')}', radix: 16);
  return value == null ? null : Color(value);
}

/// Carte d'une tâche : case à cocher (48 dp) · titre, description, catégorie
/// et date de création · suppression. Un appui long propose aussi de
/// supprimer.
class TodoCard extends StatelessWidget {
  const TodoCard({
    super.key,
    required this.todo,
    required this.busy,
    required this.onToggle,
    required this.onDelete,
  });

  final Todo todo;

  /// Le basculement est en cours : la case affiche un indicateur.
  final bool busy;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final done = todo.isDone;
    final category = todo.category;
    final createdAt = todo.createdAt;
    final description = todo.description;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xs),
      onLongPress: onDelete,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TodoCheck(done: done, busy: busy, onTap: onToggle),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    todo.title,
                    style: textTheme.titleSmall?.copyWith(
                      color: done ? colors.mutedForeground : null,
                      decoration: done ? TextDecoration.lineThrough : null,
                      decorationColor: colors.mutedForeground,
                    ),
                  ),
                  if (description != null && description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (category != null || createdAt != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (category != null)
                          AppStatusChip(
                            label: category.name,
                            color: parseTodoCategoryColor(category.color) ??
                                colors.mutedForeground,
                            icon: Icons.label_rounded,
                          ),
                        if (createdAt != null)
                          Text(
                            '${DisplayFormat.dateSmart(createdAt)} à '
                            '${TimeFormat.hm(createdAt)}',
                            style: textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          AppIconButton(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Supprimer la tâche',
            size: 20,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

/// Case à cocher de 48 dp : vide et bordée à faire, pleine et verte une fois
/// faite, indicateur pendant l'appel.
class _TodoCheck extends StatelessWidget {
  const _TodoCheck({
    required this.done,
    required this.busy,
    required this.onTap,
  });

  final bool done;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      checked: done,
      label: done ? 'Tâche faite. Marquer à faire' : 'Marquer comme faite',
      excludeSemantics: true,
      child: InkResponse(
        onTap: busy ? null : onTap,
        radius: 24,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: busy
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.primary,
                    ),
                  )
                : AnimatedContainer(
                    duration: AppDuration.fast,
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: done ? colors.success : null,
                      border: Border.all(
                        color: done
                            ? colors.success
                            : colors.mutedForeground.withValues(alpha: 0.6),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.sm - 2),
                    ),
                    child: done
                        ? Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: colors.successForeground,
                          )
                        : null,
                  ),
          ),
        ),
      ),
    );
  }
}
