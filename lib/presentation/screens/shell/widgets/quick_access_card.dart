import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_list_row.dart';

/// Accès rapide de l'Accueil : une carte de lignes vers les écrans
/// personnels les plus utilisés.
class QuickAccessCard extends StatelessWidget {
  const QuickAccessCard({
    super.key,
    required this.onHours,
    required this.onAbsences,
    required this.onAcomptes,
    required this.onVehicules,
  });

  final VoidCallback onHours;
  final VoidCallback onAbsences;
  final VoidCallback onAcomptes;
  final VoidCallback onVehicules;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Aligné sur le texte : marge 16 + boîte d'icône 40 + écart 12.
    final divider =
        Divider(height: 1, thickness: 1, color: colors.border, indent: 68);

    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        children: [
          AppListRow(
            icon: Icons.schedule_rounded,
            iconColor: colors.domainHours,
            title: 'Mes heures',
            onTap: onHours,
          ),
          divider,
          AppListRow(
            icon: Icons.event_busy_rounded,
            iconColor: colors.domainAbsence,
            title: 'Absences',
            onTap: onAbsences,
          ),
          divider,
          AppListRow(
            icon: Icons.payments_rounded,
            iconColor: colors.domainAcompte,
            title: 'Acomptes',
            onTap: onAcomptes,
          ),
          divider,
          AppListRow(
            icon: Icons.directions_car_rounded,
            iconColor: colors.domainVehicule,
            title: 'Véhicules',
            onTap: onVehicules,
          ),
        ],
      ),
    );
  }
}
