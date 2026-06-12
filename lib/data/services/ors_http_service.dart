import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/constants/ors_api_constants.dart';
import '../../core/errors/exceptions.dart';

/// Service HTTP dédié à l'API publique ORS (geocoding).
///
/// Aucune authentification : les routes sont publiques. Le seul cas d'erreur
/// métier spécifique est le `503` (« index d'adresses indisponible »).
class OrsHttpService {
  final http.Client _client;
  final String _baseUrl;

  OrsHttpService({
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? OrsApiConstants.baseUrl;

  /// Effectue une requête GET et renvoie le corps JSON décodé.
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParameters,
  }) async {
    final uri = Uri.parse('$_baseUrl$endpoint').replace(
      queryParameters: queryParameters,
    );

    return _execute(
      () => _client
          .get(uri, headers: OrsApiConstants.defaultHeaders)
          .timeout(const Duration(seconds: OrsApiConstants.connectionTimeout)),
    );
  }

  /// Effectue une requête POST (corps JSON) et renvoie le corps JSON décodé.
  Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    final headers = {
      ...OrsApiConstants.defaultHeaders,
      'Content-Type': 'application/json',
    };

    return _execute(
      () => _client
          .post(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          // L'optimisation peut prendre plusieurs secondes (solveur Timefold).
          .timeout(const Duration(seconds: OrsApiConstants.requestTimeout)),
    );
  }

  Future<dynamic> _execute(Future<http.Response> Function() request) async {
    try {
      final response = await request();
      return _handleResponse(response);
    } on SocketException {
      throw const NetworkException(
        message: 'Impossible de joindre le service d\'adresses.',
      );
    } on TimeoutException {
      throw const NetworkException(
        message: 'Le service d\'adresses ne répond pas. Veuillez réessayer.',
      );
    } on http.ClientException {
      throw const NetworkException(
        message: 'Connexion interrompue avec le service d\'adresses.',
      );
    } on FormatException {
      throw const ServerException(
        message: 'Réponse invalide du service d\'adresses.',
      );
    }
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode == 200) {
      if (response.body.isEmpty) return const [];
      return jsonDecode(response.body);
    }

    if (response.statusCode == 503) {
      throw const ServerException(
        message: 'Service d\'adresses momentanément indisponible.',
        statusCode: 503,
      );
    }

    throw ServerException(
      message: 'Erreur du service d\'adresses (${response.statusCode}).',
      statusCode: response.statusCode,
    );
  }

  void dispose() {
    _client.close();
  }
}
