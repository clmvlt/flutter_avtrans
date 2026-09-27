import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/display_format.dart';
import '../../../data/models/models.dart';
import '../../widgets/widgets.dart';
import '../absences/widgets/request_blocks.dart';
import '../absences/widgets/request_widgets.dart';
import 'widgets/acompte_detail_sheet.dart';
import 'widgets/acompte_filters.dart';
import 'widgets/acompte_visuals.dart';
import 'widgets/acomptes_hero.dart';
import 'widgets/create_acompte_sheet.dart';

/// Page « Mes acomptes » : hero des demandes en attente (nombre et montant),
/// liste paginée filtrable, détail en feuille, demande dans le dock.
class AcomptesScreen extends StatefulWidget {
  const AcomptesScreen({super.key});

  @override
  State<AcomptesScreen> createState() => _AcomptesScreenState();
}

class _AcomptesScreenState extends State<AcomptesScreen> with DockNoticeMixin {
  final List<Acompte> _acomptes = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  String? _error;

  AcompteFilters _filters = AcompteFilters.none;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadAcomptes();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ---- données ----------------------------------------------------------

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMoreAcomptes();
    }
  }

  AcompteListParams _buildParams({int page = 0}) {
    return AcompteListParams(
      page: page,
      size: 20,
      startDate: _filters.startDate,
      endDate: _filters.endDate,
      status: _filters.status,
      montantMin: _filters.montantMin,
      montantMax: _filters.montantMax,
      sortBy: 'createdAt',
      sortDirection: SortDirection.desc,
    );
  }

  /// [silent] : la liste reste affichée pendant l'appel (tirer pour
  /// rafraîchir, rechargement après une annulation).
  Future<void> _loadAcomptes({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    final result = await sl.acompteRepository.getMyAcomptes(_buildParams());
    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        _error = failure.message;
        _isLoading = false;
      }),
      (response) => setState(() {
        _error = null;
        _acomptes
          ..clear()
          ..addAll(response.content);
        _currentPage = 0;
        _hasMore = !response.last;
        _isLoading = false;
      }),
    );
  }

  Future<void> _refresh() => _loadAcomptes(silent: true);

  Future<void> _loadMoreAcomptes() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);

    final result = await sl.acompteRepository.getMyAcomptes(
      _buildParams(page: _currentPage + 1),
    );
    if (!mounted) return;

    result.fold(
      (_) => setState(() => _isLoadingMore = false),
      (response) => setState(() {
        _acomptes.addAll(response.content);
        _currentPage++;
        _hasMore = !response.last;
        _isLoadingMore = false;
      }),
    );
  }

  // ---- actions ----------------------------------------------------------

  void _applyFilters(AcompteFilters filters) {
    setState(() => _filters = filters);
    _loadAcomptes();
  }

  Future<void> _openFilters() async {
    final result = await AcompteFiltersSheet.show(context, initial: _filters);
    if (!mounted || result == null) return;
    _applyFilters(result);
  }

  Future<void> _openCreate() async {
    clearDockNotice();
    final acompte = await CreateAcompteSheet.show(context);
    if (!mounted || acompte == null) return;
    setState(() => _acomptes.insert(0, acompte));
    showDockSuccess('Demande envoyée');
  }

  Future<void> _openDetail(Acompte acompte) async {
    clearDockNotice();
    final action = await AcompteDetailSheet.show(context, acompte);
    if (!mounted || action != AcompteDetailAction.cancel) return;
    await _cancelAcompte(acompte);
  }

  Future<void> _cancelAcompte(Acompte acompte) async {
    final confirmed = await AppConfirmSheet.show(
      context,
      title: 'Annuler la demande ?',
      message: 'Ta demande d\'acompte sera retirée. '
          'Tu pourras en refaire une si besoin.',
      details: AcompteRecap(acompte: acompte),
      confirmLabel: 'Annuler la demande',
      confirmIcon: Icons.close_rounded,
      cancelLabel: 'Garder ma demande',
    );
    if (!confirmed || !mounted) return;

    final result = await sl.acompteRepository.cancelAcompte(acompte.uuid);
    if (!mounted) return;

    result.fold(
      (failure) => showDockError(failure.message),
      (_) {
        showDockSuccess('Demande annulée');
        // Recharge la liste pour refléter les changements.
        _loadAcomptes(silent: true);
      },
    );
  }

  // ---- build ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Mes acomptes',
      actions: [
        FilterIconButton(count: _filters.count, onPressed: _openFilters),
      ],
      body: _buildBody(),
      dock: AppDock(
        actions: [
          DockAction(
            label: 'Demander un acompte',
            icon: Icons.add_rounded,
            onPressed: _openCreate,
          ),
        ],
        notice: dockNotice,
        onDismissNotice: clearDockNotice,
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const AppScrollView(children: [RequestsSkeleton()]);
    }

    if (_error != null) {
      return AppScrollView(
        onRefresh: _refresh,
        children: [AppErrorState(message: _error!, onRetry: _loadAcomptes)],
      );
    }

    final pending =
        _acomptes.where((a) => a.status == AcompteStatus.pending).toList();
    final pendingAmount = pending.fold<double>(0, (sum, a) => sum + a.montant);

    final header = <Widget>[
      AcomptesHero(
        pendingCount: pending.length,
        pendingAmount: pendingAmount,
        total: _acomptes.length,
        filtered: _filters.isActive,
      ),
      if (_filters.isActive) ...[
        const SizedBox(height: AppSpacing.md),
        ActiveFiltersRow(
          filters: [
            for (final f in _filters.labels)
              ActiveFilter(label: f.label, icon: f.icon),
          ],
          onClearAll: () => _applyFilters(AcompteFilters.none),
        ),
      ],
      const SizedBox(height: AppSpacing.lg),
      if (_acomptes.isEmpty)
        AppEmptyCard(
          icon: _filters.isActive
              ? Icons.filter_list_off_rounded
              : Icons.payments_outlined,
          message: _filters.isActive
              ? 'Aucun acompte ne correspond aux filtres'
              : 'Aucune demande d\'acompte',
          detail: _filters.isActive ? null : 'Tes demandes apparaîtront ici.',
          actionLabel: _filters.isActive ? 'Effacer' : null,
          onAction: _filters.isActive
              ? () => _applyFilters(AcompteFilters.none)
              : null,
        )
      else
        AppSectionHeader(
          title: 'Mes demandes',
          summary: _hasMore
              ? null
              : DisplayFormat.plural(_acomptes.length, 'demande'),
        ),
    ];

    return AppListView(
      controller: _scrollController,
      onRefresh: _refresh,
      header: header,
      itemCount: _acomptes.length,
      itemBuilder: (context, index) {
        final a = _acomptes[index];
        return AppCard(
          padding: EdgeInsets.zero,
          child: AcompteRow(
            acompte: a,
            onTap: () => _openDetail(a),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        );
      },
      footer: _isLoadingMore ? const LoadMoreFooter() : null,
    );
  }
}
