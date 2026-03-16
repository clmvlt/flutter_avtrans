import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../../core/di/service_locator.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/app_version_model.dart';

/// Dialog shadcn/ui pour mise à jour disponible
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
        if (mounted) setState(() => _progress = progress);
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
        final openResult = await OpenFilex.open(filePath);
        if (openResult.type != ResultType.done && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Impossible d\'ouvrir le fichier: ${openResult.message}'),
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
      backgroundColor: colors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: colors.border),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(Icons.system_update, color: colors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Mise à jour disponible',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.foreground,
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
            _buildVersionInfo(colors),
            const SizedBox(height: 16),

            if (widget.version.changelog != null &&
                widget.version.changelog!.isNotEmpty) ...[
              Text(
                'Nouveautés',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.foreground,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.muted,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(
                  widget.version.changelog!,
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.mutedForeground,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            Row(
              children: [
                Icon(Icons.folder_outlined, size: 14, color: colors.mutedForeground),
                const SizedBox(width: 8),
                Text(
                  'Taille: ${widget.version.formattedFileSize}',
                  style: TextStyle(fontSize: 13, color: colors.mutedForeground),
                ),
              ],
            ),

            if (_isDownloading) ...[
              const SizedBox(height: 20),
              Text(
                'Téléchargement en cours...',
                style: TextStyle(fontSize: 13, color: colors.mutedForeground),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.full),
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: colors.muted,
                  valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(_progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 12, color: colors.mutedForeground),
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.errorBg,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: colors.destructive.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, size: 16, color: colors.destructive),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(fontSize: 13, color: colors.destructive),
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
                  style: TextStyle(color: colors.mutedForeground),
                ),
              ),
              FilledButton(
                onPressed: _downloadAndInstall,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.primaryForeground,
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
        color: colors.muted,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Text(
                  'Actuelle',
                  style: TextStyle(fontSize: 11, color: colors.mutedForeground),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.currentVersion,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colors.foreground,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward, color: colors.mutedForeground, size: 16),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Nouvelle',
                  style: TextStyle(fontSize: 11, color: colors.mutedForeground),
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
