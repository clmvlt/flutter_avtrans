import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/time_format.dart';
import '../../../widgets/app_hero_card.dart';
import '../../../widgets/app_picker_field.dart';
import '../../../widgets/app_skeleton.dart';

/// Carte hero de la signature : les heures à signer.
///
/// Heures du mois dernier connues ([fixedHours]) : grand chiffre, non
/// modifiable. Sinon : champ prérempli avec le total du mois en cours,
/// corrigeable avant de signer.
class SignHoursHero extends StatelessWidget {
  const SignHoursHero({
    super.key,
    required this.fixedHours,
    required this.controller,
    required this.loading,
    required this.enabled,
  });

  final double? fixedHours;
  final TextEditingController controller;

  /// Le total du mois en cours est en cours de chargement.
  final bool loading;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final fixed = fixedHours;

    Widget child;
    if (fixed != null) {
      child = Semantics(
        label: 'Total à signer : ${TimeFormat.hoursDecimal(fixed)}',
        excludeSemantics: true,
        child: AppHeroFigure(
          label: 'Total à signer',
          value: TimeFormat.hoursDecimal(fixed),
          muted: fixed <= 0,
        ),
      );
    } else if (loading) {
      child = const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSkeleton(width: 130, height: 15),
          SizedBox(height: AppSpacing.sm),
          AppSkeleton(height: 56),
        ],
      );
    } else {
      child = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppFieldLabel('Nombre d\'heures'),
          TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            style: textTheme.titleLarge?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            decoration: InputDecoration(
              hintText: 'Ex. 151,5',
              suffixText: 'h',
              prefixIcon: Icon(
                Icons.schedule_rounded,
                color: colors.mutedForeground,
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Text(
              'Vérifie le total : tu peux le corriger avant de signer.',
              style: textTheme.bodySmall,
            ),
          ),
        ],
      );
    }

    return AppHeroCard(
      icon: Icons.draw_rounded,
      accent: colors.domainHours,
      title: 'Heures à signer',
      subtitle: fixed != null
          ? 'Mois dernier · ta signature valide ce total'
          : 'Mois en cours · ta signature valide ce total',
      child: child,
    );
  }
}
