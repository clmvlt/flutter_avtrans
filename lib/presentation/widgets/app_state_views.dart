import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'app_button.dart';
import 'app_card.dart';
import 'app_list_row.dart';
import 'app_page.dart';
import 'app_skeleton.dart';

/// Échec de chargement, affiché SOUS l'en-tête de la page (le titre reste
/// visible) : icône, phrase simple, bouton « Réessayer ».
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.title = 'Chargement impossible',
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIconBox(
                icon: Icons.cloud_off_rounded,
                color: colors.destructive,
                size: AppLayout.heroIconBox,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(title, style: textTheme.titleMedium)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            style: textTheme.bodyMedium?.copyWith(color: colors.mutedForeground),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.base),
            AppButton(
              text: 'Réessayer',
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
              variant: ButtonVariant.secondary,
            ),
          ],
        ],
      ),
    );
  }
}

/// État vide discret : carte à plat enfoncée, icône + phrase, action texte
/// optionnelle. Comme « Aucun pointage pour l'instant ».
class AppEmptyCard extends StatelessWidget {
  const AppEmptyCard({
    super.key,
    required this.icon,
    required this.message,
    this.detail,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? detail;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      elevation: AppCardElevation.flat,
      color: colors.surfaceSunken,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.mutedForeground),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message,
                  style:
                      textTheme.bodyLarge?.copyWith(color: colors.mutedForeground),
                ),
                if (detail != null)
                  Text(detail!, style: textTheme.bodySmall),
                // Sous le texte : à 360 dp, un bouton à droite écrase la phrase.
                if (actionLabel != null && onAction != null)
                  TextButton(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                      foregroundColor: colors.primary,
                      minimumSize: const Size(48, 40),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.padded,
                      textStyle: textTheme.labelLarge,
                    ),
                    child: Text(actionLabel!),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Squelette d'une liste de lignes (boîte d'icône + deux lignes de texte),
/// dans une carte, à la géométrie d'[AppListRow].
class AppListSkeleton extends StatelessWidget {
  const AppListSkeleton({super.key, this.rows = 4, this.inCard = true});

  final int rows;
  final bool inCard;

  @override
  Widget build(BuildContext context) {
    final list = Column(
      children: [
        for (var i = 0; i < rows; i++)
          const SizedBox(
            height: AppLayout.rowMinHeight + AppSpacing.sm,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.base),
              child: Row(
                children: [
                  AppSkeleton(
                    width: AppLayout.iconBox,
                    height: AppLayout.iconBox,
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppSkeleton(width: 160, height: 15),
                        SizedBox(height: AppSpacing.sm),
                        AppSkeleton(width: 110, height: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
    if (!inCard) return list;
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: list,
    );
  }
}

/// Squelette d'une carte hero (ligne d'état + grand chiffre).
class AppHeroSkeleton extends StatelessWidget {
  const AppHeroSkeleton({super.key, this.showFigure = true});

  final bool showFigure;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      elevation: AppCardElevation.hero,
      radius: AppRadius.xl,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              AppSkeleton(
                width: AppLayout.heroIconBox,
                height: AppLayout.heroIconBox,
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSkeleton(width: 160, height: 22),
                    SizedBox(height: AppSpacing.sm),
                    AppSkeleton(width: 200, height: 15),
                  ],
                ),
              ),
            ],
          ),
          if (showFigure) ...const [
            SizedBox(height: AppSpacing.lg),
            AppSkeleton(width: 110, height: 13),
            SizedBox(height: AppSpacing.sm),
            AppSkeleton(width: 180, height: 40),
          ],
        ],
      ),
    );
  }
}
