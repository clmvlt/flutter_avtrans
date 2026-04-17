import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/di/service_locator.dart';
import '../../../data/models/models.dart';
import '../../widgets/widgets.dart';

/// Historique des pointages — vue calendrier mensuelle.
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

  DateTime _focusedDay = _today();
  DateTime? _selectedDay = _today();
  CalendarFormat _calendarFormat = CalendarFormat.month;

  /// `null` = Tout, `false` = Services, `true` = Pauses.
  bool? _typeFilter;

  @override
  void initState() {
    super.initState();
    _loadMonth(_focusedDay);
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

    setState(() => _loadingMonths.add(key));

    final result = await sl.serviceRepository.getMonthServices(
      year: month.year,
      month: month.month,
    );

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() => _loadingMonths.remove(key));
        _showError(failure.message);
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

  List<Service> _servicesOfFocusedMonth() {
    final services = _cache[_monthKey(_focusedDay)] ?? const [];
    if (_typeFilter == null) return services;
    return services.where((s) => s.isBreak == _typeFilter).toList();
  }

  List<Service> _servicesForDay(DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    return _servicesOfFocusedMonth().where((s) {
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

  void _showError(String message) {
    final colors = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: colors.destructive, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
        backgroundColor: colors.card,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.base),
          side: BorderSide(color: colors.destructive),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Historique'),
        actions: [
          if (!_isOnCurrentMonth)
            IconButton(
              icon: const Icon(Icons.today, size: 24),
              tooltip: 'Aujourd\'hui',
              onPressed: _jumpToToday,
            ),
          PopupMenuButton<bool?>(
            tooltip: 'Filtrer',
            icon: Icon(
              _typeFilter == null
                  ? Icons.filter_list_outlined
                  : Icons.filter_list,
              color: _typeFilter == null ? null : colors.primary,
            ),
            onSelected: (value) => setState(() => _typeFilter = value),
            itemBuilder: (context) => [
              _buildFilterItem(null, 'Tout', Icons.list, colors.primary),
              _buildFilterItem(false, 'Services', Icons.work, colors.success),
              _buildFilterItem(true, 'Pauses', Icons.coffee, colors.warning),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        color: colors.primary,
        backgroundColor: colors.card,
        onRefresh: _onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildCalendar(colors)),
            SliverToBoxAdapter(child: _buildDayHeader(colors)),
            _buildDayServices(colors),
            const SliverToBoxAdapter(
              child: SizedBox(height: AppSpacing.xl),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<bool?> _buildFilterItem(
    bool? value,
    String label,
    IconData icon,
    Color accent,
  ) {
    final colors = context.colors;
    final selected = _typeFilter == value;
    return PopupMenuItem<bool?>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: accent),
          const SizedBox(width: AppSpacing.md),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              color: colors.foreground,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          const Spacer(),
          if (selected)
            Icon(Icons.check, size: 18, color: colors.primary),
        ],
      ),
    );
  }

  Widget _buildCalendar(AppColors colors) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          if (_isCurrentMonthLoading)
            LinearProgressIndicator(
              minHeight: 2,
              color: colors.primary,
              backgroundColor: Colors.transparent,
            )
          else
            const SizedBox(height: 2),
          TableCalendar<Service>(
            firstDay: DateTime(2020),
            lastDay: DateTime.now().add(const Duration(days: 365)),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: _calendarFormat,
            locale: 'fr_FR',
            startingDayOfWeek: StartingDayOfWeek.monday,
            availableCalendarFormats: const {
              CalendarFormat.month: 'Mois',
              CalendarFormat.twoWeeks: '2 sem.',
              CalendarFormat.week: 'Semaine',
            },
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
            calendarStyle: CalendarStyle(
              defaultTextStyle: TextStyle(color: colors.foreground),
              weekendTextStyle: TextStyle(color: colors.mutedForeground),
              outsideTextStyle: TextStyle(
                color: colors.mutedForeground.withValues(alpha: 0.5),
              ),
              selectedDecoration: BoxDecoration(
                color: colors.primary,
                shape: BoxShape.circle,
              ),
              selectedTextStyle: const TextStyle(color: Colors.white),
              todayDecoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              todayTextStyle: TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.bold,
              ),
              markersMaxCount: 0,
            ),
            headerStyle: HeaderStyle(
              titleCentered: true,
              formatButtonVisible: true,
              formatButtonShowsNext: false,
              titleTextStyle:
                  Theme.of(context).textTheme.titleMedium!.copyWith(
                color: colors.foreground,
              ),
              formatButtonTextStyle:
                  Theme.of(context).textTheme.labelSmall!.copyWith(
                color: colors.primary,
              ),
              formatButtonDecoration: BoxDecoration(
                border: Border.all(color: colors.primary),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              leftChevronIcon:
                  Icon(Icons.chevron_left, color: colors.foreground),
              rightChevronIcon:
                  Icon(Icons.chevron_right, color: colors.foreground),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: Theme.of(context).textTheme.labelSmall!.copyWith(
                color: colors.mutedForeground,
              ),
              weekendStyle: Theme.of(context).textTheme.labelSmall!.copyWith(
                color: colors.mutedForeground,
              ),
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (events.isEmpty) return null;
                final hasService = events.any((e) => !e.isBreak);
                final hasBreak = events.any((e) => e.isBreak);
                return Positioned(
                  bottom: 2,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasService)
                        _MarkerDot(color: colors.success),
                      if (hasBreak)
                        _MarkerDot(color: colors.warning),
                    ],
                  ),
                );
              },
            ),
          ),
          _buildLegend(colors),
        ],
      ),
    );
  }

  Widget _buildLegend(AppColors colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.base,
        0,
        AppSpacing.base,
        AppSpacing.md,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _MarkerDot(color: colors.success),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'Service',
            style: Theme.of(context).textTheme.labelSmall!.copyWith(
              color: colors.mutedForeground,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          _MarkerDot(color: colors.warning),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'Pause',
            style: Theme.of(context).textTheme.labelSmall!.copyWith(
              color: colors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayHeader(AppColors colors) {
    if (_selectedDay == null) return const SizedBox.shrink();
    final count = _servicesForDay(_selectedDay!).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.base,
        0,
        AppSpacing.base,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(Icons.event, size: 20, color: colors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              _formatDateLong(_selectedDay!),
              style: Theme.of(context).textTheme.titleSmall!.copyWith(
                color: colors.foreground,
              ),
            ),
          ),
          Text(
            count > 1 ? '$count entrées' : '$count entrée',
            style: Theme.of(context).textTheme.labelSmall!.copyWith(
              color: colors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayServices(AppColors colors) {
    if (_selectedDay == null) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
          child: AppEmptyState(
            icon: Icons.touch_app,
            title: 'Sélectionnez un jour',
            subtitle: 'pour voir les pointages',
          ),
        ),
      );
    }

    final services = _servicesForDay(_selectedDay!);

    if (services.isEmpty) {
      if (_isCurrentMonthLoading &&
          !_cache.containsKey(_monthKey(_focusedDay))) {
        return const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
            child: LoadingIndicator(message: 'Chargement du mois...'),
          ),
        );
      }
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
          child: AppEmptyState(
            icon: _typeFilter == null ? Icons.event_busy : Icons.search_off,
            title: _typeFilter == null
                ? 'Aucun pointage ce jour'
                : 'Aucun résultat',
            subtitle: _typeFilter == null
                ? null
                : 'Essayez un autre filtre',
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
      sliver: SliverList.builder(
        itemCount: services.length,
        itemBuilder: (context, index) => ServiceDayTile(
          service: services[index],
        ),
      ),
    );
  }

  String _formatDateLong(DateTime date) {
    const weekdays = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    const months = [
      'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
      'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc',
    ];
    return '${weekdays[date.weekday - 1]} ${date.day} '
        '${months[date.month - 1]} ${date.year}';
  }
}

class _MarkerDot extends StatelessWidget {
  final Color color;
  const _MarkerDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
