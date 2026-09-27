import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/display_format.dart';
import '../../../data/models/entretien_model.dart';
import '../../../data/models/vehicule_model.dart';
import '../../widgets/widgets.dart';
import 'entretien_form_screen.dart';
import 'logic/entretien_catalog.dart';
import 'logic/entretien_history_controller.dart';
import 'logic/fleet_status.dart';
import 'widgets/config_sheet.dart';
import 'widgets/echeance_done_sheet.dart';
import 'widgets/entretien_detail_sheet.dart';
import 'widgets/fleet_widgets.dart';
import 'widgets/history_filters_sheet.dart';
import 'widgets/history_list.dart';
import 'widgets/history_toolbar.dart';
import 'widgets/vehicule_configs_view.dart';

enum _Tab { entretiens, suivi }

/// Entretiens d'un véhicule (Administrateur et Mécanicien).
///
/// Onglet « Entretiens » : le véhicule en hero, ses échéances (à valider
/// d'un geste quand l'entretien est fait), puis son historique. Onglet
/// « Suivi » : les rappels périodiques configurés pour ce véhicule.
class VehiculeEntretiensScreen extends StatefulWidget {
  const VehiculeEntretiensScreen({super.key, required this.vehiculeId});

  final String vehiculeId;

  @override
  State<VehiculeEntretiensScreen> createState() =>
      _VehiculeEntretiensScreenState();
}

class _VehiculeEntretiensScreenState extends State<VehiculeEntretiensScreen>
    with DockNoticeMixin {
  _Tab _tab = _Tab.entretiens;

  bool _loading = true;
  String? _error;
  Vehicule? _vehicule;
  List<FleetAlert> _alerts = const [];

  bool _configsLoading = true;
  String? _configsError;
  List<VehiculeTypeEntretien> _configs = const [];

  late final _history =
      EntretienHistoryController(vehiculeId: widget.vehiculeId);
  final _scroll = ScrollController();
  late final VoidCallback _onScroll =
      HistoryList.infiniteScroll(_scroll, _history);

  bool _quickSaving = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadAll();
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    _history.dispose();
    super.dispose();
  }

  // ---- données ----------------------------------------------------------

  Future<void> _loadAll() async {
    await Future.wait([
      _loadVehicle(),
      _loadConfigs(),
      _history.refresh(),
    ]);
  }

  Future<void> _loadVehicle() async {
    setState(() {
      _loading = _vehicule == null;
      _error = null;
    });
    final results = await Future.wait([
      sl.vehiculeRepository.getVehiculeById(widget.vehiculeId),
      sl.entretienRepository.getVehiculeUpcoming(widget.vehiculeId),
    ]);
    if (!mounted) return;
    setState(() {
      _loading = false;
      results[0].fold(
        (f) => _error = f.message,
        (v) => _vehicule = v as Vehicule,
      );
      // Sans échéances (erreur ou aucun suivi) : la page reste utilisable.
      results[1].fold(
        (_) => _alerts = const [],
        (u) => _alerts = alertsOf(u as VehiculeProchainEntretien?),
      );
    });
  }

  Future<void> _loadConfigs() async {
    setState(() {
      _configsLoading = true;
      _configsError = null;
    });
    final result =
        await sl.entretienRepository.getVehiculeConfigs(widget.vehiculeId);
    if (!mounted) return;
    setState(() {
      _configsLoading = false;
      result.fold(
        (f) => _configsError = f.message,
        (c) => _configs = c,
      );
    });
  }

  /// Après un enregistrement : échéances, suivis et historique.
  Future<void> _reloadAfterChange() => _loadAll();

  // ---- actions ----------------------------------------------------------

  Future<void> _create({TypeEntretien? type}) async {
    clearDockNotice();
    final saved = await EntretienFormScreen.open(
      context,
      vehicule: _vehicule,
      initialType: type,
    );
    if (saved && mounted) await _reloadAfterChange();
  }

  Future<void> _markDone(FleetAlert alert) async {
    final choice = await EcheanceDoneSheet.show(
      context,
      alert: alert,
      latestKm: _vehicule?.latestKm,
    );
    if (choice == null || !mounted) return;
    final type = alert.alerte.typeEntretien;

    if (choice == EcheanceDoneChoice.details || type == null) {
      await _create(type: type);
      return;
    }

    setState(() => _quickSaving = true);
    final result = await sl.entretienRepository.createEntretien(
      EntretienCreateRequest(
        vehiculeId: widget.vehiculeId,
        typeEntretienId: type.id,
        dateEntretien: DateTime.now(),
        kilometrage: _vehicule!.latestKm!,
      ),
    );
    if (!mounted) return;
    setState(() => _quickSaving = false);
    await result.fold(
      (failure) async {
        HapticFeedback.heavyImpact();
        showDockError(failure.message);
      },
      (_) async {
        HapticFeedback.mediumImpact();
        showDockSuccess('« ${type.nom} » enregistré.');
        await _reloadAfterChange();
      },
    );
  }

  Future<void> _openEntretien(Entretien e) async {
    final action = await EntretienDetailSheet.show(context, e);
    if (!mounted || action == null) return;
    switch (action) {
      case EntretienDetailAction.edit:
        final saved = await EntretienFormScreen.open(
          context,
          entretien: e,
          vehicule: _vehicule,
        );
        if (saved && mounted) await _reloadAfterChange();
      case EntretienDetailAction.deleted:
        await _reloadAfterChange();
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
        );
        if (query != null && mounted) await _history.applyQuery(query);
      },
    );
  }

  Future<void> _openConfig([VehiculeTypeEntretien? config]) async {
    clearDockNotice();
    final catalog = await EntretienCatalog.load();
    if (!mounted) return;
    final types = catalog.fold((f) {
      showDockError(f.message);
      return null;
    }, (c) => c.types);
    if (types == null) return;

    final configured = _configs.map((c) => c.typeEntretien?.id).toSet();
    final available = types.where((t) => !configured.contains(t.id)).toList();
    if (config == null && available.isEmpty) {
      showDockError(
        types.isEmpty
            ? 'Crée d\'abord un type d\'entretien.'
            : 'Tous les types d\'entretien sont déjà suivis pour ce véhicule.',
      );
      return;
    }

    final changed = await ConfigEntretienSheet.show(
      context,
      vehiculeId: widget.vehiculeId,
      config: config,
      availableTypes: available,
    );
    if (changed && mounted) {
      await Future.wait([_loadConfigs(), _loadVehicle()]);
    }
  }

  // ---- build ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final v = _vehicule;
    final activeConfigs = _configs.where((c) => c.actif).length;

    return AppPage(
      title: v?.immat.toUpperCase() ?? 'Entretiens',
      bottom: AppPageBar(
        child: AppSegmented<_Tab>(
          segments: [
            const AppSegment(value: _Tab.entretiens, label: 'Entretiens'),
            AppSegment(
              value: _Tab.suivi,
              label: 'Suivi',
              count: activeConfigs > 0 ? activeConfigs : null,
            ),
          ],
          selected: _tab,
          onChanged: (t) => setState(() => _tab = t),
        ),
      ),
      body: IndexedStack(
        index: _tab.index,
        children: [
          _buildEntretiensTab(),
          VehiculeConfigsView(
            loading: _configsLoading,
            error: _configsError,
            configs: _configs,
            onRefresh: _loadConfigs,
            onOpen: _openConfig,
          ),
        ],
      ),
      dock: AppDock(
        actions: [
          if (_tab == _Tab.entretiens)
            DockAction(
              label: 'Nouvel entretien',
              icon: Icons.add_rounded,
              onPressed: v == null ? null : () => _create(),
            )
          else
            DockAction(
              label: 'Ajouter un suivi',
              icon: Icons.add_alarm_rounded,
              onPressed: () => _openConfig(),
            ),
        ],
        notice: dockNotice,
        onDismissNotice: clearDockNotice,
        absorbing: _quickSaving,
      ),
    );
  }

  Widget _buildEntretiensTab() {
    if (_loading) {
      return const AppScrollView(
        children: [
          AppHeroSkeleton(),
          SizedBox(height: AppSpacing.lg),
          AppListSkeleton(rows: 3),
        ],
      );
    }
    if (_error != null && _vehicule == null) {
      return AppScrollView(
        onRefresh: _loadAll,
        children: [AppErrorState(message: _error!, onRetry: _loadAll)],
      );
    }

    return ListenableBuilder(
      listenable: _history,
      builder: (context, _) => AppListView(
        controller: _scroll,
        onRefresh: _loadAll,
        header: [
          _VehicleHero(
            vehicule: _vehicule!,
            level: levelOf(_alerts),
            tracked: _alerts.isNotEmpty,
          ),
          const SizedBox(height: AppSpacing.md),
          _EcheancesBlock(
            alerts: _alerts,
            hasConfigs: _configs.isNotEmpty,
            busy: _quickSaving,
            onDone: _markDone,
            onConfigure: () => setState(() => _tab = _Tab.suivi),
          ),
          const SizedBox(height: AppSpacing.lg),
          HistoryToolbar(
            title: 'Historique',
            total: _history.total,
            loaded: _history.isLoaded,
            query: _history.query,
            onFilters: _openFilters,
          ),
          ...HistoryList.states(
            _history,
            emptyMessage: _history.query.activeFilterCount > 0
                ? 'Aucun entretien ne correspond aux filtres'
                : 'Aucun entretien enregistré pour ce véhicule',
          ),
        ],
        itemCount: HistoryList.itemCount(_history),
        itemBuilder: (context, i) => HistoryList.item(
          context,
          _history,
          i,
          showVehicle: false,
          onTap: _openEntretien,
        ),
        footer: HistoryList.footer(_history),
      ),
    );
  }
}

/// Le véhicule en point focal, comme la carte de la page Pointage : l'état
/// en mot (« En retard », « À jour »…), le modèle en sous-ligne, puis le
/// kilométrage en grand chiffre avec la date du relevé.
class _VehicleHero extends StatelessWidget {
  const _VehicleHero({
    required this.vehicule,
    required this.level,
    required this.tracked,
  });

  final Vehicule vehicule;
  final FleetLevel level;
  final bool tracked;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final v = vehicule;
    final model = '${v.brand} ${v.model}'.trim();
    final kmDate = v.latestKmDate;
    final String kmLabel;
    if (kmDate == null) {
      kmLabel = 'Kilométrage';
    } else {
      final day = DisplayFormat.relativeDay(kmDate);
      kmLabel = day == 'Aujourd\'hui' || day == 'Hier'
          ? 'Kilométrage · relevé ${day.toLowerCase()}'
          : 'Kilométrage · relevé le ${DisplayFormat.dateCompact(kmDate)}';
    }

    return AppHeroCard(
      icon: tracked ? level.icon : Icons.directions_car_rounded,
      accent: tracked ? level.color(colors) : colors.domainVehicule,
      title: tracked ? level.label : 'Sans suivi',
      subtitle: model.isEmpty ? null : model,
      child: AppHeroFigure(
        label: kmLabel,
        value: v.latestKm != null ? DisplayFormat.km(v.latestKm!) : 'Aucun relevé',
        muted: v.latestKm == null,
        small: true,
      ),
    );
  }
}

/// Échéances du véhicule, avec « Fait » pour enregistrer l'entretien. Sans
/// aucun suivi : une invitation à en configurer.
class _EcheancesBlock extends StatelessWidget {
  const _EcheancesBlock({
    required this.alerts,
    required this.hasConfigs,
    required this.busy,
    required this.onDone,
    required this.onConfigure,
  });

  final List<FleetAlert> alerts;
  final bool hasConfigs;
  final bool busy;
  final ValueChanged<FleetAlert> onDone;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    if (alerts.isEmpty) {
      if (hasConfigs) return const SizedBox.shrink();
      return AppEmptyCard(
        icon: Icons.notifications_off_outlined,
        message: 'Aucune échéance suivie',
        detail: 'Ajoute un suivi pour être prévenu à temps.',
        actionLabel: 'Configurer',
        onAction: onConfigure,
      );
    }

    final level = levelOf(alerts);
    final tone = switch (level) {
      FleetLevel.late => AppCalloutTone.danger,
      FleetLevel.soon => AppCalloutTone.warning,
      FleetLevel.ok => AppCalloutTone.info,
    };

    return AppCalloutCard(
      title: 'Prochaines échéances',
      tone: tone,
      icon: level.icon,
      children: [
        for (final a in alerts)
          AppListRow(
            title: a.typeLabel,
            subtitle: [a.dueLabel, if (a.targetLabel != null) a.targetLabel!]
                .join(' · '),
            icon: a.isKm ? Icons.route_rounded : Icons.event_rounded,
            iconColor: a.level == FleetLevel.ok
                ? colors.info
                : a.level.color(colors),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            trailing: TextButton(
              onPressed: busy ? null : () => onDone(a),
              style: TextButton.styleFrom(
                foregroundColor: colors.foreground,
                backgroundColor: colors.card.withValues(alpha: 0.7),
                minimumSize: const Size(64, 40),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                textStyle: textTheme.labelLarge,
              ),
              child: const Text('Fait'),
            ),
          ),
      ],
    );
  }
}
