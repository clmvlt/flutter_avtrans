import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repositories/absence_repository.dart';
import '../../data/repositories/acompte_repository.dart';
import '../../data/repositories/app_version_repository.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/couchette_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/rapport_repository.dart';
import '../../data/repositories/service_repository.dart';
import '../../data/repositories/signature_repository.dart';
import '../../data/repositories/todo_repository.dart';
import '../../data/repositories/vehicule_repository.dart';
import '../../data/repositories/ypsium_auth_repository.dart';
import '../../data/repositories/ypsium_referentiel_repository.dart';
import '../../data/repositories/ypsium_transport_repository.dart';
import '../../data/repositories/ypsium_vehicule_repository.dart';
import '../../data/services/download_service.dart';
import '../../data/services/http_service.dart';
import '../../data/services/token_storage_service.dart';
import '../../data/services/ypsium_http_service.dart';
import '../../data/services/ypsium_spooler_service.dart';
import '../services/location_service.dart';
import '../services/update_checker_service.dart';

/// Localisateur de services simple pour l'injection de dépendances
/// Pour un projet plus complexe, utilisez get_it ou provider
class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  HttpService? _httpService;
  TokenStorageService? _tokenStorage;
  AuthRepository? _authRepository;
  ServiceRepository? _serviceRepository;
  AbsenceRepository? _absenceRepository;
  AcompteRepository? _acompteRepository;
  SignatureRepository? _signatureRepository;
  VehiculeRepository? _vehiculeRepository;
  RapportRepository? _rapportRepository;
  TodoRepository? _todoRepository;
  NotificationRepository? _notificationRepository;
  CouchetteRepository? _couchetteRepository;
  LocationService? _locationService;
  DownloadService? _downloadService;
  AppVersionRepository? _appVersionRepository;
  UpdateCheckerService? _updateCheckerService;
  YpsiumHttpService? _ypsiumHttpService;
  YpsiumAuthRepository? _ypsiumAuthRepository;
  YpsiumTransportRepository? _ypsiumTransportRepository;
  YpsiumVehiculeRepository? _ypsiumVehiculeRepository;
  YpsiumReferentielRepository? _ypsiumReferentielRepository;
  YpsiumSpoolerService? _ypsiumSpoolerService;

  bool _isInitialized = false;

  /// Initialise tous les services
  Future<void> init() async {
    if (_isInitialized) return;

    // Initialise le service de stockage de token
    _tokenStorage = await TokenStorageService.create();

    // Initialise le service HTTP
    _httpService = HttpService();

    // Initialise le repository d'authentification
    _authRepository = AuthRepository(
      httpService: _httpService!,
      tokenStorage: _tokenStorage!,
    );

    // Initialise le repository des services (pointage)
    _serviceRepository = ServiceRepository(
      httpService: _httpService!,
    );

    // Initialise le repository des absences
    _absenceRepository = AbsenceRepository(_httpService!);

    // Initialise le repository des acomptes
    _acompteRepository = AcompteRepository(_httpService!);

    // Initialise le repository des signatures
    _signatureRepository = SignatureRepository(_httpService!);

    // Initialise le repository des véhicules
    _vehiculeRepository = VehiculeRepository(
      httpService: _httpService!,
    );

    // Initialise le repository des rapports
    _rapportRepository = RapportRepository(
      httpService: _httpService!,
    );

    // Initialise le repository des todos
    _todoRepository = TodoRepository(_httpService!);

    // Initialise le repository des notifications
    _notificationRepository = NotificationRepository(_httpService!);

    // Initialise le repository des couchettes
    _couchetteRepository = CouchetteRepository(_httpService!);

    // Initialise le service de localisation
    _locationService = LocationService();

    // Initialise le service de téléchargement
    _downloadService = DownloadService();
    _downloadService!.setAuthToken(_tokenStorage!.getToken());

    // Initialise le repository des versions d'application
    _appVersionRepository = AppVersionRepository(
      httpService: _httpService!,
      downloadService: _downloadService!,
    );

    // Initialise le service de vérification des mises à jour
    _updateCheckerService = await UpdateCheckerService.create();

    // Initialise les services Ypsium
    final prefs = await SharedPreferences.getInstance();
    _ypsiumHttpService = YpsiumHttpService();
    _ypsiumAuthRepository = YpsiumAuthRepository(
      httpService: _ypsiumHttpService!,
      prefs: prefs,
    );
    _ypsiumSpoolerService = YpsiumSpoolerService(
      httpService: _ypsiumHttpService!,
    );
    await _ypsiumSpoolerService!.init();
    _ypsiumTransportRepository = YpsiumTransportRepository(
      httpService: _ypsiumHttpService!,
      authRepository: _ypsiumAuthRepository!,
      spoolerService: _ypsiumSpoolerService!,
    );
    _ypsiumVehiculeRepository = YpsiumVehiculeRepository(
      httpService: _ypsiumHttpService!,
      authRepository: _ypsiumAuthRepository!,
    );
    _ypsiumReferentielRepository = YpsiumReferentielRepository(
      httpService: _ypsiumHttpService!,
      authRepository: _ypsiumAuthRepository!,
    );

    _isInitialized = true;
  }

  /// Récupère le service HTTP
  HttpService get httpService {
    _ensureInitialized();
    return _httpService!;
  }

  /// Récupère le service de stockage de token
  TokenStorageService get tokenStorage {
    _ensureInitialized();
    return _tokenStorage!;
  }

  /// Récupère le repository d'authentification
  AuthRepository get authRepository {
    _ensureInitialized();
    return _authRepository!;
  }

  /// Récupère le repository des services (pointage)
  ServiceRepository get serviceRepository {
    _ensureInitialized();
    return _serviceRepository!;
  }

  /// Récupère le repository des absences
  AbsenceRepository get absenceRepository {
    _ensureInitialized();
    return _absenceRepository!;
  }

  /// Récupère le repository des acomptes
  AcompteRepository get acompteRepository {
    _ensureInitialized();
    return _acompteRepository!;
  }

  /// Récupère le repository des signatures
  SignatureRepository get signatureRepository {
    _ensureInitialized();
    return _signatureRepository!;
  }

  /// Récupère le repository des véhicules
  VehiculeRepository get vehiculeRepository {
    _ensureInitialized();
    return _vehiculeRepository!;
  }

  /// Récupère le repository des rapports
  RapportRepository get rapportRepository {
    _ensureInitialized();
    return _rapportRepository!;
  }

  /// Récupère le repository des todos
  TodoRepository get todoRepository {
    _ensureInitialized();
    return _todoRepository!;
  }

  /// Récupère le repository des notifications
  NotificationRepository get notificationRepository {
    _ensureInitialized();
    return _notificationRepository!;
  }

  /// Récupère le repository des couchettes
  CouchetteRepository get couchetteRepository {
    _ensureInitialized();
    return _couchetteRepository!;
  }

  /// Récupère le service de localisation
  LocationService get locationService {
    _ensureInitialized();
    return _locationService!;
  }

  /// Récupère le service de téléchargement
  DownloadService get downloadService {
    _ensureInitialized();
    return _downloadService!;
  }

  /// Récupère le repository des versions d'application
  AppVersionRepository get appVersionRepository {
    _ensureInitialized();
    return _appVersionRepository!;
  }

  /// Récupère le service de vérification des mises à jour
  UpdateCheckerService get updateCheckerService {
    _ensureInitialized();
    return _updateCheckerService!;
  }

  /// Récupère le service HTTP Ypsium
  YpsiumHttpService get ypsiumHttpService {
    _ensureInitialized();
    return _ypsiumHttpService!;
  }

  /// Récupère le repository d'authentification Ypsium
  YpsiumAuthRepository get ypsiumAuthRepository {
    _ensureInitialized();
    return _ypsiumAuthRepository!;
  }

  /// Récupère le repository de transport Ypsium
  YpsiumTransportRepository get ypsiumTransportRepository {
    _ensureInitialized();
    return _ypsiumTransportRepository!;
  }

  /// Récupère le repository de véhicules Ypsium
  YpsiumVehiculeRepository get ypsiumVehiculeRepository {
    _ensureInitialized();
    return _ypsiumVehiculeRepository!;
  }

  /// Récupère le repository des référentiels Ypsium
  YpsiumReferentielRepository get ypsiumReferentielRepository {
    _ensureInitialized();
    return _ypsiumReferentielRepository!;
  }

  /// Récupère le service spooler Ypsium
  YpsiumSpoolerService get ypsiumSpoolerService {
    _ensureInitialized();
    return _ypsiumSpoolerService!;
  }

  /// Vérifie que les services sont initialisés
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError(
        'ServiceLocator non initialisé. Appelez ServiceLocator().init() au démarrage.',
      );
    }
  }

  /// Réinitialise les services (utile pour les tests)
  void reset() {
    _httpService?.dispose();
    _httpService = null;
    _tokenStorage = null;
    _authRepository = null;
    _serviceRepository = null;
    _absenceRepository = null;
    _acompteRepository = null;
    _signatureRepository = null;
    _vehiculeRepository = null;
    _rapportRepository = null;
    _todoRepository = null;
    _notificationRepository = null;
    _couchetteRepository = null;
    _locationService = null;
    _downloadService?.dispose();
    _downloadService = null;
    _appVersionRepository = null;
    _updateCheckerService = null;
    _ypsiumHttpService?.dispose();
    _ypsiumHttpService = null;
    _ypsiumAuthRepository = null;
    _ypsiumSpoolerService?.dispose();
    _ypsiumSpoolerService = null;
    _ypsiumTransportRepository = null;
    _ypsiumVehiculeRepository = null;
    _ypsiumReferentielRepository = null;
    _isInitialized = false;
  }
}

/// Raccourci pour accéder au ServiceLocator
final sl = ServiceLocator();
