import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/display_format.dart';
import '../../../../data/models/ypsium_models.dart';
import '../../../widgets/widgets.dart';

/// Carte hero de l'accueil Ypsium : ce qu'il reste à faire sur la journée
/// affichée, puis les compteurs « À enlever · À livrer · Livrés ».
class YpsiumHomeHero extends StatelessWidget {
  const YpsiumHomeHero({
    super.key,
    required this.orders,
    required this.dateLabel,
  });

  final List<YpsiumTransportOrder> orders;

  /// « Aujourd'hui » ou « Mardi 12 mars ».
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (orders.isEmpty) {
      return AppHeroCard(
        icon: Icons.inbox_rounded,
        accent: colors.mutedForeground,
        title: 'Aucun transport',
        subtitle: dateLabel,
      );
    }

    final aEnlever = orders.where((o) => o.isAEnlever).length;
    final aLivrer = orders.where((o) => o.isEnleve).length;
    final livres = orders.where((o) => o.isLivre).length;
    final remaining = aEnlever + aLivrer;
    final allDone = remaining == 0;

    AppMetric metric(String label, int value) => AppMetric(
          label: label,
          value: '$value',
          valueColor: value == 0 ? colors.mutedForeground : null,
        );

    return AppHeroCard(
      icon: allDone ? Icons.check_circle_rounded : Icons.local_shipping_rounded,
      accent: allDone ? colors.success : colors.domainYpsium,
      title: allDone
          ? 'Tout est livré'
          : '${DisplayFormat.plural(remaining, 'transport')} à faire',
      subtitle:
          '$dateLabel · ${DisplayFormat.plural(orders.length, 'transport')} au total',
      child: AppMetricRow(
        metrics: [
          metric('À enlever', aEnlever),
          metric('À livrer', aLivrer),
          metric('Livrés', livres),
        ],
      ),
    );
  }
}

/// Squelette du premier chargement, à la géométrie de l'accueil (hero et
/// ses trois compteurs, en-tête de section, trois lignes).
class YpsiumHomeSkeleton extends StatelessWidget {
  const YpsiumHomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          elevation: AppCardElevation.hero,
          radius: AppRadius.xl,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                        AppSkeleton(width: 180, height: 22),
                        SizedBox(height: AppSpacing.sm),
                        AppSkeleton(width: 200, height: 15),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(child: _MetricSkeleton()),
                  SizedBox(width: AppSpacing.md),
                  Expanded(child: _MetricSkeleton()),
                  SizedBox(width: AppSpacing.md),
                  Expanded(child: _MetricSkeleton()),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Align(
            alignment: Alignment.centerLeft,
            child: AppSkeleton(width: 100, height: 16),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const AppListSkeleton(rows: 3),
      ],
    );
  }
}

class _MetricSkeleton extends StatelessWidget {
  const _MetricSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSkeleton(width: 64, height: 13),
        SizedBox(height: AppSpacing.xs),
        AppSkeleton(width: 32, height: 22),
      ],
    );
  }
}
