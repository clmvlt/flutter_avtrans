import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/display_format.dart';
import '../../../../data/models/app_version_model.dart';
import '../../../widgets/app_hero_card.dart';
import 'download_progress.dart';

/// Carte hero de la page Mises à jour : « Application à jour » ou « Mise à
/// jour disponible » (versions, nouveautés, progression du téléchargement).
class UpdateHeroCard extends StatelessWidget {
  const UpdateHeroCard({
    super.key,
    required this.currentVersion,
    required this.currentVersionCode,
    required this.checking,
    required this.checked,
    required this.latest,
    required this.downloadProgress,
  });

  final String currentVersion;
  final int currentVersionCode;

  /// Vérification en cours (et pas encore de mise à jour connue).
  final bool checking;

  /// Le serveur a répondu au moins une fois : « à jour » est une certitude.
  final bool checked;

  /// Version plus récente que celle installée, sinon `null`.
  final AppVersion? latest;

  /// Progression du téléchargement de [latest] (0 → 1), `null` hors
  /// téléchargement.
  final double? downloadProgress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final installed = currentVersionCode > 0
        ? '$currentVersion ($currentVersionCode)'
        : currentVersion;
    final update = latest;

    if (update == null) {
      if (checking) {
        return AppHeroCard(
          icon: Icons.sync_rounded,
          accent: colors.primary,
          title: 'Vérification…',
          subtitle: 'Version installée : $installed',
        );
      }
      if (!checked) {
        return AppHeroCard(
          icon: Icons.phone_android_rounded,
          accent: colors.mutedForeground,
          title: 'Version installée',
          subtitle: installed,
        );
      }
      return AppHeroCard(
        icon: Icons.check_circle_rounded,
        accent: colors.success,
        title: 'Application à jour',
        subtitle: 'Version installée : $installed',
      );
    }

    final changelog = update.changelog;
    final progress = downloadProgress;

    return AppHeroCard(
      icon: Icons.system_update_rounded,
      accent: colors.primary,
      title: 'Mise à jour disponible',
      subtitle: 'Version ${update.versionName} · '
          '${DisplayFormat.fileSize(update.fileSize)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppMetricRow(
            metrics: [
              AppMetric(label: 'Installée', value: currentVersion),
              AppMetric(label: 'Nouvelle', value: update.versionName),
            ],
          ),
          if (changelog != null && changelog.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text('Nouveautés', style: textTheme.bodySmall),
            const SizedBox(height: AppSpacing.xs),
            Text(changelog, style: textTheme.bodyMedium),
          ],
          if (progress != null) ...[
            const SizedBox(height: AppSpacing.lg),
            DownloadProgress(progress: progress),
          ],
        ],
      ),
    );
  }
}
