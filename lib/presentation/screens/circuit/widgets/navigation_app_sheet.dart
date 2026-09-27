import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/services/navigation_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../widgets/app_list_row.dart';
import '../../../widgets/app_sheet.dart';
import 'tour_widgets.dart';

/// Feuille de choix de l'application de navigation GPS par défaut.
///
/// Le choix est persisté (`NavigationPreferenceService`) et réutilisé pour tous
/// les arrêts ; modifiable à tout moment.
Future<void> showNavigationAppSheet(BuildContext context) {
  return AppSheet.show<void>(
    context,
    title: 'Application GPS',
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
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final service = sl.navigationPreferenceService;

    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Utilisée pour ouvrir les arrêts dans un GPS. Tu peux en changer '
              'quand tu veux.',
              style:
                  textTheme.bodyMedium?.copyWith(color: colors.mutedForeground),
            ),
            const SizedBox(height: AppSpacing.base),
            RowsCard(
              children: [
                for (final app in NavigationApp.values)
                  AppListRow(
                    icon: _icon(app),
                    iconColor: service.current == app
                        ? colors.primary
                        : colors.mutedForeground,
                    title: app.label,
                    trailing: service.current == app
                        ? Icon(
                            Icons.check_rounded,
                            size: 22,
                            color: colors.primary,
                          )
                        : null,
                    showChevron: false,
                    semanticsLabel: service.current == app
                        ? '${app.label}, sélectionnée'
                        : app.label,
                    onTap: () async {
                      await service.setApp(app);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
