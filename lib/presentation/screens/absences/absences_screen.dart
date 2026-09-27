import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/display_format.dart';
import '../../../data/models/models.dart';
import '../../widgets/widgets.dart';
import 'widgets/absence_calendar.dart';
import 'widgets/absence_day_section.dart';
import 'widgets/absence_detail_sheet.dart';
import 'widgets/absence_filters.dart';
import 'widgets/absence_visuals.dart';
import 'widgets/absences_hero.dart';
import 'widgets/create_absence_page.dart';
import 'widgets/request_blocks.dart';
import 'widgets/request_widgets.dart';

/// Page « Mes absences » : hero des demandes en attente, bascule
/// Calendrier / Liste, détail en feuille, demande dans le dock.
class AbsencesScreen extends StatefulWidget {
  const AbsencesScreen({super.key});

  @override
  State<AbsencesScreen> createState() => _AbsencesScreenState();
}

class _AbsencesScreenState extends State<AbsencesScreen> with DockNoticeMixin {
  final List<Absence> _absences = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  String? _error;

  AbsenceFilters _filters = AbsenceFilters.none;
  List<AbsenceType> _absenceTypes = [];

  // Calendrier (vue par défaut, jour du jour sélectionné).
  bool _isCalendarView = true;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  final Map<DateTime, List<Absence>> _absencesByDay = {};

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadAbsenceTypes();
    _loadAbsences();
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
      _loadMoreAbsences();
    }
  }

  Future<void> _loadAbsenceTypes() async {
    final result = await sl.absenceRepository.getAbsenceTypes();
    if (!mounted) return;
    result.fold((_) {}, (types) => setState(() => _absenceTypes = types));
  }

  /// Une absence peut couvrir plusieurs jours : on l'indexe sur chacun.
  /// Pas de `+ 24 h` : au changement d'heure, les clés ne seraient plus à
  /// minuit et les jours suivants perdraient leur absence.
  void _updateAbsencesByDay() {
    _absencesByDay.clear();
    for (final absence in _absences) {
      var day = DateUtils.dateOnly(absence.startDate);
      final endDay = DateUtils.dateOnly(absence.endDate);
      while (!day.isAfter(endDay)) {
        _absencesByDay.putIfAbsent(day, () => []).add(absence);
        day = DateTime(day.year, day.month, day.day + 1);
      }
    }
  }

  List<Absence> _getAbsencesForDay(DateTime day) =>
      _absencesByDay[DateUtils.dateOnly(day)] ?? [];

  AbsenceListParams _buildParams({int page = 0}) {
    return AbsenceListParams(
      page: page,
      size: 20,
      startDate: _filters.startDate,
      endDate: _filters.endDate,
      status: _filters.status != null
          ? AbsenceStatus.fromString(_filters.status!)
          : null,
      absenceTypeUuid: _filters.type?.uuid,
    );
  }

  /// [silent] : tirer pour rafraîchir, la liste reste affichée pendant l'appel.
  Future<void> _loadAbsences({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    final result = await sl.absenceRepository.getMyAbsences(_buildParams());
    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        _error = failure.message;
        _isLoading = false;
      }),
      (response) => setState(() {
        _error = null;
        _absences
          ..clear()
          ..addAll(response.content);
        _currentPage = 0;
        _hasMore = !response.last;
        _isLoading = false;
        _updateAbsencesByDay();
      }),
    );
  }

  Future<void> _refresh() => _loadAbsences(silent: true);

  Future<void> _loadMoreAbsences() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);

    final result = await sl.absenceRepository.getMyAbsences(
      _buildParams(page: _currentPage + 1),
    );
    if (!mounted) return;

    result.fold(
      (_) => setState(() => _isLoadingMore = false),
      (response) => setState(() {
        _absences.addAll(response.content);
        _currentPage++;
        _hasMore = !response.last;
        _isLoadingMore = false;
        _updateAbsencesByDay();
      }),
    );
  }

  // ---- actions ----------------------------------------------------------

  void _applyFilters(AbsenceFilters filters) {
    setState(() => _filters = filters);
    _loadAbsences();
  }

  /// Hero « en attente » : liste filtrée sur les demandes en attente.
  void _showPending() {
    setState(() => _isCalendarView = false);
    _applyFilters(AbsenceFilters.pendingOnly);
  }

  Future<void> _openFilters() async {
    final result = await AbsenceFiltersSheet.show(
      context,
      initial: _filters,
      absenceTypes: _absenceTypes,
    );
    if (!mounted || result == null) return;
    _applyFilters(result);
  }

  Future<void> _openCreate() async {
    clearDockNotice();
    final absence = await CreateAbsencePage.open(context);
    if (!mounted || absence == null) return;
    setState(() {
      _absences.insert(0, absence);
      _updateAbsencesByDay();
    });
    showDockSuccess('Demande envoyée');
  }

  Future<void> _openDetail(Absence absence) async {
    clearDockNotice();
    final action = await AbsenceDetailSheet.show(context, absence);
    if (!mounted || action != AbsenceDetailAction.cancel) return;
    await _cancelAbsence(absence);
  }

  Future<void> _cancelAbsence(Absence absence) async {
    final confirmed = await AppConfirmSheet.show(
      context,
      title: 'Annuler la demande ?',
      message: 'Ta demande d\'absence sera retirée. '
          'Tu pourras en refaire une si besoin.',
      details: AbsenceRecap(absence: absence),
      confirmLabel: 'Annuler la demande',
      confirmIcon: Icons.close_rounded,
      cancelLabel: 'Garder ma demande',
    );
    if (!confirmed || !mounted) return;

    final result = await sl.absenceRepository.cancelAbsence(absence.uuid);
    if (!mounted) return;

    result.fold(
      (failure) => showDockError(failure.message),
      (_) {
        // L'API supprime physiquement l'absence annulée : on la retire.
        setState(() {
          _absences.removeWhere((a) => a.uuid == absence.uuid);
          _updateAbsencesByDay();
        });
        showDockSuccess('Demande annulée');
      },
    );
  }

  // ---- build ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Mes absences',
      actions: [
        if (!_isCalendarView)
          FilterIconButton(count: _filters.count, onPressed: _openFilters),
      ],
      body: _buildBody(),
      dock: AppDock(
        actions: [
          DockAction(
            label: 'Demander une absence',
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
      return AppScrollView(
        children: [
          RequestsSkeleton(
            showSegmented: true,
            showCalendar: _isCalendarView,
          ),
        ],
      );
    }

    if (_error != null) {
      return AppScrollView(
        onRefresh: _refresh,
        children: [AppErrorState(message: _error!, onRetry: _loadAbsences)],
      );
    }

    final pendingCount =
        _absences.where((a) => a.status == AbsenceStatus.pending).length;
    final top = <Widget>[
      AbsencesHero(
        pendingCount: pendingCount,
        total: _absences.length,
        filtered: _filters.isActive,
        onShowPending: _isCalendarView || !_filters.isPendingOnly
            ? _showPending
            : null,
      ),
      const SizedBox(height: AppSpacing.lg),
      AppSegmented<bool>(
        segments: const [
          AppSegment(
            value: true,
            label: 'Calendrier',
            icon: Icons.calendar_month_rounded,
          ),
          AppSegment(
            value: false,
            label: 'Liste',
            icon: Icons.view_list_rounded,
          ),
        ],
        selected: _isCalendarView,
        onChanged: (v) => setState(() => _isCalendarView = v),
      ),
    ];

    return _isCalendarView ? _buildCalendarView(top) : _buildListView(top);
  }

  Widget _buildCalendarView(List<Widget> top) {
    final selected = _selectedDay;
    return AppScrollView(
      onRefresh: _refresh,
      children: [
        ...top,
        const SizedBox(height: AppSpacing.lg),
        AbsenceCalendar(
          focusedDay: _focusedDay,
          selectedDay: _selectedDay,
          format: _calendarFormat,
          eventLoader: _getAbsencesForDay,
          onDaySelected: (selectedDay, focusedDay) => setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          }),
          onFormatChanged: (format) => setState(() => _calendarFormat = format),
          onPageChanged: (focusedDay) => _focusedDay = focusedDay,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (selected == null)
          const AppEmptyCard(
            icon: Icons.touch_app_rounded,
            message: 'Choisis un jour pour voir ses absences',
          )
        else
          AbsenceDaySection(
            day: selected,
            absences: _getAbsencesForDay(selected),
            onOpen: _openDetail,
          ),
      ],
    );
  }

  Widget _buildListView(List<Widget> top) {
    final header = <Widget>[
      ...top,
      if (_filters.isActive) ...[
        const SizedBox(height: AppSpacing.md),
        ActiveFiltersRow(
          filters: activeAbsenceFilters(_filters, _applyFilters),
        ),
      ],
      const SizedBox(height: AppSpacing.lg),
      if (_absences.isEmpty)
        AppEmptyCard(
          icon: Icons.event_busy_rounded,
          message: _filters.isActive
              ? 'Aucune absence ne correspond aux filtres'
              : 'Aucune demande d\'absence',
          detail: _filters.isActive ? null : 'Tes demandes apparaîtront ici.',
          actionLabel: _filters.isActive ? 'Effacer' : null,
          onAction: _filters.isActive
              ? () => _applyFilters(AbsenceFilters.none)
              : null,
        )
      else
        AppSectionHeader(
          title: 'Mes demandes',
          summary: _hasMore
              ? null
              : DisplayFormat.plural(_absences.length, 'demande'),
        ),
    ];

    return AppListView(
      controller: _scrollController,
      onRefresh: _refresh,
      header: header,
      itemCount: _absences.length,
      itemBuilder: (context, index) {
        final a = _absences[index];
        return AppCard(
          padding: EdgeInsets.zero,
          child: AbsenceRow(
            absence: a,
            onTap: () => _openDetail(a),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        );
      },
      footer: _isLoadingMore ? const LoadMoreFooter() : null,
    );
  }
}
