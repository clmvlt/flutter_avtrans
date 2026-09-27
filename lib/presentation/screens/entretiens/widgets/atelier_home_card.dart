import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/display_format.dart';
import '../../../../data/models/entretien_model.dart';
import '../../../../data/models/vehicule_model.dart';
import '../../../widgets/widgets.dart';
import '../logic/fleet_status.dart';
import 'fleet_widgets.dart';

/// Résumé de la flotte pour l'accueil : véhicules en retard / à prévoir.
class FleetSummary {
  const FleetSummary({required this.late, required this.soon, required this.ok});

  final int late;
  final int soon;
  final int ok;

  FleetLevel get level => late > 0
      ? FleetLevel.late
      : soon > 0
          ? FleetLevel.soon
          : FleetLevel.ok;

  /// Charge véhicules et échéances puis compte par niveau d'urgence.
  static Future<Either<Failure, FleetSummary>> load() async {
    final results = await Future.wait([
      sl.vehiculeRepository.getAllVehicules(),
      sl.entretienRepository.getFleetUpcoming(),
    ]);
    final vehicules = results[0] as Either<Failure, List<Vehicule>>;
    final upcoming =
        results[1] as Either<Failure, List<VehiculeProchainEntretien>>;
    return vehicules.fold(Left.new, (v) {
      return upcoming.fold(Left.new, (u) {
        final fleet = computeFleetStatus(v, u);
        int count(FleetLevel l) => fleet.where((f) => f.level == l).length;
        return Right(FleetSummary(
          late: count(FleetLevel.late),
          soon: count(FleetLevel.soon),
          ok: count(FleetLevel.ok),
        ));
      });
    });
  }
}

/// Carte « Entretiens » de l'accueil (Administrateur, Mécanicien) : une
/// ligne qui dit s'il y a des véhicules à entretenir, et mène à l'atelier.
class AtelierHomeCard extends StatelessWidget {
  const AtelierHomeCard({
    super.key,
    required this.summary,
    required this.loading,
    required this.onTap,
    this.error = false,
  });

  final FleetSummary? summary;
  final bool loading;
  final bool error;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final s = summary;

    final String subtitle;
    final Color accent;
    if (s == null) {
      subtitle = loading
          ? 'Chargement des échéances…'
          : (error ? 'Échéances indisponibles' : 'Entretiens des véhicules');
      accent = colors.domainVehicule;
    } else {
      accent = s.level == FleetLevel.ok ? colors.success : s.level.color(colors);
      if (s.late > 0) {
        subtitle = '${DisplayFormat.plural(s.late, 'véhicule')} en retard'
            '${s.soon > 0 ? ' · ${s.soon} à prévoir' : ''}';
      } else if (s.soon > 0) {
        subtitle = '${DisplayFormat.plural(s.soon, 'véhicule')} à prévoir';
      } else {
        subtitle = 'Flotte à jour';
      }
    }

    return AppCard(
      padding: EdgeInsets.zero,
      child: AppListRow(
        title: 'Entretiens',
        subtitle: subtitle,
        icon: Icons.build_rounded,
        iconColor: accent,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.md,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        trailing: s != null && s.late > 0
            ? AppStatusChip(
                label: '${s.late}',
                color: colors.destructive,
                icon: Icons.error_rounded,
              )
            : null,
        showChevron: true,
      ),
    );
  }
}
