import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_skeleton.dart';

/// Squelette du formulaire de rapport : véhicule, puis deux cases photo.
class RapportSkeleton extends StatelessWidget {
  const RapportSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeaderSkeleton(width: 80),
        AppCard(child: AppSkeleton(height: 56)),
        SizedBox(height: AppSpacing.lg),
        _HeaderSkeleton(width: 70),
        AppCard(
          child: Row(
            children: [
              Expanded(child: AppSkeleton(height: 150)),
              SizedBox(width: AppSpacing.md),
              Expanded(child: AppSkeleton(height: 150)),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderSkeleton extends StatelessWidget {
  const _HeaderSkeleton({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        0,
        AppSpacing.xs,
        AppSpacing.md,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: AppSkeleton(width: width, height: 16),
      ),
    );
  }
}
