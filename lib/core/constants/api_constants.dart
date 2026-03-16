import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuration des constantes API
abstract class ApiConstants {
  /// URL de base de l'API - Sélectionnée automatiquement selon l'environnement
  static String get baseUrl {
    if (kDebugMode) {
      return dotenv.env['API_DEBUG_BASE_URL'] ?? 'http://localhost:8081';
    }
    return dotenv.env['API_PROD_BASE_URL'] ?? 'https://api.avtrans-concept.com';
  }

  /// Timeout pour les requêtes HTTP (en secondes)
  static const int connectionTimeout = 30;
  static const int receiveTimeout = 30;

  /// Headers par défaut
  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
}

/// Endpoints de l'API d'authentification
abstract class AuthEndpoints {
  static const String _base = '/auth';

  /// POST - Enregistrer un nouvel utilisateur
  static const String register = '$_base/register';

  /// POST - Connexion
  static const String login = '$_base/login';

  /// GET - Vérifier l'email avec token
  static const String verify = '$_base/verify';

  /// GET - Récupérer l'utilisateur courant
  static const String me = '$_base/me';

  /// POST - Demander réinitialisation mot de passe
  static const String passwordResetRequest = '$_base/password-reset/request';

  /// POST - Confirmer réinitialisation mot de passe
  static const String passwordResetConfirm = '$_base/password-reset/confirm';

  /// GET - Vérifier le statut d'un utilisateur par ID
  static String status(String userId) => '$_base/status/$userId';
}

/// Endpoints de l'API du profil utilisateur
abstract class ProfileEndpoints {
  static const String _base = '/profile';

  /// PUT - Modifier son profil
  static const String update = _base;

  /// PUT - Modifier son mot de passe
  static const String password = '$_base/password';
}

/// Endpoints de l'API des services (pointage)
abstract class ServiceEndpoints {
  static const String _base = '/services';

  /// POST - Démarrer un service
  static const String start = '$_base/start';

  /// POST - Terminer un service
  static const String end = '$_base/end';

  /// POST - Démarrer une pause
  static const String breakStart = '$_base/break/start';

  /// POST - Terminer une pause
  static const String breakEnd = '$_base/break/end';

  /// GET - Récupérer les services d'un mois
  static const String month = '$_base/month';

  /// GET - Récupérer les heures travaillées
  static const String hours = '$_base/hours';

  /// GET - Récupérer le service actif
  static const String active = '$_base/active';

  /// GET - Récupérer l'historique des services
  static const String history = '$_base/history';

  /// GET - Récupérer les services du jour de l'utilisateur
  static const String daily = '$_base/user/daily';
}

/// Endpoints de l'API des types d'absence
abstract class AbsenceTypeEndpoints {
  static const String _base = '/absence-types';

  /// GET - Récupérer tous les types d'absence
  static const String all = _base;

  /// GET - Récupérer un type par UUID
  static String byUuid(String uuid) => '$_base/$uuid';
}

/// Endpoints de l'API des absences
abstract class AbsenceEndpoints {
  static const String _base = '/absences';

  /// POST - Créer une demande d'absence
  static const String create = _base;

  /// POST - Récupérer mes demandes d'absence (avec filtres)
  static const String my = '$_base/my';

  /// DELETE - Annuler une demande d'absence
  static String cancel(String uuid) => '$_base/$uuid';
}

/// Endpoints de l'API des acomptes
abstract class AcompteEndpoints {
  static const String _base = '/acomptes';

  /// POST - Créer une demande d'acompte
  static const String create = _base;

  /// POST - Récupérer mes demandes d'acompte (avec filtres)
  static const String my = '$_base/my';

  /// DELETE - Annuler une demande d'acompte
  static String cancel(String uuid) => '$_base/$uuid';
}

/// Endpoints de l'API des signatures
abstract class SignatureEndpoints {
  static const String _base = '/signatures';

  /// GET - Récupérer toutes mes signatures
  static const String all = _base;

  /// POST - Créer une signature
  static const String create = _base;

  /// GET - Récupérer ma dernière signature
  static const String last = '$_base/last';

  /// GET - Récupérer le résumé de ma dernière signature
  static const String lastSummary = '$_base/last/summary';

  /// DELETE - Supprimer une signature (admin)
  static String delete(String uuid) => '$_base/$uuid';

  /// GET - Récupérer tous les utilisateurs avec leur dernière signature (admin)
  static const String allUsers = '$_base/all-users';

  /// GET - Récupérer toutes les signatures d'un utilisateur (admin)
  static String byUser(String userUuid) => '$_base/user/$userUuid';
}

/// Endpoints de l'API des utilisateurs
abstract class UserEndpoints {
  static const String _base = '/users';

  /// GET - Récupérer le dernier kilométrage de l'utilisateur
  static const String myKilometrage = '$_base/me/kilometrage';

  /// GET - Récupérer mes préférences de notification
  static const String notificationPreferences =
      '$_base/me/notification-preferences';

  /// PUT - Modifier mes préférences de notification
  static const String updateNotificationPreferences =
      '$_base/me/notification-preferences';
}

/// Endpoints de l'API des todos
abstract class TodoEndpoints {
  static const String _base = '/todos';

  /// POST - Créer un todo
  static const String create = _base;

  /// PUT - Modifier un todo
  static String update(String uuid) => '$_base/$uuid';

  /// POST - Basculer l'état done
  static String toggle(String uuid) => '$_base/$uuid/toggle';

  /// DELETE - Supprimer un todo
  static String delete(String uuid) => '$_base/$uuid';

  /// GET - Obtenir un todo par UUID
  static String byUuid(String uuid) => '$_base/$uuid';

  /// POST - Rechercher des todos
  static const String search = '$_base/search';
}

/// Endpoints de l'API des catégories todo
abstract class TodoCategoryEndpoints {
  static const String _base = '/todo-categories';

  /// GET - Toutes les catégories
  static const String all = _base;

  /// POST - Créer une catégorie
  static const String create = _base;

  /// PUT - Modifier une catégorie
  static String update(String uuid) => '$_base/$uuid';

  /// DELETE - Supprimer une catégorie
  static String delete(String uuid) => '$_base/$uuid';

  /// GET - Catégorie par UUID
  static String byUuid(String uuid) => '$_base/$uuid';
}

/// Endpoints de l'API des notifications
abstract class NotificationEndpoints {
  static const String _base = '/notifications';

  /// GET - Toutes les notifications
  static const String all = _base;

  /// GET - Notifications non lues
  static const String unread = '$_base/unread';

  /// GET - Notifications lues
  static const String read = '$_base/read';

  /// GET - Compteur de notifications non lues
  static const String unreadCount = '$_base/unread/count';

  /// GET - Notification par UUID
  static String byUuid(String uuid) => '$_base/$uuid';

  /// PATCH - Marquer une notification comme lue
  static String markRead(String uuid) => '$_base/$uuid/read';

  /// PATCH - Marquer toutes les notifications comme lues
  static const String readAll = '$_base/read-all';
}

/// Endpoints de l'API des couchettes
abstract class CouchetteEndpoints {
  static const String _base = '/couchettes';

  /// POST - Créer une couchette
  static const String create = _base;

  /// GET - Mes couchettes (paginé)
  static const String my = '$_base/me';

  /// DELETE - Supprimer une couchette
  static String delete(String uuid) => '$_base/$uuid';
}

/// Endpoints de l'API des véhicules
abstract class VehiculeEndpoints {
  static const String _base = '/vehicules';

  /// GET - Récupérer tous les véhicules
  static const String all = _base;

  /// GET - Récupérer un véhicule par ID
  static String byId(String id) => '$_base/$id';

  /// POST - Ajouter un kilométrage
  static const String addKilometrage = '$_base/kilometrages';

  /// POST - Créer une information d'ajustement
  static const String createAdjustInfo = '$_base/adjust-infos';

  /// GET - Récupérer l'historique des kilométrages d'un véhicule
  static String kilometrages(String id) => '$_base/$id/kilometrages';

  /// GET - Récupérer les informations d'ajustement d'un véhicule
  static String adjustInfos(String id) => '$_base/$id/adjust-infos';

  /// GET - Récupérer les photos d'une information d'ajustement
  static String adjustInfoPictures(String adjustInfoId) =>
      '$_base/adjust-infos/$adjustInfoId/pictures';

  /// GET - Récupérer les fichiers d'un véhicule
  static String files(String id) => '$_base/$id/files';

  /// POST - Uploader un fichier pour un véhicule
  static String uploadFile(String id) => '$_base/$id/files';

  /// DELETE - Supprimer un fichier de véhicule
  static String deleteFile(String fileId) => '$_base/files/$fileId';
}

/// Endpoints de l'API des rapports de véhicules
abstract class RapportEndpoints {
  static const String _base = '/rapports';

  /// POST - Créer un rapport de véhicule
  static const String create = _base;

  /// GET - Récupérer le dernier rapport de l'utilisateur
  static const String myLatest = '$_base/me/latest';

  /// GET - Récupérer tous les rapports d'un véhicule
  static String byVehicule(String vehiculeId) => '$_base/$vehiculeId';
}

/// Endpoints de l'API des versions d'application
abstract class AppVersionEndpoints {
  static const String _base = '/app-versions';

  /// GET - Récupérer toutes les versions actives
  static const String all = _base;

  /// GET - Récupérer la dernière version active
  static const String latest = '$_base/latest';

  /// GET - Vérifier si une mise à jour est disponible
  static const String check = '$_base/check';

  /// GET - Télécharger l'APK par ID de version
  static String download(String id) => '$_base/$id/download';

  /// GET - Télécharger la dernière version
  static const String latestDownload = '$_base/latest/download';
}
