import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/location_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/service_model.dart';
import '../../widgets/widgets.dart';
import '../rapports/create_rapport_screen.dart';
import '../signatures/sign_screen.dart';
import 'history_screen.dart';
import 'kilometrage_required_screen.dart';
import 'mes_heures_screen.dart';
import 'pointage_controller.dart';
import 'widgets/action_dock.dart';
import 'widgets/day_timeline.dart';
import 'widgets/end_service_sheet.dart';
import 'widgets/hours_strip.dart';
import 'widgets/pointage_hero_card.dart';
import 'widgets/pointage_layout.dart';
import 'widgets/pointage_skeleton.dart';
import 'widgets/prerequisite_card.dart';
import 'widgets/service_detail_sheet.dart';

/// Page « Pointage » — l'écran d'action du chauffeur.
///
/// Trois temps pilotés par les données : AVANT (carte « Avant de pointer »
/// qui remplace les dialogs en cascade), PENDANT (chrono en direct, ruban et
/// fil de la journée), APRÈS (récapitulatif figé). Un seul point focal (la
/// carte hero) et un dock persistant dans la zone du pouce dont le bouton dit
/// toujours la prochaine action — jamais un bouton grisé muet, jamais de
/// dialog au montage, jamais de snackbar.
///
/// Toute la logique vit dans [PointageController] ; cette page ne fait que
/// l'écouter, le déclencher et naviguer.
class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key, this.controller});

  /// Contrôleur injectable (tests) — sinon créé et possédé par la page.
  final PointageController? controller;

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen>
    with WidgetsBindingObserver {
  late final PointageController _c = widget.controller ?? PointageController();
  late final bool _ownsController = widget.controller == null;

  DockNotice? _notice;
  Timer? _noticeTimer;
  int _shakeToken = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _c.init();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _c.onAppResumed();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _noticeTimer?.cancel();
    if (_ownsController) _c.dispose();
    super.dispose();
  }

  // ---- navigation -------------------------------------------------------

  Future<void> _push(Widget screen, {bool fullscreenDialog = false}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => screen,
        fullscreenDialog: fullscreenDialog,
      ),
    );
    if (!mounted) return;
    await _c.refresh();
  }

  void _openHistory() => _push(const HistoryScreen());
  void _openHours() => _push(const MesHeuresScreen());
  void _openRapport() => _push(const CreateRapportScreen());

  void _openKilometrage({required bool required}) => _push(
        KilometrageRequiredScreen(isRequired: required),
        fullscreenDialog: required,
      );

  void _openSign() =>
      _push(SignScreen(heuresLastMonth: _c.prerequisites.heuresLastMonth));

  void _openDetail(Service service) =>
      ServiceDetailSheet.show(context, service, now: DateTime.now());

  Future<void> _fixLocation() async {
    switch (_c.locationStatus) {
      case LocationStatus.serviceDisabled:
        await _c.openLocationSettings();
      case LocationStatus.permissionDenied:
        await _c.requestLocationPermission();
      case LocationStatus.permissionDeniedForever:
        await _c.openAppSettings();
      case LocationStatus.granted:
      case null:
        await _c.onAppResumed();
    }
  }

  // ---- notices ----------------------------------------------------------

  void _showNotice(DockNotice notice, Duration autoHide) {
    _noticeTimer?.cancel();
    setState(() => _notice = notice);
    _noticeTimer = Timer(autoHide, _clearNotice);
  }

  void _clearNotice() {
    _noticeTimer?.cancel();
    _noticeTimer = null;
    if (_notice != null && mounted) setState(() => _notice = null);
  }

  void _handleResult(PointageActionResult result) {
    switch (result) {
      case PointageActionSuccess():
        // Le changement d'état à l'écran suffit : pas de message.
        HapticFeedback.mediumImpact();
      case PointageActionFailure(:final message):
        HapticFeedback.heavyImpact();
        _showNotice(
          DockNotice(text: message, variant: AlertVariant.destructive),
          const Duration(seconds: 6),
        );
      case PointageActionNoLocation():
        HapticFeedback.vibrate();
        setState(() => _shakeToken++);
      case PointageActionBlocked():
        // La carte « Avant de pointer » apparaît et le dock devient l'étape.
        HapticFeedback.vibrate();
      case PointageActionIgnored():
        break;
    }
  }

  // ---- actions ----------------------------------------------------------

  Future<void> _start() async {
    _clearNotice();
    final result = await _c.startService();
    if (!mounted) return;
    _handleResult(result);
  }

  Future<void> _pause() async {
    _clearNotice();
    final result = await _c.startBreak();
    if (!mounted) return;
    _handleResult(result);
  }

  Future<void> _resume() async {
    _clearNotice();
    final result = await _c.endBreak();
    if (!mounted) return;
    _handleResult(result);
  }

  Future<void> _end() async {
    _clearNotice();
    final confirmed = await EndServiceSheet.show(
      context,
      start: _c.firstStartToday,
      now: DateTime.now(),
      worked: _c.workedToday,
      breaks: _c.breakToday,
      breakCount: _c.breakCount,
    );
    if (!confirmed || !mounted) return;
    final result = await _c.endService();
    if (!mounted) return;
    _handleResult(result);
  }

  // ---- build ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final padding = MediaQuery.paddingOf(context);

    return Scaffold(
      backgroundColor: colors.background,
      // Le contenu passe sous le dock : son fondu remplace tout bord dur, et
      // la liste réserve `paddingOf.bottom` (dock + tab bar) en bas.
      extendBody: true,
      appBar: AppBar(
        title: const Text('Pointage'),
        actions: [
          AppIconButton(
            icon: Icons.speed_rounded,
            tooltip: 'Kilométrage',
            color: colors.foreground,
            onPressed: () => _openKilometrage(required: false),
          ),
          AppIconButton(
            icon: Icons.calendar_month_rounded,
            tooltip: 'Historique',
            color: colors.foreground,
            onPressed: _openHistory,
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: ListenableBuilder(
        listenable: _c,
        builder: (context, _) {
          final loading = _c.moment == PointageMoment.loading;
          return RefreshIndicator(
            onRefresh: _c.refresh,
            color: colors.primary,
            backgroundColor: colors.card,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screen + padding.left,
                AppSpacing.md,
                AppSpacing.screen + padding.right,
                // Hauteur du dock (tab bar comprise), lue depuis le contexte
                // du corps : c'est lui que le Scaffold renseigne.
                AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: PointageLayout.maxContentWidth,
                  ),
                  child: AnimatedSwitcher(
                    duration: AppDuration.base,
                    child: loading
                        ? const PointageSkeleton(key: ValueKey('skeleton'))
                        : KeyedSubtree(
                            key: const ValueKey('content'),
                            child: _buildContent(colors),
                          ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: _c,
        builder: (context, _) => _buildDock(colors),
      ),
    );
  }

  Widget _buildContent(AppColors colors) {
    final now = DateTime.now();
    final moment = _c.moment;

    if (moment == PointageMoment.offline) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [PointageHeroCard(controller: _c)],
      );
    }

    final items = buildPrerequisiteItems(
      prerequisites: _c.prerequisites,
      now: now,
      actions: PrereqActions(
        onSign: _openSign,
        onKilometrage: () => _openKilometrage(required: true),
        onRapport: _openRapport,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PointageHeroCard(controller: _c),
        AnimatedSize(
          duration: AppDuration.base,
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: items.isEmpty
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: PrerequisiteCard(items: items),
                ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _TodaySection(controller: _c, onTap: _openDetail),
        const SizedBox(height: AppSpacing.lg),
        HoursStrip(hours: _c.workedHours, onTap: _openHours),
      ],
    );
  }

  // ---- dock -------------------------------------------------------------

  Widget _buildDock(AppColors colors) {
    final moment = _c.moment;
    final busy = _c.isActing;
    final inFlight = _c.inFlightAction;

    List<DockAction> actions;
    switch (moment) {
      case PointageMoment.loading:
        actions = const [];
      case PointageMoment.offline:
        actions = [
          DockAction(
            label: 'Réessayer',
            icon: Icons.refresh_rounded,
            tone: DockTone.secondary,
            onPressed: _c.refresh,
          ),
        ];
      case PointageMoment.onDuty:
        actions = [
          DockAction(
            label: 'Pause',
            icon: Icons.coffee_rounded,
            tone: DockTone.soft,
            isLoading: inFlight == PointageAction.breakStart,
            onPressed: busy ? null : _pause,
            semanticsHint: 'Met le service en pause',
          ),
          DockAction(
            label: 'Terminer',
            icon: Icons.stop_rounded,
            tone: DockTone.danger,
            isLoading: inFlight == PointageAction.end,
            onPressed: busy ? null : _end,
            semanticsHint: 'Ouvre le récapitulatif avant de clôturer',
          ),
        ];
      case PointageMoment.onBreak:
        actions = [
          DockAction(
            label: 'Reprendre le service',
            icon: Icons.play_arrow_rounded,
            tone: DockTone.success,
            isLoading: inFlight == PointageAction.breakEnd,
            onPressed: busy ? null : _resume,
          ),
        ];
      case PointageMoment.notStarted:
      case PointageMoment.dayDone:
        final blocker = _blockerAction();
        actions = [
          blocker ??
              DockAction(
                label: moment == PointageMoment.dayDone
                    ? 'Commencer le service'
                    : 'Démarrer le service',
                icon: Icons.play_arrow_rounded,
                tone: DockTone.success,
                isLoading: inFlight == PointageAction.start,
                onPressed: busy ? null : _start,
              ),
        ];
    }

    return ActionDock(
      actions: actions,
      skeleton: moment == PointageMoment.loading,
      gps: _gpsStatus(colors),
      notice: _notice,
      onDismissNotice: _clearNotice,
      absorbing: busy,
      shakeToken: _shakeToken,
    );
  }

  /// Le dock DEVIENT le premier prérequis bloquant (signature > kilométrage >
  /// rapport). Le GPS n'est pas un bloqueur : il est traité dans sa ligne.
  DockAction? _blockerAction() {
    final p = _c.prerequisites;
    if (p.signatureRequired) {
      return DockAction(
        label: 'Signer mes heures',
        icon: Icons.draw_rounded,
        onPressed: _openSign,
      );
    }
    if (p.kilometrageRequired) {
      return DockAction(
        label: 'Saisir le kilométrage',
        icon: Icons.speed_rounded,
        onPressed: () => _openKilometrage(required: true),
      );
    }
    if (p.rapportRequired) {
      return DockAction(
        label: 'Faire le rapport véhicule',
        icon: Icons.description_rounded,
        onPressed: _openRapport,
      );
    }
    return null;
  }

  /// Ligne GPS, par priorité : action en vol > statut de permission >
  /// position introuvable. Silencieuse (`null`) quand tout va bien.
  GpsStatus? _gpsStatus(AppColors colors) {
    switch (_c.actionPhase) {
      case PointageActionPhase.checking:
        return const GpsStatus(text: 'Vérification des formalités…', busy: true);
      case PointageActionPhase.locating:
        return const GpsStatus(text: 'Recherche de la position…', busy: true);
      case PointageActionPhase.sending:
        return const GpsStatus(text: 'Envoi du pointage…', busy: true);
      case PointageActionPhase.idle:
        break;
    }

    switch (_c.locationStatus) {
      case LocationStatus.serviceDisabled:
        return GpsStatus(
          icon: Icons.location_off_rounded,
          color: colors.warning,
          text: 'Localisation désactivée',
          actionLabel: 'Activer',
          onAction: _fixLocation,
        );
      case LocationStatus.permissionDenied:
        return GpsStatus(
          icon: Icons.location_off_rounded,
          color: colors.warning,
          text: 'Permission de localisation requise',
          actionLabel: 'Autoriser',
          onAction: _fixLocation,
        );
      case LocationStatus.permissionDeniedForever:
        return GpsStatus(
          icon: Icons.location_off_rounded,
          color: colors.warning,
          text: 'Localisation bloquée',
          actionLabel: 'Réglages',
          onAction: _fixLocation,
        );
      case LocationStatus.granted:
      case null:
        break;
    }

    return switch (_c.locationReadiness) {
      LocationReadiness.ready || LocationReadiness.searching => null,
      LocationReadiness.notFound => GpsStatus(
          icon: Icons.gps_off_rounded,
          color: colors.warning,
          text: 'Position introuvable · réessaie dans un instant',
          actionLabel: 'Réessayer',
          onAction: _fixLocation,
        ),
    };
  }
}

// ---- aujourd'hui -----------------------------------------------------------

/// En-tête « Aujourd'hui » + fil de la journée (ou état vide / indisponible).
class _TodaySection extends StatelessWidget {
  const _TodaySection({required this.controller, required this.onTap});

  final PointageController controller;
  final ValueChanged<Service> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final c = controller;

    final summary = <String>[
      if (c.serviceCount > 0)
        '${c.serviceCount} ${c.serviceCount > 1 ? 'services' : 'service'}',
      if (c.breakCount > 0)
        '${c.breakCount} ${c.breakCount > 1 ? 'pauses' : 'pause'}',
    ].join(' · ');

    Widget body;
    if (c.dailyServicesUnavailable && c.segments.isEmpty) {
      body = const AppAlert(
        variant: AlertVariant.warning,
        description:
            'Détail du jour indisponible. Tire vers le bas pour réessayer.',
      );
    } else if (c.segments.isEmpty) {
      body = AppCard(
        elevation: AppCardElevation.flat,
        color: colors.surfaceSunken,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Icon(Icons.bedtime_outlined, size: 20, color: colors.mutedForeground),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'Aucun pointage pour l\'instant',
                style: textTheme.bodyLarge
                    ?.copyWith(color: colors.mutedForeground),
              ),
            ),
          ],
        ),
      );
    } else {
      body = AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        child: DayTimeline(
          segments: c.segments,
          clock: c.clock,
          onTap: onTap,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Row(
            children: [
              Expanded(
                child: Text('Aujourd\'hui', style: textTheme.titleMedium),
              ),
              if (summary.isNotEmpty) Text(summary, style: textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        body,
      ],
    );
  }
}
