import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/display_format.dart';
import '../../../data/models/models.dart';
import '../../widgets/widgets.dart';
import 'sign_screen.dart';
import 'widgets/signature_detail_sheet.dart';

/// Mes signatures : une ligne par signature passée (détail au tap), et
/// « Signer mes heures » dans le dock quand une signature est attendue.
class SignaturesScreen extends StatefulWidget {
  const SignaturesScreen({super.key});

  @override
  State<SignaturesScreen> createState() => _SignaturesScreenState();
}

class _SignaturesScreenState extends State<SignaturesScreen>
    with DockNoticeMixin {
  List<Signature> _signatures = [];
  bool _isLoading = true;
  String? _error;

  /// Vérification « faut-il signer ? » en cours (bouton du dock).
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _loadSignatures();
  }

  Future<void> _loadSignatures() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await sl.signatureRepository.getMySignatures();

    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        _error = failure.message;
        _isLoading = false;
      }),
      (signatures) => setState(() {
        // Copie modifiable : une nouvelle signature y est insérée en tête.
        _signatures = [...signatures];
        _isLoading = false;
      }),
    );
  }

  Future<void> _openSignScreen() async {
    clearDockNotice();
    setState(() => _checking = true);
    final summaryResult =
        await sl.signatureRepository.getLastSignatureSummary();
    if (!mounted) return;
    setState(() => _checking = false);

    final summary = summaryResult.fold<SignatureSummary?>(
      (failure) {
        showDockError(failure.message);
        return null;
      },
      (summary) => summary,
    );
    if (summary == null) return;

    if (!summary.needsToSign) {
      showDockNotice(
        'Tu as déjà signé tes heures pour cette période',
        variant: AlertVariant.info,
      );
      return;
    }

    final result = await Navigator.of(context).push<Signature>(
      MaterialPageRoute(
        builder: (_) => SignScreen(heuresLastMonth: summary.heuresLastMonth),
      ),
    );

    if (result != null && mounted) {
      setState(() => _signatures.insert(0, result));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Mes signatures',
      body: _buildBody(),
      dock: AppDock(
        notice: dockNotice,
        onDismissNotice: clearDockNotice,
        actions: [
          DockAction(
            label: 'Signer mes heures',
            icon: Icons.draw_rounded,
            isLoading: _checking,
            onPressed: _checking ? null : _openSignScreen,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const AppScrollView(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xs,
              0,
              AppSpacing.xs,
              AppSpacing.md,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: AppSkeleton(width: 100, height: 16),
            ),
          ),
          AppListSkeleton(rows: 4),
        ],
      );
    }

    if (_error != null) {
      return AppScrollView(
        onRefresh: _loadSignatures,
        children: [AppErrorState(message: _error!, onRetry: _loadSignatures)],
      );
    }

    if (_signatures.isEmpty) {
      return AppScrollView(
        onRefresh: _loadSignatures,
        children: const [
          AppEmptyCard(
            icon: Icons.draw_outlined,
            message: 'Aucune signature pour l\'instant',
            detail: 'Chaque mois, signe tes heures avec le bouton en bas.',
          ),
        ],
      );
    }

    return AppScrollView(
      onRefresh: _loadSignatures,
      children: [
        AppSectionHeader(
          title: 'Historique',
          summary: DisplayFormat.plural(_signatures.length, 'signature'),
        ),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            children: [
              for (final s in _signatures)
                SignatureRow(key: ValueKey(s.uuid), signature: s),
            ],
          ),
        ),
      ],
    );
  }
}
