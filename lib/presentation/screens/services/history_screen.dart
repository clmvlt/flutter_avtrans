import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/live_counter.dart';
import '../../../core/utils/live_refresher.dart';
import '../../../data/models/models.dart';
import '../../widgets/widgets.dart';
import 'history/history_calendar_card.dart';
import 'history/history_day_section.dart';
import 'history/history_filter.dart';
import 'widgets/service_detail_sheet.dart';

/// Historique des pointages : calendrier du mois, puis le fil du jour choisi
/// (même dessin que « Aujourd'hui » sur la page Pointage). Un tap sur une
/// ligne ouvre son détail.
///
/// Chaque mois affiché déclenche un `GET /services/month` (mis en cache
/// mémoire) : services de travail débutés dans le mois, pauses imbriquées.
/// Un service compte en entier sur son jour de début, pauses comprises (même
/// après minuit) ; la sélection d'un jour lit localement les services du
/// mois. Les lignes en cours avancent en direct.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final Map<String, List<Service>> _cache = {};
  final Set<String> _loadingMonths = {};

  /// Échec du dernier chargement d'un mois (affiché sous le calendrier).
  final Map<String, String> _monthErrors = {};

  /// Mois rechargés au retour au premier plan, au changement de jour, et
  /// toutes les 5 min tant qu'une ligne est en cours.
  late final LiveRefresher _refresher = LiveRefresher(
    onRefresh: _resync,
    isLive: () => _cache.values.any((m) => m.any((s) => s.enCours)),
  );

  DateTime _focusedDay = _today();
  DateTime? _selectedDay = _today();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  HistoryTypeFilter _typeFilter = HistoryTypeFilter.all;

  @override
  void initState() {
    super.initState();
    _loadMonth(_focusedDay);
    _refresher.start();
  }

  @override
  void dispose() {
    _refresher.dispose();
    super.dispose();
  }

  /// Recharge sans squelette le mois affiché et celui du jour choisi.
  Future<void> _resync() async {
    final months = {
      _monthKey(_focusedDay): _focusedDay,
      if (_selectedDay != null) _monthKey(_selectedDay!): _selectedDay!,
    };
    await Future.wait([
      for (final m in months.values) _loadMonth(m, force: true, silent: true),
    ]);
  }

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String _monthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  bool get _isCurrentMonthLoading =>
      _loadingMonths.contains(_monthKey(_focusedDay));

  bool get _isOnCurrentMonth {
    final now = DateTime.now();
    return _focusedDay.year == now.year && _focusedDay.month == now.month;
  }

  /// [silent] : resynchronisation, sans indicateur ni message d'erreur.
  Future<void> _loadMonth(
    DateTime month, {
    bool force = false,
    bool silent = false,
  }) async {
    final key = _monthKey(month);
    if (!force && (_cache.containsKey(key) || _loadingMonths.contains(key))) {
      return;
    }

    if (!silent) {
      setState(() {
        _loadingMonths.add(key);
        _monthErrors.remove(key);
      });
    }

    final result = await sl.serviceRepository.getMonthServices(
      year: month.year,
      month: month.month,
    );

    if (!mounted) return;

    result.fold(
      (failure) {
        if (silent) return;
        setState(() {
          _loadingMonths.remove(key);
          _monthErrors[key] = failure.message;
        });
      },
      (services) {
        final sorted = [...services]..sort((a, b) => a.debut.compareTo(b.debut));
        setState(() {
          _cache[key] = sorted;
          _loadingMonths.remove(key);
        });
      },
    );
  }

  /// Services de travail débutés un jour, lus dans le mois affiché
  /// (marqueurs du calendrier) ou, pour la liste du jour choisi, dans le
  /// mois de ce jour ([month]) : après un changement de mois, le jour choisi
  /// garde ses pointages au lieu d'apparaître vide.
  List<Service> _servicesForDay(DateTime day, {DateTime? month}) {
    final services = _cache[_monthKey(month ?? _focusedDay)] ?? const [];
    return services.where((s) {
      final local = s.debut.toLocal();
      return local.year == day.year &&
          local.month == day.month &&
          local.day == day.day;
    }).toList();
  }

  /// Lignes d'un jour (services puis leurs pauses, à plat, par début),
  /// selon le filtre de type. Les pauses suivent leur service, même après
  /// minuit.
  List<Service> _entriesForDay(DateTime day, {DateTime? month}) {
    final isBreak = _typeFilter.isBreak;
    final entries = [
      for (final s in _servicesForDay(day, month: month)) ...[s, ...s.pauses],
    ]..sort((a, b) => a.debut.compareTo(b.debut));
    if (isBreak == null) return entries;
    return entries.where((s) => s.isBreak == isBreak).toList();
  }

  Future<void> _onRefresh() async {
    await _loadMonth(_focusedDay, force: true);
  }

  void _jumpToToday() {
    final today = _today();
    setState(() {
      _focusedDay = today;
      _selectedDay = today;
    });
    _loadMonth(today);
  }

  Future<void> _openFilter() async {
    final picked = await HistoryFilterSheet.show(context, current: _typeFilter);
    if (picked == null || !mounted) return;
    setState(() => _typeFilter = picked);
  }

  void _openDetail(Service service) => ServiceDetailSheet.show(context, service);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final selected = _selectedDay;
    // Mois du jour choisi : c'est lui qui alimente la liste du jour.
    final dayMonth = selected ?? _focusedDay;
    final dayKey = _monthKey(dayMonth);
    final monthMissing = !_cache.containsKey(dayKey);

    return AppPage(
      title: 'Historique',
      actions: [
        if (!_isOnCurrentMonth)
          AppIconButton(
            icon: Icons.today_rounded,
            tooltip: 'Aujourd\'hui',
            color: colors.foreground,
            onPressed: _jumpToToday,
          ),
        HistoryFilterButton(
          active: _typeFilter != HistoryTypeFilter.all,
          onPressed: _openFilter,
        ),
      ],
      body: AppScrollView(
        onRefresh: _onRefresh,
        children: [
          HistoryCalendarCard(
            focusedDay: _focusedDay,
            selectedDay: _selectedDay,
            format: _calendarFormat,
            loading: _isCurrentMonthLoading,
            eventLoader: _entriesForDay,
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) {
              setState(() => _calendarFormat = format);
            },
            onPageChanged: (focusedDay) {
              setState(() => _focusedDay = focusedDay);
              _loadMonth(focusedDay);
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          HistoryDaySection(
            day: selected,
            services: selected == null
                ? const []
                : _servicesForDay(selected, month: selected),
            entries: selected == null
                ? const []
                : _entriesForDay(selected, month: selected),
            clock: LiveTicker.instance,
            loading: _loadingMonths.contains(dayKey) && monthMissing,
            error: monthMissing ? _monthErrors[dayKey] : null,
            filter: _typeFilter,
            onRetry: () => _loadMonth(dayMonth, force: true),
            onClearFilter: () =>
                setState(() => _typeFilter = HistoryTypeFilter.all),
            onTapService: _openDetail,
          ),
        ],
      ),
    );
  }
}
