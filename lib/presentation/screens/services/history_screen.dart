import 'dart:async';

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
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
/// mémoire). La sélection d'un jour filtre localement les services du mois.
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

  /// Horloge des lignes « en cours » du fil.
  final ValueNotifier<DateTime> _clock = ValueNotifier(DateTime.now());
  Timer? _ticker;

  DateTime _focusedDay = _today();
  DateTime? _selectedDay = _today();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  HistoryTypeFilter _typeFilter = HistoryTypeFilter.all;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _clock.value = DateTime.now(),
    );
    _loadMonth(_focusedDay);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _clock.dispose();
    super.dispose();
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

  Future<void> _loadMonth(DateTime month, {bool force = false}) async {
    final key = _monthKey(month);
    if (!force && (_cache.containsKey(key) || _loadingMonths.contains(key))) {
      return;
    }

    setState(() {
      _loadingMonths.add(key);
      _monthErrors.remove(key);
    });

    final result = await sl.serviceRepository.getMonthServices(
      year: month.year,
      month: month.month,
    );

    if (!mounted) return;

    result.fold(
      (failure) {
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

  List<Service> _servicesOfMonth(DateTime month) {
    final services = _cache[_monthKey(month)] ?? const [];
    final isBreak = _typeFilter.isBreak;
    if (isBreak == null) return services;
    return services.where((s) => s.isBreak == isBreak).toList();
  }

  /// Pointages d'un jour, lus dans le mois affiché (marqueurs du
  /// calendrier) ou, pour la liste du jour choisi, dans le mois de ce jour
  /// ([month]) : après un changement de mois, le jour choisi garde ses
  /// pointages au lieu d'apparaître vide.
  List<Service> _servicesForDay(DateTime day, {DateTime? month}) {
    final normalized = DateTime(day.year, day.month, day.day);
    return _servicesOfMonth(month ?? _focusedDay).where((s) {
      final local = s.debut.toLocal();
      return local.year == normalized.year &&
          local.month == normalized.month &&
          local.day == normalized.day;
    }).toList();
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

  void _openDetail(Service service) =>
      ServiceDetailSheet.show(context, service, now: DateTime.now());

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
            eventLoader: _servicesForDay,
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
            clock: _clock,
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
