import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/display_format.dart';
import '../../../../data/models/app_version_model.dart';
import '../../../widgets/app_list_row.dart';

/// Une version de l'historique : numéro, date et taille, pastille
/// « Installée » ou progression du téléchargement. Tapable : détail.
class VersionRow extends StatelessWidget {
  const VersionRow({
    super.key,
    required this.version,
    required this.isCurrent,
    required this.downloadProgress,
    required this.onTap,
  });

  final AppVersion version;
  final bool isCurrent;

  /// Progression du téléchargement de cette version, `null` sinon.
  final double? downloadProgress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final progress = downloadProgress;

    Widget? trailing;
    if (isCurrent) {
      trailing = AppStatusChip(
        label: 'Installée',
        color: colors.success,
        icon: Icons.check_rounded,
      );
    } else if (progress != null) {
      trailing = SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          value: progress,
          color: colors.primary,
          backgroundColor: colors.surfaceSunken,
        ),
      );
    }

    return AppListRow(
      icon: Icons.phone_android_rounded,
      iconColor: isCurrent ? colors.success : colors.mutedForeground,
      title: 'Version ${version.versionName}',
      subtitle: '${DisplayFormat.date(version.createdAt)} · '
          '${DisplayFormat.fileSize(version.fileSize)}',
      trailing: trailing,
      showChevron: true,
      onTap: onTap,
    );
  }
}
