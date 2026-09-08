import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_skeleton.dart';
import 'pointage_layout.dart';

/// Squelette du premier chargement, à la géométrie du contenu réel (hero,
/// en-tête, trois lignes de fil, bandeau) pour un fondu sans saut.
class PointageSkeleton extends StatelessWidget {
  const PointageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          elevation: AppCardElevation.hero,
          radius: AppRadius.xl,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Row(
                children: [
                  AppSkeleton(
                    width: PointageLayout.iconBoxSize,
                    height: PointageLayout.iconBoxSize,
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppSkeleton(width: 160, height: 22),
                        SizedBox(height: AppSpacing.sm),
                        AppSkeleton(width: 220, height: 16),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.lg),
              AppSkeleton(width: 120, height: 13),
              SizedBox(height: AppSpacing.sm),
              AppSkeleton(width: 200, height: 52),
              SizedBox(height: AppSpacing.lg),
              AppSkeleton(
                height: PointageLayout.ribbonHeight,
                borderRadius: AppRadius.full,
              ),
              SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  AppSkeleton(width: 40, height: 13),
                  Spacer(),
                  AppSkeleton(width: 96, height: 13),
                  Spacer(),
                  AppSkeleton(width: 40, height: 13),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: AppSkeleton(width: 100, height: 16),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            children: [
              for (var i = 0; i < 3; i++)
                const SizedBox(
                  height: PointageLayout.rowMinHeight,
                  child: Row(
                    children: [
                      AppSkeleton(width: 40, height: 15),
                      SizedBox(width: AppSpacing.md),
                      AppSkeleton(
                        width: PointageLayout.dotSize,
                        height: PointageLayout.dotSize,
                        borderRadius: AppRadius.full,
                      ),
                      SizedBox(width: AppSpacing.md),
                      Expanded(child: AppSkeleton(height: 16)),
                      SizedBox(width: AppSpacing.md),
                      AppSkeleton(width: 48, height: 22, borderRadius: AppRadius.full),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
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
