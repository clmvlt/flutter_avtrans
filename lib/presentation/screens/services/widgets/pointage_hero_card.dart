import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/time_format.dart';
import '../../../widgets/app_card.dart';
import '../pointage_controller.dart';
import 'day_ribbon.dart';
import 'live_timer.dart';
import 'pointage_layout.dart';
import 'pointage_status.dart';

/// Carte hero de la page Pointage : le seul point focal.
///
/// Ligne d'état (icône teintée + mot d'état 22 sp en `foreground` + sous-ligne
/// + point pulsant), « Travaillé aujourd'hui », chrono 52 sp tabulaire, ruban
/// de la journée. La carte reste sur `card` dans tous les états : l'état vit
/// dans l'icône, le mot et le ruban — jamais dans un fond teinté.
class PointageHeroCard extends StatelessWidget {
  const PointageHeroCard({super.key, required this.controller});

  final PointageController controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final c = controller;
    final moment = c.moment;
    final visual = PointageStatusVisual.of(moment, colors);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return AppCard(
      elevation: AppCardElevation.hero,
      radius: AppRadius.xl,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSwitcher(
            duration: reduceMotion ? Duration.zero : AppDuration.base,
            switchInCurve: Curves.easeOutCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.15),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.centerLeft,
              children: [...previous, if (current != null) current],
            ),
            child: _StatusLine(
              key: ValueKey(moment),
              controller: c,
              visual: visual,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Travaillé aujourd\'hui', style: textTheme.bodySmall),
          const SizedBox(height: AppSpacing.xs),
          LiveTimer(
            clock: c.clock,
            duration: () => c.workedToday,
            showSeconds: moment == PointageMoment.onDuty,
            color: moment == PointageMoment.notStarted
                ? colors.mutedForeground
                : colors.foreground,
            placeholder: moment == PointageMoment.offline ? '–:––' : null,
          ),
          AnimatedSize(
            duration: reduceMotion ? Duration.zero : AppDuration.base,
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: moment == PointageMoment.offline || c.segments.isEmpty
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.lg),
                    child: ValueListenableBuilder<DateTime>(
                      valueListenable: c.clock,
                      builder: (context, now, _) => DayRibbon(
                        segments: c.segments,
                        now: now,
                        isLive: c.hasActiveService,
                        liveAccent: visual.accent,
                        serviceCount: c.serviceCount,
                        breakCount: c.breakCount,
                        breakTotal: c.breakToday,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Icône dans sa boîte 44 · mot d'état + sous-ligne · point pulsant.
class _StatusLine extends StatelessWidget {
  const _StatusLine({
    super.key,
    required this.controller,
    required this.visual,
  });

  final PointageController controller;
  final PointageStatusVisual visual;

  String _subline(PointageController c, DateTime now) {
    final first = c.firstStartToday;
    switch (c.moment) {
      case PointageMoment.loading:
        return '';
      case PointageMoment.offline:
        return 'Impossible de joindre le serveur';
      case PointageMoment.notStarted:
        return 'Aucun pointage aujourd\'hui';
      case PointageMoment.onDuty:
        final since = first != null ? 'Depuis ${TimeFormat.hm(first)}' : '';
        return c.serviceCount > 1
            ? '$since · ${c.serviceCount}e service'
            : since;
      case PointageMoment.onBreak:
        final active = c.activeService;
        if (active == null) return 'En pause';
        return 'Pause depuis ${TimeFormat.hm(active.debut)} · '
            '${TimeFormat.durationShort(now.difference(active.debut))}';
      case PointageMoment.dayDone:
        final end = c.lastEndToday;
        if (first == null || end == null) return 'Service terminé';
        return '${TimeFormat.hmRange(first, end)} · '
            'amplitude ${TimeFormat.durationShort(c.amplitudeToday)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final c = controller;

    return ValueListenableBuilder<DateTime>(
      valueListenable: c.clock,
      builder: (context, now, _) {
        final subline = _subline(c, now);
        return Semantics(
          label: 'Statut : ${visual.label}. $subline',
          excludeSemantics: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: PointageLayout.iconBoxSize,
                height: PointageLayout.iconBoxSize,
                decoration: BoxDecoration(
                  color: visual.accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(visual.icon, size: 24, color: visual.accent),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        visual.label,
                        style: textTheme.headlineSmall,
                        maxLines: 1,
                      ),
                    ),
                    if (subline.isNotEmpty)
                      Text(
                        subline,
                        style: textTheme.bodyLarge
                            ?.copyWith(color: colors.mutedForeground),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (visual.isLive) ...[
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Center(child: PulseDot(color: visual.accent)),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
