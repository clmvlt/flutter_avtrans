import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../widgets/widgets.dart';

/// Squelette du premier chargement de la fiche véhicule, à la géométrie du
/// contenu (hero, segments, raccourcis, première section).
class VehiculeDetailsSkeleton extends StatelessWidget {
  const VehiculeDetailsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppHeroSkeleton(),
        SizedBox(height: AppSpacing.lg),
        AppSkeleton(height: 48, borderRadius: AppRadius.md + 4),
        SizedBox(height: AppSpacing.lg),
        AppListSkeleton(rows: 2),
        SizedBox(height: AppSpacing.lg),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: AppSkeleton(width: 120, height: 16),
        ),
        SizedBox(height: AppSpacing.md),
        AppListSkeleton(rows: 4),
      ],
    );
  }
}
