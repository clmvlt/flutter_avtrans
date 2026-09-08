import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/time_format.dart';
import '../pointage_controller.dart';
import 'pointage_layout.dart';
import 'pointage_status.dart';

/// Ruban de la journée : une piste horizontale de la première prise de
/// service à maintenant (ou à la dernière fin). Les services sont pleins, les
/// pauses « creusent le trait » (trait plus fin dessiné par-dessus : la forme
/// porte le sens, pas seulement la couleur), les coupures laissent la piste
/// visible.
///
/// Le parent le reconstruit au tic de l'horloge ; le painter ne repeint
/// qu'une fois par minute (ou quand un segment change).
class DayRibbon extends StatelessWidget {
  const DayRibbon({
    super.key,
    required this.segments,
    required this.now,
    required this.isLive,
    required this.liveAccent,
    this.serviceCount = 0,
    this.breakCount = 0,
    this.breakTotal = Duration.zero,
  });

  final List<DaySegment> segments;
  final DateTime now;

  /// Un pointage est ouvert : la piste va jusqu'à « maintenant ».
  final bool isLive;

  /// Couleur du point pulsant à droite (accent du moment).
  final Color liveAccent;

  final int serviceCount;
  final int breakCount;
  final Duration breakTotal;

  DateTime get _start {
    DateTime? s;
    for (final seg in segments) {
      if (s == null || seg.start.isBefore(s)) s = seg.start;
    }
    return s ?? now;
  }

  DateTime get _end {
    var e = isLive ? now : _start;
    for (final seg in segments) {
      if (seg.end.isAfter(e)) e = seg.end;
    }
    return e;
  }

  String get _summary {
    final parts = <String>[
      if (serviceCount > 1) '$serviceCount services',
      if (breakCount == 0)
        'Aucune pause'
      else
        '$breakCount pause${breakCount > 1 ? 's' : ''} · '
            '${TimeFormat.durationShort(breakTotal)}',
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    if (segments.isEmpty) return const SizedBox.shrink();

    final start = _start;
    var end = _end;
    if (end.difference(start) < PointageLayout.ribbonMinSpan) {
      end = start.add(PointageLayout.ribbonMinSpan);
    }
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final labelStyle = textTheme.bodySmall?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Semantics(
      label: 'Journée de ${TimeFormat.hm(start)} à '
          '${isLive ? 'maintenant' : TimeFormat.hm(_end)}, $_summary',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RepaintBoundary(
            child: TweenAnimationBuilder<double>(
              // Le dernier segment « pousse » à chaque nouveau pointage.
              key: ValueKey<int>(segments.length),
              tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
              duration: reduceMotion ? Duration.zero : AppDuration.slow,
              curve: Curves.easeOutCubic,
              builder: (context, growth, _) => CustomPaint(
                size: const Size(double.infinity, PointageLayout.ribbonHeight),
                painter: _RibbonPainter(
                  segments: segments,
                  start: start,
                  end: end,
                  growth: growth,
                  trackColor:
                      colors.isDarkMode ? colors.border : colors.surfaceSunken,
                  serviceColor: colors.success,
                  pauseColor: colors.warning,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text(TimeFormat.hm(start), style: labelStyle),
              Expanded(
                child: Text(
                  _summary,
                  style: labelStyle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(TimeFormat.hm(isLive ? now : _end), style: labelStyle),
              if (isLive) ...[
                const SizedBox(width: AppSpacing.xs),
                PulseDot(color: liveAccent, size: 6),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _RibbonPainter extends CustomPainter {
  _RibbonPainter({
    required this.segments,
    required this.start,
    required this.end,
    required this.growth,
    required this.trackColor,
    required this.serviceColor,
    required this.pauseColor,
  });

  final List<DaySegment> segments;
  final DateTime start;
  final DateTime end;
  final double growth;
  final Color trackColor;
  final Color serviceColor;
  final Color pauseColor;

  DateTime get _endMinute =>
      DateTime(end.year, end.month, end.day, end.hour, end.minute);

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final radius = Radius.circular(h / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, radius),
      Paint()..color = trackColor,
    );

    final total = end.difference(start).inSeconds;
    if (total <= 0) return;

    double x(DateTime t) {
      final s = t.difference(start).inSeconds.clamp(0, total);
      return size.width * s / total;
    }

    // Le dernier segment (par ordre de début) grandit à son apparition.
    DaySegment? last;
    for (final seg in segments) {
      if (last == null || seg.start.isAfter(last.start)) last = seg;
    }

    void drawSpan(DaySegment seg, double barHeight, double minWidth, Color c) {
      final l = x(seg.start);
      var r = x(seg.end);
      if (identical(seg, last)) r = l + (r - l) * growth;
      if (r < l + minWidth) r = (l + minWidth).clamp(0, size.width);
      final top = (h - barHeight) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(l, top, r, top + barHeight),
          Radius.circular(barHeight / 2),
        ),
        Paint()..color = c,
      );
    }

    for (final seg in segments) {
      if (seg.isBreak) continue;
      drawSpan(seg, h, PointageLayout.ribbonHeight, serviceColor);
    }
    for (final seg in segments) {
      if (!seg.isBreak) continue;
      drawSpan(
        seg,
        PointageLayout.ribbonPauseHeight,
        PointageLayout.ribbonPauseHeight,
        pauseColor,
      );
    }
  }

  @override
  bool shouldRepaint(_RibbonPainter old) {
    if (old.growth != growth ||
        old.start != start ||
        old._endMinute != _endMinute ||
        old.trackColor != trackColor ||
        old.serviceColor != serviceColor ||
        old.pauseColor != pauseColor ||
        old.segments.length != segments.length) {
      return true;
    }
    for (var i = 0; i < segments.length; i++) {
      final a = segments[i];
      final b = old.segments[i];
      if (a.service.uuid != b.service.uuid ||
          a.start != b.start ||
          a.isActive != b.isActive ||
          (!a.isActive && a.end != b.end) ||
          (a.isActive && a.end.minute != b.end.minute)) {
        return true;
      }
    }
    return false;
  }
}
