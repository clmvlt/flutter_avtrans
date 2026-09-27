import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../../core/di/service_locator.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/app_version_model.dart';
import 'app_alert.dart';
import 'app_button.dart';
import 'app_confirm_sheet.dart';
import 'app_list_row.dart';
import 'app_page.dart';

/// Proposition de mise à jour, affichée au démarrage (splash).
///
/// Malgré son nom (API historique conservée pour `main.dart`), c'est une
/// feuille : versions installée et nouvelle, nouveautés, « Mettre à jour »
/// (téléchargement puis ouverture de l'installateur) ou « Plus tard ».
/// Elle ne se ferme ni au tap à côté ni au glissé : il faut choisir.
class UpdateDialog extends StatefulWidget {
  final AppVersion version;
  final String currentVersion;
  final VoidCallback? onSkip;

  const UpdateDialog({
    super.key,
    required this.version,
    required this.currentVersion,
    this.onSkip,
  });

  /// Se termine à la fermeture de la feuille.
  static Future<void> show(
    BuildContext context, {
    required AppVersion version,
    required String currentVersion,
    VoidCallback? onSkip,
  }) {
    final colors = context.colors;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      showDragHandle: false,
      backgroundColor: colors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => UpdateDialog(
        version: version,
        currentVersion: currentVersion,
        onSkip: onSkip,
      ),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0;
  String? _error;

  Future<void> _downloadAndInstall() async {
    setState(() {
      _isDownloading = true;
      _progress = 0;
      _error = null;
    });

    final result = await sl.appVersionRepository.downloadApk(
      widget.version.id,
      widget.version.originalFileName,
      (progress) {
        if (mounted) setState(() => _progress = progress);
      },
    );

    if (!mounted) return;

    final filePath = result.fold<String?>(
      (failure) {
        setState(() {
          _isDownloading = false;
          _error = failure.message;
        });
        return null;
      },
      (path) => path,
    );
    if (filePath == null) return;

    // Ouvre l'installateur AVANT de fermer la feuille : en cas d'échec, le
    // message reste lisible ici (fermée, la feuille ne pourrait plus
    // l'afficher).
    final openResult = await OpenFilex.open(filePath);
    if (!mounted) return;
    if (openResult.type == ResultType.done) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _isDownloading = false;
        _error = 'Impossible d\'ouvrir le fichier : ${openResult.message}';
      });
    }
  }

  void _skip() {
    widget.onSkip?.call();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final media = MediaQuery.of(context);
    final changelog = widget.version.changelog;
    final error = _error;
    final percent = (_progress * 100).clamp(0, 100).toStringAsFixed(0);

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.92),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.lg,
            AppSpacing.screen,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  AppIconBox(
                    icon: Icons.system_update_rounded,
                    color: colors.primary,
                    size: AppLayout.heroIconBox,
                    iconSize: 24,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mise à jour disponible',
                          style: textTheme.titleLarge,
                        ),
                        Text(
                          'Installe la nouvelle version pour rester à jour.',
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              AppRecapBox(
                rows: [
                  AppRecapRow(
                    icon: Icons.phone_android_rounded,
                    label: 'Version installée',
                    value: widget.currentVersion,
                  ),
                  AppRecapRow(
                    icon: Icons.new_releases_outlined,
                    label: 'Nouvelle version',
                    value: widget.version.versionName,
                    emphasized: true,
                  ),
                  AppRecapRow(
                    icon: Icons.folder_outlined,
                    label: 'Taille',
                    value: widget.version.formattedFileSize,
                  ),
                ],
              ),
              if (changelog != null && changelog.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text('Nouveautés', style: textTheme.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                Text(changelog, style: textTheme.bodyMedium),
              ],
              if (_isDownloading) ...[
                const SizedBox(height: AppSpacing.lg),
                Semantics(
                  label: 'Téléchargement',
                  value: '$percent %',
                  excludeSemantics: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Téléchargement…',
                              style: textTheme.bodySmall,
                            ),
                          ),
                          Text(
                            '$percent %',
                            style: textTheme.labelMedium?.copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        child: LinearProgressIndicator(
                          value: _progress,
                          minHeight: 6,
                          backgroundColor: colors.surfaceSunken,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(colors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (error != null) ...[
                const SizedBox(height: AppSpacing.base),
                AppAlert(variant: AlertVariant.destructive, description: error),
              ],
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                text: 'Mettre à jour',
                icon: Icons.download_rounded,
                size: ButtonSize.lg,
                isLoading: _isDownloading,
                onPressed: _downloadAndInstall,
              ),
              if (!_isDownloading) ...[
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: 52,
                  child: TextButton(
                    onPressed: _skip,
                    style:
                        TextButton.styleFrom(foregroundColor: colors.foreground),
                    child: const Text('Plus tard'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
