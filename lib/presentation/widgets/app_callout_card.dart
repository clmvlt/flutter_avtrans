import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'app_card.dart';
import 'app_dock.dart';

/// Tonalité d'une [AppCalloutCard].
enum AppCalloutTone { info, warning, danger, success }

/// Carte d'attention à plat et teintée, sur le modèle de « AVANT DE
/// POINTER » : en-tête en petites capitales avec son icône, puis des lignes
/// (généralement des [AppListRow] sans marge horizontale). À n'afficher que
/// quand il y a quelque chose à faire : le silence est la récompense.
class AppCalloutCard extends StatelessWidget {
  const AppCalloutCard({
    super.key,
    required this.title,
    required this.tone,
    required this.children,
    this.icon,
  });

  /// Titre court, affiché en capitales (« À FAIRE », « EN RETARD »).
  final String title;
  final AppCalloutTone tone;
  final IconData? icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    final (bg, fg, defaultIcon) = switch (tone) {
      AppCalloutTone.info => (
          colors.infoMuted,
          colors.info,
          Icons.info_outline_rounded,
        ),
      AppCalloutTone.warning => (
          colors.warningMuted,
          onWarningMuted(colors),
          Icons.schedule_rounded,
        ),
      AppCalloutTone.danger => (
          colors.errorBg,
          colors.destructive,
          Icons.error_outline_rounded,
        ),
      AppCalloutTone.success => (
          colors.successMuted,
          colors.success,
          Icons.check_circle_outline_rounded,
        ),
    };

    return AppCard(
      elevation: AppCardElevation.flat,
      color: bg,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.base,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon ?? defaultIcon, size: 18, color: fg),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: textTheme.labelSmall?.copyWith(
                    letterSpacing: 0.8,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...children,
        ],
      ),
    );
  }
}
