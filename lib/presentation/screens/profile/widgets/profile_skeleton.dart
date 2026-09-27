import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_skeleton.dart';

/// Squelette du chargement du profil : photo, nom, puis deux groupes de
/// champs.
class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(
          child: AppSkeleton(
            width: 104,
            height: 104,
            borderRadius: AppRadius.full,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const Center(child: AppSkeleton(width: 160, height: 20)),
        const SizedBox(height: AppSpacing.lg),
        for (final fields in const [4, 3]) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xs,
              0,
              AppSpacing.xs,
              AppSpacing.md,
            ),
            child: AppSkeleton(width: 180, height: 16),
          ),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < fields; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.md),
                  const AppSkeleton(width: 120, height: 14),
                  const SizedBox(height: AppSpacing.sm),
                  const AppSkeleton(height: 52),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }
}
