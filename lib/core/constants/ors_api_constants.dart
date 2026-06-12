/// Configuration de l'API ORS (geocoding d'adresses).
///
/// API publique — toutes les routes sont accessibles sans authentification.
/// Sert à transformer un texte libre (saisi ou scanné) en adresse normalisée
/// avec ses coordonnées GPS.
abstract class OrsApiConstants {
  static const String baseUrl = 'https://ors.stack.bzh';

  static const int connectionTimeout = 20;

  /// Timeout des requêtes lourdes (optimisation : solveur ~5 s + matrice).
  static const int requestTimeout = 45;

  static const Map<String, String> defaultHeaders = {
    'Accept': 'application/json',
  };
}

/// Endpoints de l'API ORS.
abstract class OrsEndpoints {
  /// GET - Recherche plein texte avec autocomplétion.
  ///
  /// Paramètres : `q` (texte recherché), `limit` (1 à 50, défaut 10).
  /// Renvoie la liste des adresses les plus pertinentes, triées par score
  /// décroissant, avec leurs coordonnées GPS.
  static const String geocodingSearch = '/geocoding/search';

  /// GET - État de l'index d'adresses (`{ ready: bool }`).
  static const String geocodingStatus = '/geocoding/status';

  /// POST - Optimisation de tournée (VRP/TSP via Timefold).
  static const String optimize = '/optimization/optimize';

  /// GET - État du moteur de routing (`{ ready, profile }`).
  static const String routingStatus = '/routing/status';

  /// POST - Itinéraire point à point ou multi-points ordonné.
  static const String route = '/routing/route';

  /// POST - Matrice des temps de trajet (NxN).
  static const String matrix = '/routing/matrix';
}
