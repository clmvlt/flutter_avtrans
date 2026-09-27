import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/display_format.dart';
import '../../../widgets/widgets.dart';

/// Point focal de « Mes acomptes » : les demandes en attente et leur montant.
class AcomptesHero extends StatelessWidget {
  const AcomptesHero({
    super.key,
    required this.pendingCount,
    required this.pendingAmount,
    required this.total,
    required this.filtered,
  });

  final int pendingCount;
  final double pendingAmount;

  /// Nombre de demandes chargées.
  final int total;

  /// Des filtres restreignent la liste chargée.
  final bool filtered;

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
        child: AppHeroFigure(
          label: 'Montant demandé',
          value: DisplayFormat.euros(pendingAmount),
        ),
      );
    }

    return AppHeroCard(
      icon: Icons.payments_rounded,
      accent: colors.domainAcompte,
      title: 'Rien en attente',
      subtitle: filtered
          ? 'Selon tes filtres'
          : total == 0
              ? 'Aucune demande pour le moment'
              : 'Tes demandes ont toutes une réponse',
    );
  }
}
