import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/time_format.dart';
import '../../../widgets/widgets.dart';

/// Point focal de « Mes couchettes » : la couchette du jour est-elle
/// déclarée ? Tapable quand elle l'est (détail et suppression).
class CouchetteHero extends StatelessWidget {
  const CouchetteHero({super.key, required this.declared, this.onTap});

  final bool declared;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final day = TimeFormat.dateLong(DateTime.now());
    final today = 'Aujourd\'hui, ${day[0].toLowerCase()}${day.substring(1)}';

    if (declared) {
      return AppHeroCard(
        icon: Icons.hotel_rounded,
        accent: colors.success,
        title: 'Couchette déclarée',
        subtitle: today,
        onTap: onTap,
      );
    }

    return AppHeroCard(
      icon: Icons.hotel_outlined,
      accent: colors.info,
      title: 'Pas de couchette aujourd\'hui',
      subtitle: today,
    );
  }
}
