import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../data/models/service_model.dart';
import '../pointage_controller.dart';
import 'pointage_layout.dart';
import 'pointage_status.dart';

/// Fil de la journée : une ligne par enregistrement (service ou pause), à
/// hauteur fixe, reliée par un rail vertical ; une ligne « Coupure » entre
/// deux services séparés. Seule la sous-ligne de la ligne active écoute
/// l'horloge.
class DayTimeline extends StatelessWidget {
  const DayTimeline({
    super.key,
    required this.segments,
    required this.clock,
    this.onTap,
  });

  final List<DaySegment> segments;
  final ValueListenable<DateTime> clock;
  final ValueChanged<Service>? onTap;

  /// Écart minimal entre deux services pour afficher une coupure.
  static const Duration minGap = Duration(minutes: 1);

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    DateTime? lastServiceEnd;

    for (final seg in segments) {
      if (!seg.isBreak && lastServiceEnd != null) {
        final gap = seg.start.difference(lastServiceEnd);
        if (gap > minGap) {
          rows.add(
            DayTimelineGap(
              key: ValueKey('gap-${seg.service.uuid}'),
              duration: gap,
            ),
          );
        }
      }
      rows.add(
        DayTimelineRow(
          key: ValueKey(seg.service.uuid),
          segment: seg,
          clock: clock,
          onTap: onTap == null ? null : () => onTap!(seg.service),
        ),
      );
      if (!seg.isBreak && !seg.isActive) lastServiceEnd = seg.end;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++)
          _RailScope(
            isFirst: i == 0,
            isLast: i == rows.length - 1,
            child: rows[i],
          ),
      ],
    );
  }
}

/// Transmet aux lignes leur position dans le fil (pour le rail).
class _RailScope extends InheritedWidget {
  const _RailScope({
    required this.isFirst,
    required this.isLast,
    required super.child,
  });

  final bool isFirst;
  final bool isLast;

  static _RailScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_RailScope>();

  @override
  bool updateShouldNotify(_RailScope old) =>
      old.isFirst != isFirst || old.isLast != isLast;
}

/// Une ligne du fil : heure · rail + point · titre + sous-ligne · durée.
class DayTimelineRow extends StatelessWidget {
  const DayTimelineRow({
    super.key,
    required this.segment,
    required this.clock,
    this.onTap,
  });

  final DaySegment segment;
  final ValueListenable<DateTime> clock;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final scope = _RailScope.of(context);
    final isBreak = segment.isBreak;
    final isActive = segment.isActive;
    final accent = isBreak ? colors.warning : colors.success;
    final title = isBreak ? 'Pause' : 'Service';

    final tabular = const [FontFeature.tabularFigures()];

    Widget subline(DateTime now) {
      final text = isActive
          ? 'depuis ${TimeFormat.hm(segment.start)} · '
                '${TimeFormat.durationShort(now.difference(segment.start))}'
          : TimeFormat.hmRange(segment.start, segment.end);
      return Text(
        text,
        style: textTheme.bodySmall?.copyWith(fontFeatures: tabular),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: isActive
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PulseDot(color: accent, size: 6),
                const SizedBox(width: 6),
                Text(
                  'En cours',
                  style: textTheme.labelMedium?.copyWith(
                    color: colors.foreground,
                  ),
                ),
              ],
            )
          : Text(
              TimeFormat.durationShort(segment.duration),
              style: textTheme.labelMedium?.copyWith(
                color: colors.foreground,
                fontFeatures: tabular,
              ),
            ),
    );

    final semanticsLabel = isActive
        ? '$title en cours depuis ${TimeFormat.hm(segment.start)}'
        : '$title de ${TimeFormat.hm(segment.start)} à '
              '${TimeFormat.hm(segment.end)}, '
              '${TimeFormat.durationShort(segment.duration)}';

    return Semantics(
      label: semanticsLabel,
      button: onTap != null,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: PointageLayout.rowMinHeight,
            ),
            // IntrinsicHeight : le rail s'étire sur toute la hauteur de la
            // ligne (quelques lignes par jour, coût négligeable).
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: PointageLayout.timeColumnWidth,
                    child: Center(
                      child: Text(
                        TimeFormat.hm(segment.start),
                        style: textTheme.labelLarge?.copyWith(
                          fontFeatures: tabular,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: PointageLayout.railWidth,
                    child: CustomPaint(
                      painter: _RailPainter(
                        color: colors.border,
                        drawTop: !(scope?.isFirst ?? false),
                        drawBottom: !(scope?.isLast ?? false),
                        dashed: false,
                      ),
                      child: Center(
                        child: isActive
                            ? PulseDot(
                                color: accent,
                                size: PointageLayout.dotSize,
                              )
                            : Container(
                                width: PointageLayout.dotSize,
                                height: PointageLayout.dotSize,
                                decoration: BoxDecoration(
                                  color: accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: textTheme.titleMedium),
                          const SizedBox(height: 1),
                          if (isActive)
                            ValueListenableBuilder<DateTime>(
                              valueListenable: clock,
                              builder: (_, now, __) => subline(now),
                            )
                          else
                            subline(segment.end),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Center(child: pill),
                  const SizedBox(width: AppSpacing.xs),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ligne « Coupure · 1h05 » entre deux services.
class DayTimelineGap extends StatelessWidget {
  const DayTimelineGap({super.key, required this.duration});

  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final scope = _RailScope.of(context);

    return Semantics(
      label: 'Coupure de ${TimeFormat.durationShort(duration)}',
      excludeSemantics: true,
      child: SizedBox(
        height: PointageLayout.gapRowHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(width: PointageLayout.timeColumnWidth),
            SizedBox(
              width: PointageLayout.railWidth,
              child: CustomPaint(
                painter: _RailPainter(
                  color: colors.border,
                  drawTop: !(scope?.isFirst ?? false),
                  drawBottom: !(scope?.isLast ?? false),
                  dashed: true,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Coupure · ${TimeFormat.durationShort(duration)}',
                  style: textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rail vertical (2 dp) : continu, ou pointillé 2/4 pour une coupure ; laisse
/// la place au point central sauf sur les lignes de coupure.
class _RailPainter extends CustomPainter {
  const _RailPainter({
    required this.color,
    required this.drawTop,
    required this.drawBottom,
    required this.dashed,
  });

  final Color color;
  final bool drawTop;
  final bool drawBottom;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final cx = size.width / 2;

    if (dashed) {
      var y = 2.0;
      while (y < size.height - 2) {
        canvas.drawLine(Offset(cx, y), Offset(cx, y + 2), paint);
        y += 6;
      }
      return;
    }

    final cy = size.height / 2;
    const gap = PointageLayout.dotSize / 2 + 4;
    if (drawTop) canvas.drawLine(Offset(cx, 0), Offset(cx, cy - gap), paint);
    if (drawBottom) {
      canvas.drawLine(Offset(cx, cy + gap), Offset(cx, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_RailPainter old) =>
      old.color != color ||
      old.drawTop != drawTop ||
      old.drawBottom != drawBottom ||
      old.dashed != dashed;
}
