import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/entretien_model.dart';
import '../../../data/models/vehicule_model.dart';
import '../../widgets/widgets.dart';
import 'entretien_form_screen.dart';
import 'logic/entretien_catalog.dart';
import 'logic/entretien_history_controller.dart';
import 'logic/fleet_status.dart';
import 'types_entretien_screen.dart';
import 'vehicule_entretiens_screen.dart';
import 'widgets/entretien_detail_sheet.dart';
import 'widgets/fleet_dashboard.dart';
import 'widgets/history_filters_sheet.dart';
import 'widgets/history_list.dart';
import 'widgets/history_toolbar.dart';

enum _Tab { echeances, historique }

/// Page « Entretiens » de l'atelier (Administrateur et Mécanicien).
///
/// Deux vues : « Échéances » (la flotte par urgence, point focal = combien
/// de véhicules en retard) et « Historique » (tous les entretiens, filtres,
/// défilement infini). L'action principale, « Nouvel entretien », est dans
/// le dock ; les types d'entretien sont accessibles depuis la barre de titre.
class EntretiensScreen extends StatefulWidget {
  const EntretiensScreen({super.key});

  @override
  State<EntretiensScreen> createState() => _EntretiensScreenState();
}

class _EntretiensScreenState extends State<EntretiensScreen>
    with DockNoticeMixin {
  _Tab _tab = _Tab.echeances;

  // Échéances.
  bool _fleetLoading = true;
  String? _fleetError;
  List<FleetVehicleStatus> _fleet = const [];
  List<Vehicule> _vehicules = const [];

  // Historique.
  final _history = EntretienHistoryController();
  final _historyScroll = ScrollController();
  late final VoidCallback _onHistoryScroll =
      HistoryList.infiniteScroll(_historyScroll, _history);
  bool _historyStarted = false;

  @override
  void initState() {
    super.initState();
    _historyScroll.addListener(_onHistoryScroll);
    _loadFleet();
  }

  @override
  void dispose() {
    _historyScroll
      ..removeListener(_onHistoryScroll)
      ..dispose();
    _history.dispose();
    super.dispose();
  }

  // ---- données ----------------------------------------------------------

  Future<void> _loadFleet() async {
    setState(() {
      _fleetLoading = true;
      _fleetError = null;
    });
    final results = await Future.wait([
      sl.vehiculeRepository.getAllVehicules(),
      sl.entretienRepository.getFleetUpcoming(),
    ]);
    if (!mounted) return;

    String? error;
    var vehicules = _vehicules;
    var upcoming = const <VehiculeProchainEntretien>[];
    results[0].fold((f) => error = f.message, (v) {
      vehicules = v as List<Vehicule>;
    });
    results[1].fold((f) => error ??= f.message, (u) {
      upcoming = u as List<VehiculeProchainEntretien>;
    });

    setState(() {
      _fleetLoading = false;
      _fleetError = error;
      if (error == null) {
        _vehicules = vehicules;
        _fleet = computeFleetStatus(vehicules, upcoming);
      }
    });
  }

  void _selectTab(_Tab tab) {
    setState(() => _tab = tab);
    if (tab == _Tab.historique && !_historyStarted) {
      _historyStarted = true;
      _history.refresh();
    }
  }

  /// Tout ce qu'un enregistrement peut changer.
  Future<void> _reloadAll() async {
    await Future.wait([
      _loadFleet(),
      if (_historyStarted) _history.refresh(),
    ]);
  }

  // ---- navigation -------------------------------------------------------

  Future<void> _create() async {
    clearDockNotice();
    final saved = await EntretienFormScreen.open(context);
    if (saved && mounted) await _reloadAll();
  }

  Future<void> _openVehicle(FleetVehicleStatus status) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            VehiculeEntretiensScreen(vehiculeId: status.vehicule.id),
      ),
    );
    if (mounted) await _reloadAll();
  }

  Future<void> _openTypes() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TypesEntretienScreen()),
    );
    // Les noms de types ont pu changer.
    if (mounted && _historyStarted) await _history.refresh();
  }

  Future<void> _openEntretien(Entretien e) async {
    final action = await EntretienDetailSheet.show(context, e);
    if (!mounted || action == null) return;
    switch (action) {
      case EntretienDetailAction.edit:
        final saved = await EntretienFormScreen.open(context, entretien: e);
        if (saved && mounted) await _reloadAll();
      case EntretienDetailAction.deleted:
        await _reloadAll();
    }
  }

  Future<void> _openFilters() async {
    final catalog = await EntretienCatalog.load();
    if (!mounted) return;
    await catalog.fold(
      (failure) async => showDockError(failure.message),
      (c) async {
        final query = await showHistoryFiltersSheet(
          context,
          query: _history.query,
          types: c.types,
          dossiers: c.dossiers,
          vehicules: _vehicules,
        );
        if (query != null && mounted) await _history.applyQuery(query);
      },
    );
  }

  // ---- build ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final late = _fleet.where((f) => f.level == FleetLevel.late).length;

    return AppPage(
      title: 'Entretiens',
      actions: [
        AppIconButton(
          icon: Icons.category_rounded,
          tooltip: 'Types d\'entretien',
          color: colors.foreground,
          onPressed: _openTypes,
        ),
      ],
      bottom: AppPageBar(
        child: AppSegmented<_Tab>(
          segments: [
            AppSegment(
              value: _Tab.echeances,
              label: 'Échéances',
              count: late > 0 ? late : null,
            ),
            const AppSegment(value: _Tab.historique, label: 'Historique'),
          ],
          selected: _tab,
          onChanged: _selectTab,
        ),
      ),
      body: IndexedStack(
        index: _tab.index,
        children: [
          FleetDashboard(
            loading: _fleetLoading,
            error: _fleetError,
            fleet: _fleet,
            onRefresh: _loadFleet,
            onOpenVehicle: _openVehicle,
          ),
          ListenableBuilder(
            listenable: _history,
            builder: (context, _) => AppListView(
              controller: _historyScroll,
              onRefresh: _history.refresh,
              header: [
                HistoryToolbar(
                  title: 'Tous les entretiens',
                  total: _history.total,
                  loaded: _history.isLoaded,
                  query: _history.query,
                  onFilters: _openFilters,
                  extraFilterCount: _history.query.vehiculeId != null ? 1 : 0,
                ),
                ...HistoryList.states(
                  _history,
                  emptyMessage: _history.query.activeFilterCount > 0 ||
                          _history.query.vehiculeId != null
                      ? 'Aucun entretien ne correspond aux filtres'
                      : 'Aucun entretien enregistré',
                ),
              ],
              itemCount: HistoryList.itemCount(_history),
              itemBuilder: (context, i) => HistoryList.item(
                context,
                _history,
                i,
                showVehicle: true,
                onTap: _openEntretien,
              ),
              footer: HistoryList.footer(_history),
            ),
          ),
        ],
      ),
      dock: AppDock(
        actions: [
          DockAction(
            label: 'Nouvel entretien',
            icon: Icons.add_rounded,
            onPressed: _create,
          ),
        ],
        notice: dockNotice,
        onDismissNotice: clearDockNotice,
      ),
    );
  }
}
