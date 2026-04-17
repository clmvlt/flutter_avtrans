import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../widgets/rapport_reminder_dialog.dart';
import '../../widgets/widgets.dart';
import '../rapports/create_rapport_screen.dart';
import '../signatures/sign_screen.dart';
import 'history_screen.dart';
import 'kilometrage_required_screen.dart';

/// Statut du rapport de véhicule
enum RapportStatus {
  /// Rapport à jour (cette semaine)
  upToDate,
  /// Rapport de la semaine dernière (avertissement)
  warning,
  /// Rapport trop ancien (obligatoire)
  required,
}

/// Page de gestion des services (pointage)
class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  Service? _activeService;
  WorkedHours? _workedHours;
  List<Service> _todayServices = [];
  bool _isLoading = true;
  bool _isActionLoading = false;
  LocationStatus? _locationStatus;

  // Cache de la dernière localisation pour accélérer les actions
  LocationData? _cachedLocation;
  DateTime? _locationCacheTime;

  // Timer pour la mise à jour en direct du temps écoulé
  Timer? _elapsedTimeTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _checkLocationStatus();
    // Pré-charger la localisation en arrière-plan
    _preloadLocation();
    // Vérifier si une signature est requise
    _checkSignatureRequired();
    // Vérifier si un kilométrage est requis (hors weekend)
    _checkKilometrageRequired();
    // Vérifier si un rappel de rapport est nécessaire
    _checkRapportReminder();
    // Démarrer le timer pour la mise à jour du temps écoulé
    _startElapsedTimeTimer();
  }

  @override
  void dispose() {
    _elapsedTimeTimer?.cancel();
    super.dispose();
  }

  /// Démarre le timer pour mettre à jour le temps écoulé chaque seconde
  void _startElapsedTimeTimer() {
    _elapsedTimeTimer?.cancel();
    _elapsedTimeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_activeService != null && mounted) {
        setState(() {
          // Force rebuild pour mettre à jour le temps écoulé
        });
      }
    });
  }

  /// Vérifie si une signature est requise
  Future<void> _checkSignatureRequired() async {
    final result = await sl.signatureRepository.getLastSignatureSummary();

    if (!mounted) return;

    result.fold(
      (_) {}, // Ignore les erreurs
      (summary) {
        if (summary.needsToSign) {
          // Affiche un dialog pour signer
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _showSignatureRequiredDialog(summary.heuresLastMonth);
            }
          });
        }
      },
    );
  }

  /// ID du rôle "Utilisateur" qui nécessite la saisie obligatoire du kilométrage
  static const String _roleUtilisateurId = '99127dd5-f7bd-446c-9fd0-c05d4ea135b2';

  /// IDs des rôles exemptés du rapport obligatoire (mécanicien et admin)
  static const List<String> _rolesExemptesRapport = [
    'mecanicien', // Nom du rôle mécanicien
    'admin', // Nom du rôle admin
  ];

  /// Vérifie si un kilométrage est requis (hors weekend, uniquement pour le rôle Utilisateur)
  Future<void> _checkKilometrageRequired() async {
    // Vérifier si l'utilisateur a le rôle "Utilisateur"
    final user = sl.authRepository.getCachedUser();
    if (user?.role?.uuid != _roleUtilisateurId) return;

    // Vérifier si c'est un jour de semaine (lundi = 1, dimanche = 7)
    final now = DateTime.now();
    final isWeekend = now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;

    // Ne pas vérifier le weekend
    if (isWeekend) return;

    final result = await sl.vehiculeRepository.getMyLastKilometrage();

    if (!mounted) return;

    result.fold(
      (_) {}, // Ignore les erreurs
      (response) {
        if (!response.hasEnteredToday) {
          // Affiche l'écran de saisie du kilométrage (obligatoire)
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted) {
              _showKilometrageRequiredScreen();
            }
          });
        }
      },
    );
  }

  /// Vérifie si un rappel de rapport est nécessaire (avertissement uniquement)
  Future<void> _checkRapportReminder() async {
    final rapportStatus = await _checkRapportRequired();

    if (!mounted) return;

    if (rapportStatus == RapportStatus.warning) {
      // Affiche un avertissement (non bloquant)
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) {
          _showRapportReminderAndNavigate(isRequired: false);
        }
      });
    }
  }

  /// Affiche l'écran de saisie du kilométrage (obligatoire)
  Future<void> _showKilometrageRequiredScreen() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const KilometrageRequiredScreen(isRequired: true),
        fullscreenDialog: true,
      ),
    );

    if (!mounted) return;

    if (result == true) {
      // Kilométrage saisi, recharger les données
      _loadData();
    } else {
      // L'utilisateur a refusé de saisir le kilométrage, fermer la page de pointage
      Navigator.of(context).pop();
    }
  }

  /// Ouvre l'écran de saisie du kilométrage (optionnel, accessible à tous)
  void _openKilometrageScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const KilometrageRequiredScreen(isRequired: false),
      ),
    );
  }

  /// Affiche le dialog pour demander à l'utilisateur de signer
  void _showSignatureRequiredDialog(double? heuresLastMonth) {
    final colors = context.colors;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.base),
        ),
        title: Row(
          children: [
            Icon(Icons.draw, color: colors.primary),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Signature requise',
              style: TextStyle(color: colors.foreground),
            ),
          ],
        ),
        content: Text(
          'Vous devez signer vos heures avant de pouvoir pointer.',
          style: TextStyle(color: colors.mutedForeground),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Ferme le dialog
              Navigator.of(context).pop(); // Retourne à l'écran précédent
            },
            child: Text(
              'Plus tard',
              style: TextStyle(color: colors.mutedForeground),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(context).pop(); // Ferme le dialog
              // Ouvre l'écran de signature avec les heures du mois dernier
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SignScreen(
                    heuresLastMonth: heuresLastMonth,
                  ),
                ),
              );
              // Vérifie à nouveau si la signature est requise
              if (mounted) {
                _loadData();
                _checkSignatureRequired();
              }
            },
            icon: const Icon(Icons.draw, size: 16),
            label: const Text('Signer maintenant'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.primaryForeground,
            ),
          ),
        ],
      ),
    );
  }

  /// Pré-charge la localisation en arrière-plan
  Future<void> _preloadLocation() async {
    final location = await sl.locationService.getLocation();
    if (location.isReal) {
      _cachedLocation = location;
      _locationCacheTime = DateTime.now();
    }
  }

  Future<void> _checkLocationStatus() async {
    final status = await sl.locationService.checkStatus();
    if (mounted) {
      setState(() => _locationStatus = status);
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final results = await Future.wait([
      sl.serviceRepository.getActiveService(),
      sl.serviceRepository.getWorkedHours(const WorkedHoursParams()),
      sl.serviceRepository.getDailyServices(),
    ]);

    if (!mounted) return;

    final activeResult = results[0] as dynamic;
    final hoursResult = results[1] as dynamic;
    final dailyServicesResult = results[2] as dynamic;

    activeResult.fold(
      (failure) {},
      (service) => _activeService = service,
    );

    hoursResult.fold(
      (failure) {
        print('❌ Erreur lors du chargement des heures: ${failure.message}');
      },
      (hours) {
        print('✅ Heures travaillées reçues: ${hours.toJson()}');
        _workedHours = hours;
      },
    );

    dailyServicesResult.fold(
      (failure) {
        // Log l'erreur pour le débogage
        print('❌ ERREUR lors du chargement des services du jour: ${failure.message}');
        _todayServices = [];
      },
      (services) {
        print('✅ Services du jour reçus: ${services.length}');
        _todayServices = services as List<Service>;
        // Log détaillé de chaque service
        for (var service in _todayServices) {
          print('  - Service: ${service.isBreak ? "Pause" : "Travail"}, '
              'Début: ${service.debut}, '
              'Fin: ${service.fin}, '
              'Actif: ${service.isActive}');
        }
      },
    );

    setState(() => _isLoading = false);
  }

  Future<LocationData?> _getLocationWithPermissionCheck() async {
    // Utiliser le cache si disponible et récent (< 30 secondes)
    if (_cachedLocation != null &&
        _locationCacheTime != null &&
        DateTime.now().difference(_locationCacheTime!).inSeconds < 30) {
      // Rafraîchir le cache en arrière-plan pour la prochaine fois
      _preloadLocation();
      return _cachedLocation;
    }

    final location = await sl.locationService.getLocation();

    // Mettre en cache
    if (location.isReal) {
      _cachedLocation = location;
      _locationCacheTime = DateTime.now();
    }

    if (!location.isReal) {
      // La localisation n'est pas disponible
      final status = await sl.locationService.checkStatus();

      if (!mounted) return null;

      String message;
      VoidCallback? action;
      String? actionLabel;

      switch (status) {
        case LocationStatus.serviceDisabled:
          message = 'Activez la localisation pour pointer';
          actionLabel = 'Paramètres';
          action = () => sl.locationService.openLocationSettings();
          break;
        case LocationStatus.permissionDenied:
          message = 'Permission de localisation requise';
          actionLabel = 'Autoriser';
          action = () async {
            await sl.locationService.requestPermission();
            _checkLocationStatus();
          };
          break;
        case LocationStatus.permissionDeniedForever:
          message = 'Autorisez la localisation dans les paramètres';
          actionLabel = 'Paramètres';
          action = () => sl.locationService.openAppSettings();
          break;
        case LocationStatus.granted:
          message = 'Impossible d\'obtenir la position';
          break;
      }

      _showLocationError(message, action, actionLabel);
      return null;
    }

    return location;
  }

  void _showLocationError(String message, VoidCallback? action, String? actionLabel) {
    final colors = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.location_off, color: colors.warning, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: colors.card,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.base),
          side: BorderSide(color: colors.warning),
        ),
        action: action != null && actionLabel != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: colors.primary,
                onPressed: action,
              )
            : null,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Vérifie si l'utilisateur doit faire un rapport cette semaine
  /// Retourne le statut du rapport :
  /// - upToDate : rapport de cette semaine
  /// - warning : rapport de la semaine dernière (avertissement)
  /// - required : rapport trop ancien (obligatoire avant de pointer)
  Future<RapportStatus> _checkRapportRequired() async {
    // Récupérer l'utilisateur courant
    final user = sl.authRepository.getCachedUser();

    // Les rôles mécanicien et admin sont exemptés du rapport
    final roleName = user?.role?.nom.toLowerCase() ?? '';
    if (_rolesExemptesRapport.contains(roleName)) {
      return RapportStatus.upToDate;
    }

    final result = await sl.rapportRepository.getMyLatestRapport();

    return result.fold(
      (failure) {
        // En cas d'erreur, on laisse passer (ne pas bloquer l'utilisateur)
        return RapportStatus.upToDate;
      },
      (rapport) {
        final now = DateTime.now();

        // Calculer le début de la semaine actuelle (lundi)
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final startOfWeekMidnight = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

        // Calculer le début de la semaine dernière
        final startOfLastWeek = startOfWeekMidnight.subtract(const Duration(days: 7));

        if (rapport == null) {
          // Aucun rapport n'existe, utiliser la date de création du profil
          final userCreatedAt = user?.createdAt;
          if (userCreatedAt != null) {
            // Profil créé cette semaine → pas besoin de rapport
            if (!userCreatedAt.isBefore(startOfWeekMidnight)) {
              return RapportStatus.upToDate;
            }
            // Profil créé la semaine dernière → avertissement
            if (!userCreatedAt.isBefore(startOfLastWeek)) {
              return RapportStatus.warning;
            }
          }
          // Profil créé il y a plus d'une semaine, rapport obligatoire
          return RapportStatus.required;
        }

        // Vérifier la date du rapport
        final rapportDate = rapport.createdAt;

        // Si la date de création est null, demander un nouveau rapport
        if (rapportDate == null) {
          return RapportStatus.required;
        }

        // Rapport de cette semaine → OK
        if (!rapportDate.isBefore(startOfWeekMidnight)) {
          return RapportStatus.upToDate;
        }

        // Rapport de la semaine dernière → avertissement
        if (!rapportDate.isBefore(startOfLastWeek)) {
          return RapportStatus.warning;
        }

        // Rapport plus ancien → obligatoire
        return RapportStatus.required;
      },
    );
  }

  /// Affiche le dialogue de rappel de rapport et navigue vers l'écran de création
  /// [isRequired] : true si le rapport est obligatoire (bloque le pointage), false pour un simple avertissement
  Future<void> _showRapportReminderAndNavigate({bool isRequired = false}) async {
    if (!mounted) return;

    await RapportReminderDialog.show(
      context,
      isRequired: isRequired,
      onCreateRapport: () async {
        // Naviguer vers l'écran de création de rapport
        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const CreateRapportScreen(),
          ),
        );

        // Si un rapport a été créé, recharger les données
        if (result == true && mounted) {
          _loadData();
        }
      },
    );
  }

  Future<void> _startService() async {
    // Vérifier si un rapport est requis avant de démarrer le service
    final rapportStatus = await _checkRapportRequired();

    if (rapportStatus == RapportStatus.required) {
      // Rapport obligatoire - bloquer le pointage
      await _showRapportReminderAndNavigate(isRequired: true);
      // Ne pas continuer avec le pointage
      return;
    }

    setState(() => _isActionLoading = true);

    final location = await _getLocationWithPermissionCheck();
    if (location == null) {
      setState(() => _isActionLoading = false);
      return;
    }

    final result = await sl.serviceRepository.startService(
      ServiceGpsRequest(latitude: location.latitude, longitude: location.longitude),
    );

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() => _isActionLoading = false);
        _showError(failure.message);
      },
      (service) {
        // Mettre à jour immédiatement l'état
        setState(() {
          _activeService = service;
          _isActionLoading = false;
        });
        // Actualiser toutes les données après le démarrage du service
        _loadData();
      },
    );
  }

  Future<void> _endService() async {
    setState(() => _isActionLoading = true);

    final location = await _getLocationWithPermissionCheck();
    if (location == null) {
      setState(() => _isActionLoading = false);
      return;
    }

    final result = await sl.serviceRepository.endService(
      ServiceGpsRequest(latitude: location.latitude, longitude: location.longitude),
    );

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() => _isActionLoading = false);
        _showError(failure.message);
      },
      (service) {
        // Mettre à jour immédiatement l'état
        setState(() {
          _activeService = null;
          _isActionLoading = false;
        });
        // Recharger les données pour synchroniser
        _loadData();
      },
    );
  }

  Future<void> _startBreak() async {
    setState(() => _isActionLoading = true);

    final location = await _getLocationWithPermissionCheck();
    if (location == null) {
      setState(() => _isActionLoading = false);
      return;
    }

    final result = await sl.serviceRepository.startBreak(
      ServiceGpsRequest(latitude: location.latitude, longitude: location.longitude),
    );

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() => _isActionLoading = false);
        _showError(failure.message);
      },
      (service) {
        // Mettre à jour immédiatement l'état
        setState(() {
          _activeService = service;
          _isActionLoading = false;
        });
        // Actualiser toutes les données après le démarrage de la pause
        _loadData();
      },
    );
  }

  Future<void> _endBreak() async {
    setState(() => _isActionLoading = true);

    final location = await _getLocationWithPermissionCheck();
    if (location == null) {
      setState(() => _isActionLoading = false);
      return;
    }

    final result = await sl.serviceRepository.endBreak(
      ServiceGpsRequest(latitude: location.latitude, longitude: location.longitude),
    );

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() => _isActionLoading = false);
        _showError(failure.message);
      },
      (service) {
        // Mettre à jour immédiatement l'état avec le service retourné
        setState(() {
          _activeService = service;
          _isActionLoading = false;
        });
        // Recharger les données pour synchroniser
        _loadData();
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Services'),
        actions: [
          IconButton(
            icon: const Icon(Icons.speed, size: 22),
            onPressed: _openKilometrageScreen,
            tooltip: 'Kilométrage',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          ),
          IconButton(
            icon: const Icon(Icons.history, size: 22),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              );
            },
            tooltip: 'Historique',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingIndicator(message: 'Chargement...')
          : RefreshIndicator(
              onRefresh: _loadData,
              color: colors.primary,
              backgroundColor: colors.card,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.base),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_locationStatus != null &&
                        _locationStatus != LocationStatus.granted)
                      _buildLocationWarning(colors, textTheme),
                    _buildActionButtons(colors),
                    const SizedBox(height: AppSpacing.base),
                    _buildStatusCard(colors, textTheme),
                    const SizedBox(height: AppSpacing.base),
                    _buildWorkedHoursCard(colors, textTheme),
                    const SizedBox(height: AppSpacing.base),
                    _buildTodayServicesCard(colors, textTheme),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLocationWarning(AppColors colors, TextTheme textTheme) {
    String message;
    VoidCallback? action;
    String actionLabel;

    switch (_locationStatus!) {
      case LocationStatus.serviceDisabled:
        message = 'La localisation est désactivée';
        actionLabel = 'Activer';
        action = () => sl.locationService.openLocationSettings();
        break;
      case LocationStatus.permissionDenied:
        message = 'Permission de localisation requise';
        actionLabel = 'Autoriser';
        action = () async {
          await sl.locationService.requestPermission();
          _checkLocationStatus();
        };
        break;
      case LocationStatus.permissionDeniedForever:
        message = 'Localisation bloquée';
        actionLabel = 'Paramètres';
        action = () => sl.locationService.openAppSettings();
        break;
      case LocationStatus.granted:
        return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.base),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.warningMuted,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.warning),
      ),
      child: Row(
        children: [
          Icon(Icons.location_off, color: colors.warning, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: textTheme.bodySmall?.copyWith(
                color: colors.foreground,
              ),
            ),
          ),
          TextButton(
            onPressed: action,
            style: TextButton.styleFrom(
              foregroundColor: colors.warning,
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(AppColors colors, TextTheme textTheme) {
    final isServiceActive = _activeService != null && !_activeService!.isBreak;
    final isOnBreak = _activeService != null && _activeService!.isBreak;

    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (isOnBreak) {
      statusText = 'En pause';
      statusColor = colors.warning;
      statusIcon = Icons.coffee;
    } else if (isServiceActive) {
      statusText = 'En service';
      statusColor = colors.success;
      statusIcon = Icons.work;
    } else {
      statusText = 'Hors service';
      statusColor = colors.mutedForeground;
      statusIcon = Icons.work_off;
    }

    // Calculer le temps de travail effectif aujourd'hui (sans les pauses)
    final workedTimeToday = _calculateWorkedTimeToday();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.base),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              statusIcon,
              size: 40,
              color: statusColor,
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          Text(
            statusText,
            style: textTheme.titleLarge?.copyWith(
              color: statusColor,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Travaillé aujourd\'hui: ${_formatDuration(workedTimeToday)}',
            style: textTheme.bodySmall?.copyWith(
              color: colors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkedHoursCard(AppColors colors, TextTheme textTheme) {
    return Container(
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
              Icon(Icons.schedule, color: colors.primary, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Heures travaillées',
                style: textTheme.titleMedium?.copyWith(
                  color: colors.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          Row(
            children: [
              Expanded(child: _buildHourItem('Aujourd\'hui', _workedHours?.day, colors, textTheme)),
              Expanded(child: _buildHourItem('Semaine', _workedHours?.week, colors, textTheme)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(child: _buildHourItem('Mois', _workedHours?.month, colors, textTheme)),
              Expanded(child: _buildHourItem('Mois dernier', _workedHours?.lastMonth, colors, textTheme)),
            ],
          ),
        ],
      ),
    );
  }

  /// Convertit les heures décimales en format "XX heures XX minutes"
  String _formatHours(double? hours) {
    if (hours == null || hours == 0) return '0h';

    final totalMinutes = (hours * 60).round();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;

    if (h == 0) {
      return '$m min';
    } else if (m == 0) {
      return '$h h';
    } else {
      return '$h h $m min';
    }
  }

  Widget _buildHourItem(String label, double? hours, AppColors colors, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      margin: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: colors.muted,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          Text(
            _formatHours(hours),
            style: textTheme.titleMedium?.copyWith(
              color: colors.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: colors.mutedForeground,
              letterSpacing: 1,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTodayServicesCard(AppColors colors, TextTheme textTheme) {
    return Container(
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
              Icon(Icons.today, color: colors.primary, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Services d\'aujourd\'hui',
                style: textTheme.titleMedium?.copyWith(
                  color: colors.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          if (_todayServices.isEmpty)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.muted,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: colors.mutedForeground, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Aucun service aujourd\'hui',
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.mutedForeground,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ...(_todayServices.toList()
                  ..sort((a, b) => a.debut.compareTo(b.debut)))
                .map((service) => ServiceDayTile(service: service)),
        ],
      ),
    );
  }

  Widget _buildActionButtons(AppColors colors) {
    final isServiceActive = _activeService != null && !_activeService!.isBreak;
    final isOnBreak = _activeService != null && _activeService!.isBreak;
    final hasActiveService = _activeService != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!hasActiveService) ...[
          AppButton(
            text: 'Démarrer le service',
            icon: Icons.play_arrow,
            onPressed: _startService,
            isLoading: _isActionLoading,
            backgroundColor: colors.success,
            foregroundColor: colors.primaryForeground,
          ),
        ] else if (isOnBreak) ...[
          AppButton(
            text: 'Terminer la pause',
            icon: Icons.play_arrow,
            onPressed: _endBreak,
            isLoading: _isActionLoading,
            backgroundColor: colors.warning,
            foregroundColor: colors.primaryForeground,
          ),
        ] else if (isServiceActive) ...[
          AppButton(
            text: 'Prendre une pause',
            icon: Icons.coffee,
            onPressed: _startBreak,
            isLoading: _isActionLoading,
            backgroundColor: colors.warning,
            foregroundColor: colors.primaryForeground,
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            text: 'Terminer le service',
            icon: Icons.stop,
            onPressed: _endService,
            isLoading: _isActionLoading,
            isDanger: true,
            foregroundColor: colors.primaryForeground,
          ),
        ],
      ],
    );
  }

  /// Calcule le temps de travail effectif aujourd'hui (sans les pauses)
  Duration _calculateWorkedTimeToday() {
    int totalWorkSeconds = 0;
    int totalBreakSeconds = 0;

    // Parcourir tous les services de la journée
    for (var service in _todayServices) {
      if (service.isBreak) {
        // C'est une pause
        if (service.fin != null && service.duree != null) {
          // Pause terminée : utiliser la durée
          totalBreakSeconds += service.duree!;
        } else if (service.fin == null) {
          // Pause en cours : calculer la durée depuis le début
          final elapsed = DateTime.now().difference(service.debut);
          totalBreakSeconds += elapsed.inSeconds;
        }
      } else {
        // C'est un service de travail
        if (service.fin != null && service.duree != null) {
          // Service terminé : utiliser la durée
          totalWorkSeconds += service.duree!;
        } else if (service.fin == null) {
          // Service en cours : calculer la durée depuis le début
          final elapsed = DateTime.now().difference(service.debut);
          totalWorkSeconds += elapsed.inSeconds;
        }
      }
    }

    // Temps effectif = temps de travail - temps de pause
    final effectiveSeconds = totalWorkSeconds - totalBreakSeconds;
    return Duration(seconds: effectiveSeconds > 0 ? effectiveSeconds : 0);
  }

  /// Formate une durée en heures, minutes, secondes
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}min';
    } else if (minutes > 0) {
      return '${minutes}min ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
}
