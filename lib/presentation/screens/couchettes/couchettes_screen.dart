import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/display_format.dart';
import '../../../data/models/models.dart';
import '../../widgets/widgets.dart';
import '../absences/widgets/request_blocks.dart';
import 'widgets/couchette_detail_sheet.dart';
import 'widgets/couchette_hero.dart';
import 'widgets/couchette_visuals.dart';

/// Page « Mes couchettes » : hero de la couchette du jour, historique
/// paginé, détail en feuille, déclaration du jour dans le dock (un tap, sans
/// formulaire : le serveur prend la date du jour).
class CouchettesScreen extends StatefulWidget {
  const CouchettesScreen({super.key});

  @override
  State<CouchettesScreen> createState() => _CouchettesScreenState();
}

class _CouchettesScreenState extends State<CouchettesScreen>
    with DockNoticeMixin {
  final List<Couchette> _couchettes = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  String? _error;
  bool _isCreating = false;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadCouchettes();
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
      _loadMoreCouchettes();
    }
  }

  /// [silent] : tirer pour rafraîchir, la liste reste affichée pendant l'appel.
  Future<void> _loadCouchettes({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    final result = await sl.couchetteRepository.getMyCouchettes(page: 0);
    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        _error = failure.message;
        _isLoading = false;
      }),
      (response) => setState(() {
        _error = null;
        _couchettes
          ..clear()
          ..addAll(response.content);
        _currentPage = 0;
        _hasMore = !response.last;
        _isLoading = false;
      }),
    );
  }

  Future<void> _refresh() => _loadCouchettes(silent: true);

  Future<void> _loadMoreCouchettes() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);

    final result = await sl.couchetteRepository.getMyCouchettes(
      page: _currentPage + 1,
    );
    if (!mounted) return;

    result.fold(
      (_) => setState(() => _isLoadingMore = false),
      (response) => setState(() {
        _couchettes.addAll(response.content);
        _currentPage++;
        _hasMore = !response.last;
        _isLoadingMore = false;
      }),
    );
  }

  // ---- actions ----------------------------------------------------------

  Future<void> _createCouchette() async {
    if (_isCreating) return;
    clearDockNotice();
    setState(() => _isCreating = true);

    final result = await sl.couchetteRepository.createCouchette();
    if (!mounted) return;

    setState(() => _isCreating = false);

    result.fold(
      (failure) => showDockError(failure.message),
      (couchette) {
        setState(() => _couchettes.insert(0, couchette));
        showDockSuccess('Couchette ajoutée pour aujourd\'hui');
      },
    );
  }

  Future<void> _openDetail(Couchette couchette) async {
    clearDockNotice();
    final action = await CouchetteDetailSheet.show(context, couchette);
    if (!mounted || action != CouchetteDetailAction.delete) return;
    await _deleteCouchette(couchette);
  }

  Future<void> _deleteCouchette(Couchette couchette) async {
    final confirmed = await AppConfirmSheet.show(
      context,
      title: 'Supprimer la couchette ?',
      message: 'La couchette du jour sera retirée. '
          'Tu pourras la déclarer à nouveau si besoin.',
      details: CouchetteRecap(couchette: couchette),
      confirmLabel: 'Supprimer la couchette',
      confirmIcon: Icons.delete_outline_rounded,
      cancelLabel: 'Garder ma couchette',
    );
    if (!confirmed || !mounted) return;

    final result = await sl.couchetteRepository.deleteCouchette(couchette.uuid);
    if (!mounted) return;

    result.fold(
      (failure) => showDockError(failure.message),
      (_) {
        setState(
          () => _couchettes.removeWhere((c) => c.uuid == couchette.uuid),
        );
        showDockSuccess('Couchette supprimée');
      },
    );
  }

  // ---- build ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Mes couchettes',
      body: _buildBody(),
      dock: AppDock(
        actions: [
          DockAction(
            label: 'Déclarer une couchette',
            icon: Icons.add_rounded,
            isLoading: _isCreating,
            onPressed: _isCreating ? null : _createCouchette,
            semanticsHint: 'Déclare une couchette pour aujourd\'hui',
          ),
        ],
        notice: dockNotice,
        onDismissNotice: clearDockNotice,
        absorbing: _isCreating,
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
        children: [AppErrorState(message: _error!, onRetry: _loadCouchettes)],
      );
    }

    Couchette? today;
    for (final c in _couchettes) {
      if (isTodayCouchette(c)) {
        today = c;
        break;
      }
    }
    final todayCouchette = today;

    final header = <Widget>[
      CouchetteHero(
        declared: todayCouchette != null,
        onTap: todayCouchette == null
            ? null
            : () => _openDetail(todayCouchette),
      ),
      const SizedBox(height: AppSpacing.lg),
      if (_couchettes.isEmpty)
        const AppEmptyCard(
          icon: Icons.hotel_outlined,
          message: 'Aucune couchette',
          detail: 'Tes couchettes déclarées apparaîtront ici.',
        )
      else
        AppSectionHeader(
          title: 'Historique',
          summary: _hasMore
              ? null
              : DisplayFormat.plural(_couchettes.length, 'couchette'),
        ),
    ];

    return AppListView(
      controller: _scrollController,
      onRefresh: _refresh,
      header: header,
      itemCount: _couchettes.length,
      itemBuilder: (context, index) {
        final c = _couchettes[index];
        return AppCard(
          padding: EdgeInsets.zero,
          child: CouchetteRow(
            couchette: c,
            onTap: () => _openDetail(c),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        );
      },
      footer: _isLoadingMore ? const LoadMoreFooter() : null,
    );
  }
}
