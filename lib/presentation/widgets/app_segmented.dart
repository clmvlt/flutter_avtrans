import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Un segment d'[AppSegmented].
class AppSegment<T> {
  const AppSegment({
    required this.value,
    required this.label,
    this.icon,
    this.count,
  });

  final T value;
  final String label;
  final IconData? icon;

  /// Compteur discret après le libellé (« À prévoir 3 »).
  final int? count;
}

/// Sélecteur à segments : piste enfoncée, pastille `card` sous le segment
/// actif. Remplace les `TabBar` Material (2 à 4 choix courts).
class AppSegmented<T> extends StatelessWidget {
  const AppSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<AppSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppRadius.md + 4),
      ),
      child: Row(
        children: [
          for (final s in segments)
            Expanded(
              child: Semantics(
                button: true,
                selected: s.value == selected,
                label: s.count == null ? s.label : '${s.label}, ${s.count}',
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (s.value != selected) onChanged(s.value);
                  },
                  child: AnimatedContainer(
                    duration: AppDuration.fast,
                    curve: Curves.easeOut,
                    height: 40,
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: s.value == selected
                          ? (colors.isDarkMode
                              ? colors.surfaceElevated
                              : colors.card)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      boxShadow:
                          s.value == selected ? colors.controlShadow : const [],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (s.icon != null) ...[
                          Icon(
                            s.icon,
                            size: 18,
                            color: s.value == selected
                                ? colors.foreground
                                : colors.mutedForeground,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            s.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.labelLarge?.copyWith(
                              color: s.value == selected
                                  ? colors.foreground
                                  : colors.mutedForeground,
                            ),
                          ),
                        ),
                        if (s.count != null && s.count! > 0) ...[
                          const SizedBox(width: 6),
                          Text(
                            '${s.count}',
                            style: textTheme.labelMedium?.copyWith(
                              color: colors.mutedForeground,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Rangée de filtres « puces » défilante (dossiers, catégories, statuts) :
/// une puce active pleine, les autres enfoncées.
class AppFilterChips<T> extends StatelessWidget {
  const AppFilterChips({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.padding = EdgeInsets.zero,
  });

  final List<AppSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (var i = 0; i < segments.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            Builder(
              builder: (context) {
                final s = segments[i];
                final active = s.value == selected;
                final fg = active ? colors.primaryForeground : colors.foreground;
                return Material(
                  color: active ? colors.primary : colors.surfaceSunken,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    onTap: () {
                      if (!active) onChanged(s.value);
                    },
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 40),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (s.icon != null) ...[
                            Icon(s.icon, size: 16, color: fg),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            s.label,
                            style: textTheme.labelLarge?.copyWith(color: fg),
                          ),
                          if (s.count != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              '${s.count}',
                              style: textTheme.labelMedium?.copyWith(
                                color: active
                                    ? colors.primaryForeground
                                        .withValues(alpha: 0.8)
                                    : colors.mutedForeground,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
