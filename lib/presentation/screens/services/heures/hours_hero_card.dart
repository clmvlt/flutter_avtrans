import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/time_format.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_hero_card.dart';
import '../../../widgets/app_skeleton.dart';

/// Carte hero de Mes heures : la période choisie et son total travaillé
/// (pauses déduites) en grand. Pour la semaine, deux boutons pour passer à
/// la semaine précédente ou suivante ; un lien ramène à la période en cours.
class HoursHeroCard extends StatelessWidget {
  const HoursHeroCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.hours,
    required this.loading,
    this.error,
    this.onRetry,
    this.onPrevious,
    this.onNext,
    this.showNavigation = false,
    this.resetLabel,
    this.onReset,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Heures décimales de l'API (`null` = aucune donnée).
  final double? hours;

  /// La valeur de la période est en cours de chargement.
  final bool loading;

  /// Échec du chargement de la période : message + « Réessayer » à la place
  /// du total (la navigation reste disponible).
  final String? error;
  final VoidCallback? onRetry;

  /// Navigation semaine par semaine ; [onNext] `null` = déjà la semaine en
  /// cours.
  final bool showNavigation;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  /// « Revenir à cette semaine » : présent quand la période n'est pas celle
  /// en cours.
  final String? resetLabel;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final failed = !loading && error != null;
    final empty = !loading && !failed && (hours == null || hours! <= 0);

    return AppHeroCard(
      icon: icon,
      accent: colors.domainHours,
      title: title,
      subtitle: subtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedSwitcher(
            duration: AppDuration.base,
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.centerLeft,
              children: [...previous, if (current != null) current],
            ),
            child: failed
                ? _ErrorBlock(
                    key: const ValueKey('error'),
                    message: error!,
                    onRetry: onRetry,
                  )
                : loading
                ? Column(
                    key: const ValueKey('loading'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      AppSkeleton(width: 150, height: 13),
                      SizedBox(height: AppSpacing.sm),
                      AppSkeleton(width: 180, height: 52),
                    ],
                  )
                : Semantics(
                    key: ValueKey('value-$hours'),
                    label: 'Travaillé, pauses déduites : '
                        '${TimeFormat.hoursDecimal(hours)}',
                    excludeSemantics: true,
                    child: AppHeroFigure(
                      label: 'Travaillé, pauses déduites',
                      value: TimeFormat.hoursDecimal(hours),
                      muted: empty,
                    ),
                  ),
          ),
          if (empty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Aucune heure sur cette période',
              style: textTheme.bodySmall,
            ),
          ],
          if (showNavigation) ...[
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: _NavButton(
                    label: 'Précédente',
                    tooltip: 'Semaine précédente',
                    icon: Icons.chevron_left_rounded,
                    onPressed: onPrevious,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _NavButton(
                    label: 'Suivante',
                    tooltip: 'Semaine suivante',
                    icon: Icons.chevron_right_rounded,
                    iconAfter: true,
                    onPressed: onNext,
                  ),
                ),
              ],
            ),
          ],
          if (onReset != null && resetLabel != null) ...[
            SizedBox(height: showNavigation ? AppSpacing.sm : AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onReset,
                style: TextButton.styleFrom(
                  foregroundColor: colors.primary,
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  textStyle: textTheme.labelLarge,
                ),
                icon: const Icon(Icons.undo_rounded, size: 20),
                label: Text(resetLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Échec du chargement du total : icône + phrase, puis « Réessayer ».
class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.cloud_off_rounded, size: 20, color: colors.destructive),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total indisponible', style: textTheme.titleSmall),
                  Text(
                    message,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (onRetry != null) ...[
          const SizedBox(height: AppSpacing.md),
          AppButton(
            text: 'Réessayer',
            icon: Icons.refresh_rounded,
            onPressed: onRetry,
            variant: ButtonVariant.secondary,
          ),
        ],
      ],
    );
  }
}

/// Bouton « Précédente » / « Suivante » : surface enfoncée, 48 dp.
class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.label,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.iconAfter = false,
  });

  final String label;
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool iconAfter;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final enabled = onPressed != null;
    final fg = enabled ? colors.foreground : colors.disabled;

    final iconWidget = Icon(icon, size: 22, color: fg);
    final text = Flexible(
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: textTheme.labelLarge?.copyWith(color: fg),
      ),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: tooltip,
      excludeSemantics: true,
      child: Material(
        color: colors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: SizedBox(
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: iconAfter
                  ? [
                      text,
                      const SizedBox(width: AppSpacing.xs),
                      iconWidget,
                    ]
                  : [
                      iconWidget,
                      const SizedBox(width: AppSpacing.xs),
                      text,
                    ],
            ),
          ),
        ),
      ),
    );
  }
}
