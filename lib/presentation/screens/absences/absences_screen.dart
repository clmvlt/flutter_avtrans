import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../widgets/widgets.dart';

/// Page de gestion des absences
class AbsencesScreen extends StatefulWidget {
  const AbsencesScreen({super.key});

  @override
  State<AbsencesScreen> createState() => _AbsencesScreenState();
}

class _AbsencesScreenState extends State<AbsencesScreen> {
  final List<Absence> _absences = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  String? _error;

  // Filtres
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  String? _filterStatus;
  AbsenceType? _filterType;
  List<AbsenceType> _absenceTypes = [];
  bool _hasActiveFilters = false;

  // Calendrier
  bool _isCalendarView = true; // Par défaut, afficher le calendrier
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now(); // Sélectionner la date du jour par défaut
  CalendarFormat _calendarFormat = CalendarFormat.month;
  Map<DateTime, List<Absence>> _absencesByDay = {};

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
    result.fold(
      (_) {},
      (types) => setState(() => _absenceTypes = types),
    );
  }

  void _updateFiltersState() {
    _hasActiveFilters = _filterStartDate != null ||
        _filterEndDate != null ||
        _filterStatus != null ||
        _filterType != null;
  }

  void _updateAbsencesByDay() {
    _absencesByDay.clear();
    for (final absence in _absences) {
      // Une absence peut couvrir plusieurs jours
      DateTime currentDay = DateTime(
        absence.startDate.year,
        absence.startDate.month,
        absence.startDate.day,
      );
      final endDay = DateTime(
        absence.endDate.year,
        absence.endDate.month,
        absence.endDate.day,
      );

      while (!currentDay.isAfter(endDay)) {
        _absencesByDay.putIfAbsent(currentDay, () => []).add(absence);
        currentDay = currentDay.add(const Duration(days: 1));
      }
    }
  }

  List<Absence> _getAbsencesForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _absencesByDay[normalizedDay] ?? [];
  }

  String _formatDateLong(DateTime date) {
    final dayNames = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    final monthNames = [
      'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
      'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'
    ];
    return '${dayNames[date.weekday - 1]} ${date.day} ${monthNames[date.month - 1]} ${date.year}';
  }

  AbsenceListParams _buildParams({int page = 0}) {
    return AbsenceListParams(
      page: page,
      size: 20,
      startDate: _filterStartDate,
      endDate: _filterEndDate,
      status: _filterStatus,
      absenceTypeUuid: _filterType?.uuid,
    );
  }

  Future<void> _loadAbsences() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await sl.absenceRepository.getMyAbsences(_buildParams());

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() {
          _error = failure.message;
          _isLoading = false;
        });
      },
      (response) {
        setState(() {
          _absences.clear();
          _absences.addAll(response.content);
          _currentPage = 0;
          _hasMore = !response.last;
          _isLoading = false;
          _updateAbsencesByDay();
        });
      },
    );
  }

  Future<void> _loadMoreAbsences() async {
    if (_isLoadingMore) return;

    setState(() => _isLoadingMore = true);

    final result = await sl.absenceRepository.getMyAbsences(
      _buildParams(page: _currentPage + 1),
    );

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() => _isLoadingMore = false);
      },
      (response) {
        setState(() {
          _absences.addAll(response.content);
          _currentPage++;
          _hasMore = !response.last;
          _isLoadingMore = false;
          _updateAbsencesByDay();
        });
      },
    );
  }

  Future<void> _cancelAbsence(Absence absence) async {
    final colors = context.colors;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.base),
        ),
        title: Text(
          'Annuler la demande',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: colors.foreground),
        ),
        content: Text(
          'Voulez-vous vraiment annuler cette demande d\'absence ?',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.mutedForeground),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Non',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: colors.mutedForeground),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: colors.destructive),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await sl.absenceRepository.cancelAbsence(absence.uuid);

    if (!mounted) return;

    result.fold(
      (failure) => _showError(failure.message),
      (updatedAbsence) {
        final index = _absences.indexWhere((a) => a.uuid == absence.uuid);
        if (index != -1) {
          setState(() {
            _absences[index] = updatedAbsence;
            _updateAbsencesByDay();
          });
        }
        _showSuccess('Demande annulée');
      },
    );
  }

  void _showCreateDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateAbsenceSheet(
        onCreated: (absence) {
          setState(() {
            _absences.insert(0, absence);
            _updateAbsencesByDay();
          });
        },
      ),
    );
  }

  void _showFiltersDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FiltersSheet(
        absenceTypes: _absenceTypes,
        initialStartDate: _filterStartDate,
        initialEndDate: _filterEndDate,
        initialStatus: _filterStatus,
        initialType: _filterType,
        onApply: (startDate, endDate, status, type) {
          setState(() {
            _filterStartDate = startDate;
            _filterEndDate = endDate;
            _filterStatus = status;
            _filterType = type;
            _updateFiltersState();
          });
          _loadAbsences();
        },
        onClear: () {
          setState(() {
            _filterStartDate = null;
            _filterEndDate = null;
            _filterStatus = null;
            _filterType = null;
            _hasActiveFilters = false;
          });
          _loadAbsences();
        },
      ),
    );
  }

  void _showError(String message) {
    final colors = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: colors.destructive, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(message)),
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

  void _showSuccess(String message) {
    final colors = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline, color: colors.success, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: colors.card,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.base),
          side: BorderSide(color: colors.success),
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
        title: const Text('Mes absences'),
        actions: [
          // Toggle vue calendrier / liste
          IconButton(
            icon: Icon(
              _isCalendarView ? Icons.list : Icons.calendar_month,
              size: 22,
            ),
            onPressed: () => setState(() => _isCalendarView = !_isCalendarView),
            tooltip: _isCalendarView ? 'Vue liste' : 'Vue calendrier',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          ),
          // Filtres (seulement en vue liste)
          if (!_isCalendarView)
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.filter_list, size: 22),
                  onPressed: _showFiltersDialog,
                  tooltip: 'Filtres',
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                ),
                if (_hasActiveFilters)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        backgroundColor: colors.primary,
        child: Icon(Icons.add, color: colors.primaryForeground),
      ),
      body: _buildBody(colors),
    );
  }

  Widget _buildBody(AppColors colors) {
    if (_isLoading) {
      return const LoadingIndicator(message: 'Chargement...');
    }

    if (_error != null) {
      return AppEmptyState(
        icon: Icons.error_outline,
        title: _error!,
        actionText: 'Réessayer',
        onAction: _loadAbsences,
      );
    }

    // Vue calendrier
    if (_isCalendarView) {
      return _buildCalendarView(colors);
    }

    // Vue liste
    if (_absences.isEmpty) {
      return AppEmptyState(
        icon: Icons.event_busy,
        title: _hasActiveFilters
            ? 'Aucune absence ne correspond aux filtres'
            : 'Aucune demande d\'absence',
        subtitle: _hasActiveFilters
            ? null
            : 'Appuyez sur + pour créer une demande',
        actionText: _hasActiveFilters ? 'Effacer les filtres' : null,
        onAction: _hasActiveFilters
            ? () {
                setState(() {
                  _filterStartDate = null;
                  _filterEndDate = null;
                  _filterStatus = null;
                  _filterType = null;
                  _hasActiveFilters = false;
                });
                _loadAbsences();
              }
            : null,
      );
    }

    return Column(
      children: [
        // Barre de filtres actifs
        if (_hasActiveFilters) _buildActiveFiltersBar(colors),
        // Liste des absences
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadAbsences,
            color: colors.primary,
            backgroundColor: colors.card,
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(AppSpacing.base),
              itemCount: _absences.length + (_isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _absences.length) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.base),
                      child: CircularProgressIndicator(color: colors.primary),
                    ),
                  );
                }

                final absence = _absences[index];
                return _buildAbsenceCard(absence, colors);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarView(AppColors colors) {
    // Compter les absences en attente
    final pendingCount = _absences.where((a) => a.status == AbsenceStatus.pending).length;

    return Column(
      children: [
        // Bannière absences en attente (cliquable)
        if (pendingCount > 0)
          GestureDetector(
            onTap: () {
              setState(() {
                _isCalendarView = false;
                _filterStatus = 'PENDING';
                _filterStartDate = null;
                _filterEndDate = null;
                _filterType = null;
                _updateFiltersState();
              });
              _loadAbsences();
            },
            child: Container(
              margin: const EdgeInsets.all(AppSpacing.sm),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: colors.warningMuted,
                borderRadius: BorderRadius.circular(AppRadius.base),
                border: Border.all(color: colors.warning.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: colors.warning,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$pendingCount',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      pendingCount == 1
                          ? 'Vous avez 1 demande en attente de validation'
                          : 'Vous avez $pendingCount demandes en attente de validation',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.warning,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 20, color: colors.warning),
                ],
              ),
            ),
          ),
        // Calendrier
        TableCalendar<Absence>(
          firstDay: DateTime(2020),
          lastDay: DateTime.now().add(const Duration(days: 365)),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          calendarFormat: _calendarFormat,
          locale: 'fr_FR',
          startingDayOfWeek: StartingDayOfWeek.monday,
          eventLoader: _getAbsencesForDay,
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
            defaultTextStyle: TextStyle(color: colors.foreground),
            weekendTextStyle: TextStyle(color: colors.mutedForeground),
            outsideTextStyle: TextStyle(color: colors.mutedForeground),
            selectedDecoration: BoxDecoration(
              color: colors.primary,
              shape: BoxShape.circle,
            ),
            selectedTextStyle: const TextStyle(color: Colors.white),
            todayDecoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            todayTextStyle: TextStyle(
              color: colors.primary,
              fontWeight: FontWeight.bold,
            ),
            markerDecoration: BoxDecoration(
              color: colors.warning,
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
            titleTextStyle: Theme.of(context).textTheme.titleMedium!.copyWith(
              color: colors.foreground,
            ),
            formatButtonTextStyle: Theme.of(context).textTheme.labelSmall!.copyWith(
              color: colors.primary,
            ),
            formatButtonDecoration: BoxDecoration(
              border: Border.all(color: colors.primary),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            leftChevronIcon: Icon(Icons.chevron_left, color: colors.foreground),
            rightChevronIcon: Icon(Icons.chevron_right, color: colors.foreground),
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

              // Rouge pour les absences approuvées, gris pour tout le reste
              final hasApproved = events.any((e) => e.status == AbsenceStatus.approved);
              final markerColor = hasApproved ? colors.destructive : colors.mutedForeground;

              return Positioned(
                bottom: 1,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: markerColor,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Détails du jour sélectionné
        if (_selectedDay != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
            child: Row(
              children: [
                Icon(Icons.event, size: 20, color: colors.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  _formatDateLong(_selectedDay!),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colors.foreground,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_getAbsencesForDay(_selectedDay!).length} absence(s)',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        // Liste des absences du jour
        Expanded(
          child: _selectedDay == null
              ? _buildSelectDayHint(colors)
              : _getAbsencesForDay(_selectedDay!).isEmpty
                  ? _buildNoDayAbsences(colors)
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
                      itemCount: _getAbsencesForDay(_selectedDay!).length,
                      itemBuilder: (context, index) {
                        return _buildAbsenceCard(
                          _getAbsencesForDay(_selectedDay!)[index],
                          colors,
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildSelectDayHint(AppColors colors) {
    return AppEmptyState(
      icon: Icons.touch_app,
      title: 'Sélectionnez un jour',
      subtitle: 'pour voir les absences',
    );
  }

  Widget _buildNoDayAbsences(AppColors colors) {
    return AppEmptyState(
      icon: Icons.event_busy,
      title: 'Aucune absence ce jour',
    );
  }

  Widget _buildActiveFiltersBar(AppColors colors) {
    final dateFormat = DateFormat('dd/MM', 'fr_FR');
    final filters = <Widget>[];

    if (_filterStartDate != null || _filterEndDate != null) {
      String dateText = '';
      if (_filterStartDate != null && _filterEndDate != null) {
        dateText = '${dateFormat.format(_filterStartDate!)} - ${dateFormat.format(_filterEndDate!)}';
      } else if (_filterStartDate != null) {
        dateText = 'Depuis ${dateFormat.format(_filterStartDate!)}';
      } else {
        dateText = 'Jusqu\'au ${dateFormat.format(_filterEndDate!)}';
      }
      filters.add(_buildFilterChip(dateText, Icons.calendar_today, colors, () {
        setState(() {
          _filterStartDate = null;
          _filterEndDate = null;
          _updateFiltersState();
        });
        _loadAbsences();
      }));
    }

    if (_filterStatus != null) {
      final status = AbsenceStatus.fromString(_filterStatus!);
      filters.add(_buildFilterChip(status.displayName, Icons.flag, colors, () {
        setState(() {
          _filterStatus = null;
          _updateFiltersState();
        });
        _loadAbsences();
      }));
    }

    if (_filterType != null) {
      filters.add(_buildFilterChip(_filterType!.name, Icons.category, colors, () {
        setState(() {
          _filterType = null;
          _updateFiltersState();
        });
        _loadAbsences();
      }));
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(
          bottom: BorderSide(color: colors.border),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text(
              'Filtres:',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.mutedForeground,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            ...filters,
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, IconData icon, AppColors colors, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(right: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.primary),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          GestureDetector(
            onTap: onRemove,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: Icon(Icons.close, size: 14, color: colors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAbsenceCard(Absence absence, AppColors colors) {
    final dateFormat = DateFormat('dd/MM/yyyy', 'fr_FR');
    final statusColor = _getStatusColor(absence.status, colors);
    final typeColor = _parseColor(absence.typeColor, colors);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Type d'absence
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  absence.typeName,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: typeColor,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Statut
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  absence.status.displayName,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: statusColor,
                  ),
                ),
              ),
              const Spacer(),
              if (absence.canBeCancelled)
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 20,
                    color: colors.destructive,
                  ),
                  onPressed: () => _cancelAbsence(absence),
                  tooltip: 'Annuler',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 20, color: colors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${dateFormat.format(absence.startDate)} - ${dateFormat.format(absence.endDate)}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.foreground,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '(${absence.durationInDays} jour${absence.durationInDays > 1 ? 's' : ''})',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.mutedForeground,
                ),
              ),
              if (absence.period != null && absence.period!.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    absence.period == 'matin' ? 'Matin' : 'Après-midi',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.info,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (absence.reason.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              absence.reason,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.mutedForeground,
              ),
            ),
          ],
          if (absence.rejectionReason != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: colors.destructive.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 20, color: colors.destructive),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Motif du refus : ${absence.rejectionReason}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.destructive,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(AbsenceStatus status, AppColors colors) {
    switch (status) {
      case AbsenceStatus.pending:
        return colors.warning;
      case AbsenceStatus.approved:
        return colors.success;
      case AbsenceStatus.rejected:
        return colors.destructive;
      case AbsenceStatus.cancelled:
        return colors.mutedForeground;
    }
  }

  Color _parseColor(String? colorString, AppColors colors) {
    if (colorString == null) return colors.primary;
    try {
      if (colorString.startsWith('#')) {
        return Color(int.parse(colorString.substring(1), radix: 16) + 0xFF000000);
      }
      return colors.primary;
    } catch (_) {
      return colors.primary;
    }
  }
}

/// Bottom sheet pour les filtres
class _FiltersSheet extends StatefulWidget {
  final List<AbsenceType> absenceTypes;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final String? initialStatus;
  final AbsenceType? initialType;
  final void Function(DateTime?, DateTime?, String?, AbsenceType?) onApply;
  final VoidCallback onClear;

  const _FiltersSheet({
    required this.absenceTypes,
    this.initialStartDate,
    this.initialEndDate,
    this.initialStatus,
    this.initialType,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  DateTime? _startDate;
  DateTime? _endDate;
  String? _status;
  AbsenceType? _type;

  final List<Map<String, String>> _statusOptions = [
    {'value': 'PENDING', 'label': 'En attente'},
    {'value': 'APPROVED', 'label': 'Approuvée'},
    {'value': 'REJECTED', 'label': 'Refusée'},
    {'value': 'CANCELLED', 'label': 'Annulée'},
  ];

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;
    _status = widget.initialStatus;
    _type = widget.initialType;
  }

  Future<void> _selectStartDate() async {
    final colors = context.colors;
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: colors.primary,
                    surface: colors.card,
                    onSurface: colors.foreground,
                  )
                : ColorScheme.light(
                    primary: colors.primary,
                    surface: colors.card,
                    onSurface: colors.foreground,
                  ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      setState(() {
        _startDate = date;
        if (_endDate != null && _endDate!.isBefore(date)) {
          _endDate = date;
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    final colors = context.colors;
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: colors.primary,
                    surface: colors.card,
                    onSurface: colors.foreground,
                  )
                : ColorScheme.light(
                    primary: colors.primary,
                    surface: colors.card,
                    onSurface: colors.foreground,
                  ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      setState(() => _endDate = date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dateFormat = DateFormat('dd/MM/yyyy', 'fr_FR');

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.base),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.base),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filtres',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colors.foreground,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    widget.onClear();
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  child: Text(
                    'Effacer tout',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(color: colors.destructive),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Période
            Text(
              'Période',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colors.mutedForeground,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _selectStartDate,
                    borderRadius: BorderRadius.circular(AppRadius.base),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: colors.muted,
                        borderRadius: BorderRadius.circular(AppRadius.base),
                        border: Border.all(color: colors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, size: 20, color: colors.primary),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              _startDate != null
                                  ? dateFormat.format(_startDate!)
                                  : 'Début',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: _startDate != null
                                    ? colors.foreground
                                    : colors.mutedForeground,
                              ),
                            ),
                          ),
                          if (_startDate != null)
                            GestureDetector(
                              onTap: () => setState(() => _startDate = null),
                              child: Icon(Icons.close, size: 20, color: colors.mutedForeground),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: Text('-', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.mutedForeground)),
                ),
                Expanded(
                  child: InkWell(
                    onTap: _selectEndDate,
                    borderRadius: BorderRadius.circular(AppRadius.base),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: colors.muted,
                        borderRadius: BorderRadius.circular(AppRadius.base),
                        border: Border.all(color: colors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, size: 20, color: colors.primary),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              _endDate != null
                                  ? dateFormat.format(_endDate!)
                                  : 'Fin',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: _endDate != null
                                    ? colors.foreground
                                    : colors.mutedForeground,
                              ),
                            ),
                          ),
                          if (_endDate != null)
                            GestureDetector(
                              onTap: () => setState(() => _endDate = null),
                              child: Icon(Icons.close, size: 20, color: colors.mutedForeground),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Statut
            Text(
              'Statut',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colors.mutedForeground,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: _statusOptions.map((option) {
                final isSelected = _status == option['value'];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _status = isSelected ? null : option['value'];
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colors.primary.withValues(alpha: 0.2)
                          : colors.muted,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                        color: isSelected ? colors.primary : colors.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      option['label']!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? colors.primary : colors.foreground,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Type d'absence
            if (widget.absenceTypes.isNotEmpty) ...[
              Text(
                'Type d\'absence',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.mutedForeground,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: widget.absenceTypes.map((type) {
                  final isSelected = _type?.uuid == type.uuid;
                  final typeColor = _parseTypeColor(type.color, colors);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _type = isSelected ? null : type;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? typeColor.withValues(alpha: 0.2)
                            : colors.muted,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                          color: isSelected ? typeColor : colors.border,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Text(
                        type.name,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? typeColor : colors.foreground,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            // Bouton appliquer
            AppButton(
              text: 'Appliquer les filtres',
              onPressed: () {
                widget.onApply(_startDate, _endDate, _status, _type);
                Navigator.pop(context);
              },
              backgroundColor: colors.primary,
              foregroundColor: colors.primaryForeground,
            ),
            const SizedBox(height: AppSpacing.base),
          ],
        ),
      ),
    );
  }

  Color _parseTypeColor(String? colorString, AppColors colors) {
    if (colorString == null) return colors.primary;
    try {
      if (colorString.startsWith('#')) {
        return Color(int.parse(colorString.substring(1), radix: 16) + 0xFF000000);
      }
      return colors.primary;
    } catch (_) {
      return colors.primary;
    }
  }
}

/// Bottom sheet pour créer une nouvelle absence
class _CreateAbsenceSheet extends StatefulWidget {
  final void Function(Absence absence) onCreated;

  const _CreateAbsenceSheet({required this.onCreated});

  @override
  State<_CreateAbsenceSheet> createState() => _CreateAbsenceSheetState();
}

class _CreateAbsenceSheetState extends State<_CreateAbsenceSheet> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _customTypeController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedPeriod;
  bool _isLoading = false;
  bool _isLoadingTypes = true;
  List<AbsenceType> _absenceTypes = [];
  AbsenceType? _selectedType;
  bool _useCustomType = false;

  @override
  void initState() {
    super.initState();
    _loadAbsenceTypes();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _customTypeController.dispose();
    super.dispose();
  }

  Future<void> _loadAbsenceTypes() async {
    final result = await sl.absenceRepository.getAbsenceTypes();

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() => _isLoadingTypes = false);
      },
      (types) {
        setState(() {
          _absenceTypes = types;
          _isLoadingTypes = false;
        });
      },
    );
  }

  Future<void> _selectStartDate() async {
    final colors = context.colors;
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: colors.primary,
                    surface: colors.card,
                    onSurface: colors.foreground,
                  )
                : ColorScheme.light(
                    primary: colors.primary,
                    surface: colors.card,
                    onSurface: colors.foreground,
                  ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      setState(() {
        _startDate = date;
        if (_endDate != null && _endDate!.isBefore(date)) {
          _endDate = date;
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    if (_startDate == null) {
      _selectStartDate();
      return;
    }

    final colors = context.colors;
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate!,
      firstDate: _startDate!,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: colors.primary,
                    surface: colors.card,
                    onSurface: colors.foreground,
                  )
                : ColorScheme.light(
                    primary: colors.primary,
                    surface: colors.card,
                    onSurface: colors.foreground,
                  ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      setState(() => _endDate = date);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      _showError('Veuillez sélectionner les dates');
      return;
    }
    if (_selectedType == null && !_useCustomType) {
      _showError('Veuillez sélectionner un type d\'absence');
      return;
    }
    if (_useCustomType && _customTypeController.text.trim().isEmpty) {
      _showError('Veuillez saisir un type personnalisé');
      return;
    }

    setState(() => _isLoading = true);

    final result = await sl.absenceRepository.createAbsence(
      CreateAbsenceRequest(
        startDate: _startDate!,
        endDate: _endDate!,
        reason: _reasonController.text.trim(),
        absenceTypeUuid: _useCustomType ? null : _selectedType?.uuid,
        customType: _useCustomType ? _customTypeController.text.trim() : null,
        period: _selectedPeriod,
      ),
    );

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() => _isLoading = false);
        _showError(failure.message);
      },
      (absence) {
        widget.onCreated(absence);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Demande créée avec succès'),
            backgroundColor: context.colors.success,
          ),
        );
      },
    );
  }

  void _showError(String message) {
    final colors = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: colors.destructive, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(message)),
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

  Widget _buildPeriodChip(String? value, String label, AppColors colors) {
    final isSelected = _selectedPeriod == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedPeriod = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.primary.withValues(alpha: 0.2)
              : colors.muted,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: isSelected ? colors.primary : colors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? colors.primary : colors.foreground,
          ),
        ),
      ),
    );
  }

  Color _parseTypeColor(String? colorString, AppColors colors) {
    if (colorString == null) return colors.primary;
    try {
      if (colorString.startsWith('#')) {
        return Color(int.parse(colorString.substring(1), radix: 16) + 0xFF000000);
      }
      return colors.primary;
    } catch (_) {
      return colors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dateFormat = DateFormat('dd/MM/yyyy', 'fr_FR');

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.base,
        right: AppSpacing.base,
        top: AppSpacing.base,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.base,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.base),
              Text(
                'Nouvelle demande d\'absence',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colors.foreground,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),

              // Type d'absence
              Text(
                'Type d\'absence',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.mutedForeground,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_isLoadingTypes)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.primary,
                      ),
                    ),
                  ),
                )
              else ...[
                // Liste des types
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    ..._absenceTypes.map((type) {
                      final isSelected = _selectedType == type && !_useCustomType;
                      final typeColor = _parseTypeColor(type.color, colors);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedType = type;
                            _useCustomType = false;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? typeColor.withValues(alpha: 0.2)
                                : colors.muted,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            border: Border.all(
                              color: isSelected ? typeColor : colors.border,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Text(
                            type.name,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected ? typeColor : colors.foreground,
                            ),
                          ),
                        ),
                      );
                    }),
                    // Option type personnalisé
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _useCustomType = true;
                          _selectedType = null;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: _useCustomType
                              ? colors.primary.withValues(alpha: 0.2)
                              : colors.muted,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(
                            color: _useCustomType ? colors.primary : colors.border,
                            width: _useCustomType ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add,
                              size: 20,
                              color: _useCustomType ? colors.primary : colors.mutedForeground,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              'Autre',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: _useCustomType ? FontWeight.w600 : FontWeight.w400,
                                color: _useCustomType ? colors.primary : colors.foreground,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (_useCustomType) ...[
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _customTypeController,
                    decoration: InputDecoration(
                      hintText: 'Type personnalisé...',
                      hintStyle: TextStyle(color: colors.mutedForeground),
                      filled: true,
                      fillColor: colors.muted,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.base),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.base),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.base),
                        borderSide: BorderSide(color: colors.primary),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.md,
                      ),
                    ),
                    style: TextStyle(color: colors.foreground),
                  ),
                ],
              ],
              const SizedBox(height: AppSpacing.base),

              // Date de début
              Text(
                'Date de début',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.mutedForeground,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              InkWell(
                onTap: _selectStartDate,
                borderRadius: BorderRadius.circular(AppRadius.base),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: colors.muted,
                    borderRadius: BorderRadius.circular(AppRadius.base),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 20, color: colors.primary),
                      const SizedBox(width: AppSpacing.md),
                      Text(
                        _startDate != null
                            ? dateFormat.format(_startDate!)
                            : 'Sélectionner une date',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _startDate != null
                              ? colors.foreground
                              : colors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.base),

              // Date de fin
              Text(
                'Date de fin',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.mutedForeground,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              InkWell(
                onTap: _selectEndDate,
                borderRadius: BorderRadius.circular(AppRadius.base),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: colors.muted,
                    borderRadius: BorderRadius.circular(AppRadius.base),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 20, color: colors.primary),
                      const SizedBox(width: AppSpacing.md),
                      Text(
                        _endDate != null
                            ? dateFormat.format(_endDate!)
                            : 'Sélectionner une date',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _endDate != null
                              ? colors.foreground
                              : colors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.base),

              // Période (demi-journée)
              Text(
                'Période (optionnel)',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.mutedForeground,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  _buildPeriodChip(null, 'Journée complète', colors),
                  _buildPeriodChip('matin', 'Matin', colors),
                  _buildPeriodChip('apres-midi', 'Après-midi', colors),
                ],
              ),
              const SizedBox(height: AppSpacing.base),

              // Motif
              Text(
                'Motif (optionnel)',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.mutedForeground,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Décrivez le motif de votre absence...',
                  hintStyle: TextStyle(color: colors.mutedForeground),
                  filled: true,
                  fillColor: colors.muted,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.base),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.base),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.base),
                    borderSide: BorderSide(color: colors.primary),
                  ),
                ),
                style: TextStyle(color: colors.foreground),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Bouton submit
              AppButton(
                text: 'Créer la demande',
                onPressed: _submit,
                isLoading: _isLoading,
                backgroundColor: colors.primary,
                foregroundColor: colors.primaryForeground,
              ),
              const SizedBox(height: AppSpacing.base),
            ],
          ),
        ),
      ),
    );
  }
}
