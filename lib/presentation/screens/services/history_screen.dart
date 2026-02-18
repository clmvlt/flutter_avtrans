import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/di/service_locator.dart';
import '../../../data/models/models.dart';
import '../../widgets/widgets.dart';

/// Page d'historique des services
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final List<Service> _services = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  static const int _pageSize = 20;

  final ScrollController _scrollController = ScrollController();

  // Filtres
  bool? _filterIsBreak;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  ServiceHistorySortBy _sortBy = ServiceHistorySortBy.debut;
  SortDirection _sortDirection = SortDirection.desc;

  // Vue calendrier (par défaut)
  bool _isCalendarView = true;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now(); // Sélectionner la date du jour par défaut
  CalendarFormat _calendarFormat = CalendarFormat.month;
  Map<DateTime, List<Service>> _servicesByDay = {};

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  ServiceHistoryParams _buildParams({int page = 0}) {
    return ServiceHistoryParams(
      page: page,
      size: _pageSize,
      isBreak: _filterIsBreak,
      startDate: _filterStartDate,
      endDate: _filterEndDate,
      sortBy: _sortBy,
      sortDirection: _sortDirection,
    );
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _currentPage = 0;
      _services.clear();
      _hasMore = true;
    });

    final result = await sl.serviceRepository.getHistory(_buildParams());

    if (!mounted) return;

    result.fold(
      (failure) {
        _showError(failure.message);
        setState(() => _isLoading = false);
      },
      (response) {
        setState(() {
          _services.addAll(response.content);
          _hasMore = !response.last;
          _isLoading = false;
          _updateServicesByDay();
        });
      },
    );
  }

  void _updateServicesByDay() {
    _servicesByDay.clear();
    for (final service in _services) {
      // Convertir en heure locale pour regrouper par jour local
      final debutLocal = service.debut.toLocal();
      final day = DateTime(
        debutLocal.year,
        debutLocal.month,
        debutLocal.day,
      );
      _servicesByDay.putIfAbsent(day, () => []).add(service);
    }
  }

  List<Service> _getServicesForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _servicesByDay[normalizedDay] ?? [];
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    final result = await sl.serviceRepository.getHistory(
      _buildParams(page: _currentPage + 1),
    );

    if (!mounted) return;

    result.fold(
      (failure) {
        _showError(failure.message);
        setState(() => _isLoadingMore = false);
      },
      (response) {
        setState(() {
          _currentPage++;
          _services.addAll(response.content);
          _hasMore = !response.last;
          _isLoadingMore = false;
        });
      },
    );
  }

  void _showError(String message) {
    final colors = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: colors.error, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: colors.bgSecondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.base),
          side: BorderSide(color: colors.error),
        ),
      ),
    );
  }

  void _showFilterSheet() {
    final colors = context.colors;

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.bgSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) => _FilterSheet(
        filterIsBreak: _filterIsBreak,
        filterStartDate: _filterStartDate,
        filterEndDate: _filterEndDate,
        sortBy: _sortBy,
        sortDirection: _sortDirection,
        onApply: (isBreak, startDate, endDate, sortBy, sortDirection) {
          setState(() {
            _filterIsBreak = isBreak;
            _filterStartDate = startDate;
            _filterEndDate = endDate;
            _sortBy = sortBy;
            _sortDirection = sortDirection;
          });
          _loadHistory();
        },
      ),
    );
  }

  int get _activeFiltersCount {
    int count = 0;
    if (_filterIsBreak != null) count++;
    if (_filterStartDate != null) count++;
    if (_filterEndDate != null) count++;
    return count;
  }

  bool get _hasActiveFilters => _activeFiltersCount > 0;

  void _clearFilters() {
    setState(() {
      _filterIsBreak = null;
      _filterStartDate = null;
      _filterEndDate = null;
      _sortBy = ServiceHistorySortBy.debut;
      _sortDirection = SortDirection.desc;
    });
    _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bgPrimary,
      appBar: AppBar(
        title: const Text('Historique'),
        backgroundColor: colors.bgSecondary,
        actions: [
          // Toggle vue liste/calendrier
          IconButton(
            icon: Icon(
              _isCalendarView ? Icons.list : Icons.calendar_month,
              size: 24,
            ),
            onPressed: () => setState(() => _isCalendarView = !_isCalendarView),
            tooltip: _isCalendarView ? 'Vue liste' : 'Vue calendrier',
          ),
          // Bouton filtre avec badge (seulement en vue liste)
          if (!_isCalendarView)
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    _hasActiveFilters ? Icons.filter_list : Icons.filter_list_outlined,
                    size: 24,
                    color: _hasActiveFilters ? colors.primary : null,
                  ),
                  onPressed: _showFilterSheet,
                  tooltip: 'Filtres',
                ),
                if (_hasActiveFilters)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$_activeFiltersCount',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // Barre de filtres actifs (seulement en vue liste)
          if (_hasActiveFilters && !_isCalendarView) _buildActiveFiltersBar(colors),
          // Contenu
          Expanded(
            child: _isLoading
                ? const LoadingIndicator(message: 'Chargement...')
                : _isCalendarView
                    ? _buildCalendarView(colors)
                    : RefreshIndicator(
                        onRefresh: _loadHistory,
                        color: colors.primary,
                        backgroundColor: colors.bgSecondary,
                        child: _services.isEmpty
                            ? _buildEmptyState(colors)
                            : _buildHistoryList(colors),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarView(AppColors colors) {
    return Column(
      children: [
        // Calendrier
        Container(
          margin: const EdgeInsets.all(AppSpacing.base),
          decoration: BoxDecoration(
            color: colors.bgSecondary,
            borderRadius: BorderRadius.circular(AppRadius.base),
            border: Border.all(color: colors.borderPrimary),
          ),
          child: TableCalendar<Service>(
            firstDay: DateTime(2020),
            lastDay: DateTime.now().add(const Duration(days: 365)),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: _calendarFormat,
            locale: 'fr_FR',
            startingDayOfWeek: StartingDayOfWeek.monday,
            eventLoader: _getServicesForDay,
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
              _focusedDay = focusedDay;
            },
            calendarStyle: CalendarStyle(
              // Jours normaux
              defaultTextStyle: TextStyle(color: colors.textPrimary),
              weekendTextStyle: TextStyle(color: colors.textSecondary),
              outsideTextStyle: TextStyle(color: colors.textMuted),
              // Jour sélectionné
              selectedDecoration: BoxDecoration(
                color: colors.primary,
                shape: BoxShape.circle,
              ),
              selectedTextStyle: const TextStyle(color: Colors.white),
              // Aujourd'hui
              todayDecoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              todayTextStyle: TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.bold,
              ),
              // Marqueurs d'événements
              markerDecoration: BoxDecoration(
                color: colors.success,
                shape: BoxShape.circle,
              ),
              markersMaxCount: 3,
              markerSize: 6,
              markerMargin: const EdgeInsets.symmetric(horizontal: 1),
            ),
            headerStyle: HeaderStyle(
              titleCentered: true,
              formatButtonVisible: true,
              formatButtonShowsNext: false,
              titleTextStyle: TextStyle(
                color: colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              formatButtonTextStyle: TextStyle(
                color: colors.primary,
                fontSize: 12,
              ),
              formatButtonDecoration: BoxDecoration(
                border: Border.all(color: colors.primary),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              leftChevronIcon: Icon(Icons.chevron_left, color: colors.textPrimary),
              rightChevronIcon: Icon(Icons.chevron_right, color: colors.textPrimary),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(
                color: colors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              weekendStyle: TextStyle(
                color: colors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (events.isEmpty) return null;

                final hasService = events.any((e) => !e.isBreak);
                final hasBreak = events.any((e) => e.isBreak);

                return Positioned(
                  bottom: 1,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasService)
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: colors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                      if (hasBreak)
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: colors.warning,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        // Liste des services du jour sélectionné
        if (_selectedDay != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
            child: Row(
              children: [
                Icon(Icons.event, size: 18, color: colors.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  _formatDateLong(_selectedDay!),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_getServicesForDay(_selectedDay!).length} entrée(s)',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        // Liste des services
        Expanded(
          child: _selectedDay == null
              ? _buildSelectDayHint(colors)
              : _getServicesForDay(_selectedDay!).isEmpty
                  ? _buildNoDayServices(colors)
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
                      itemCount: _getServicesForDay(_selectedDay!).length,
                      itemBuilder: (context, index) {
                        return _buildServiceCard(
                          _getServicesForDay(_selectedDay!)[index],
                          colors,
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildSelectDayHint(AppColors colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.touch_app,
            size: 48,
            color: colors.textMuted.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Sélectionnez un jour',
            style: TextStyle(
              fontSize: 16,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'pour voir les services',
            style: TextStyle(
              fontSize: 14,
              color: colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDayServices(AppColors colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy,
            size: 48,
            color: colors.textMuted.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Aucun service ce jour',
            style: TextStyle(
              fontSize: 16,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateLong(DateTime date) {
    const weekdays = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    const months = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'];
    return '${weekdays[date.weekday - 1]} ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Widget _buildActiveFiltersBar(AppColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.bgSecondary,
        border: Border(bottom: BorderSide(color: colors.borderPrimary)),
      ),
      child: Row(
        children: [
          // Chips des filtres actifs
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (_filterIsBreak != null)
                    _buildFilterChip(
                      icon: _filterIsBreak! ? Icons.coffee : Icons.work,
                      label: _filterIsBreak! ? 'Pauses' : 'Services',
                      color: _filterIsBreak! ? colors.warning : colors.success,
                      onRemove: () {
                        setState(() => _filterIsBreak = null);
                        _loadHistory();
                      },
                    ),
                  if (_filterStartDate != null)
                    _buildFilterChip(
                      icon: Icons.calendar_today,
                      label: 'Du ${_formatDateFull(_filterStartDate!)}',
                      color: colors.info,
                      onRemove: () {
                        setState(() => _filterStartDate = null);
                        _loadHistory();
                      },
                    ),
                  if (_filterEndDate != null)
                    _buildFilterChip(
                      icon: Icons.event,
                      label: 'Au ${_formatDateFull(_filterEndDate!)}',
                      color: colors.info,
                      onRemove: () {
                        setState(() => _filterEndDate = null);
                        _loadHistory();
                      },
                    ),
                ],
              ),
            ),
          ),
          // Bouton effacer tout
          const SizedBox(width: AppSpacing.sm),
          GestureDetector(
            onTap: _clearFilters,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: colors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(
                Icons.close,
                size: 18,
                color: colors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onRemove,
  }) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.only(right: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: colors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close, size: 14, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppColors colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _hasActiveFilters ? Icons.search_off : Icons.history,
            size: 64,
            color: colors.textMuted.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppSpacing.base),
          Text(
            _hasActiveFilters ? 'Aucun résultat' : 'Aucun historique',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _hasActiveFilters
                ? 'Modifiez vos filtres pour voir plus de résultats'
                : 'Vos services apparaîtront ici',
            style: TextStyle(
              fontSize: 14,
              color: colors.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
          if (_hasActiveFilters) ...[
            const SizedBox(height: AppSpacing.xl),
            OutlinedButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.filter_list_off, size: 18),
              label: const Text('Effacer les filtres'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.primary,
                side: BorderSide(color: colors.primary),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryList(AppColors colors) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppSpacing.base),
      itemCount: _services.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _services.length) {
          return _buildLoadingMore(colors);
        }
        return _buildServiceCard(_services[index], colors);
      },
    );
  }

  Widget _buildServiceCard(Service service, AppColors colors) {
    final isBreak = service.isBreak;
    final statusColor = isBreak ? colors.warning : colors.success;
    final statusIcon = isBreak ? Icons.coffee : Icons.work;
    final statusText = isBreak ? 'Pause' : 'Service';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: colors.bgSecondary,
        borderRadius: BorderRadius.circular(AppRadius.base),
        border: Border.all(color: colors.borderPrimary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  statusIcon,
                  size: 20,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                    Text(
                      _formatDate(service.debut.toLocal()),
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (service.fin != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.bgTertiary,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Text(
                    _formatDuration(service.debut, service.fin!),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colors.bgTertiary,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildTimeInfo(
                    'Début',
                    _formatTime(service.debut.toLocal()),
                    Icons.login,
                    colors,
                  ),
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: colors.borderPrimary,
                ),
                Expanded(
                  child: _buildTimeInfo(
                    'Fin',
                    service.fin != null ? _formatTime(service.fin!.toLocal()) : '-',
                    Icons.logout,
                    colors,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeInfo(String label, String time, IconData icon, AppColors colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: colors.textMuted),
        const SizedBox(width: AppSpacing.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: colors.textMuted,
              ),
            ),
            Text(
              time,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoadingMore(AppColors colors) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Center(
        child: CircularProgressIndicator(
          color: colors.primary,
          strokeWidth: 2,
        ),
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year;
    return '$day/$month/$year';
  }

  String _formatDateFull(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    return '$day/$month';
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDuration(DateTime start, DateTime end) {
    final duration = end.difference(start);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h${minutes.toString().padLeft(2, '0')}';
    }
    return '${minutes}min';
  }
}

/// Bottom sheet pour les filtres - Design amélioré
class _FilterSheet extends StatefulWidget {
  final bool? filterIsBreak;
  final DateTime? filterStartDate;
  final DateTime? filterEndDate;
  final ServiceHistorySortBy sortBy;
  final SortDirection sortDirection;
  final void Function(
    bool? isBreak,
    DateTime? startDate,
    DateTime? endDate,
    ServiceHistorySortBy sortBy,
    SortDirection sortDirection,
  ) onApply;

  const _FilterSheet({
    required this.filterIsBreak,
    required this.filterStartDate,
    required this.filterEndDate,
    required this.sortBy,
    required this.sortDirection,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late bool? _isBreak;
  late DateTime? _startDate;
  late DateTime? _endDate;
  late ServiceHistorySortBy _sortBy;
  late SortDirection _sortDirection;

  @override
  void initState() {
    super.initState();
    _isBreak = widget.filterIsBreak;
    _startDate = widget.filterStartDate;
    _endDate = widget.filterEndDate;
    _sortBy = widget.sortBy;
    _sortDirection = widget.sortDirection;
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final colors = context.colors;
    final initialDate = isStartDate
        ? (_startDate ?? DateTime.now())
        : (_endDate ?? DateTime.now());

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: colors.primary,
              brightness: colors.isDarkMode ? Brightness.dark : Brightness.light,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = DateTime(picked.year, picked.month, picked.day, 0, 0, 0);
        } else {
          _endDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
        }
      });
    }
  }

  bool get _hasChanges =>
      _isBreak != null ||
      _startDate != null ||
      _endDate != null ||
      _sortBy != ServiceHistorySortBy.debut ||
      _sortDirection != SortDirection.desc;

  void _resetAll() {
    setState(() {
      _isBreak = null;
      _startDate = null;
      _endDate = null;
      _sortBy = ServiceHistorySortBy.debut;
      _sortDirection = SortDirection.desc;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.borderSecondary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Header avec titre et bouton reset
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.tune, color: colors.primary, size: 24),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Filtres & Tri',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
              if (_hasChanges)
                TextButton(
                  onPressed: _resetAll,
                  style: TextButton.styleFrom(
                    foregroundColor: colors.error,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: const Text('Réinitialiser'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // Section Type
          _buildSectionHeader('Type d\'entrée', Icons.category, colors),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(child: _buildTypeOption(null, 'Tout', Icons.list, colors)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _buildTypeOption(false, 'Services', Icons.work, colors)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _buildTypeOption(true, 'Pauses', Icons.coffee, colors)),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // Section Période
          _buildSectionHeader('Période', Icons.date_range, colors),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _buildDateSelector(
                  'Date début',
                  _startDate,
                  Icons.event,
                  () => _selectDate(context, true),
                  () => setState(() => _startDate = null),
                  colors,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Icon(Icons.arrow_forward, color: colors.textMuted, size: 20),
              ),
              Expanded(
                child: _buildDateSelector(
                  'Date fin',
                  _endDate,
                  Icons.event,
                  () => _selectDate(context, false),
                  () => setState(() => _endDate = null),
                  colors,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // Section Tri
          _buildSectionHeader('Tri', Icons.sort, colors),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: colors.bgTertiary,
              borderRadius: BorderRadius.circular(AppRadius.base),
              border: Border.all(color: colors.borderPrimary),
            ),
            child: Row(
              children: [
                // Options de tri
                Expanded(
                  child: Row(
                    children: [
                      _buildSortOption(ServiceHistorySortBy.debut, 'Date', colors),
                      _buildSortOption(ServiceHistorySortBy.duree, 'Durée', colors),
                    ],
                  ),
                ),
                // Direction
                Container(
                  height: 32,
                  width: 1,
                  color: colors.borderPrimary,
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                ),
                _buildDirectionButton(colors),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),

          // Bouton Appliquer
          ElevatedButton(
            onPressed: () {
              widget.onApply(
                _isBreak,
                _startDate,
                _endDate,
                _sortBy,
                _sortDirection,
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.base),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Appliquer les filtres',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, AppColors colors) {
    return Row(
      children: [
        Icon(icon, size: 16, color: colors.textSecondary),
        const SizedBox(width: AppSpacing.sm),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildTypeOption(bool? value, String label, IconData icon, AppColors colors) {
    final isSelected = _isBreak == value;
    final Color bgColor;
    final Color borderColor;
    final Color contentColor;

    if (isSelected) {
      if (value == null) {
        bgColor = colors.primary;
        borderColor = colors.primary;
        contentColor = Colors.white;
      } else if (value) {
        bgColor = colors.warning;
        borderColor = colors.warning;
        contentColor = Colors.white;
      } else {
        bgColor = colors.success;
        borderColor = colors.success;
        contentColor = Colors.white;
      }
    } else {
      bgColor = colors.bgTertiary;
      borderColor = colors.borderPrimary;
      contentColor = colors.textSecondary;
    }

    return GestureDetector(
      onTap: () => setState(() => _isBreak = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: contentColor),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: contentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector(
    String label,
    DateTime? date,
    IconData icon,
    VoidCallback onTap,
    VoidCallback onClear,
    AppColors colors,
  ) {
    final hasDate = date != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: hasDate ? colors.info.withValues(alpha: 0.1) : colors.bgTertiary,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: hasDate ? colors.info.withValues(alpha: 0.3) : colors.borderPrimary,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: hasDate ? colors.info : colors.textMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.textMuted,
                  ),
                ),
                const Spacer(),
                if (hasDate)
                  GestureDetector(
                    onTap: onClear,
                    child: Icon(
                      Icons.close,
                      size: 14,
                      color: colors.textMuted,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              hasDate
                  ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'
                  : 'Sélectionner',
              style: TextStyle(
                fontSize: 14,
                fontWeight: hasDate ? FontWeight.w600 : FontWeight.normal,
                color: hasDate ? colors.textPrimary : colors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(ServiceHistorySortBy value, String label, AppColors colors) {
    final isSelected = _sortBy == value;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _sortBy = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected ? colors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? Colors.white : colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDirectionButton(AppColors colors) {
    final isDesc = _sortDirection == SortDirection.desc;

    return GestureDetector(
      onTap: () => setState(() {
        _sortDirection = isDesc ? SortDirection.asc : SortDirection.desc;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isDesc ? Icons.arrow_downward : Icons.arrow_upward,
              size: 16,
              color: colors.primary,
            ),
            const SizedBox(width: 4),
            Text(
              isDesc ? 'Récent' : 'Ancien',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
