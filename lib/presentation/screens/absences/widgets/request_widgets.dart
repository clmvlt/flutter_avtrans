import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/display_format.dart';
import '../../../widgets/widgets.dart';

// Petits blocs communs aux pages « demandes » de l'espace personnel
// (absences, acomptes, couchettes). Candidats à rejoindre le kit partagé.

/// Borne [date] dans `[first ; last]` (jours entiers). Évite l'assertion de
/// `showDatePicker` quand la date initiale sort des bornes.
DateTime clampPickerDate(DateTime date, DateTime first, DateTime last) {
  final d = DateUtils.dateOnly(date);
  final f = DateUtils.dateOnly(first);
  final l = DateUtils.dateOnly(last);
  if (d.isBefore(f)) return f;
  if (d.isAfter(l)) return l;
  return d;
}

/// Action « Filtres » de la barre de titre (`tune_rounded`) avec le nombre
/// de filtres actifs en pastille.
class FilterIconButton extends StatelessWidget {
  const FilterIconButton({
    super.key,
    required this.count,
    required this.onPressed,
  });

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: count == 0
          ? 'Filtres'
          : 'Filtres, ${DisplayFormat.plural(count, 'actif')}',
      onTap: onPressed,
      excludeSemantics: true,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AppIconButton(
            icon: Icons.tune_rounded,
            tooltip: 'Filtres',
            color: colors.foreground,
            onPressed: onPressed,
          ),
          if (count > 0)
            Positioned(
              top: 6,
              right: 4,
              child: IgnorePointer(
                child: Container(
                  constraints:
                      const BoxConstraints(minWidth: 18, minHeight: 18),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(color: colors.background, width: 2),
                  ),
                  child: Text(
                    '$count',
                    style: textTheme.labelSmall?.copyWith(
                      color: colors.primaryForeground,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                      height: 1.1,
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

/// Une option de [ChoiceChipsWrap].
@immutable
class ChoiceOption<T> {
  const ChoiceOption({
    required this.value,
    required this.label,
    this.icon,
    this.dotColor,
  });

  final T value;
  final String label;
  final IconData? icon;

  /// Pastille de couleur avant le libellé (couleur d'un type d'absence).
  final Color? dotColor;
}

/// Choix unique en pastilles qui passent à la ligne : toutes les options
/// restent visibles, un tap suffit. Pastille active pleine, les autres
/// enfoncées (même langage qu'`AppFilterChips`).
class ChoiceChipsWrap<T> extends StatelessWidget {
  const ChoiceChipsWrap({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.errorText,
  });

  final List<ChoiceOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final o in options)
              _ChoiceChip<T>(
                option: o,
                active: o.value == selected,
                onTap: () {
                  if (o.value != selected) onChanged(o.value);
                },
              ),
          ],
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: AppSpacing.xs),
            child: Text(
              errorText!,
              style: textTheme.bodySmall?.copyWith(
                color: colors.destructive,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}

class _ChoiceChip<T> extends StatelessWidget {
  const _ChoiceChip({
    required this.option,
    required this.active,
    required this.onTap,
  });

  final ChoiceOption<T> option;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final fg = active ? colors.primaryForeground : colors.foreground;

    Widget? lead;
    if (active) {
      lead = Icon(Icons.check_rounded, size: 16, color: fg);
    } else if (option.dotColor != null) {
      lead = Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: option.dotColor,
          shape: BoxShape.circle,
        ),
      );
    } else if (option.icon != null) {
      lead = Icon(option.icon, size: 16, color: colors.mutedForeground);
    }

    return Semantics(
      button: true,
      selected: active,
      label: option.label,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: active ? colors.primary : colors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.full),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (lead != null) ...[lead, const SizedBox(width: 8)],
                Text(
                  option.label,
                  style: textTheme.labelLarge?.copyWith(color: fg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Un filtre actif affiché en tête de liste.
@immutable
class ActiveFilter {
  const ActiveFilter({required this.label, required this.icon, this.onRemove});

  final String label;
  final IconData icon;

  /// Croix qui retire ce filtre seul (absente : filtre non retirable seul).
  final VoidCallback? onRemove;
}

/// Rangée défilante des filtres actifs, avec « Tout effacer » optionnel.
class ActiveFiltersRow extends StatelessWidget {
  const ActiveFiltersRow({super.key, required this.filters, this.onClearAll});

  final List<ActiveFilter> filters;
  final VoidCallback? onClearAll;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < filters.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            _ActiveFilterChip(filter: filters[i]),
          ],
          if (onClearAll != null) ...[
            const SizedBox(width: AppSpacing.xs),
            TextButton(
              onPressed: onClearAll,
              style: TextButton.styleFrom(
                foregroundColor: colors.primary,
                minimumSize: const Size(48, 40),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                textStyle: textTheme.labelLarge,
              ),
              child: const Text('Tout effacer'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActiveFilterChip extends StatelessWidget {
  const _ActiveFilterChip({required this.filter});

  final ActiveFilter filter;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final removable = filter.onRemove != null;

    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: removable ? 0 : AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(filter.icon, size: 16, color: colors.mutedForeground),
          const SizedBox(width: 6),
          Text(filter.label, style: textTheme.labelLarge),
          if (removable)
            SizedBox(
              width: 40,
              height: 40,
              child: IconButton(
                onPressed: filter.onRemove,
                tooltip: 'Retirer le filtre ${filter.label}',
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: colors.mutedForeground,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
