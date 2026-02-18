import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../../core/di/service_locator.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/app_version_model.dart';

/// Dialog pour afficher une mise à jour disponible
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

  /// Affiche le dialog de mise à jour
  static Future<void> show(
    BuildContext context, {
    required AppVersion version,
    required String currentVersion,
    VoidCallback? onSkip,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
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
        if (mounted) {
          setState(() => _progress = progress);
        }
      },
    );

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() {
          _isDownloading = false;
          _error = failure.message;
        });
      },
      (filePath) async {
        setState(() => _isDownloading = false);

        if (!mounted) return;
        Navigator.of(context).pop();

        // Ouvre l'APK pour installation
        final openResult = await OpenFilex.open(filePath);
        if (openResult.type != ResultType.done && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Impossible d\'ouvrir le fichier: ${openResult.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AlertDialog(
      backgroundColor: colors.bgSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.base),
            ),
            child: Icon(
              Icons.system_update,
              color: colors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Mise à jour disponible',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Versions
            _buildVersionInfo(colors),
            const SizedBox(height: 16),

            // Changelog
            if (widget.version.changelog != null &&
                widget.version.changelog!.isNotEmpty) ...[
              Text(
                'Nouveautés',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.bgPrimary,
                  borderRadius: BorderRadius.circular(AppRadius.base),
                  border: Border.all(color: colors.borderPrimary),
                ),
                child: Text(
                  widget.version.changelog!,
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Taille du fichier
            Row(
              children: [
                Icon(
                  Icons.folder_outlined,
                  size: 16,
                  color: colors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Taille: ${widget.version.formattedFileSize}',
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),

            // Progress bar si téléchargement en cours
            if (_isDownloading) ...[
              const SizedBox(height: 20),
              Text(
                'Téléchargement en cours...',
                style: TextStyle(
                  fontSize: 13,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: colors.borderPrimary,
                  valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(_progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12,
                  color: colors.textSecondary,
                ),
              ),
            ],

            // Erreur
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.base),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 20,
                      color: colors.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: _isDownloading
          ? null
          : [
              TextButton(
                onPressed: () {
                  widget.onSkip?.call();
                  Navigator.of(context).pop();
                },
                child: Text(
                  'Plus tard',
                  style: TextStyle(color: colors.textSecondary),
                ),
              ),
              FilledButton(
                onPressed: _downloadAndInstall,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                ),
                child: const Text('Mettre à jour'),
              ),
            ],
    );
  }

  Widget _buildVersionInfo(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.bgPrimary,
        borderRadius: BorderRadius.circular(AppRadius.base),
        border: Border.all(color: colors.borderPrimary),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Text(
                  'Version actuelle',
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.currentVersion,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward,
            color: colors.primary,
            size: 20,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Nouvelle version',
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.version.versionName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colors.success,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
