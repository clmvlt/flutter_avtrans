import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/errors/failures.dart';
import '../../../core/services/location_service.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/rapport_repository.dart';
import '../../../data/repositories/service_repository.dart';
import '../../../data/repositories/signature_repository.dart';
import '../../../data/repositories/vehicule_repository.dart';

/// Statut courant du pointage.
enum PointageStatus {
  /// Aucun service en cours.
  offDuty,

  /// Service en cours.
  onDuty,

  /// Pause en cours (un service est ouvert derrière).
  onBreak,
}

/// Statut du rapport de véhicule hebdomadaire.
enum RapportStatus {
  /// Rapport de cette semaine.
  upToDate,

  /// Rapport de la semaine dernière — simple avertissement.
  warning,

  /// Rapport trop ancien — obligatoire avant de pointer.
  required,
}

/// État d'une ligne de prérequis (signature, kilométrage, rapport).
enum PrereqState {
  /// Ne s'applique pas à cet utilisateur / ce jour — ligne masquée.
  notApplicable,

  /// Vérification en cours.
  checking,

  /// Rien à faire.
  ok,

  /// Conseillé — ne bloque pas.
  warning,

  /// Obligatoire avant de démarrer un service.
  required,

  /// Vérification impossible (réseau, délai dépassé) — ne bloque pas.
  unavailable,
}

/// Phase d'une action de pointage en vol, pour un libellé qui raconte
/// (« Vérification… », « Position… », « Envoi… »).
enum PointageActionPhase { idle, checking, locating, sending }

/// Moment de la journée, dérivé des données déjà chargées : pilote l'écran
/// entier (hero, checklist, dock).
enum PointageMoment { loading, offline, notStarted, onDuty, onBreak, dayDone }

/// Action de pointage en vol — pour afficher le spinner sur le bon bouton.
enum PointageAction { start, end, breakStart, breakEnd }

/// Disponibilité d'une position récente (permission accordée).
enum LocationReadiness { ready, searching, notFound }

/// Prérequis à vérifier avant de démarrer un service.
///
/// Règle gravée : un prérequis ne bloque QUE le démarrage. Pause, reprise
/// et fin de service restent toujours possibles.
@immutable
class PointagePrerequisites {
  const PointagePrerequisites({
    this.signature = PrereqState.checking,
    this.kilometrage = PrereqState.checking,
    this.rapport = PrereqState.checking,
    this.heuresLastMonth,
    this.lastKilometrageAt,
    this.lastRapportAt,
  });

  /// Heures du mois dernier à signer.
  final PrereqState signature;

  /// Kilométrage du jour (rôle « Utilisateur », jours ouvrés).
  final PrereqState kilometrage;

  /// Rapport de véhicule hebdomadaire.
  final PrereqState rapport;

  final double? heuresLastMonth;
  final DateTime? lastKilometrageAt;
  final DateTime? lastRapportAt;

  /// Aucune ligne n'est plus en cours de vérification.
  bool get loaded => !isChecking;
  bool get isChecking =>
      signature == PrereqState.checking ||
      kilometrage == PrereqState.checking ||
      rapport == PrereqState.checking;

  bool get signatureRequired => signature == PrereqState.required;
  bool get kilometrageRequired => kilometrage == PrereqState.required;
  bool get rapportRequired => rapport == PrereqState.required;
  bool get rapportWarning => rapport == PrereqState.warning;

  RapportStatus get rapportStatus => switch (rapport) {
        PrereqState.required => RapportStatus.required,
        PrereqState.warning => RapportStatus.warning,
        _ => RapportStatus.upToDate,
      };

  /// Au moins un prérequis bloque le démarrage du service.
  bool get blocksStart =>
      signatureRequired || kilometrageRequired || rapportRequired;

  /// Nombre de points bloquants.
  int get requiredCount =>
      (signatureRequired ? 1 : 0) +
      (kilometrageRequired ? 1 : 0) +
      (rapportRequired ? 1 : 0);

  /// Nombre de points à traiter (bloquants + conseillés).
  int get pendingCount => requiredCount + (rapportWarning ? 1 : 0);

  /// Tout est vérifié et rien n'est à faire.
  bool get allClear => loaded && pendingCount == 0;

  PointagePrerequisites copyWith({
    PrereqState? signature,
    PrereqState? kilometrage,
    PrereqState? rapport,
    double? heuresLastMonth,
    DateTime? lastKilometrageAt,
    DateTime? lastRapportAt,
  }) {
    return PointagePrerequisites(
      signature: signature ?? this.signature,
      kilometrage: kilometrage ?? this.kilometrage,
      rapport: rapport ?? this.rapport,
      heuresLastMonth: heuresLastMonth ?? this.heuresLastMonth,
      lastKilometrageAt: lastKilometrageAt ?? this.lastKilometrageAt,
      lastRapportAt: lastRapportAt ?? this.lastRapportAt,
    );
  }
}

/// Segment de la journée (service ou pause) prêt à dessiner sur une
/// chronologie : bornes locales, `end` vaut « maintenant » si en cours.
@immutable
class DaySegment {
  const DaySegment({
    required this.service,
    required this.start,
    required this.end,
  });

  final Service service;
  final DateTime start;
  final DateTime end;

  bool get isBreak => service.isBreak;
  bool get isActive => service.isActive;
  Duration get duration {
    final d = end.difference(start);
    return d.isNegative ? Duration.zero : d;
  }
}

/// Résultat d'une action de pointage (démarrer / terminer / pause).
sealed class PointageActionResult {
  const PointageActionResult();
}

/// Action effectuée ; [service] est le pointage retourné par l'API.
class PointageActionSuccess extends PointageActionResult {
  const PointageActionSuccess(this.service);
  final Service service;
}

/// L'API a refusé l'action.
class PointageActionFailure extends PointageActionResult {
  const PointageActionFailure(this.message);
  final String message;
}

/// Impossible d'obtenir une position GPS — [status] explique pourquoi.
class PointageActionNoLocation extends PointageActionResult {
  const PointageActionNoLocation(this.status);
  final LocationStatus status;
}

/// Démarrage refusé : un prérequis bloque (signature, kilométrage, rapport).
class PointageActionBlocked extends PointageActionResult {
  const PointageActionBlocked(this.prerequisites);
  final PointagePrerequisites prerequisites;
}

/// Action ignorée (une autre est déjà en cours).
class PointageActionIgnored extends PointageActionResult {
  const PointageActionIgnored();
}

/// Contrôleur de la page Pointage — toute la logique métier de l'écran.
///
/// La page ne fait que l'écouter et déclencher ses méthodes. Les dépendances
/// sont injectables pour les tests ; par défaut elles viennent de [sl].
///
/// Deux canaux de notification :
/// - [ChangeNotifier] pour les changements d'état (chargement, service actif,
///   prérequis, GPS…) ;
/// - [clock] qui tique chaque seconde quand un pointage est ouvert, pour ne
///   reconstruire que les compteurs et pas toute la page.
class PointageController extends ChangeNotifier {
  PointageController({
    ServiceRepository? serviceRepository,
    SignatureRepository? signatureRepository,
    VehiculeRepository? vehiculeRepository,
    RapportRepository? rapportRepository,
    AuthRepository? authRepository,
    LocationService? locationService,
    DateTime Function()? now,
    this.prerequisitesTimeout = const Duration(seconds: 6),
  })  : _serviceRepository = serviceRepository ?? sl.serviceRepository,
        _signatureRepository = signatureRepository ?? sl.signatureRepository,
        _vehiculeRepository = vehiculeRepository ?? sl.vehiculeRepository,
        _rapportRepository = rapportRepository ?? sl.rapportRepository,
        _authRepository = authRepository ?? sl.authRepository,
        _locationService = locationService ?? sl.locationService,
        _now = now ?? DateTime.now {
    clock = ValueNotifier<DateTime>(_now());
  }

  /// Rôle « Utilisateur » : kilométrage journalier obligatoire.
  static const String roleUtilisateurId =
      '99127dd5-f7bd-446c-9fd0-c05d4ea135b2';

  /// Préfixes (minuscules, sans accents) des rôles exemptés du rapport
  /// véhicule hebdomadaire : « Administrateur », « Admin », « Mécanicien »…
  static const List<String> rolesExemptesRapport = ['admin', 'mecan'];

  /// Durée de validité du cache de position.
  static const Duration locationCacheTtl = Duration(seconds: 30);

  /// Délai maximal d'une vérification de prérequis : au-delà, la ligne passe
  /// en « vérification impossible » et ne bloque pas.
  final Duration prerequisitesTimeout;

  final ServiceRepository _serviceRepository;
  final SignatureRepository _signatureRepository;
  final VehiculeRepository _vehiculeRepository;
  final RapportRepository _rapportRepository;
  final AuthRepository _authRepository;
  final LocationService _locationService;
  final DateTime Function() _now;

  /// Horloge qui tique chaque seconde tant qu'un pointage est ouvert.
  late final ValueNotifier<DateTime> clock;

  Timer? _ticker;
  bool _disposed = false;

  bool _isLoading = true;
  PointageActionPhase _phase = PointageActionPhase.idle;
  PointageAction? _inFlight;
  String? _loadError;
  bool _dailyUnavailable = false;
  bool _locationNotFound = false;
  Service? _activeService;
  WorkedHours? _workedHours;
  List<Service> _todayServices = const [];
  LocationStatus? _locationStatus;
  PointagePrerequisites _prerequisites = const PointagePrerequisites();

  LocationData? _cachedLocation;
  DateTime? _locationCacheTime;

  // ---- état exposé ------------------------------------------------------

  /// Premier chargement en cours (avant toute donnée).
  bool get isLoading => _isLoading;

  /// Une action de pointage est en vol.
  bool get isActing => _phase != PointageActionPhase.idle;

  /// Phase de l'action en vol.
  PointageActionPhase get actionPhase => _phase;

  /// Action en vol (`null` au repos).
  PointageAction? get inFlightAction => _inFlight;

  /// Message d'erreur si le chargement initial a échoué (aucune donnée).
  String? get loadError => _loadError;

  /// Le détail du jour n'a pas pu être chargé alors que le reste a répondu.
  bool get dailyServicesUnavailable => _dailyUnavailable;

  /// Moment de la journée — la clé de lecture de tout l'écran.
  PointageMoment get moment {
    if (_isLoading) return PointageMoment.loading;
    if (_loadError != null) return PointageMoment.offline;
    return switch (status) {
      PointageStatus.onDuty => PointageMoment.onDuty,
      PointageStatus.onBreak => PointageMoment.onBreak,
      PointageStatus.offDuty =>
        dayFinished ? PointageMoment.dayDone : PointageMoment.notStarted,
    };
  }

  /// Disponibilité de la position (pertinent quand la permission est accordée).
  LocationReadiness get locationReadiness {
    if (hasFreshLocation) return LocationReadiness.ready;
    return _locationNotFound
        ? LocationReadiness.notFound
        : LocationReadiness.searching;
  }

  Service? get activeService => _activeService;
  WorkedHours? get workedHours => _workedHours;

  /// Pointages du jour, triés par heure de début croissante.
  List<Service> get todayServices => _todayServices;

  LocationStatus? get locationStatus => _locationStatus;
  bool get locationGranted =>
      _locationStatus == null || _locationStatus == LocationStatus.granted;

  /// Une position récente est en cache : le pointage sera immédiat.
  bool get hasFreshLocation =>
      _cachedLocation != null &&
      _locationCacheTime != null &&
      _now().difference(_locationCacheTime!) < locationCacheTtl;

  PointagePrerequisites get prerequisites => _prerequisites;

  PointageStatus get status {
    final active = _activeService;
    if (active == null) return PointageStatus.offDuty;
    return active.isBreak ? PointageStatus.onBreak : PointageStatus.onDuty;
  }

  bool get hasActiveService => _activeService != null;

  /// La journée a démarré puis a été clôturée (au moins un service terminé,
  /// aucun pointage ouvert).
  bool get dayFinished =>
      _activeService == null && _todayServices.any((s) => !s.isBreak);

  /// La journée n'a pas encore commencé.
  bool get dayNotStarted =>
      _activeService == null && !_todayServices.any((s) => !s.isBreak);

  /// Heure de la première prise de service du jour (locale).
  DateTime? get firstStartToday {
    Service? first;
    for (final s in _allServicesToday()) {
      if (s.isBreak) continue;
      if (first == null || s.debut.isBefore(first.debut)) first = s;
    }
    return first?.debut.toLocal();
  }

  /// Heure de fin du dernier service clôturé (locale) — `null` si un pointage
  /// est ouvert ou si rien n'est terminé.
  DateTime? get lastEndToday {
    if (_activeService != null) return null;
    DateTime? last;
    for (final s in _todayServices) {
      if (s.isBreak || s.fin == null) continue;
      if (last == null || s.fin!.isAfter(last)) last = s.fin;
    }
    return last?.toLocal();
  }

  /// Nombre de pauses prises aujourd'hui (terminées ou en cours).
  int get breakCount => _allServicesToday().where((s) => s.isBreak).length;

  /// Nombre de services (hors pauses) démarrés aujourd'hui.
  int get serviceCount => _allServicesToday().where((s) => !s.isBreak).length;

  /// Temps écoulé sur le pointage ouvert (service ou pause).
  Duration get currentSegmentElapsed {
    final active = _activeService;
    if (active == null) return Duration.zero;
    final d = _now().difference(active.debut);
    return d.isNegative ? Duration.zero : d;
  }

  /// Temps de pause cumulé aujourd'hui (terminé + en cours).
  Duration get breakToday {
    var seconds = 0;
    for (final s in _allServicesToday()) {
      if (s.isBreak) seconds += _secondsOf(s);
    }
    return Duration(seconds: seconds);
  }

  /// Temps de travail effectif aujourd'hui (services − pauses), en direct.
  Duration get workedToday {
    var work = 0;
    var pause = 0;
    for (final s in _allServicesToday()) {
      if (s.isBreak) {
        pause += _secondsOf(s);
      } else {
        work += _secondsOf(s);
      }
    }
    final effective = work - pause;
    return Duration(seconds: effective > 0 ? effective : 0);
  }

  /// Segments de la journée (services et pauses) triés par début, bornes
  /// locales, le segment ouvert se termine à « maintenant ».
  List<DaySegment> get segments {
    final now = _now();
    return [
      for (final s in _allServicesToday())
        DaySegment(
          service: s,
          start: s.debut.toLocal(),
          end: (s.fin ?? now).toLocal(),
        ),
    ];
  }

  /// Amplitude de la journée : de la première prise de service à maintenant
  /// (ou à la dernière fin de service si la journée est clôturée).
  Duration get amplitudeToday {
    final first = firstStartToday;
    if (first == null) return Duration.zero;
    final end = lastEndToday ?? _now().toLocal();
    final d = end.difference(first);
    return d.isNegative ? Duration.zero : d;
  }

  /// Pointages du jour + service actif s'il manque à la liste, triés.
  List<Service> _allServicesToday() {
    final active = _activeService;
    if (active == null) return _todayServices;
    // Le service actif peut ne pas encore être dans la liste du jour
    // (juste après un démarrage, avant la resynchronisation).
    if (_todayServices.any((s) => s.uuid == active.uuid)) {
      return _todayServices;
    }
    return [..._todayServices, active]
      ..sort((a, b) => a.debut.compareTo(b.debut));
  }

  int _secondsOf(Service s) {
    if (s.fin != null) {
      return s.duree ?? s.fin!.difference(s.debut).inSeconds;
    }
    final elapsed = _now().difference(s.debut).inSeconds;
    return elapsed > 0 ? elapsed : 0;
  }

  // ---- cycle de vie -----------------------------------------------------

  /// Chargement initial : données, GPS, prérequis, en parallèle.
  Future<void> init() async {
    await Future.wait([
      load(),
      checkLocationStatus(),
      _preloadLocation(),
      checkPrerequisites(),
    ]);
  }

  /// Rafraîchit tout (pull-to-refresh, retour d'un écran).
  Future<void> refresh() async {
    await Future.wait([
      load(),
      checkLocationStatus(),
      checkPrerequisites(),
    ]);
  }

  /// Retour au premier plan (réglages GPS, autre app) : statut de
  /// localisation, position et données sont revérifiés.
  Future<void> onAppResumed() async {
    await Future.wait([
      checkLocationStatus(),
      _preloadLocation(),
      load(),
    ]);
  }

  /// Recharge service actif, heures et pointages du jour.
  Future<void> load() async {
    final results = await Future.wait([
      _serviceRepository.getActiveService(),
      _serviceRepository.getWorkedHours(const WorkedHoursParams()),
      _serviceRepository.getDailyServices(),
    ]);
    if (_disposed) return;

    String? error;
    var anySuccess = false;
    var dailyFailed = false;

    results[0].fold(
      (failure) => error ??= failure.message,
      (service) {
        anySuccess = true;
        _activeService = service as Service?;
      },
    );
    results[1].fold(
      (failure) => error ??= failure.message,
      (hours) {
        anySuccess = true;
        _workedHours = hours as WorkedHours;
      },
    );
    results[2].fold(
      (failure) {
        error ??= failure.message;
        dailyFailed = true;
      },
      (services) {
        anySuccess = true;
        _todayServices = List<Service>.from(services as List)
          ..sort((a, b) => a.debut.compareTo(b.debut));
      },
    );

    // Sans aucune donnée, on remonte l'erreur ; sinon on garde l'affichage.
    _loadError = anySuccess ? null : error;
    _dailyUnavailable = anySuccess && dailyFailed;
    _isLoading = false;
    _syncTicker();
    notifyListeners();
  }

  Future<void> checkLocationStatus() async {
    final status = await _locationService.checkStatus();
    if (_disposed) return;
    if (status != _locationStatus) {
      _locationStatus = status;
      notifyListeners();
    }
  }

  /// Demande la permission puis relit le statut (et précharge la position).
  Future<void> requestLocationPermission() async {
    await _locationService.requestPermission();
    await checkLocationStatus();
    if (_locationStatus == LocationStatus.granted) {
      await _preloadLocation();
    }
  }

  Future<void> openLocationSettings() => _locationService.openLocationSettings();
  Future<void> openAppSettings() => _locationService.openAppSettings();

  Future<void> _preloadLocation() async {
    final location = await _locationService.getLocation();
    if (_disposed) return;
    final before = locationReadiness;
    if (location.isReal) {
      _cachedLocation = location;
      _locationCacheTime = _now();
      _locationNotFound = false;
    } else {
      _locationNotFound = true;
    }
    if (locationReadiness != before) notifyListeners();
  }

  // ---- prérequis --------------------------------------------------------

  /// Vérifie signature, kilométrage et rapport véhicule (en parallèle).
  ///
  /// Une erreur réseau ou un délai dépassé ([prerequisitesTimeout]) rend la
  /// ligne « indisponible » : on ne bloque jamais sur un doute.
  Future<void> checkPrerequisites() async {
    final user = _authRepository.getCachedUser();
    final now = _now();
    final checkKm = _needsKilometrageCheck(user, now);
    final checkRapport = !_isExemptFromRapport(user);

    _prerequisites = _prerequisites.copyWith(
      signature: PrereqState.checking,
      kilometrage: checkKm ? PrereqState.checking : PrereqState.notApplicable,
      rapport:
          checkRapport ? PrereqState.checking : PrereqState.notApplicable,
    );
    notifyListeners();

    final results = await Future.wait<Either<Failure, dynamic>?>([
      _guard(_signatureRepository.getLastSignatureSummary()),
      checkKm
          ? _guard(_vehiculeRepository.getMyLastKilometrage())
          : Future.value(null),
      checkRapport
          ? _guard(_rapportRepository.getMyLatestRapport())
          : Future.value(null),
    ]);
    if (_disposed) return;

    var next = _prerequisites;

    next = _fold<SignatureSummary>(results[0], PrereqState.unavailable,
        (summary) {
      return next.copyWith(
        signature:
            summary.needsToSign ? PrereqState.required : PrereqState.ok,
        heuresLastMonth: summary.heuresLastMonth,
      );
    }, (state) => next.copyWith(signature: state));

    if (checkKm) {
      next = _fold<LastKilometrageResponse>(results[1], PrereqState.unavailable,
          (response) {
        return next.copyWith(
          kilometrage: response.hasEnteredToday
              ? PrereqState.ok
              : PrereqState.required,
          lastKilometrageAt: response.lastKilometrage?.createdAt,
        );
      }, (state) => next.copyWith(kilometrage: state));
    }

    if (checkRapport) {
      next = _fold<RapportVehicule?>(results[2], PrereqState.unavailable,
          (rapport) {
        final status = computeRapportStatus(
          rapportDate: rapport?.createdAt,
          userCreatedAt: user?.createdAt,
          now: now,
        );
        return next.copyWith(
          rapport: switch (status) {
            RapportStatus.upToDate => PrereqState.ok,
            RapportStatus.warning => PrereqState.warning,
            RapportStatus.required => PrereqState.required,
          },
          lastRapportAt: rapport?.createdAt,
        );
      }, (state) => next.copyWith(rapport: state));
    }

    _prerequisites = next;
    notifyListeners();
  }

  /// Borne une vérification par [prerequisitesTimeout] ; `null` = délai.
  Future<Either<Failure, T>?> _guard<T>(Future<Either<Failure, T>> call) {
    return call
        .then<Either<Failure, T>?>((v) => v)
        .timeout(prerequisitesTimeout, onTimeout: () => null);
  }

  /// Applique [onValue] sur un `Right`, sinon [onState] avec [fallback].
  PointagePrerequisites _fold<T>(
    Either<Failure, dynamic>? result,
    PrereqState fallback,
    PointagePrerequisites Function(T value) onValue,
    PointagePrerequisites Function(PrereqState state) onState,
  ) {
    if (result == null) return onState(fallback);
    return result.fold(
      (_) => onState(fallback),
      (value) => onValue(value as T),
    );
  }

  bool _needsKilometrageCheck(User? user, DateTime now) {
    if (user?.role?.uuid != roleUtilisateurId) return false;
    return now.weekday != DateTime.saturday && now.weekday != DateTime.sunday;
  }

  bool _isExemptFromRapport(User? user) {
    final roleName = _normalizeRole(user?.role?.nom);
    return rolesExemptesRapport.any(roleName.startsWith);
  }

  /// Nom de rôle en minuscules, sans accents ni espaces de bord.
  static String _normalizeRole(String? name) => (name ?? '')
      .trim()
      .toLowerCase()
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[àâä]'), 'a')
      .replaceAll(RegExp('[îï]'), 'i');

  /// Statut du rapport hebdomadaire.
  ///
  /// - rapport (ou création du profil) cette semaine → à jour ;
  /// - la semaine dernière → avertissement ;
  /// - plus ancien ou date inconnue → obligatoire.
  @visibleForTesting
  static RapportStatus computeRapportStatus({
    required DateTime? rapportDate,
    required DateTime? userCreatedAt,
    required DateTime now,
  }) {
    final startOfWeek = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final startOfLastWeek = startOfWeek.subtract(const Duration(days: 7));

    final reference = rapportDate ?? userCreatedAt;
    if (reference == null) return RapportStatus.required;
    if (!reference.isBefore(startOfWeek)) return RapportStatus.upToDate;
    if (!reference.isBefore(startOfLastWeek)) return RapportStatus.warning;
    return RapportStatus.required;
  }

  // ---- actions ----------------------------------------------------------

  /// Démarre un service. Revérifie les prérequis juste avant : s'ils
  /// bloquent, retourne [PointageActionBlocked] sans appeler l'API.
  Future<PointageActionResult> startService() async {
    if (isActing) return const PointageActionIgnored();
    _inFlight = PointageAction.start;
    _setPhase(PointageActionPhase.checking);
    await checkPrerequisites();
    if (_disposed) return const PointageActionIgnored();
    if (_prerequisites.blocksStart) {
      _setPhase(PointageActionPhase.idle);
      return PointageActionBlocked(_prerequisites);
    }
    return _perform(
      PointageAction.start,
      _serviceRepository.startService,
      alreadyActing: true,
    );
  }

  Future<PointageActionResult> endService() => _perform(
        PointageAction.end,
        _serviceRepository.endService,
        clearsActive: true,
      );

  Future<PointageActionResult> startBreak() =>
      _perform(PointageAction.breakStart, _serviceRepository.startBreak);

  Future<PointageActionResult> endBreak() =>
      _perform(PointageAction.breakEnd, _serviceRepository.endBreak);

  Future<PointageActionResult> _perform(
    PointageAction action,
    Future<Either<Failure, Service>> Function(ServiceGpsRequest request) call, {
    bool clearsActive = false,
    bool alreadyActing = false,
  }) async {
    if (isActing && !alreadyActing) return const PointageActionIgnored();
    _inFlight = action;
    _setPhase(PointageActionPhase.locating);

    final location = await _getLocation();
    if (_disposed) return const PointageActionIgnored();
    if (location == null) {
      final status = await _locationService.checkStatus();
      if (_disposed) return const PointageActionIgnored();
      _locationStatus = status;
      _locationNotFound = true;
      _setPhase(PointageActionPhase.idle);
      return PointageActionNoLocation(status);
    }

    _setPhase(PointageActionPhase.sending);
    final result = await call(ServiceGpsRequest(
      latitude: location.latitude,
      longitude: location.longitude,
    ));
    if (_disposed) return const PointageActionIgnored();

    return result.fold(
      (failure) {
        _setPhase(PointageActionPhase.idle);
        return PointageActionFailure(failure.message);
      },
      (service) {
        _activeService = clearsActive ? null : service;
        _phase = PointageActionPhase.idle;
        _inFlight = null;
        _syncTicker();
        notifyListeners();
        // Resynchronise heures et liste du jour en arrière-plan.
        unawaited(load());
        return PointageActionSuccess(service);
      },
    );
  }

  void _setPhase(PointageActionPhase phase) {
    if (phase == PointageActionPhase.idle) _inFlight = null;
    if (_phase == phase) return;
    _phase = phase;
    notifyListeners();
  }

  Future<LocationData?> _getLocation() async {
    final cached = _cachedLocation;
    if (cached != null && hasFreshLocation) {
      // Rafraîchit le cache pour la prochaine fois, sans attendre.
      unawaited(_preloadLocation());
      return cached;
    }

    final location = await _locationService.getLocation();
    if (!location.isReal) return null;
    _cachedLocation = location;
    _locationCacheTime = _now();
    return location;
  }

  // ---- horloge ----------------------------------------------------------

  void _syncTicker() {
    if (_activeService != null) {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        clock.value = _now();
      });
      clock.value = _now();
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    clock.dispose();
    super.dispose();
  }
}
