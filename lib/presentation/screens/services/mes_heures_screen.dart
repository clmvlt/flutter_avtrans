import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../widgets/widgets.dart';
import 'heures/hours_hero_card.dart';
import 'heures/hours_labels.dart';
import 'heures/hours_overview_card.dart';
import 'heures/hours_period.dart';
import 'heures/hours_pickers.dart';

/// « Mes heures » : total travaillé (pauses déduites) d'une période.
///
/// Segments Jour · Semaine · Mois · Année ; la carte hero montre le total de
/// la période choisie (en cours par défaut, lu dans la vue d'ensemble), le
/// dock ouvre le choix d'une autre période. « Mes totaux » rappelle les
/// cinq totaux en cours.
///
/// Appels : `GET /services/hours` sans filtre (vue d'ensemble), puis avec
/// `period` = day / week / month / year pour une période choisie.
class MesHeuresScreen extends StatefulWidget {
  const MesHeuresScreen({super.key});

  @override
  State<MesHeuresScreen> createState() => _MesHeuresScreenState();
}

class _MesHeuresScreenState extends State<MesHeuresScreen> {
  // Vue d'ensemble (jour, semaine, mois, mois dernier, année en cours).
  WorkedHours? _overview;
  bool _isLoading = true;
  String? _error;

  HoursPeriod _period = HoursPeriod.week;

  // Période choisie par segment (`null` = période en cours).
  DateTime? _selectedDate;
  late int _weekNumber;
  late int _weekYear;
  int? _selectedMonth;
  int? _selectedMonthYear;
  int? _selectedYear;

  // Résultat, requête, chargement et erreur de la dernière requête filtrée,
  // par segment. Sans résultat, le segment lit la vue d'ensemble.
  final Map<HoursPeriod, double?> _values = {};
  final Map<HoursPeriod, WorkedHoursParams> _queries = {};
  final Set<HoursPeriod> _loadingPeriods = {};
  final Map<HoursPeriod, String> _periodErrors = {};

  /// Jeton par segment : une réponse arrivée après une nouvelle requête ou
  /// un retour à la période en cours est ignorée.
  final Map<HoursPeriod, int> _tokens = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _weekNumber = HoursWeeks.weekNumber(now);
    _weekYear = now.year;
    _loadOverview();
  }

  // ---- données ------------------------------------------------------------

  /// Vue d'ensemble : sans filtre, toutes les périodes en cours. Ramène
  /// aussi chaque segment sur sa période en cours.
  Future<void> _loadOverview() async {
    setState(() {
      _isLoading = true;
      _error = null;
      for (final p in HoursPeriod.values) {
        _resetPeriod(p);
      }
    });

    final result = await sl.serviceRepository.getWorkedHours(
      const WorkedHoursParams(),
    );

    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        _error = failure.message;
        _isLoading = false;
      }),
      (hours) => setState(() {
        _overview = hours;
        _isLoading = false;
      }),
    );
  }

  /// Requête filtrée d'une période ; garde la valeur du champ de la période.
  Future<void> _query(HoursPeriod period, WorkedHoursParams params) async {
    final token = (_tokens[period] ?? 0) + 1;
    _tokens[period] = token;
    _queries[period] = params;
    setState(() {
      _loadingPeriods.add(period);
      _periodErrors.remove(period);
    });

    final result = await sl.serviceRepository.getWorkedHours(params);

    if (!mounted || _tokens[period] != token) return;

    result.fold(
      (failure) => setState(() {
        _loadingPeriods.remove(period);
        _periodErrors[period] = failure.message;
      }),
      (hours) => setState(() {
        _loadingPeriods.remove(period);
        _values[period] = switch (period) {
          HoursPeriod.day => hours.day,
          HoursPeriod.week => hours.week,
          HoursPeriod.month => hours.month,
          HoursPeriod.year => hours.year,
        };
      }),
    );
  }

  /// Ramène [period] sur la période en cours (à appeler dans un setState).
  void _resetPeriod(HoursPeriod period) {
    _tokens[period] = (_tokens[period] ?? 0) + 1;
    _values.remove(period);
    _queries.remove(period);
    _loadingPeriods.remove(period);
    _periodErrors.remove(period);
    switch (period) {
      case HoursPeriod.day:
        _selectedDate = null;
      case HoursPeriod.week:
        final now = DateTime.now();
        _weekNumber = HoursWeeks.weekNumber(now);
        _weekYear = now.year;
      case HoursPeriod.month:
        _selectedMonth = null;
        _selectedMonthYear = null;
      case HoursPeriod.year:
        _selectedYear = null;
    }
  }

  double? _valueFor(HoursPeriod period) {
    if (_values.containsKey(period)) return _values[period];
    final o = _overview;
    return switch (period) {
      HoursPeriod.day => o?.day,
      HoursPeriod.week => o?.week,
      HoursPeriod.month => o?.month,
      HoursPeriod.year => o?.year,
    };
  }

  // ---- choix d'une période -------------------------------------------------

  void _pickCurrentPeriod() => switch (_period) {
        HoursPeriod.day => _pickDay(),
        HoursPeriod.week => _pickWeek(),
        HoursPeriod.month => _pickMonth(),
        HoursPeriod.year => _pickYear(),
      };

  Future<void> _pickDay() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('fr', 'FR'),
    );
    if (date == null || !mounted) return;

    setState(() => _selectedDate = date);
    await _query(
      HoursPeriod.day,
      WorkedHoursParams(
        period: WorkedHoursPeriod.day,
        year: date.year,
        month: date.month,
        day: date.day,
      ),
    );
  }

  Future<void> _pickWeek() async {
    final now = DateTime.now();
    final currentWeek = HoursWeeks.weekNumber(now);
    final week = await HoursPickers.week(
      context,
      year: now.year,
      initialWeek: _weekYear == now.year ? _weekNumber : currentWeek,
      currentWeek: currentWeek,
    );
    if (week == null || !mounted) return;

    setState(() {
      _weekNumber = week;
      _weekYear = now.year;
    });
    await _query(
      HoursPeriod.week,
      WorkedHoursParams(
        period: WorkedHoursPeriod.week,
        year: now.year,
        week: week,
      ),
    );
  }

  /// Semaine précédente (-1) ou suivante (+1).
  void _navigateWeek(int direction) {
    if (direction > 0 &&
        !HoursWeeks.canGoForward(_weekNumber, _weekYear, DateTime.now())) {
      return;
    }
    final (week, year) = HoursWeeks.shift(_weekNumber, _weekYear, direction);
    setState(() {
      _weekNumber = week;
      _weekYear = year;
    });
    _query(
      HoursPeriod.week,
      WorkedHoursParams(period: WorkedHoursPeriod.week, year: year, week: week),
    );
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final picked = await HoursPickers.month(
      context,
      initialMonth: _selectedMonth ?? now.month,
      initialYear: _selectedMonthYear ?? now.year,
    );
    if (picked == null || !mounted) return;
    final (month, year) = picked;

    setState(() {
      _selectedMonth = month;
      _selectedMonthYear = year;
    });
    await _query(
      HoursPeriod.month,
      WorkedHoursParams(
        period: WorkedHoursPeriod.month,
        year: year,
        month: month,
      ),
    );
  }

  Future<void> _pickYear() async {
    final year = await HoursPickers.year(
      context,
      initialYear: _selectedYear ?? DateTime.now().year,
    );
    if (year == null || !mounted) return;

    setState(() => _selectedYear = year);
    await _query(
      HoursPeriod.year,
      WorkedHoursParams(period: WorkedHoursPeriod.year, year: year),
    );
  }

  /// Tap sur une ligne de « Mes totaux » : valeur déjà connue, sans appel.
  void _openShortcut(HoursShortcut shortcut) {
    setState(() {
      switch (shortcut) {
        case HoursShortcut.today:
          _period = HoursPeriod.day;
          _resetPeriod(HoursPeriod.day);
        case HoursShortcut.week:
          _period = HoursPeriod.week;
          _resetPeriod(HoursPeriod.week);
        case HoursShortcut.month:
          _period = HoursPeriod.month;
          _resetPeriod(HoursPeriod.month);
        case HoursShortcut.lastMonth:
          final now = DateTime.now();
          final lastMonth = DateTime(now.year, now.month - 1, 1);
          _period = HoursPeriod.month;
          _resetPeriod(HoursPeriod.month);
          _selectedMonth = lastMonth.month;
          _selectedMonthYear = lastMonth.year;
          _values[HoursPeriod.month] = _overview?.lastMonth;
        case HoursShortcut.year:
          _period = HoursPeriod.year;
          _resetPeriod(HoursPeriod.year);
      }
    });
  }

  // ---- build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final ready = _overview != null && _error == null;

    return AppPage(
      title: 'Mes heures',
      bottom: AppPageBar(
        child: AppSegmented<HoursPeriod>(
          segments: [
            for (final p in HoursPeriod.values)
              AppSegment(value: p, label: p.label),
          ],
          selected: _period,
          onChanged: (p) => setState(() => _period = p),
        ),
      ),
      body: _buildBody(),
      dock: AppDock(
        skeleton: _isLoading && _overview == null,
        actions: [
          if (ready)
            DockAction(
              label: _period.pickLabel,
              icon: Icons.event_rounded,
              tone: DockTone.secondary,
              onPressed: _pickCurrentPeriod,
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return AppScrollView(
        onRefresh: _loadOverview,
        children: [AppErrorState(message: _error!, onRetry: _loadOverview)],
      );
    }

    final overview = _overview;
    if (overview == null) {
      return const AppScrollView(
        children: [
          AppHeroSkeleton(),
          SizedBox(height: AppSpacing.lg),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: AppSkeleton(width: 110, height: 16),
          ),
          SizedBox(height: AppSpacing.md),
          AppListSkeleton(rows: 5),
        ],
      );
    }

    final now = DateTime.now();
    return AppScrollView(
      onRefresh: _loadOverview,
      children: [
        AnimatedSwitcher(
          duration: AppDuration.base,
          child: KeyedSubtree(
            key: ValueKey(_period),
            child: _buildHero(now),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const AppSectionHeader(title: 'Mes totaux', summary: 'pauses déduites'),
        HoursOverviewCard(
          hours: overview,
          now: now,
          onSelect: _openShortcut,
        ),
      ],
    );
  }

  Widget _buildHero(DateTime now) {
    final period = _period;
    final query = _queries[period];
    final hours = _valueFor(period);
    final loading = _loadingPeriods.contains(period);
    final error = _periodErrors[period];
    final isWeek = period == HoursPeriod.week;
    final labels = switch (period) {
      HoursPeriod.day => HoursHeroLabels.day(_selectedDate, now),
      HoursPeriod.week => HoursHeroLabels.week(_weekNumber, _weekYear, now),
      HoursPeriod.month =>
        HoursHeroLabels.month(_selectedMonth, _selectedMonthYear, now),
      HoursPeriod.year => HoursHeroLabels.year(_selectedYear, now),
    };

    return HoursHeroCard(
      icon: period.icon,
      title: labels.title,
      subtitle: labels.subtitle,
      hours: hours,
      loading: loading,
      error: error,
      onRetry: query == null ? null : () => _query(period, query),
      showNavigation: isWeek,
      onPrevious: isWeek ? () => _navigateWeek(-1) : null,
      onNext: isWeek && HoursWeeks.canGoForward(_weekNumber, _weekYear, now)
          ? () => _navigateWeek(1)
          : null,
      resetLabel: labels.resetLabel,
      onReset: labels.isCurrent
          ? null
          : () => setState(() => _resetPeriod(period)),
    );
  }
}
