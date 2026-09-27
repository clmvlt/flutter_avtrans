import 'package:flutter/material.dart';

import '../../../../core/services/navigation_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/tour_stop.dart';
import '../../../widgets/app_callout_card.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_list_row.dart';
import '../../../widgets/app_page.dart';
import '../circuit_format.dart';

/// Lignes ([AppListRow]) regroupées dans une carte, séparées par un trait
/// aligné sur le texte (marge 16 + boîte d'icône 40 + écart 12).
class RowsCard extends StatelessWidget {
  const RowsCard({super.key, required this.children});

  final List<Widget> children;

  static const double dividerIndent =
      AppSpacing.base + AppLayout.iconBox + AppSpacing.md;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: colors.border,
                indent: dividerIndent,
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Numéro d'arrêt dans une boîte teintée, à la géométrie d'[AppIconBox].
/// Un arrêt écarté par l'optimisation affiche un avertissement à la place.
class StopNumberBox extends StatelessWidget {
  const StopNumberBox({
    super.key,
    required this.number,
    this.skipped = false,
    this.size = AppLayout.iconBox,
  });

  /// Rang de passage ; `null` pour un arrêt écarté ou sans rang.
  final int? number;
  final bool skipped;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (skipped || number == null) {
      return AppIconBox(
        icon: skipped ? Icons.warning_amber_rounded : Icons.location_on_rounded,
        color: skipped ? colors.warning : colors.primary,
        size: size,
      );
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        '$number',
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
      ),
    );
  }
}

/// Sous-ligne d'un arrêt : motif d'écart, heure d'arrivée estimée (tournée
/// optimisée) ou ligne secondaire de l'adresse.
String? stopSubtitle(TourStop stop, {required bool optimized}) {
  if (stop.skipped) {
    return stop.skipReason == 'TOO_FAR'
        ? 'Écarté · trop éloigné d\'une route'
        : 'Écarté · hors réseau routier';
  }
  if (optimized && stop.arrivalTime != null) {
    final dist = stop.cumulativeDistanceMeters;
    final arrival = 'Arrivée ${formatTime(stop.arrivalTime)}';
    return dist != null ? '$arrival · ${formatDistance(dist)}' : arrival;
  }
  final secondary = stop.address.secondaryLine;
  return secondary.isEmpty || stop.label.contains(secondary) ? null : secondary;
}

/// Carte « À vérifier » : arrêts écartés par l'optimisation.
class SkippedStopsCallout extends StatelessWidget {
  const SkippedStopsCallout({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final text = count == 1
        ? '1 arrêt écarté : adresse non rattachable au réseau routier. '
            'Ajuste son point GPS.'
        : '$count arrêts écartés : adresses non rattachables au réseau '
            'routier. Ajuste leur point GPS.';

    return AppCalloutCard(
      title: 'À vérifier',
      tone: AppCalloutTone.warning,
      icon: Icons.warning_amber_rounded,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            right: AppSpacing.sm,
            bottom: AppSpacing.xs,
          ),
          child: Text(
            text,
            style: textTheme.bodyMedium?.copyWith(color: colors.foreground),
          ),
        ),
      ],
    );
  }
}

/// Ligne d'état d'un dock (au-dessus des boutons), sur le modèle de la ligne
/// GPS de la page Pointage : icône ou indicateur, texte, accessoire.
class DockStatusLine extends StatelessWidget {
  const DockStatusLine({
    super.key,
    required this.text,
    this.icon,
    this.color,
    this.busy = false,
    this.trailing,
  });

  final String text;
  final IconData? icon;
  final Color? color;

  /// Indicateur de progression à la place de l'icône.
  final bool busy;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      liveRegion: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 32),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: busy
                  ? Padding(
                      padding: const EdgeInsets.all(2),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.primary,
                      ),
                    )
                  : Icon(
                      icon ?? Icons.info_outline_rounded,
                      size: 18,
                      color: color ?? colors.mutedForeground,
                    ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                text,
                style: textTheme.labelMedium?.copyWith(
                  color: colors.foreground,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// Ligne d'état « navigation » d'un dock : résumé du tracé (ou « Application
/// GPS ») et l'application choisie, touchable pour en changer.
class NavigationAppLine extends StatelessWidget {
  const NavigationAppLine({
    super.key,
    required this.app,
    required this.onChangeApp,
    this.summary,
  });

  final NavigationApp app;
  final VoidCallback onChangeApp;

  /// « 45 km · 1 h 20 » ; `null` → « Application GPS ».
  final String? summary;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return DockStatusLine(
      icon: summary != null ? Icons.route_rounded : Icons.navigation_outlined,
      color: summary != null ? colors.primary : colors.mutedForeground,
      text: summary ?? 'Application GPS',
      trailing: Semantics(
        button: true,
        label: 'Application GPS : ${app.label}. Changer',
        excludeSemantics: true,
        child: TextButton(
          onPressed: onChangeApp,
          style: TextButton.styleFrom(
            foregroundColor: colors.primary,
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            textStyle: textTheme.labelLarge,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(app.label),
              const SizedBox(width: AppSpacing.xs),
              const Icon(Icons.unfold_more_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
