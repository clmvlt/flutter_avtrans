import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_list_row.dart';

/// Carte « Circuit » de l'Accueil (optimisation de tournée), signalée comme
/// nouveauté par une pastille. Reste sur `card` : seule l'icône est teintée.
class CircuitCard extends StatelessWidget {
  const CircuitCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: AppListRow(
        icon: Icons.route_rounded,
        iconColor: colors.primary,
        title: 'Circuit',
        subtitle: 'Optimise tes tournées',
        trailing: AppStatusChip(
          label: 'Nouveau',
          color: colors.primary,
          icon: Icons.auto_awesome_rounded,
        ),
        showChevron: true,
        onTap: onTap,
      ),
    );
  }
}
