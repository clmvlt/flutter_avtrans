import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/services/update_checker_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/display_format.dart';
import '../../../data/models/app_version_model.dart';
import '../../../data/models/update_check_response.dart';
import '../../widgets/widgets.dart';
import 'widgets/update_hero_card.dart';
import 'widgets/version_detail_sheet.dart';
import 'widgets/version_row.dart';

/// Page des mises à jour de l'application : état en carte hero (à jour ou
/// mise à jour disponible), « Télécharger et installer » dans le dock
/// (Android), historique des versions dont le détail s'ouvre en feuille.
class UpdatesScreen extends StatefulWidget {
  const UpdatesScreen({super.key});

  @override
  State<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends State<UpdatesScreen> with DockNoticeMixin {
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

  /// Une vraie mise à jour n'est disponible que si le versionName proposé est
  /// strictement plus récent que celui installé (le versionCode est peu fiable).
  bool get _hasRealUpdate {
    final check = _updateCheck;
    final latest = check?.latestVersion;
    if (check == null || latest == null || !check.updateAvailable) return false;
    return UpdateCheckerService.isVersionNewer(
        latest.versionName, _currentVersion);
  }

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

  /// « Réessayer » de l'état d'erreur : repart du squelette.
  Future<void> _retry() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    await _initialize();
  }

  Future<void> _refresh() async {
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
    if (!mounted) return;
    if (_currentVersionCode == 0) {
      // Numéro de build illisible : pas de vérification possible, mais la
      // page ne reste pas bloquée sur le chargement.
      if (_isLoading) setState(() => _isLoading = false);
      return;
    }

    setState(() => _isChecking = true);

    final result =
        await sl.appVersionRepository.checkForUpdate(_currentVersionCode);

    if (!mounted) return;

    result.fold(
      (failure) {
        if (_updateCheck != null) {
          // Un état est déjà affiché : on le garde, l'erreur va au dock.
          setState(() => _isChecking = false);
          showDockError(failure.message);
        } else {
          setState(() {
            _error = failure.message;
            _isChecking = false;
            _isLoading = false;
          });
        }
      },
      (response) => setState(() {
        _updateCheck = response;
        _error = null;
        _isChecking = false;
        _isLoading = false;
      }),
    );
  }

  Future<void> _loadAllVersions() async {
    final result = await sl.appVersionRepository.getAllVersions();

    if (!mounted) return;

    result.fold(
      (failure) {}, // Échec silencieux pour l'historique
      (versions) => setState(() => _allVersions = versions),
    );
  }

  Future<void> _downloadAndInstall(AppVersion version) async {
    if (_downloadingVersionId != null) return;
    clearDockNotice();

    if (!Platform.isAndroid) {
      showDockError(
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
    setState(() => _downloadingVersionId = null);

    final filePath = result.fold<String?>(
      (failure) {
        showDockError(failure.message);
        return null;
      },
      (path) => path,
    );
    if (filePath == null) return;

    // Ouvre l'APK pour installation
    final openResult = await OpenFilex.open(filePath);
    if (!mounted) return;
    if (openResult.type != ResultType.done) {
      showDockError('Impossible d\'ouvrir le fichier : ${openResult.message}');
    }
  }

  Future<void> _openVersion(AppVersion version) async {
    final isCurrent = version.versionCode == _currentVersionCode;
    final install = await VersionDetailSheet.show(
      context,
      version: version,
      isCurrent: isCurrent,
      canInstall:
          !isCurrent && Platform.isAndroid && _downloadingVersionId == null,
    );
    if (!install || !mounted) return;
    await _downloadAndInstall(version);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final latest = _hasRealUpdate ? _updateCheck!.latestVersion : null;
    final ready = !_isLoading && _error == null;

    return AppPage(
      title: 'Mises à jour',
      actions: [
        if (_isChecking)
          Semantics(
            label: 'Vérification en cours',
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.primary,
                  ),
                ),
              ),
            ),
          )
        else
          AppIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Vérifier les mises à jour',
            color: colors.foreground,
            onPressed: _refresh,
          ),
      ],
      body: _buildBody(latest),
      dock: AppDock(
        actions: [
          if (ready && latest != null && Platform.isAndroid)
            DockAction(
              label: 'Télécharger et installer',
              icon: Icons.download_rounded,
              isLoading: _downloadingVersionId == latest.id,
              onPressed: _downloadingVersionId != null
                  ? null
                  : () => _downloadAndInstall(latest),
            ),
        ],
        notice: dockNotice,
        onDismissNotice: clearDockNotice,
      ),
    );
  }

  Widget _buildBody(AppVersion? latest) {
    if (_isLoading) {
      return const AppScrollView(
        children: [
          AppHeroSkeleton(showFigure: false),
          SizedBox(height: AppSpacing.lg),
          AppListSkeleton(rows: 3),
        ],
      );
    }

    final error = _error;
    if (error != null) {
      return AppScrollView(
        children: [
          AppErrorState(message: error, onRetry: _retry),
        ],
      );
    }

    return AppScrollView(
      onRefresh: _refresh,
      children: [
        UpdateHeroCard(
          currentVersion: _currentVersion,
          currentVersionCode: _currentVersionCode,
          checking: _isChecking,
          checked: _updateCheck != null,
          latest: latest,
          downloadProgress:
              latest != null && _downloadingVersionId == latest.id
                  ? _downloadProgress
                  : null,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppSectionHeader(
          title: 'Historique des versions',
          summary: _allVersions.isEmpty
              ? null
              : DisplayFormat.plural(_allVersions.length, 'version'),
        ),
        if (_allVersions.isEmpty)
          const AppEmptyCard(
            icon: Icons.history_rounded,
            message: 'Aucune version dans l\'historique',
          )
        else
          _buildHistory(),
      ],
    );
  }

  Widget _buildHistory() {
    final colors = context.colors;
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        children: [
          for (var i = 0; i < _allVersions.length; i++) ...[
            if (i > 0)
              // Aligné sur le texte : marge 16 + boîte d'icône 40 + 12.
              Divider(
                height: 1,
                thickness: 1,
                color: colors.border,
                indent: 68,
              ),
            VersionRow(
              key: ValueKey(_allVersions[i].id),
              version: _allVersions[i],
              isCurrent: _allVersions[i].versionCode == _currentVersionCode,
              downloadProgress: _downloadingVersionId == _allVersions[i].id
                  ? _downloadProgress
                  : null,
              onTap: () => _openVersion(_allVersions[i]),
            ),
          ],
        ],
      ),
    );
  }
}
