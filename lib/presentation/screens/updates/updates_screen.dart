import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/app_version_model.dart';
import '../../../data/models/update_check_response.dart';

/// Page des mises à jour de l'application
class UpdatesScreen extends StatefulWidget {
  const UpdatesScreen({super.key});

  @override
  State<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends State<UpdatesScreen> {
  bool _isLoading = true;
  bool _isChecking = false;
  String? _error;

  String _currentVersion = '';
  int _currentVersionCode = 0;
  UpdateCheckResponse? _updateCheck;
  List<AppVersion> _allVersions = [];

  // État du téléchargement
  String? _downloadingVersionId;
  double _downloadProgress = 0;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadPackageInfo();
    await _checkForUpdates();
    await _loadAllVersions();
  }

  Future<void> _loadPackageInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _currentVersion = packageInfo.version;
      _currentVersionCode = int.tryParse(packageInfo.buildNumber) ?? 0;
    });
  }

  Future<void> _checkForUpdates() async {
    if (_currentVersionCode == 0) return;

    setState(() => _isChecking = true);

    final result =
        await sl.appVersionRepository.checkForUpdate(_currentVersionCode);

    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        _error = failure.message;
        _isChecking = false;
        _isLoading = false;
      }),
      (response) => setState(() {
        _updateCheck = response;
        _isChecking = false;
        _isLoading = false;
      }),
    );
  }

  Future<void> _loadAllVersions() async {
    final result = await sl.appVersionRepository.getAllVersions();

    if (!mounted) return;

    result.fold(
      (failure) => {}, // Silent fail for version list
      (versions) => setState(() => _allVersions = versions),
    );
  }

  Future<void> _downloadAndInstall(AppVersion version) async {
    if (!Platform.isAndroid) {
      _showError(
          'L\'installation automatique n\'est disponible que sur Android');
      return;
    }

    setState(() {
      _downloadingVersionId = version.id;
      _downloadProgress = 0;
    });

    final result = await sl.appVersionRepository.downloadApk(
      version.id,
      version.originalFileName,
      (progress) {
        if (mounted) {
          setState(() => _downloadProgress = progress);
        }
      },
    );

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() => _downloadingVersionId = null);
        _showError(failure.message);
      },
      (filePath) async {
        setState(() => _downloadingVersionId = null);

        // Ouvre l'APK pour installation
        final openResult = await OpenFilex.open(filePath);
        if (openResult.type != ResultType.done) {
          _showError('Impossible d\'ouvrir le fichier: ${openResult.message}');
        }
      },
    );
  }

  void _showError(String message) {
    final colors = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: colors.error, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: colors.bgSecondary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bgPrimary,
      appBar: AppBar(
        title: const Text('Mises à jour'),
        backgroundColor: colors.bgSecondary,
        actions: [
          IconButton(
            icon: _isChecking
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.primary,
                    ),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isChecking
                ? null
                : () {
                    _checkForUpdates();
                    _loadAllVersions();
                  },
          ),
        ],
      ),
      body: _buildBody(colors),
    );
  }

  Widget _buildBody(AppColors colors) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: colors.primary),
            const SizedBox(height: AppSpacing.base),
            Text(
              'Vérification des mises à jour...',
              style: TextStyle(color: colors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: colors.error),
              const SizedBox(height: AppSpacing.base),
              Text(
                _error!,
                style: TextStyle(color: colors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.base),
              ElevatedButton(
                onPressed: _initialize,
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _checkForUpdates();
        await _loadAllVersions();
      },
      color: colors.primary,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.base),
        children: [
          _buildCurrentVersionCard(colors),
          const SizedBox(height: AppSpacing.base),
          if (_updateCheck?.updateAvailable == true)
            _buildUpdateAvailableCard(colors),
          if (_allVersions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            _buildVersionHistorySection(colors),
          ],
        ],
      ),
    );
  }

  Widget _buildCurrentVersionCard(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: colors.bgSecondary,
        borderRadius: BorderRadius.circular(AppRadius.base),
        border: Border.all(color: colors.borderPrimary),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(Icons.phone_android, color: colors.primary, size: 24),
          ),
          const SizedBox(width: AppSpacing.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Version actuelle',
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.textSecondary,
                  ),
                ),
                Text(
                  '$_currentVersion ($_currentVersionCode)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (_updateCheck?.updateAvailable == false)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: colors.success, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'À jour',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
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

  Widget _buildUpdateAvailableCard(AppColors colors) {
    final latestVersion = _updateCheck!.latestVersion!;
    final isDownloading = _downloadingVersionId == latestVersion.id;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.base),
        border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.system_update, color: colors.primary, size: 24),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Mise à jour disponible',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colors.primary,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(
                  'v${latestVersion.versionName}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Icon(Icons.storage, size: 16, color: colors.textSecondary),
              const SizedBox(width: 4),
              Text(
                latestVersion.formattedFileSize,
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
            ],
          ),
          if (latestVersion.changelog != null &&
              latestVersion.changelog!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Nouveautés:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              latestVersion.changelog!,
              style: TextStyle(
                fontSize: 13,
                color: colors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.base),
          if (isDownloading)
            Column(
              children: [
                LinearProgressIndicator(
                  value: _downloadProgress,
                  backgroundColor: colors.bgTertiary,
                  valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${(_downloadProgress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            )
          else if (Platform.isAndroid)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _downloadAndInstall(latestVersion),
                icon: const Icon(Icons.download),
                label: const Text('Télécharger et installer'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVersionHistorySection(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Historique des versions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ...(_allVersions.map((version) => _buildVersionItem(version, colors))),
      ],
    );
  }

  Widget _buildVersionItem(AppVersion version, AppColors colors) {
    final isCurrentVersion = version.versionCode == _currentVersionCode;
    final isDownloading = _downloadingVersionId == version.id;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.bgSecondary,
        borderRadius: BorderRadius.circular(AppRadius.base),
        border: Border.all(
          color: isCurrentVersion ? colors.primary : colors.borderPrimary,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'v${version.versionName}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (isCurrentVersion) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Installée',
                          style: TextStyle(
                            fontSize: 10,
                            color: colors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${version.formattedFileSize} - ${_formatDate(version.createdAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.textMuted,
                  ),
                ),
                if (version.changelog != null &&
                    version.changelog!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    version.changelog!,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (!isCurrentVersion && Platform.isAndroid)
            isDownloading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      value: _downloadProgress,
                      color: colors.primary,
                    ),
                  )
                : IconButton(
                    icon: Icon(Icons.download, color: colors.primary),
                    onPressed: () => _downloadAndInstall(version),
                  ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
