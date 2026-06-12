/// Configuration de l'API ORS (geocoding d'adresses).
///
/// API publique — toutes les routes sont accessibles sans authentification.
/// Sert à transformer un texte libre (saisi ou scanné) en adresse normalisée
/// avec ses coordonnées GPS.
abstract class OrsApiConstants {
  static const String baseUrl = 'https://ors.stack.bzh';

  static const int connectionTimeout = 20;

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
}
