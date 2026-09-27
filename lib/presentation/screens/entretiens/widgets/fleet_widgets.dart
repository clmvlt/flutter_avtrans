import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/display_format.dart';
import '../../../widgets/widgets.dart';
import '../logic/fleet_status.dart';

/// Apparence d'un niveau d'urgence : icône + mot + teinte (portée par
/// l'icône uniquement).
extension FleetLevelVisual on FleetLevel {
  Color color(AppColors c) => switch (this) {
        FleetLevel.late => c.destructive,
        FleetLevel.soon => c.warning,
        FleetLevel.ok => c.success,
      };

  IconData get icon => switch (this) {
        FleetLevel.late => Icons.error_rounded,
        FleetLevel.soon => Icons.schedule_rounded,
        FleetLevel.ok => Icons.check_circle_rounded,
      };

  String get label => switch (this) {
        FleetLevel.late => 'En retard',
        FleetLevel.soon => 'À prévoir',
        FleetLevel.ok => 'À jour',
      };
}

/// Une échéance sur une ligne : icône (route = km, calendrier = date)
/// teintée selon l'urgence · « Vidange · dans 3 400 km ».
class FleetAlertLine extends StatelessWidget {
  const FleetAlertLine({super.key, required this.alert});

  final FleetAlert alert;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final accent = alert.level == FleetLevel.ok
        ? colors.mutedForeground
        : alert.level.color(colors);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              alert.isKm ? Icons.route_rounded : Icons.event_rounded,
              size: 16,
              color: accent,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: alert.typeLabel,
                    style: textTheme.labelMedium,
                  ),
                  TextSpan(
                    text: ' · ${alert.dueLabel}',
                    style: textTheme.bodySmall?.copyWith(
                      color: alert.level == FleetLevel.late
                          ? colors.foreground
                          : colors.mutedForeground,
                      fontWeight: alert.level == FleetLevel.late
                          ? FontWeight.w600
                          : null,
                    ),
                  ),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Véhicule du tableau de bord : boîte d'icône teintée selon l'urgence,
/// immatriculation, modèle · kilométrage, puis ses échéances.
class FleetVehicleRow extends StatelessWidget {
  const FleetVehicleRow({super.key, required this.status, required this.onTap});

  final FleetVehicleStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final v = status.vehicule;
    final model = '${v.brand} ${v.model}'.trim();
    final subtitle = [
      if (model.isNotEmpty) model,
      if (v.latestKm != null) DisplayFormat.km(v.latestKm!),
    ].join(' · ');

    return Semantics(
      button: true,
      label: '${v.immat}, ${status.level.label}. '
          '${status.alerts.map((a) => '${a.typeLabel} ${a.dueLabel}').join('. ')}',
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.base,
              vertical: AppSpacing.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppIconBox(
                  icon: Icons.directions_car_rounded,
                  color: status.isTracked
                      ? status.level.color(colors)
                      : colors.domainVehicule,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v.immat.toUpperCase(), style: textTheme.titleSmall),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          style: textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (status.alerts.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Text(
                            'Aucune échéance suivie',
                            style: textTheme.bodySmall,
                          ),
                        )
                      else
                        for (final a in status.alerts) FleetAlertLine(alert: a),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Carte groupant des lignes séparées par un trait discret.
class DividedCard extends StatelessWidget {
  const DividedCard({super.key, required this.children, this.indent = 68});

  final List<Widget> children;
  final double indent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(height: 1, color: colors.border, indent: indent),
            children[i],
          ],
        ],
      ),
    );
  }
}
