import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/time_format.dart';
import '../../../widgets/app_callout_card.dart';
import '../../../widgets/app_list_row.dart';

/// Carte « À faire » de l'Accueil : la signature des heures du mois
/// dernier est requise. N'apparaît que dans ce cas.
class SignatureCallout extends StatelessWidget {
  const SignatureCallout({
    super.key,
    required this.heuresLastMonth,
    required this.onTap,
  });

  final double? heuresLastMonth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final heures = heuresLastMonth;

    return AppCalloutCard(
      title: 'À faire',
      tone: AppCalloutTone.warning,
      icon: Icons.lock_rounded,
      children: [
        AppListRow(
          icon: Icons.draw_rounded,
          iconColor: colors.warning,
          title: 'Signer mes heures',
          subtitle: heures != null && heures > 0
              ? 'Obligatoire · ${TimeFormat.hoursDecimal(heures)} du mois '
                  'dernier à signer'
              : 'Obligatoire · heures du mois dernier à signer',
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          showChevron: true,
          onTap: onTap,
        ),
      ],
    );
  }
}
