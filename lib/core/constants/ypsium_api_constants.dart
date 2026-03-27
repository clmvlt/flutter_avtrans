/// Configuration des constantes API Ypsium
/// L'IP reste identique quel que soit l'environnement
abstract class YpsiumApiConstants {
  static const String baseUrl = 'http://213.186.35.201';

  static const int connectionTimeout = 30;

  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Connection': 'close',
  };
}

/// Endpoints d'authentification Ypsium
abstract class YpsiumAuthEndpoints {
  /// GET - Obtenir un token de session via clé machine
  static String getConnexion(String cle) =>
      '/authentification/getConnexion/$cle';

  /// POST - Authentifier un utilisateur
  static String logon(String sessionId) =>
      '/authentification/logon/$sessionId';
}

/// Endpoints généraux Ypsium
abstract class YpsiumEndpoints {
  /// GET - Vérifier la disponibilité du serveur
  static const String ping = '/ping';
}

/// Endpoints référentiels Ypsium
abstract class YpsiumReferentielEndpoints {
  /// GET - Liste des codes anomalie
  static String getCodeAnomalie(String token) => '/getCodeAnomalie/$token';

  /// GET - Liste des lieux d'entreposage
  static String getListeEntreposage(String token) =>
      '/getListeEntreposage/$token';

  /// GET - Types de règlement (pas de token)
  static const String getListeTypeReglementCR = '/getListeTypeReglementCR';

  /// GET - Liste des clients
  static String getListeClient(String token) => '/getListeClient/$token';

  /// GET - Liste des emplacements
  static String getListeEmplacement(String token) =>
      '/getListeEmplacement/$token';

  /// GET - Référentiel articles
  static String getListeArticleReferenciel(String token) =>
      '/getListeArticleReferenciel/$token';
}

/// Endpoints stockage / EDI Ypsium
abstract class YpsiumStockageEndpoints {
  /// GET - Liste des EDI
  static String getListeEDI(String token) => '/stockage/getListeEDI/$token';

  /// GET - Nombre de camions favoris
  static String getNbCamionsFavoris(String token) =>
      '/stockage/getNbCamionsFavoris/$token';
}

/// Endpoints véhicules Ypsium
abstract class YpsiumVehiculeEndpoints {
  /// GET - Liste des véhicules du chauffeur
  static String getListeVehicules(String idChauffeur, String token) =>
      '/getListeVehicules/$idChauffeur/$token';

  /// GET - Paramètres de saisie du kilométrage
  static String getParamSaisieKilometrage(String token) =>
      '/getParamSaisieKilometrage/$token';

  /// GET - Kilométrage d'un véhicule
  static String getKilometreVehicule(int idVehicule, String token) =>
      '/getKilometreVehicule/$idVehicule/$token';

  /// GET - Choix véhicule et kilométrage d'un chauffeur
  static String getUserVehiculeKilometrage(
    String idChauffeur,
    int idVehicule,
    String token,
  ) =>
      '/getUserVehiculeKilometrage/$idChauffeur/$idVehicule/$token';

  /// POST - Enregistrer le choix de véhicule
  static String setChoixVehicule(String token) =>
      '/setChoixVehicule/$token';
}

/// Endpoints transport Ypsium
abstract class YpsiumTransportEndpoints {
  /// GET - Liste des ordres de transport
  static String getListeTransport(
    String idChauffeur,
    String date,
    String filtre,
    String token,
  ) =>
      '/getListeTransport/$idChauffeur/$date/$filtre/$token';
}

/// Endpoints opérations de chargement / enlèvement Ypsium
abstract class YpsiumOperationEndpoints {
  /// POST - Ajouter un colis au chargement
  static String addColisChargement(int idOrdre, String token) =>
      '/addColisChargement/$idOrdre/$token';

  /// POST - Photo au départ de l'enlèvement
  static String setPhotoEnlDepart(int idOrdre, String token) =>
      '/setPhotoEnlDepart/$idOrdre/$token';

  /// POST - Valider l'enlèvement
  static String setPointEnleve(int idOrdre, String token) =>
      '/setPointEnleve/$idOrdre/$token';

  /// POST - Photo à la livraison
  static String setPhotoLivDepart(int idOrdre, String token) =>
      '/setPhotoLivDepart/$idOrdre/$token';

  /// POST - Valider la livraison
  static String setPointLivre(int idOrdre, String token) =>
      '/setPointLivre/$idOrdre/$token';
}

/// Endpoints géolocalisation Ypsium
abstract class YpsiumGpsEndpoints {
  /// POST - Envoyer la position GPS (pas de token dans l'URL)
  static const String setPositionGPS = '/setPositionGPS';
}
