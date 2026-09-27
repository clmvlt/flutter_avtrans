import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_skeleton.dart';
import '../../../widgets/app_state_views.dart';

/// Squelette du premier chargement de l'Accueil, à la géométrie du haut de
/// page : carte hero du pointage puis bandeau des heures.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppHeroSkeleton(),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Row(
            children: const [
              Expanded(child: AppSkeleton(height: 40)),
              SizedBox(width: AppSpacing.md),
              Expanded(child: AppSkeleton(height: 40)),
              SizedBox(width: AppSpacing.md),
              Expanded(child: AppSkeleton(height: 40)),
            ],
          ),
        ),
      ],
    );
  }
}
