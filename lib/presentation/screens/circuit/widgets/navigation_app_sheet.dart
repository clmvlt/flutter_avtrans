import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/services/navigation_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../widgets/app_sheet.dart';

/// Feuille de choix de l'application de navigation GPS par défaut.
///
/// Le choix est persisté (`NavigationPreferenceService`) et réutilisé pour tous
/// les arrêts ; modifiable à tout moment.
Future<void> showNavigationAppSheet(BuildContext context) {
  return AppSheet.show<void>(
    context,
    title: 'Application de navigation',
    builder: (ctx) => const _NavigationAppOptions(),
  );
}

class _NavigationAppOptions extends StatelessWidget {
  const _NavigationAppOptions();

  IconData _icon(NavigationApp app) => switch (app) {
        NavigationApp.googleMaps => Icons.map_rounded,
        NavigationApp.waze => Icons.navigation_rounded,
        NavigationApp.appleMaps => Icons.map_outlined,
        NavigationApp.system => Icons.smartphone_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final service = sl.navigationPreferenceService;

    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Utilisée pour ouvrir les arrêts dans un GPS. Tu peux en changer quand tu veux.',
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            for (final app in NavigationApp.values)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _AppTile(
                  icon: _icon(app),
                  label: app.label,
                  selected: service.current == app,
                  onTap: () async {
                    await service.setApp(app);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AppTile extends StatelessWidget {
  const _AppTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: selected ? colors.primarySoft : colors.surfaceSunken,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Row(
            children: [
              Icon(icon,
                  size: 22,
                  color: selected ? colors.primary : colors.mutedForeground),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: textTheme.titleSmall?.copyWith(
                    color: selected ? colors.primary : colors.foreground,
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded,
                    size: 20, color: colors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
