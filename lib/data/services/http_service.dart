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

  /// Traite la réponse HTTP
  dynamic _handleResponse(http.Response response) {
    // 204 No Content - pas de body à parser
    if (response.statusCode == 204 || response.body.isEmpty) {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return <String, dynamic>{};
      }
    }

    final dynamic body;

    try {
      body = jsonDecode(response.body);
    } catch (_) {
      throw ServerException(
        message: 'Erreur de format de réponse du serveur.',
        statusCode: response.statusCode,
      );
    }

    switch (response.statusCode) {
      case 200:
      case 201:
      case 204:
        return body;
      case 400:
        final message = body is Map<String, dynamic>
            ? (body['message'] as String? ?? 'Requête invalide.')
            : 'Requête invalide.';
        throw ServerException(
          message: message,
          statusCode: 400,
        );
      case 401:
        final message = body is Map<String, dynamic>
            ? (body['message'] as String? ?? 'Non autorisé.')
            : 'Non autorisé.';
        throw UnauthorizedException(
          message: message,
        );
      case 403:
        final message = body is Map<String, dynamic>
            ? (body['message'] as String? ?? 'Accès refusé.')
            : 'Accès refusé.';
        throw AuthException(
          message: message,
          statusCode: 403,
        );
      case 404:
        final message = body is Map<String, dynamic>
            ? (body['message'] as String? ?? 'Ressource non trouvée.')
            : 'Ressource non trouvée.';
        throw ServerException(
          message: message,
          statusCode: 404,
        );
      case 422:
        final message = body is Map<String, dynamic>
            ? (body['message'] as String? ?? 'Erreur de validation.')
            : 'Erreur de validation.';
        throw ValidationException(
          message: message,
          statusCode: 422,
        );
      case 500:
      default:
        final message = body is Map<String, dynamic>
            ? (body['message'] as String? ?? 'Erreur serveur.')
            : 'Erreur serveur.';
        throw ServerException(
          message: message,
          statusCode: response.statusCode,
        );
    }
  }

  /// Ferme le client HTTP
  void dispose() {
    _client.close();
  }
}
