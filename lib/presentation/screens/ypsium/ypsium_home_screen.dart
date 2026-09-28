import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/ypsium_models.dart';
import '../../widgets/widgets.dart';
import 'widgets/ypsium_date_bar.dart';
import 'widgets/ypsium_dock_lines.dart';
import 'widgets/ypsium_home_hero.dart';
import 'widgets/ypsium_menu_sheet.dart';
import 'widgets/ypsium_spooler_widgets.dart';
import 'widgets/ypsium_transport_list.dart';
import 'ypsium_login_screen.dart';
import 'ypsium_spooler_screen.dart';
import 'ypsium_transport_detail_screen.dart';
import 'ypsium_vehicule_screen.dart';

/// Accueil Ypsium après connexion : les ordres de transport d'une journée.
///
/// Sélecteur de journée sous le titre, hero « N transports à faire » avec
/// ses compteurs, carte « Envois en attente » seulement s'il reste des
/// envois hors ligne, puis les sections À enlever · À livrer · Livrés.
///
/// Les validations passent par la file d'envoi : un ordre validé change de
/// section tout de suite (état visé par la file), puis la liste est relue
/// en silence dès que la validation est partie au serveur.
class YpsiumHomeScreen extends StatefulWidget {
  const YpsiumHomeScreen({super.key, this.onExit});

  /// Transmis depuis l'écran de login → permet de revenir à l'onglet Accueil
  /// après déconnexion (conserve une route racine valide dans l'onglet).
  final VoidCallback? onExit;

  @override
  State<YpsiumHomeScreen> createState() => _YpsiumHomeScreenState();
}

class _YpsiumHomeScreenState extends State<YpsiumHomeScreen>
    with DockNoticeMixin {
  /// Liste telle que renvoyée par le serveur.
  List<YpsiumTransportOrder> _orders = [];

  /// États visés par les validations encore dans la file d'envoi.
  Map<int, int> _pendingEtats = {};

  /// Validations parties de la file, affichées jusqu'à ce que la liste
  /// relue du serveur les reprenne.
  final Map<int, int> _sentEtats = {};

  /// Numéro du dernier chargement : une réponse plus ancienne est ignorée.
  int _loadSeq = 0;

  bool _isLoading = true;
  bool _isLoadingReferentiels = true;
  String? _errorMessage;
  DateTime _selectedDate = DateTime.now();
  bool _showTermines = false;

  @override
  void initState() {
    super.initState();
    _pendingEtats = sl.ypsiumTransportRepository.pendingEtats;
    sl.ypsiumSpoolerService.addListener(_onSpoolerChanged);
    _loadReferentiels();
    _loadTransports();
  }

  @override
  void dispose() {
    sl.ypsiumSpoolerService.removeListener(_onSpoolerChanged);
    super.dispose();
  }

  /// Une validation qui quitte la file (envoyée, ou supprimée par
  /// l'utilisateur) : on relit la liste pour afficher l'état du serveur.
  void _onSpoolerChanged() {
    if (!mounted) return;
    final pending = sl.ypsiumTransportRepository.pendingEtats;
    final left = {
      for (final e in _pendingEtats.entries)
        if (!pending.containsKey(e.key)) e.key: e.value,
    };
    setState(() {
      _pendingEtats = pending;
      _sentEtats.addAll(left);
    });
    if (left.isNotEmpty) _loadTransports(silent: true);
  }

  /// Liste du serveur avec les validations qu'il n'a pas encore reprises.
  List<YpsiumTransportOrder> get _visibleOrders {
    if (_pendingEtats.isEmpty && _sentEtats.isEmpty) return _orders;
    return [
      for (final order in _orders)
        order.withEtatAtLeast(
          math.max(
            _pendingEtats[order.idOrdre] ?? 0,
            _sentEtats[order.idOrdre] ?? 0,
          ),
        ),
    ];
  }

  Future<void> _loadReferentiels() async {
    final result = await sl.ypsiumReferentielRepository.loadAll();
    if (!mounted) return;
    result.fold(
      (_) {},
      (_) {},
    );
    setState(() => _isLoadingReferentiels = false);
  }

  /// [silent] : relecture en arrière-plan, sans squelette ; son échec
  /// laisse la liste affichée (sauf si un chargement visible est en cours).
  Future<void> _loadTransports({bool silent = false}) async {
    final seq = ++_loadSeq;
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    final dateStr = DateFormat('yyyyMMdd').format(_selectedDate);
    final result = await sl.ypsiumTransportRepository.getListeTransport(
      date: dateStr,
    );

    if (!mounted || seq != _loadSeq) return;
    result.fold(
      (failure) => setState(() {
        if (_isLoading) _errorMessage = failure.message;
        _isLoading = false;
      }),
      (orders) => setState(() {
        _orders = orders;
        _sentEtats.clear();
        _errorMessage = null;
        _isLoading = false;
      }),
    );
  }

  void _changeDate(int days) {
    setState(() => _selectedDate = _selectedDate.add(Duration(days: days)));
    _loadTransports();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('fr', 'FR'),
    );
    if (!mounted) return;
    if (picked != null && !DateUtils.isSameDay(picked, _selectedDate)) {
      setState(() => _selectedDate = picked);
      _loadTransports();
    }
  }

  Future<void> _openDetail(YpsiumTransportOrder order) async {
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => YpsiumTransportDetailScreen(order: order),
      ),
    );
    if (!mounted) return;
    // Le parcours validé remplace l'ancienne snackbar de succès ; l'ordre a
    // déjà changé de section (file d'envoi), la liste est relue en silence.
    if (done == true) showDockSuccess('Validation enregistrée');
    _loadTransports(silent: true);
  }

  void _openVehicules() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const YpsiumVehiculeScreen()),
    );
  }

  void _openSpooler() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const YpsiumSpoolerScreen()),
    );
  }

  Future<void> _openMenu() async {
    final action = await YpsiumMenuSheet.show(
      context,
      pendingCount: sl.ypsiumSpoolerService.pendingCount,
    );
    if (!mounted || action == null) return;
    switch (action) {
      case YpsiumMenuAction.spooler:
        _openSpooler();
      case YpsiumMenuAction.vehicule:
        _openVehicules();
      case YpsiumMenuAction.logout:
        _confirmLogout();
    }
  }

  /// Demande confirmation avant de se déconnecter d'Ypsium.
  Future<void> _confirmLogout() async {
    final confirmed = await AppConfirmSheet.show(
      context,
      title: 'Se déconnecter d\'Ypsium ?',
      message: 'Tu reviendras à l\'écran de connexion Ypsium.',
      confirmLabel: 'Se déconnecter',
      confirmIcon: Icons.logout_rounded,
    );
    if (!confirmed || !mounted) return;
    _logout();
  }

  Future<void> _logout() async {
    await sl.ypsiumAuthRepository.logout();
    if (!mounted) return;
    // Revenir au formulaire de connexion (route racine valide de l'onglet)
    // au lieu de `pop()` qui viderait le Navigator imbriqué → écran blanc.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => YpsiumLoginScreen(onExit: widget.onExit),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppPage(
      title: 'Ypsium',
      actions: [
        AppIconButton(
          icon: Icons.more_horiz_rounded,
          tooltip: 'Options Ypsium',
          color: colors.foreground,
          onPressed: _openMenu,
        ),
      ],
      bottom: AppPageBar(
        child: YpsiumDateBar(
          date: _selectedDate,
          onPrevious: () => _changeDate(-1),
          onNext: () => _changeDate(1),
          onPick: _pickDate,
        ),
      ),
      body: AppScrollView(
        onRefresh: _loadTransports,
        children: _buildContent(),
      ),
      dock: AppDock(
        status: _isLoadingReferentiels
            ? const YpsiumBusyLine(text: 'Chargement des référentiels…')
            : null,
        notice: dockNotice,
        onDismissNotice: clearDockNotice,
        bottomGap: AppSpacing.lg,
      ),
    );
  }

  List<Widget> _buildContent() {
    if (_isLoading) return const [YpsiumHomeSkeleton()];

    final spooler = sl.ypsiumSpoolerService;
    final callout = spooler.pendingCount > 0
        ? YpsiumSpoolerCallout(
            pendingCount: spooler.pendingCount,
            isProcessing: spooler.isProcessing,
            onOpen: _openSpooler,
          )
        : null;

    if (_errorMessage != null) {
      return [
        AppErrorState(message: _errorMessage!, onRetry: _loadTransports),
        if (callout != null) ...[
          const SizedBox(height: AppSpacing.md),
          callout,
        ],
      ];
    }

    final orders = _visibleOrders;
    return [
      YpsiumHomeHero(
        orders: orders,
        dateLabel: ypsiumDayLabel(_selectedDate),
      ),
      if (callout != null) ...[
        const SizedBox(height: AppSpacing.md),
        callout,
      ],
      const SizedBox(height: AppSpacing.lg),
      if (orders.isEmpty)
        AppEmptyCard(
          icon: Icons.inbox_outlined,
          message: 'Pas de commande prévue pour cette date',
          actionLabel: 'Actualiser',
          onAction: _loadTransports,
        )
      else
        YpsiumTransportSections(
          orders: orders,
          showLivres: _showTermines,
          onToggleLivres: () => setState(() => _showTermines = !_showTermines),
          onOpen: _openDetail,
        ),
    ];
  }
}
