import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/constants/api_constants.dart';
import '../../core/errors/exceptions.dart';

/// Service HTTP générique pour les appels API
class HttpService {
  final http.Client _client;
  final String _baseUrl;
  String? _authToken;

  /// Callback déclenché sur un 401 d'authentification (token absent/invalide,
  /// compte inactif, aucun rôle). Le cas "rôle insuffisant" n'est PAS concerné :
  /// c'est un problème d'autorisation, il remonte en [AuthException].
  /// Contrat API §1.2 : un 401 doit déconnecter l'utilisateur et le renvoyer au login.
  void Function()? onUnauthorized;

  /// Préfixe du message serveur pour un rôle insuffisant (contrat API §1.2)
  static const String _insufficientRolePrefix = 'Access denied: Required role is';

  HttpService({
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConstants.baseUrl;

  /// Définit le token d'authentification
  void setAuthToken(String? token) {
    _authToken = token;
  }

  /// Récupère le token actuel
  String? get authToken => _authToken;

  /// Construit les headers avec authentification Bearer si disponible
  Map<String, String> _buildHeaders({Map<String, String>? additionalHeaders}) {
    final headers = Map<String, String>.from(ApiConstants.defaultHeaders);

    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }

    if (additionalHeaders != null) {
      headers.addAll(additionalHeaders);
    }

    return headers;
  }

  /// Effectue une requête GET
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
  }) async {
    final uri = _buildUri(endpoint, queryParameters);
    return _executeRequest(
      () => _client.get(uri, headers: _buildHeaders(additionalHeaders: headers)),
    );
  }

  /// Effectue une requête POST
  Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(endpoint);
    return _executeRequest(
      () => _client.post(
        uri,
        headers: _buildHeaders(additionalHeaders: headers),
        body: body != null ? jsonEncode(body) : null,
      ),
    );
  }

  /// Effectue une requête PUT
  Future<dynamic> put(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(endpoint);
    return _executeRequest(
      () => _client.put(
        uri,
        headers: _buildHeaders(additionalHeaders: headers),
        body: body != null ? jsonEncode(body) : null,
      ),
    );
  }

  /// Effectue une requête PATCH
  Future<dynamic> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(endpoint);
    return _executeRequest(
      () => _client.patch(
        uri,
        headers: _buildHeaders(additionalHeaders: headers),
        body: body != null ? jsonEncode(body) : null,
      ),
    );
  }

  /// Effectue une requête DELETE
  Future<dynamic> delete(
    String endpoint, {
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(endpoint);
    return _executeRequest(
      () => _client.delete(uri, headers: _buildHeaders(additionalHeaders: headers)),
    );
  }

  /// Construit l'URI avec les paramètres de requête
  Uri _buildUri(String endpoint, [Map<String, String>? queryParameters]) {
    final uri = Uri.parse('$_baseUrl$endpoint');
    if (queryParameters != null && queryParameters.isNotEmpty) {
      return uri.replace(queryParameters: queryParameters);
    }
    return uri;
  }

  /// Exécute une requête et gère les erreurs
  Future<dynamic> _executeRequest(
    Future<http.Response> Function() request,
  ) async {
    try {
      final response = await request().timeout(
        const Duration(seconds: ApiConstants.connectionTimeout),
      );

      return _handleResponse(response);
    } on SocketException {
      throw const NetworkException();
    } on TimeoutException {
      throw const NetworkException(
        message: 'La requête a expiré. Veuillez réessayer.',
      );
    } on FormatException {
      throw const ServerException(
        message: 'Erreur de format de réponse du serveur.',
      );
    }
  }

  /// Traite la réponse HTTP.
  ///
  /// Contrat API §1.4 : le corps d'erreur est `{"success": false, "message": "..."}`
  /// (plus `errors: string[]` sur un 400 "Validation error"). Certaines erreurs
  /// (404 `/auth/status/{id}`, 204 `DELETE /couchettes/{uuid}`) ont un corps vide.
  /// "Introuvable" est un 400 dans la majorité des routes : le client se base sur
  /// `message`, pas uniquement sur le code HTTP.
  dynamic _handleResponse(http.Response response) {
    final isSuccess = response.statusCode >= 200 && response.statusCode < 300;

    // 204 No Content ou corps vide en succès : rien à parser
    if (response.body.trim().isEmpty) {
      if (isSuccess) return <String, dynamic>{};
      _throwForStatus(response.statusCode, null);
    }

    final dynamic body;
    try {
      body = jsonDecode(response.body);
    } catch (_) {
      throw ServerException(
        message: isSuccess
            ? 'Erreur de format de réponse du serveur.'
            : _defaultMessageFor(response.statusCode),
        statusCode: response.statusCode,
      );
    }

    if (isSuccess) return body;

    _throwForStatus(
      response.statusCode,
      body is Map<String, dynamic> ? body : null,
    );
  }

  /// Message par défaut si le serveur n'en fournit pas
  String _defaultMessageFor(int statusCode) {
    switch (statusCode) {
      case 400:
        return 'Requête invalide.';
      case 401:
        return 'Session expirée. Veuillez vous reconnecter.';
      case 403:
        return 'Accès refusé.';
      case 404:
        return 'Ressource non trouvée.';
      default:
        return 'Erreur serveur.';
    }
  }

  /// Lève l'exception typée correspondant au code HTTP et au corps d'erreur
  Never _throwForStatus(int statusCode, Map<String, dynamic>? body) {
    final message = body?['message'] as String? ?? _defaultMessageFor(statusCode);

    switch (statusCode) {
      case 400:
        // Body @Valid invalide : { message: "Validation error", errors: ["champ: message"] }
        final rawErrors = body?['errors'];
        if (rawErrors is List && rawErrors.isNotEmpty) {
          final errors = <String, List<String>>{};
          for (final entry in rawErrors) {
            final text = entry.toString();
            final sep = text.indexOf(': ');
            final field = sep > 0 ? text.substring(0, sep) : '';
            final detail = sep > 0 ? text.substring(sep + 2) : text;
            errors.putIfAbsent(field, () => []).add(detail);
          }
          throw ValidationException(
            message: errors.values.expand((e) => e).join('\n'),
            errors: errors,
            statusCode: 400,
          );
        }
        throw ServerException(message: message, statusCode: 400);
      case 401:
        // Rôle insuffisant = autorisation, pas authentification : ne pas déconnecter
        if (message.startsWith(_insufficientRolePrefix)) {
          throw AuthException(message: message, statusCode: 401);
        }
        onUnauthorized?.call();
        throw UnauthorizedException(message: message);
      case 403:
        throw AuthException(message: message, statusCode: 403);
      case 404:
        throw ServerException(message: message, statusCode: 404);
      default:
        throw ServerException(message: message, statusCode: statusCode);
    }
  }

  /// Ferme le client HTTP
  void dispose() {
    _client.close();
  }
}
