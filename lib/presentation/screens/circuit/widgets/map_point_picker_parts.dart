import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_theme.dart';
import 'tour_map_parts.dart';

/// Repère central animé : une pastille-cible reste au sol (centre exact) tandis
/// que la « goutte » se soulève pendant le geste et retombe au relâcher.
class CenterPin extends StatelessWidget {
  const CenterPin({super.key, required this.lifted});

  final bool lifted;

  @override
  Widget build(BuildContext context) {
    final accent = MapPalette.accent;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: lifted ? 1 : 0),
      duration: const Duration(milliseconds: 170),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // Point-cible au sol (emplacement exact retenu).
            Transform.scale(
              scale: 1 + 0.18 * t,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.20),
                  border: Border.all(color: accent, width: 2),
                ),
              ),
            ),
            // « Goutte » : pointe sur le centre, se soulève pendant le geste.
            Transform.translate(
              offset: Offset(0, -23 - 12 * t),
              child: Icon(
                Icons.location_on,
                size: 46,
                color: accent,
                shadows: [
                  Shadow(
                    color: MapPalette.ink.withValues(alpha: 0.25 + 0.15 * t),
                    blurRadius: 8 + 6 * t,
                    offset: Offset(0, 3 + 4 * t),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Ligne d'état du dock du sélecteur de point : aide au geste, adresse (ou
/// point GPS) et statut vivant « positionné » / « déplacé de X ».
class PickerInfo extends StatelessWidget {
  const PickerInfo({
    super.key,
    required this.addressLabel,
    required this.center,
    required this.movedMeters,
    required this.moved,
    required this.onResetToAddress,
  });

  final String? addressLabel;
  final LatLng center;
  final double? movedMeters;
  final bool moved;
  final VoidCallback onResetToAddress;

  static String _fmt(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final isAddress = addressLabel != null;

    final Widget status;
    if (!isAddress) {
      status = _Line(
        icon: Icons.pin_drop_outlined,
        color: colors.mutedForeground,
        text: '${center.latitude.toStringAsFixed(6)}, '
            '${center.longitude.toStringAsFixed(6)}',
      );
    } else if (!moved) {
      status = _Line(
        icon: Icons.check_circle_rounded,
        color: colors.success,
        text: 'Positionné sur l\'adresse',
      );
    } else {
      status = _Line(
        icon: Icons.adjust_rounded,
        color: colors.primary,
        text: 'Déplacé de ${_fmt(movedMeters ?? 0)} de l\'adresse',
        trailing: TextButton(
          onPressed: onResetToAddress,
          style: TextButton.styleFrom(
            foregroundColor: colors.primary,
            minimumSize: const Size(48, 40),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            textStyle: textTheme.labelLarge,
          ),
          child: const Text('Revenir'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          isAddress ? addressLabel! : 'Nouveau point GPS',
          style: textTheme.titleMedium,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.xs),
        Semantics(liveRegion: true, child: status),
        const SizedBox(height: AppSpacing.xs),
        _Line(
          icon: Icons.touch_app_outlined,
          color: colors.mutedForeground,
          text: 'Glisse la carte pour ajuster le point',
          muted: true,
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.icon,
    required this.color,
    required this.text,
    this.trailing,
    this.muted = false,
  });

  final IconData icon;
  final Color color;
  final String text;
  final Widget? trailing;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 28),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: muted
                  ? textTheme.bodySmall
                  : textTheme.labelMedium?.copyWith(
                      color: colors.foreground,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
