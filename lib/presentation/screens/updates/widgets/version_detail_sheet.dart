import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/display_format.dart';
import '../../../../data/models/app_version_model.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_confirm_sheet.dart';
import '../../../widgets/app_sheet.dart';

/// Détail d'une version de l'historique : date, taille, nouveautés, et
/// « Télécharger et installer » quand c'est possible (Android, autre
/// version que celle installée).
abstract final class VersionDetailSheet {
  /// Retourne `true` si l'utilisateur demande l'installation.
  static Future<bool> show(
    BuildContext context, {
    required AppVersion version,
    required bool isCurrent,
    required bool canInstall,
  }) async {
    final result = await AppSheet.show<bool>(
      context,
      title: 'Version ${version.versionName}',
      builder: (ctx) => _Body(
        version: version,
        isCurrent: isCurrent,
        canInstall: canInstall,
      ),
    );
    return result ?? false;
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.version,
    required this.isCurrent,
    required this.canInstall,
  });

  final AppVersion version;
  final bool isCurrent;
  final bool canInstall;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final changelog = version.changelog;
    final notes =
        changelog != null && changelog.isNotEmpty ? changelog : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppRecapBox(
          rows: [
            AppRecapRow(
              icon: Icons.event_rounded,
              label: 'Publiée le',
              value: DisplayFormat.date(version.createdAt),
            ),
            AppRecapRow(
              icon: Icons.folder_outlined,
              label: 'Taille',
              value: DisplayFormat.fileSize(version.fileSize),
            ),
            if (isCurrent)
              const AppRecapRow(
                icon: Icons.check_circle_outline_rounded,
                label: 'Statut',
                value: 'Installée',
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Nouveautés', style: textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Text(
          notes ?? 'Pas de notes pour cette version.',
          style: textTheme.bodyMedium?.copyWith(
            color: notes != null ? colors.foreground : colors.mutedForeground,
          ),
        ),
        if (canInstall) ...[
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            text: 'Télécharger et installer',
            icon: Icons.download_rounded,
            size: ButtonSize.lg,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 52,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(foregroundColor: colors.foreground),
              child: const Text('Fermer'),
            ),
          ),
        ],
      ],
    );
  }
}
