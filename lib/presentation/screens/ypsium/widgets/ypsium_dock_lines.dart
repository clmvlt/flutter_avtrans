import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Ligne d'état du dock pendant une opération : indicateur + texte, comme
/// « Envoi du pointage… » sur la page Pointage.
class YpsiumBusyLine extends StatelessWidget {
  const YpsiumBusyLine({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      liveRegion: true,
      label: text,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 32),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.primary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                text,
                style: textTheme.labelMedium?.copyWith(color: colors.foreground),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lien « revenir à l'étape précédente » du dock d'un parcours : discret,
/// au-dessus du bouton qui dit l'étape suivante.
class YpsiumBackLink extends StatelessWidget {
  const YpsiumBackLink({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: colors.primary,
          minimumSize: const Size(48, 40),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          textStyle: textTheme.labelLarge,
        ),
        icon: const Icon(Icons.arrow_back_rounded, size: 18),
        label: Text(label),
      ),
    );
  }
}
