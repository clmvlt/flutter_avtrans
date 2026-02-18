import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../widgets/widgets.dart';

/// Écran d'affichage des heures travaillées
class MesHeuresScreen extends StatefulWidget {
  const MesHeuresScreen({super.key});

  @override
  State<MesHeuresScreen> createState() => _MesHeuresScreenState();
}

class _MesHeuresScreenState extends State<MesHeuresScreen> {
  WorkedHours? _workedHours;
  bool _isLoading = true;
  String? _error;

  // Période sélectionnée pour la recherche
  DateTime? _selectedDate;
  int? _selectedWeek;
  int? _selectedMonth;
  int? _selectedYear;
  bool _isSearchMode = false;

  // Navigation par semaine dans la vue d'ensemble
  late int _displayedWeekNumber;
  late int _displayedWeekYear;
  double? _displayedWeekHours;
  bool _isLoadingWeek = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayedWeekNumber = _getWeekNumber(now);
    _displayedWeekYear = now.year;
    _loadWorkedHours();
  }

  Future<void> _loadWorkedHours() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _isSearchMode = false;
      _selectedDate = null;
      _selectedWeek = null;
      _selectedMonth = null;
      _selectedYear = null;
    });

    // Requête sans filtres pour obtenir toutes les périodes
    final result = await sl.serviceRepository.getWorkedHours(
      const WorkedHoursParams(),
    );

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() {
          _error = failure.message;
          _isLoading = false;
        });
      },
      (hours) {
        setState(() {
          _workedHours = hours;
          _displayedWeekHours = hours.week;
          _isLoading = false;
        });
      },
    );
  }

  Future<void> _searchByDay() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('fr', 'FR'),
    );

    if (date == null) return;

    setState(() {
      _isLoading = true;
      _isSearchMode = true;
      _selectedDate = date;
      _selectedWeek = null;
      _selectedMonth = null;
      _selectedYear = null;
    });

    final result = await sl.serviceRepository.getWorkedHours(
      WorkedHoursParams(
        period: WorkedHoursPeriod.day,
        year: date.year,
        month: date.month,
        day: date.day,
      ),
    );

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() {
          _error = failure.message;
          _isLoading = false;
        });
      },
      (hours) {
        setState(() {
          _workedHours = hours;
          _isLoading = false;
        });
      },
    );
  }

  Future<void> _searchByWeek() async {
    final colors = context.colors;
    final now = DateTime.now();
    final currentWeek = _getWeekNumber(now);

    final week = await showDialog<int>(
      context: context,
      builder: (context) => _WeekPickerDialog(
        initialWeek: _selectedWeek ?? currentWeek,
        colors: colors,
      ),
    );

    if (week == null) return;

    setState(() {
      _isLoading = true;
      _isSearchMode = true;
      _selectedWeek = week;
      _selectedDate = null;
      _selectedMonth = null;
      _selectedYear = null;
    });

    final result = await sl.serviceRepository.getWorkedHours(
      WorkedHoursParams(
        period: WorkedHoursPeriod.week,
        year: now.year,
        week: week,
      ),
    );

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() {
          _error = failure.message;
          _isLoading = false;
        });
      },
      (hours) {
        setState(() {
          _workedHours = hours;
          _isLoading = false;
        });
      },
    );
  }

  Future<void> _searchByMonth() async {
    final colors = context.colors;
    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (context) => _MonthYearPickerDialog(
        initialMonth: _selectedMonth ?? DateTime.now().month,
        initialYear: _selectedYear ?? DateTime.now().year,
        colors: colors,
      ),
    );

    if (result == null) return;

    final month = result['month']!;
    final year = result['year']!;

    setState(() {
      _isLoading = true;
      _isSearchMode = true;
      _selectedMonth = month;
      _selectedYear = year;
      _selectedDate = null;
      _selectedWeek = null;
    });

    final apiResult = await sl.serviceRepository.getWorkedHours(
      WorkedHoursParams(
        period: WorkedHoursPeriod.month,
        year: year,
        month: month,
      ),
    );

    if (!mounted) return;

    apiResult.fold(
      (failure) {
        setState(() {
          _error = failure.message;
          _isLoading = false;
        });
      },
      (hours) {
        setState(() {
          _workedHours = hours;
          _isLoading = false;
        });
      },
    );
  }

  Future<void> _searchByYear() async {
    final colors = context.colors;
    final year = await showDialog<int>(
      context: context,
      builder: (context) => _YearPickerDialog(
        initialYear: _selectedYear ?? DateTime.now().year,
        colors: colors,
      ),
    );

    if (year == null) return;

    setState(() {
      _isLoading = true;
      _isSearchMode = true;
      _selectedYear = year;
      _selectedDate = null;
      _selectedWeek = null;
      _selectedMonth = null;
    });

    final result = await sl.serviceRepository.getWorkedHours(
      WorkedHoursParams(
        period: WorkedHoursPeriod.year,
        year: year,
      ),
    );

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() {
          _error = failure.message;
          _isLoading = false;
        });
      },
      (hours) {
        setState(() {
          _workedHours = hours;
          _isLoading = false;
        });
      },
    );
  }

  int _getWeekNumber(DateTime date) {
    // ISO 8601: la semaine 1 contient le premier jeudi de l'année
    final jan4 = DateTime(date.year, 1, 4);
    final daysSinceMonday = (jan4.weekday - 1) % 7;
    final firstMondayOfYear = jan4.subtract(Duration(days: daysSinceMonday));

    final daysSinceFirstMonday = date.difference(firstMondayOfYear).inDays;
    if (daysSinceFirstMonday < 0) {
      // La date est dans la dernière semaine de l'année précédente
      return _getWeekNumber(DateTime(date.year - 1, 12, 31));
    }
    return (daysSinceFirstMonday / 7).floor() + 1;
  }

  /// Retourne le lundi et le dimanche de la semaine donnée (ISO 8601)
  (DateTime start, DateTime end) _getWeekDateRange(int weekNumber, int year) {
    // Trouver le premier jeudi de l'année (norme ISO 8601)
    final jan4 = DateTime(year, 1, 4);
    final daysSinceMonday = (jan4.weekday - 1) % 7;
    final firstMondayOfYear = jan4.subtract(Duration(days: daysSinceMonday));

    // Calculer le lundi de la semaine demandée
    final monday = firstMondayOfYear.add(Duration(days: (weekNumber - 1) * 7));
    final sunday = monday.add(const Duration(days: 6));

    return (monday, sunday);
  }

  /// Formate la plage de dates de la semaine affichée
  String _formatWeekRange() {
    final (start, end) = _getWeekDateRange(_displayedWeekNumber, _displayedWeekYear);
    final startFormat = DateFormat('d MMMM', 'fr_FR').format(start);
    final endFormat = DateFormat('d MMMM', 'fr_FR').format(end);

    // Ajouter l'année si différente de l'année courante
    if (_displayedWeekYear != DateTime.now().year) {
      return 'du $startFormat au $endFormat $_displayedWeekYear';
    }
    return 'du $startFormat au $endFormat';
  }

  /// Vérifie si on peut naviguer vers la semaine suivante
  bool get _canNavigateForward {
    final now = DateTime.now();
    final currentWeek = _getWeekNumber(now);
    final currentYear = now.year;

    if (_displayedWeekYear < currentYear) return true;
    if (_displayedWeekYear == currentYear && _displayedWeekNumber < currentWeek) return true;
    return false;
  }

  /// Navigue vers la semaine précédente ou suivante
  void _navigateWeek(int direction) {
    if (direction > 0 && !_canNavigateForward) return;

    setState(() {
      _displayedWeekNumber += direction;

      // Gérer le passage d'année
      if (_displayedWeekNumber < 1) {
        _displayedWeekYear--;
        _displayedWeekNumber = _getWeekNumber(DateTime(_displayedWeekYear, 12, 31));
      } else if (_displayedWeekNumber > 52) {
        // Vérifier si la semaine 53 existe pour cette année
        final lastDayOfYear = DateTime(_displayedWeekYear, 12, 31);
        final maxWeek = _getWeekNumber(lastDayOfYear);
        if (_displayedWeekNumber > maxWeek) {
          _displayedWeekYear++;
          _displayedWeekNumber = 1;
        }
      }
    });

    _loadWeekHours();
  }

  /// Charge uniquement les heures de la semaine affichée
  Future<void> _loadWeekHours() async {
    setState(() => _isLoadingWeek = true);

    final result = await sl.serviceRepository.getWorkedHours(
      WorkedHoursParams(
        period: WorkedHoursPeriod.week,
        year: _displayedWeekYear,
        week: _displayedWeekNumber,
      ),
    );

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() {
          _isLoadingWeek = false;
        });
      },
      (hours) {
        setState(() {
          _displayedWeekHours = hours.week;
          _isLoadingWeek = false;
        });
      },
    );
  }

  String _getSearchTitle() {
    if (_selectedDate != null) {
      return DateFormat('d MMMM yyyy', 'fr_FR').format(_selectedDate!);
    } else if (_selectedWeek != null) {
      return 'Semaine $_selectedWeek - ${DateTime.now().year}';
    } else if (_selectedMonth != null && _selectedYear != null) {
      final monthNames = [
        'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
        'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
      ];
      return '${monthNames[_selectedMonth! - 1]} $_selectedYear';
    } else if (_selectedYear != null) {
      return 'Année $_selectedYear';
    }
    return 'Vue d\'ensemble';
  }

  String _formatHours(double? hours) {
    if (hours == null) return '0h 00';
    final h = hours.floor();
    final m = ((hours - h) * 60).round();
    return '${h}h ${m.toString().padLeft(2, '0')}';
  }


  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bgPrimary,
      appBar: AppBar(
        title: const Text('Mes heures'),
        backgroundColor: colors.bgSecondary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 22),
            onPressed: _loadWorkedHours,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _buildBody(colors),
    );
  }

  Widget _buildBody(AppColors colors) {
    if (_isLoading) {
      return const LoadingIndicator(message: 'Chargement...');
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: colors.error),
            const SizedBox(height: AppSpacing.base),
            Text(
              _error!,
              style: TextStyle(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.base),
            AppButton(
              text: 'Réessayer',
              onPressed: _loadWorkedHours,
              backgroundColor: colors.primary,
              foregroundColor: Colors.white,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadWorkedHours,
      color: colors.primary,
      backgroundColor: colors.bgSecondary,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.base),
        children: [
          // Info explicative avec titre de recherche
          Container(
            padding: const EdgeInsets.all(AppSpacing.base),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.base),
              border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: colors.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Total des heures travaillées (pauses déduites)',
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_isSearchMode) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Période : ${_getSearchTitle()}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colors.primary,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _loadWorkedHours,
                        icon: Icon(Icons.close, size: 16, color: colors.error),
                        label: Text(
                          'Réinitialiser',
                          style: TextStyle(fontSize: 12, color: colors.error),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.base),

          // Boutons de recherche
          _buildSearchButtons(colors),
          const SizedBox(height: AppSpacing.xl),

          // Carte principale
          if (_isSearchMode)
            _buildSearchResultCard(colors)
          else
            _buildTodayCard(colors),

          const SizedBox(height: AppSpacing.base),

          // Grille des périodes (seulement en mode vue d'ensemble)
          if (!_isSearchMode) _buildPeriodsGrid(colors),
        ],
      ),
    );
  }

  Widget _buildTodayCard(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary, colors.primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.base),
                ),
                child: const Icon(
                  Icons.today,
                  size: 24,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aujourd\'hui',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('EEEE d MMMM', 'fr_FR').format(DateTime.now()),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            _formatHours(_workedHours?.day),
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'de travail effectuées',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodsGrid(AppColors colors) {
    // Calculer le mois dernier pour le subtitle
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1, 1);

    return Column(
      children: [
        // Carte semaine avec navigation
        _buildWeekCard(colors),
        const SizedBox(height: AppSpacing.md),

        // Carte mois
        _buildPeriodCard(
          colors: colors,
          title: 'Ce mois',
          subtitle: DateFormat('MMMM yyyy', 'fr_FR').format(now),
          value: _formatHours(_workedHours?.month),
          icon: Icons.calendar_month,
          color: colors.warning,
        ),
        const SizedBox(height: AppSpacing.md),

        // Carte mois dernier
        _buildPeriodCard(
          colors: colors,
          title: 'Mois dernier',
          subtitle: DateFormat('MMMM yyyy', 'fr_FR').format(lastMonth),
          value: _formatHours(_workedHours?.lastMonth),
          icon: Icons.history,
          color: colors.info,
        ),
        const SizedBox(height: AppSpacing.md),

        // Carte année
        _buildPeriodCard(
          colors: colors,
          title: 'Cette année',
          subtitle: now.year.toString(),
          value: _formatHours(_workedHours?.year),
          icon: Icons.calendar_today,
          color: colors.secondary,
        ),
      ],
    );
  }

  /// Carte de la semaine avec navigation par flèches
  Widget _buildWeekCard(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: colors.bgSecondary,
        borderRadius: BorderRadius.circular(AppRadius.base),
        border: Border.all(color: colors.borderPrimary),
      ),
      child: Column(
        children: [
          // En-tête avec navigation
          Row(
            children: [
              // Flèche gauche
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _navigateWeek(-1),
                  borderRadius: BorderRadius.circular(AppRadius.base),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: colors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.base),
                    ),
                    child: Icon(
                      Icons.chevron_left,
                      size: 28,
                      color: colors.success,
                    ),
                  ),
                ),
              ),

              // Titre et plage de dates
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Semaine $_displayedWeekNumber',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatWeekRange(),
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // Flèche droite
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _canNavigateForward ? () => _navigateWeek(1) : null,
                  borderRadius: BorderRadius.circular(AppRadius.base),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: _canNavigateForward
                          ? colors.success.withValues(alpha: 0.1)
                          : colors.bgTertiary,
                      borderRadius: BorderRadius.circular(AppRadius.base),
                    ),
                    child: Icon(
                      Icons.chevron_right,
                      size: 28,
                      color: _canNavigateForward
                          ? colors.success
                          : colors.textMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.base),

          // Heures travaillées
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.base),
                ),
                child: Icon(
                  Icons.calendar_view_week,
                  size: 28,
                  color: colors.success,
                ),
              ),
              const SizedBox(width: AppSpacing.base),
              if (_isLoadingWeek)
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.success,
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatHours(_displayedWeekHours),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      'heures travaillées',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Widget générique pour les cartes de période (mois, année)
  Widget _buildPeriodCard({
    required AppColors colors,
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.bgSecondary,
        borderRadius: BorderRadius.circular(AppRadius.base),
        border: Border.all(color: colors.borderPrimary),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.base),
            ),
            child: Icon(
              icon,
              size: 28,
              color: color,
            ),
          ),
          const SizedBox(width: AppSpacing.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              Text(
                'heures',
                style: TextStyle(
                  fontSize: 11,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchButtons(AppColors colors) {
    return Row(
      children: [
        Expanded(
          child: _SearchButton(
            icon: Icons.today,
            label: 'Jour',
            onPressed: _searchByDay,
            color: colors.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _SearchButton(
            icon: Icons.calendar_view_week,
            label: 'Semaine',
            onPressed: _searchByWeek,
            color: colors.success,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _SearchButton(
            icon: Icons.calendar_month,
            label: 'Mois',
            onPressed: _searchByMonth,
            color: colors.warning,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _SearchButton(
            icon: Icons.calendar_today,
            label: 'Année',
            onPressed: _searchByYear,
            color: colors.secondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResultCard(AppColors colors) {
    String title = '';
    IconData icon = Icons.search;
    Color color = colors.primary;
    double? hours;

    if (_selectedDate != null) {
      title = DateFormat('d MMMM yyyy', 'fr_FR').format(_selectedDate!);
      icon = Icons.today;
      color = colors.primary;
      hours = _workedHours?.day;
    } else if (_selectedWeek != null) {
      title = 'Semaine $_selectedWeek';
      icon = Icons.calendar_view_week;
      color = colors.success;
      hours = _workedHours?.week;
    } else if (_selectedMonth != null && _selectedYear != null) {
      final monthNames = [
        'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
        'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
      ];
      title = '${monthNames[_selectedMonth! - 1]} $_selectedYear';
      icon = Icons.calendar_month;
      color = colors.warning;
      hours = _workedHours?.month;
    } else if (_selectedYear != null) {
      title = 'Année $_selectedYear';
      icon = Icons.calendar_today;
      color = colors.secondary;
      hours = _workedHours?.year;
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.base),
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Heures travaillées',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            _formatHours(hours),
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'de travail effectuées',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget pour les boutons de recherche
class _SearchButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color color;

  const _SearchButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: colors.bgSecondary,
      borderRadius: BorderRadius.circular(AppRadius.base),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.base),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(AppRadius.base),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog pour sélectionner une semaine
class _WeekPickerDialog extends StatefulWidget {
  final int initialWeek;
  final AppColors colors;

  const _WeekPickerDialog({
    required this.initialWeek,
    required this.colors,
  });

  @override
  State<_WeekPickerDialog> createState() => _WeekPickerDialogState();
}

class _WeekPickerDialogState extends State<_WeekPickerDialog> {
  late int _selectedWeek;

  @override
  void initState() {
    super.initState();
    _selectedWeek = widget.initialWeek;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: widget.colors.bgSecondary,
      title: Text(
        'Sélectionner une semaine',
        style: TextStyle(color: widget.colors.textPrimary),
      ),
      content: SizedBox(
        width: 300,
        height: 400,
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 1.5,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: 53,
          itemBuilder: (context, index) {
            final week = index + 1;
            final isSelected = week == _selectedWeek;

            return Material(
              color: isSelected
                  ? widget.colors.primary
                  : widget.colors.bgPrimary,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: InkWell(
                onTap: () => setState(() => _selectedWeek = week),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Center(
                  child: Text(
                    'S$week',
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : widget.colors.textPrimary,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Annuler', style: TextStyle(color: widget.colors.error)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _selectedWeek),
          child: Text('Valider', style: TextStyle(color: widget.colors.primary)),
        ),
      ],
    );
  }
}

/// Dialog pour sélectionner un mois et une année
class _MonthYearPickerDialog extends StatefulWidget {
  final int initialMonth;
  final int initialYear;
  final AppColors colors;

  const _MonthYearPickerDialog({
    required this.initialMonth,
    required this.initialYear,
    required this.colors,
  });

  @override
  State<_MonthYearPickerDialog> createState() => _MonthYearPickerDialogState();
}

class _MonthYearPickerDialogState extends State<_MonthYearPickerDialog> {
  late int _selectedMonth;
  late int _selectedYear;

  final List<String> _monthNames = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
  ];

  @override
  void initState() {
    super.initState();
    _selectedMonth = widget.initialMonth;
    _selectedYear = widget.initialYear;
  }

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    final years = List.generate(
      currentYear - 2020 + 1,
      (index) => 2020 + index,
    ).reversed.toList();

    return AlertDialog(
      backgroundColor: widget.colors.bgSecondary,
      title: Text(
        'Sélectionner un mois et une année',
        style: TextStyle(color: widget.colors.textPrimary),
      ),
      content: SizedBox(
        width: 300,
        height: 450,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sélecteur d'année
            Text(
              'Année',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: widget.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 50,
              decoration: BoxDecoration(
                color: widget.colors.bgPrimary,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: years.length,
                itemBuilder: (context, index) {
                  final year = years[index];
                  final isSelected = year == _selectedYear;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Material(
                      color: isSelected
                          ? widget.colors.primary
                          : widget.colors.bgSecondary,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: InkWell(
                        onTap: () => setState(() => _selectedYear = year),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          child: Center(
                            child: Text(
                              year.toString(),
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : widget.colors.textPrimary,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            // Sélecteur de mois
            Text(
              'Mois',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: widget.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: 12,
                itemBuilder: (context, index) {
                  final month = index + 1;
                  final isSelected = month == _selectedMonth;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: isSelected
                          ? widget.colors.primary
                          : widget.colors.bgPrimary,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: InkWell(
                        onTap: () => setState(() => _selectedMonth = month),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 16,
                          ),
                          child: Text(
                            _monthNames[index],
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : widget.colors.textPrimary,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Annuler', style: TextStyle(color: widget.colors.error)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, {
            'month': _selectedMonth,
            'year': _selectedYear,
          }),
          child: Text('Valider', style: TextStyle(color: widget.colors.primary)),
        ),
      ],
    );
  }
}

/// Dialog pour sélectionner une année
class _YearPickerDialog extends StatefulWidget {
  final int initialYear;
  final AppColors colors;

  const _YearPickerDialog({
    required this.initialYear,
    required this.colors,
  });

  @override
  State<_YearPickerDialog> createState() => _YearPickerDialogState();
}

class _YearPickerDialogState extends State<_YearPickerDialog> {
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialYear;
  }

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    final years = List.generate(
      currentYear - 2020 + 1,
      (index) => 2020 + index,
    ).reversed.toList();

    return AlertDialog(
      backgroundColor: widget.colors.bgSecondary,
      title: Text(
        'Sélectionner une année',
        style: TextStyle(color: widget.colors.textPrimary),
      ),
      content: SizedBox(
        width: 300,
        height: 400,
        child: ListView.builder(
          itemCount: years.length,
          itemBuilder: (context, index) {
            final year = years[index];
            final isSelected = year == _selectedYear;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: isSelected
                    ? widget.colors.primary
                    : widget.colors.bgPrimary,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: InkWell(
                  onTap: () => setState(() => _selectedYear = year),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 16,
                    ),
                    child: Text(
                      year.toString(),
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : widget.colors.textPrimary,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Annuler', style: TextStyle(color: widget.colors.error)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _selectedYear),
          child: Text('Valider', style: TextStyle(color: widget.colors.primary)),
        ),
      ],
    );
  }
}
