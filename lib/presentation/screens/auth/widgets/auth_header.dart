import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// En-tête centré des écrans d'authentification : logo de l'app (ou
/// [leading], ex. l'avatar Google), titre, puis une ligne qui dit à quoi sert
/// l'écran.
class AuthHeader extends StatelessWidget {
  const AuthHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
  });

  final String title;
  final String? subtitle;

  /// Remplace le logo de l'app.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(child: leading ?? const AuthLogo()),
        const SizedBox(height: AppSpacing.base),
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: textTheme.headlineMedium,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge?.copyWith(color: colors.mutedForeground),
          ),
        ],
      ],
    );
  }
}

/// Icône de l'app aux coins `AppRadius.xl`, comme sur l'écran de démarrage,
/// posée sur une ombre douce de carte.
class AuthLogo extends StatelessWidget {
  const AuthLogo({super.key, this.size = 80});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(AppRadius.xl);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: colors.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Image.asset(
          'lib/assets/icons/icon-512x512.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          semanticLabel: 'Logo AVTRANS',
        ),
      ),
    );
  }
}
