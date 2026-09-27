import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/display_format.dart';
import '../../../widgets/widgets.dart';

/// Point focal de « Mes absences » : les demandes qui attendent une réponse.
/// Tapable quand il y en a : affiche alors la liste filtrée « En attente ».
class AbsencesHero extends StatelessWidget {
  const AbsencesHero({
    super.key,
    required this.pendingCount,
    required this.total,
    required this.filtered,
    this.onShowPending,
  });

  final int pendingCount;

  /// Nombre de demandes chargées.
  final int total;

  /// Des filtres restreignent la liste chargée.
  final bool filtered;
  final VoidCallback? onShowPending;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (pendingCount > 0) {
      return AppHeroCard(
        icon: Icons.hourglass_top_rounded,
        accent: colors.warning,
        title: '${DisplayFormat.plural(pendingCount, 'demande')} en attente',
        subtitle: filtered
            ? 'En attente de validation · selon tes filtres'
            : 'En attente de validation',
        onTap: onShowPending,
      );
    }

    return AppHeroCard(
      icon: Icons.event_available_rounded,
      accent: colors.success,
      title: 'Rien en attente',
      subtitle: filtered
          ? 'Selon tes filtres'
          : total == 0
              ? 'Aucune demande pour le moment'
              : 'Tes demandes ont toutes une réponse',
    );
  }
}
