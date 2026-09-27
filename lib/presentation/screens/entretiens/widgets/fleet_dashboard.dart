import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/display_format.dart';
import '../../../widgets/widgets.dart';
import '../logic/fleet_status.dart';
import 'fleet_widgets.dart';

/// Onglet « Échéances » : la flotte vue par urgence. Hero (combien de
/// véhicules en retard / à prévoir), puis les sections En retard, À prévoir
/// et À jour (repliée).
class FleetDashboard extends StatefulWidget {
  const FleetDashboard({
    super.key,
    required this.loading,
    required this.error,
    required this.fleet,
    required this.onRefresh,
    required this.onOpenVehicle,
  });

  final bool loading;
  final String? error;
  final List<FleetVehicleStatus> fleet;
  final Future<void> Function() onRefresh;
  final ValueChanged<FleetVehicleStatus> onOpenVehicle;

  @override
  State<FleetDashboard> createState() => _FleetDashboardState();
}

class _FleetDashboardState extends State<FleetDashboard> {
  bool _showOk = false;

  @override
  Widget build(BuildContext context) {
    if (widget.loading && widget.fleet.isEmpty) {
      return const AppScrollView(
        children: [
          AppHeroSkeleton(),
          SizedBox(height: AppSpacing.lg),
          AppListSkeleton(rows: 3),
        ],
      );
    }
    if (widget.error != null && widget.fleet.isEmpty) {
      return AppScrollView(
        onRefresh: widget.onRefresh,
        children: [
          AppErrorState(message: widget.error!, onRetry: widget.onRefresh),
        ],
      );
    }

    final late = widget.fleet.where((f) => f.level == FleetLevel.late).toList();
    final soon = widget.fleet.where((f) => f.level == FleetLevel.soon).toList();
    final ok = widget.fleet.where((f) => f.level == FleetLevel.ok).toList();

    return AppScrollView(
      onRefresh: widget.onRefresh,
      children: [
        _FleetHero(late: late.length, soon: soon.length, ok: ok.length),
        if (widget.fleet.isEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          const AppEmptyCard(
            icon: Icons.directions_car_outlined,
            message: 'Aucun véhicule dans la flotte',
          ),
        ],
        if (late.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          AppSectionHeader(
            title: 'En retard',
            summary: DisplayFormat.plural(late.length, 'véhicule'),
          ),
          _rows(late),
        ],
        if (soon.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          AppSectionHeader(
            title: 'À prévoir',
            summary: DisplayFormat.plural(soon.length, 'véhicule'),
          ),
          _rows(soon),
        ],
        if (ok.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          AppSectionHeader(
            title: 'À jour',
            actionLabel: _showOk
                ? 'Masquer'
                : 'Afficher les ${ok.length}',
            onAction: () => setState(() => _showOk = !_showOk),
          ),
          AnimatedSize(
            duration: AppDuration.base,
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _showOk
                ? _rows(ok)
                : const SizedBox(width: double.infinity),
          ),
        ],
      ],
    );
  }

  Widget _rows(List<FleetVehicleStatus> list) {
    return DividedCard(
      children: [
        for (final s in list)
          FleetVehicleRow(
            key: ValueKey(s.vehicule.id),
            status: s,
            onTap: () => widget.onOpenVehicle(s),
          ),
      ],
    );
  }
}

/// Point focal : le nombre de véhicules qui demandent une action.
class _FleetHero extends StatelessWidget {
  const _FleetHero({required this.late, required this.soon, required this.ok});

  final int late;
  final int soon;
  final int ok;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final total = late + soon + ok;

    final (FleetLevel level, String title, String subtitle) = late > 0
        ? (
            FleetLevel.late,
            '${DisplayFormat.plural(late, 'véhicule')} en retard',
            soon > 0
                ? '${DisplayFormat.plural(soon, 'autre')} à prévoir bientôt'
                : 'Échéance dépassée : entretien à faire',
          )
        : soon > 0
            ? (
                FleetLevel.soon,
                '${DisplayFormat.plural(soon, 'véhicule')} à prévoir',
                'Échéance à moins de ${DisplayFormat.km(FleetThresholds.km)} '
                    'ou ${FleetThresholds.days} jours',
              )
            : (
                FleetLevel.ok,
                'Flotte à jour',
                total == 0
                    ? 'Aucun véhicule suivi'
                    : 'Aucune échéance proche',
              );

    return Semantics(
      label: '$title. $subtitle. En retard $late, à prévoir $soon, à jour $ok.',
      excludeSemantics: true,
      child: AppHeroCard(
        icon: level.icon,
        accent: level.color(colors),
        title: title,
        subtitle: subtitle,
        child: AppMetricRow(
          metrics: [
            AppMetric(label: 'En retard', value: '$late'),
            AppMetric(label: 'À prévoir', value: '$soon'),
            AppMetric(label: 'À jour', value: '$ok'),
          ],
        ),
      ),
    );
  }
}
