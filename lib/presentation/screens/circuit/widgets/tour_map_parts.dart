import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/tour_stop.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_card.dart';
import '../circuit_format.dart';
import 'tour_widgets.dart';

/// Palette des éléments dessinés SUR la carte (repères, tracé, viseur).
///
/// Le style Mapbox `streets-v12` est toujours clair, même en thème sombre :
/// ces éléments suivent donc la palette claire pour garder leur contraste.
abstract final class MapPalette {
  static const AppColors _c = AppColors.light;

  static Color get accent => _c.primary;
  static Color get onAccent => _c.primaryForeground;
  static Color get ink => _c.foreground;
  static Color get halo => _c.card;
  static List<BoxShadow> get shadow => _c.cardShadow;
}

/// Carte flottante de l'arrêt touché sur la carte : rang, adresse, arrivée
/// estimée, et le bouton de navigation (56 dp).
class SelectedStopCard extends StatelessWidget {
  const SelectedStopCard({
    super.key,
    required this.stop,
    required this.number,
    required this.onNavigate,
    required this.onClose,
  });

  final TourStop stop;

  /// Rang sur la carte ; `null` si introuvable.
  final int? number;
  final VoidCallback onNavigate;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final arrival = stop.arrivalTime == null
        ? null
        : 'Arrivée estimée ${formatTime(stop.arrivalTime)}'
            '${stop.cumulativeDistanceMeters != null ? ' · ${formatDistance(stop.cumulativeDistanceMeters)}' : ''}';

    return AppCard(
      elevation: AppCardElevation.hero,
      radius: AppRadius.xl,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.base,
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.base,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              StopNumberBox(number: number),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      stop.label,
                      style: textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (arrival != null)
                      Text(arrival, style: textTheme.bodySmall),
                  ],
                ),
              ),
              AppIconButton(
                icon: Icons.close_rounded,
                tooltip: 'Fermer',
                color: colors.mutedForeground,
                onPressed: onClose,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: AppButton(
              text: 'Naviguer ici',
              icon: Icons.navigation_rounded,
              size: ButtonSize.lg,
              onPressed: onNavigate,
            ),
          ),
        ],
      ),
    );
  }
}

/// État vide posé sur la carte (aucun repère à montrer).
class MapEmptyNotice extends StatelessWidget {
  const MapEmptyNotice({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      elevation: AppCardElevation.hero,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Icon(Icons.wrong_location_outlined,
              size: 20, color: colors.mutedForeground),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style:
                  textTheme.bodyLarge?.copyWith(color: colors.mutedForeground),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bouton rond flottant sur une carte (recentrer…), 48 dp, surface `card`.
/// Remplace le `FloatingActionButton`.
class MapRoundButton extends StatelessWidget {
  const MapRoundButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.loading = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        label: tooltip,
        excludeSemantics: true,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: colors.card,
            shape: BoxShape.circle,
            boxShadow: colors.heroShadow,
            border: colors.isDarkMode ? Border.all(color: colors.border) : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: Center(
                child: loading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.primary,
                        ),
                      )
                    : Icon(icon, size: 22, color: colors.primary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
