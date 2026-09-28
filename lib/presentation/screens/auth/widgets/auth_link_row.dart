import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Lien secondaire sous le formulaire : « Pas encore de compte ? Créer un
/// compte ». La question en discret, l'action en bouton texte (48 dp) ; les
/// deux passent l'une sous l'autre si l'écran est étroit.
class AuthLinkRow extends StatelessWidget {
  const AuthLinkRow({
    super.key,
    required this.prompt,
    required this.actionLabel,
    required this.onPressed,
  });

  final String prompt;
  final String actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          prompt,
          style: textTheme.bodyMedium?.copyWith(color: colors.mutedForeground),
        ),
        AuthTextLink(label: actionLabel, onPressed: onPressed),
      ],
    );
  }
}

/// Action secondaire en bouton texte `primary` (48 dp) : « Créer un
/// compte », « Mot de passe oublié ? ».
class AuthTextLink extends StatelessWidget {
  const AuthTextLink({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: context.colors.primary,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        textStyle: Theme.of(context).textTheme.labelLarge,
      ),
      child: Text(label),
    );
  }
}

/// Séparateur « ou » entre la connexion par email et Google.
class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return ExcludeSemantics(
      child: Row(
        children: [
          Expanded(child: Divider(height: 1, color: colors.border)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text('ou', style: textTheme.bodySmall),
          ),
          Expanded(child: Divider(height: 1, color: colors.border)),
        ],
      ),
    );
  }
}
