import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../widgets/widgets.dart';

/// Carte hero d'un parcours (enlèvement, livraison) : l'étape en cours comme
/// mot d'état, « Étape 2 sur 3 » en sous-ligne, et une frise des étapes.
class YpsiumFlowHero extends StatelessWidget {
  const YpsiumFlowHero({
    super.key,
    required this.steps,
    required this.current,
    required this.icon,
    this.detail,
  });

  /// Nom de chaque étape (« Chargement », « Photos », « Signature »).
  final List<String> steps;
  final int current;
  final IconData icon;

  /// Contexte ajouté à la sous-ligne (le client).
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final stepText = 'Étape ${current + 1} sur ${steps.length}';
    final hasDetail = detail != null && detail!.isNotEmpty;

    return AppHeroCard(
      icon: icon,
      accent: colors.domainYpsium,
      title: steps[current],
      subtitle: hasDetail ? '$stepText · $detail' : stepText,
      child: YpsiumStepProgress(steps: steps, current: current),
    );
  }
}

/// Frise des étapes : un segment par étape, rempli jusqu'à l'étape en
/// cours, avec son nom dessous (coche pour les étapes faites).
class YpsiumStepProgress extends StatelessWidget {
  const YpsiumStepProgress({
    super.key,
    required this.steps,
    required this.current,
  });

  final List<String> steps;
  final int current;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      label: 'Étape ${current + 1} sur ${steps.length} : ${steps[current]}',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: reduceMotion ? Duration.zero : AppDuration.base,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i <= current ? colors.domainYpsium : colors.border,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (i < current) ...[
                        Icon(Icons.check_rounded, size: 14, color: colors.success),
                        const SizedBox(width: 2),
                      ],
                      Flexible(
                        child: Text(
                          steps[i],
                          style: textTheme.labelSmall?.copyWith(
                            color: i == current
                                ? colors.foreground
                                : colors.mutedForeground,
                            fontWeight: i == current ? FontWeight.w600 : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
