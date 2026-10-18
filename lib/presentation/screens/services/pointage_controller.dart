import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/errors/failures.dart';
import '../../../core/services/break_reminder_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/utils/live_counter.dart';
import '../../../core/utils/live_refresher.dart';
import '../../../core/utils/display_format.dart';
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
/// chronologie : bornes locales ; une ligne en cours se termine à
/// « début + durée en direct » à l'instant de la construction.
@immutable
class DaySegment {
  const DaySegment({
    required this.service,
    required this.start,
    required this.end,
    this.counter = LiveCounter.zero,
  });

  /// Segment d'une ligne de l'API (service ou pause).
  factory DaySegment.of(Service service) {
    final start = service.debut.toLocal();
    final counter = service.liveDuree;
    return DaySegment(
      service: service,
      start: start,
      end: service.fin?.toLocal() ?? start.add(counter.value),
      counter: counter,
    );
  }

  /// Services de travail et leurs pauses, à plat, par début croissant.
  static List<DaySegment> flatten(Iterable<Service> services) => [
        for (final s in services) ...[
          DaySegment.of(s),
          for (final p in s.pauses) DaySegment.of(p),
        ],
      ]..sort((a, b) => a.start.compareTo(b.start));

  final Service service;
  final DateTime start;
  final DateTime end;

  /// Durée brute de l'API, qui avance si la ligne est en cours.
  final LiveCounter counter;

  bool get isBreak => service.isBreak;
  bool get isActive => service.enCours;

  /// Durée à l'instant présent.
  Duration get duration => counter.value;
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
/// - [clock] qui tique chaque seconde tant qu'un compteur avance (service en
///   cours, période d'heures en cours), pour ne reconstruire que les
///   compteurs et pas toute la page.
///
/// Aucun total n'est calculé ici : les durées viennent de l'API et avancent
/// localement entre deux appels (voir `LiveCounter`).
class PointageController extends ChangeNotifier {
  PointageController({
    ServiceRepository? serviceRepository,
    SignatureRepository? signatureRepository,
    VehiculeRepository? vehiculeRepository,
    RapportRepository? rapportRepository,
    AuthRepository? authRepository,
    LocationService? locationService,
    BreakReminderService? breakReminder,
    DateTime Function()? now,
    this.prerequisitesTimeout = const Duration(seconds: 6),
  })  : _serviceRepository = serviceRepository ?? sl.serviceRepository,
        _signatureRepository = signatureRepository ?? sl.signatureRepository,
        _vehiculeRepository = vehiculeRepository ?? sl.vehiculeRepository,
        _rapportRepository = rapportRepository ?? sl.rapportRepository,
        _authRepository = authRepository ?? sl.authRepository,
        _locationService = locationService ?? sl.locationService,
        _breakReminder = breakReminder ?? sl.breakReminderService,
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
  final BreakReminderService _breakReminder;
  final DateTime Function() _now;

  /// Horloge qui tique chaque seconde tant qu'un compteur avance.
  late final ValueNotifier<DateTime> clock;

  Timer? _ticker;
  LiveRefresher? _refresher;
  bool _disposed = false;

  /// Incrémenté à chaque action réussie : un chargement lancé avant ne
  /// remplace pas le service renvoyé par l'action.
  int _actionSeq = 0;

  /// Dernière valeur de [breakDue] publiée : l'horloge ne notifie la page
  /// qu'au franchissement du seuil.
  bool _breakDue = false;

  bool _isLoading = true;
  PointageActionPhase _phase = PointageActionPhase.idle;
  PointageAction? _inFlight;
  String? _loadError;
  bool _dailyUnavailable = false;
  bool _locationNotFound = false;
  Service? _activeService;
  WorkedHours? _workedHours;
  JourneeTravail? _journee;
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

  /// Journée de travail en cours, calculée par l'API : la veille pour un
  /// salarié de nuit tant que son service touche aujourd'hui.
  JourneeTravail? get journee => _journee;

  /// Services de travail de la journée (pauses imbriquées), par début
  /// croissant.
  List<Service> get dayServices => _journee?.services ?? const [];

  /// La journée affichée est aujourd'hui (vrai tant qu'elle est inconnue).
  bool get journeeIsToday => _journee?.aujourdhui ?? true;

  /// Jour de la journée affichée (`null` tant qu'elle est inconnue).
  DateTime? get journeeDate => _journee?.date;

  /// « Aujourd'hui » ou « Journée du lun. 12/10 (service de nuit) ».
  String get journeeTitle {
    final j = _journee;
    if (j == null) return 'Aujourd\'hui';
    return DisplayFormat.workingDay(j.date, today: j.aujourdhui);
  }

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
    return active.enPause ? PointageStatus.onBreak : PointageStatus.onDuty;
  }

  /// Au moins un compteur avance : l'horloge tique.
  bool get isLive =>
      _activeService != null ||
      (_journee?.heures.enCours ?? false) ||
      (_workedHours?.anyRunning ?? false);

  bool get hasActiveService => _activeService != null;

  /// La journée a démarré puis a été clôturée (au moins un service terminé,
  /// aucun pointage ouvert).
  bool get dayFinished => _activeService == null && dayServices.isNotEmpty;

  /// La journée n'a pas encore commencé.
  bool get dayNotStarted => _activeService == null && dayServices.isEmpty;

  /// Heure de la première prise de service de la journée (locale).
  DateTime? get firstStart {
    final services = dayServices;
    return services.isEmpty ? null : services.first.debut.toLocal();
  }

  /// Heure de fin du dernier service clôturé (locale) — `null` si un pointage
  /// est ouvert ou si rien n'est terminé.
  DateTime? get lastEnd {
    if (_activeService != null) return null;
    DateTime? last;
    for (final s in dayServices) {
      if (s.fin == null) continue;
      if (last == null || s.fin!.isAfter(last)) last = s.fin;
    }
    return last?.toLocal();
  }

  /// Nombre de pauses de la journée (terminées ou en cours).
  int get breakCount => dayServices.fold(0, (n, s) => n + s.pauses.length);

  /// Nombre de services de la journée.
  int get serviceCount => dayServices.length;

  /// Temps écoulé sur le pointage ouvert : la pause en cours, sinon le
  /// service.
  Duration get currentSegmentElapsed {
    final active = _activeService;
    if (active == null) return Duration.zero;
    return (active.pauseEnCours ?? active).liveDuree.value;
  }

  /// Temps net de la journée (`journee.heures` en direct : avance en
  /// service, figé en pause et hors service). À défaut, le `day` de
  /// `/services/hours` (même journée). `null` si inconnu.
  Duration? get workedTime =>
      (_journee?.heures ?? _workedHours?.day)?.live.value;

  /// Temps de pause de la journée (en direct pendant une pause).
  Duration get breakTime => dayServices.fold(
        Duration.zero,
        (total, s) => total + s.livePauses.value,
      );

  /// Début du travail continu en cours : reprise après la dernière pause, ou
  /// prise de service. `null` hors service ou en pause.
  DateTime? get continuousWorkStart {
    final active = _activeService;
    if (active == null || active.enPause) return null;
    var start = active.debut;
    for (final p in active.pauses) {
      final end = p.fin;
      if (end != null && end.isAfter(start)) start = end;
    }
    return start;
  }

  /// Temps de travail depuis [continuousWorkStart], en direct : durée du
  /// service moins ce qui précède la reprise (horloge monotone, pas celle du
  /// téléphone).
  Duration get continuousWork {
    final active = _activeService;
    final start = continuousWorkStart;
    if (active == null || start == null) return Duration.zero;
    final d = active.liveDuree.value - start.difference(active.debut);
    return d.isNegative ? Duration.zero : d;
  }

  /// Six heures de travail sans pause : la page invite à en prendre une.
  bool get breakDue => continuousWork >= BreakReminderService.threshold;

  /// Segments des services de la journée et de leurs pauses, par début,
  /// bornes locales ; une ligne en cours se termine « maintenant ».
  List<DaySegment> get segments => DaySegment.flatten(dayServices);

  /// Amplitude : de la première prise de service à maintenant (ou à la
  /// dernière fin de service si la journée est clôturée).
  Duration get amplitude {
    final first = firstStart;
    if (first == null) return Duration.zero;
    final active = _activeService;
    final end = active != null
        ? active.debut.toLocal().add(active.liveDuree.value)
        : lastEnd;
    if (end == null) return Duration.zero;
    final d = end.difference(first);
    return d.isNegative ? Duration.zero : d;
  }

  // ---- cycle de vie -----------------------------------------------------

  /// Chargement initial : données, GPS, prérequis, en parallèle. Lance la
  /// resynchronisation (toutes les 5 min tant qu'un compteur avance, et au
  /// changement de jour) ; le retour au premier plan passe par
  /// [onAppResumed].
  Future<void> init() async {
    _refresher ??= LiveRefresher(
      onRefresh: load,
      isLive: () => isLive,
      now: _now,
      observeLifecycle: false,
    )..start();
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

  /// Recharge heures, journée de travail et (sauf [withActive] à `false`) le
  /// service en cours.
  Future<void> load({bool withActive = true}) async {
    final seq = _actionSeq;
    final activeFuture =
        withActive ? _serviceRepository.getActiveService() : null;
    final hoursFuture =
        _serviceRepository.getWorkedHours(const WorkedHoursParams());
    final dailyFuture = _serviceRepository.getDailyServices();
    final activeResult = await activeFuture;
    final hoursResult = await hoursFuture;
    final dailyResult = await dailyFuture;
    if (_disposed) return;

    String? error;
    var anySuccess = false;
    var activeLoaded = false;
    var dailyFailed = false;
    // Une action a abouti pendant le chargement : son service fait foi.
    final stale = seq != _actionSeq;

    activeResult?.fold(
      (failure) => error ??= failure.message,
      (service) {
        anySuccess = true;
        activeLoaded = true;
        if (!stale) _activeService = service;
      },
    );
    hoursResult.fold(
      (failure) => error ??= failure.message,
      (hours) {
        anySuccess = true;
        _workedHours = hours;
      },
    );
    dailyResult.fold(
      (failure) {
        error ??= failure.message;
        dailyFailed = true;
      },
      (journee) {
        anySuccess = true;
        _journee = journee;
      },
    );

    // Sans aucune donnée, on remonte l'erreur ; sinon on garde l'affichage.
    // Après une action, le service renvoyé suffit à l'affichage.
    _loadError = anySuccess || !withActive ? null : error;
    _dailyUnavailable = anySuccess && dailyFailed;
    _isLoading = false;
    _syncTicker();
    // Hors ligne, on garde le rappel déjà programmé.
    if (activeLoaded) _syncBreakReminder();
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

  Future<PointageActionResult> endService() =>
      _perform(PointageAction.end, _serviceRepository.endService);

  Future<PointageActionResult> startBreak() =>
      _perform(PointageAction.breakStart, _serviceRepository.startBreak);

  Future<PointageActionResult> endBreak() =>
      _perform(PointageAction.breakEnd, _serviceRepository.endBreak);

  Future<PointageActionResult> _perform(
    PointageAction action,
    Future<Either<Failure, Service>> Function(ServiceGpsRequest request) call, {
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
        // L'action renvoie le service de travail dans son état complet.
        _actionSeq++;
        _activeService = service.enCours ? service : null;
        // Mise à jour sur place ; un nouveau service n'apparaît (et la
        // journée ne bascule sur aujourd'hui) qu'au rechargement ci-dessous.
        _journee = _journee?.withService(service);
        _phase = PointageActionPhase.idle;
        _inFlight = null;
        _syncTicker();
        if (action == PointageAction.start ||
            action == PointageAction.breakEnd) {
          // Autorisation demandée au moment où le rappel devient utile.
          unawaited(_breakReminder
              .requestPermission()
              .then((_) => _syncBreakReminder()));
        } else {
          _syncBreakReminder();
        }
        notifyListeners();
        // Resynchronise heures et journée en arrière-plan : démarrer un
        // service fait passer la journée sur aujourd'hui.
        unawaited(load(withActive: false));
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

  // ---- rappel de pause --------------------------------------------------

  /// Programme la notification à la fin des 6 h de travail continu, ou
  /// l'annule hors service et en pause. L'heure vient du temps restant (pas
  /// d'un écart avec l'horloge du téléphone), arrondie à la minute pour ne
  /// pas reprogrammer à chaque rechargement.
  void _syncBreakReminder() {
    if (continuousWorkStart == null) {
      unawaited(_breakReminder.cancel());
      return;
    }
    final at = _now().add(BreakReminderService.threshold - continuousWork);
    const minute = Duration.millisecondsPerMinute;
    final rounded = DateTime.fromMillisecondsSinceEpoch(
      (at.millisecondsSinceEpoch / minute).round() * minute,
      isUtc: at.isUtc,
    );
    unawaited(_breakReminder.scheduleAt(rounded));
  }

  // ---- horloge ----------------------------------------------------------

  void _syncTicker() {
    if (isLive) {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        clock.value = _now();
        final due = breakDue;
        if (due != _breakDue) {
          _breakDue = due;
          notifyListeners();
        }
      });
      clock.value = _now();
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
    _breakDue = breakDue;
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    _refresher?.dispose();
    clock.dispose();
    super.dispose();
  }
}
