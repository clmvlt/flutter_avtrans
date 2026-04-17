import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/service_model.dart';

/// Tuile d'affichage d'un pointage (service ou pause) pour la journée.
///
/// Utilisée dans l'écran Services (liste du jour) et l'écran Historique
/// (liste du jour sélectionné). Mise en page compacte, statut lisible,
/// durée en `Xh YY` et indicateur animé « En cours » pour les pointages
/// non clôturés.
class ServiceDayTile extends StatelessWidget {
  final Service service;

  const ServiceDayTile({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    final isBreak = service.isBreak;
    final isActive = service.isActive;
    final accent = isBreak ? colors.warning : colors.success;
    final icon = isBreak ? Icons.coffee_outlined : Icons.work_outline;
    final label = isBreak ? 'Pause' : 'Service';

    final startLocal = service.debut.toLocal();
    final endLocal = service.fin?.toLocal();

    final Duration? duration = isActive
        ? DateTime.now().difference(startLocal)
        : endLocal?.difference(startLocal);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isActive ? accent : colors.border,
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: textTheme.titleSmall?.copyWith(
                          color: colors.foreground,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    if (isActive)
                      _LivePill(color: accent)
                    else if (duration != null)
                      _DurationPill(
                        text: _formatDuration(duration),
                        color: accent,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 14,
                      color: colors.mutedForeground,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _buildTimeLine(
                          startLocal: startLocal,
                          endLocal: endLocal,
                          isActive: isActive,
                          elapsed: duration,
                        ),
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.mutedForeground,
                          fontFeatures: const [
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _buildTimeLine({
    required DateTime startLocal,
    required DateTime? endLocal,
    required bool isActive,
    required Duration? elapsed,
  }) {
    final start = _formatHm(startLocal);
    if (isActive) {
      if (elapsed != null) {
        return 'Depuis $start · ${_formatDuration(elapsed)}';
      }
      return 'Depuis $start';
    }
    if (endLocal != null) {
      return '$start → ${_formatHm(endLocal)}';
    }
    return start;
  }

  static String _formatHm(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h == 0) return '${m}min';
    if (m == 0) return '${h}h';
    return '${h}h${m.toString().padLeft(2, '0')}';
  }
}

class _DurationPill extends StatelessWidget {
  final String text;
  final Color color;
  const _DurationPill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _LivePill extends StatefulWidget {
  final Color color;
  const _LivePill({required this.color});

  @override
  State<_LivePill> createState() => _LivePillState();
}

class _LivePillState extends State<_LivePill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: widget.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: Tween<double>(begin: 0.35, end: 1.0).animate(_controller),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'En cours',
            style: TextStyle(
              color: widget.color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
