import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/display_format.dart';
import '../../../../data/models/entretien_model.dart';
import '../../../widgets/widgets.dart';
import '../logic/fleet_status.dart';
import 'fleet_widgets.dart';

/// Onglet « Suivi » d'un véhicule : rappels périodiques actifs, puis ceux
/// mis en pause. Un tap ouvre la modification.
class VehiculeConfigsView extends StatelessWidget {
  const VehiculeConfigsView({
    super.key,
    required this.loading,
    required this.error,
    required this.configs,
    required this.onRefresh,
    required this.onOpen,
  });

  final bool loading;
  final String? error;
  final List<VehiculeTypeEntretien> configs;
  final Future<void> Function() onRefresh;
  final ValueChanged<VehiculeTypeEntretien> onOpen;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (loading && configs.isEmpty) {
      return const AppScrollView(children: [AppListSkeleton(rows: 3)]);
    }
    if (error != null && configs.isEmpty) {
      return AppScrollView(
        onRefresh: onRefresh,
        children: [AppErrorState(message: error!, onRetry: onRefresh)],
      );
    }

    int byName(VehiculeTypeEntretien a, VehiculeTypeEntretien b) =>
        (a.typeEntretien?.nom ?? '').compareTo(b.typeEntretien?.nom ?? '');
    final active = configs.where((c) => c.actif).toList()..sort(byName);
    final paused = configs.where((c) => !c.actif).toList()..sort(byName);

    return AppScrollView(
      onRefresh: onRefresh,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Text(
            'Chaque suivi rappelle un entretien à intervalle régulier et '
            'alimente les échéances du véhicule.',
            style: textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (configs.isEmpty)
          const AppEmptyCard(
            icon: Icons.notifications_off_outlined,
            message: 'Aucun suivi pour ce véhicule',
            detail: 'Ex. « Vidange tous les 30 000 km ».',
          )
        else ...[
          AppSectionHeader(
            title: 'Suivis actifs',
            summary: DisplayFormat.plural(active.length, 'suivi'),
          ),
          if (active.isEmpty)
            const AppEmptyCard(
              icon: Icons.pause_circle_outline_rounded,
              message: 'Tous les suivis sont en pause',
            )
          else
            DividedCard(
              children: [
                for (final c in active) _ConfigRow(config: c, onTap: onOpen),
              ],
            ),
          if (paused.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            AppSectionHeader(
              title: 'En pause',
              summary: DisplayFormat.plural(paused.length, 'suivi'),
            ),
            DividedCard(
              children: [
                for (final c in paused) _ConfigRow(config: c, onTap: onOpen),
              ],
            ),
          ],
        ],
      ],
    );
  }
}

class _ConfigRow extends StatelessWidget {
  const _ConfigRow({required this.config, required this.onTap});

  final VehiculeTypeEntretien config;
  final ValueChanged<VehiculeTypeEntretien> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isKm = config.periodiciteType == PeriodiciteType.kilometrage;
    return AppListRow(
      title: config.typeEntretien?.nom ?? 'Entretien',
      subtitle: formatPeriodicite(
        config.periodiciteType,
        config.periodiciteValeur,
      ),
      icon: isKm ? Icons.route_rounded : Icons.event_rounded,
      iconColor: config.actif ? colors.primary : colors.mutedForeground,
      trailing: config.actif
          ? null
          : AppStatusChip(
              label: 'En pause',
              color: colors.mutedForeground,
              icon: Icons.pause_rounded,
            ),
      showChevron: true,
      onTap: () => onTap(config),
    );
  }
}
