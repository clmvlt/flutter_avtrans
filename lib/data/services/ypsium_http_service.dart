import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../../core/constants/ypsium_api_constants.dart';
import '../../core/errors/exceptions.dart';

/// Service HTTP dédié à l'API Ypsium
/// Utilise un HttpClient avec persistentConnection désactivé
/// car le serveur Ypsium utilise Connection: close
class YpsiumHttpService {
  final String _baseUrl;
  late final http.Client _client;

  YpsiumHttpService({
    http.Client? client,
    String? baseUrl,
  }) : _baseUrl = baseUrl ?? YpsiumApiConstants.baseUrl {
    if (client != null) {
      _client = client;
    } else {
      final httpClient = HttpClient();
      httpClient.idleTimeout = Duration.zero;
      httpClient.autoUncompress = true;
      _client = IOClient(httpClient);
    }
  }

  /// Effectue une requête GET
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
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
    final uri = Uri.parse('$_baseUrl$endpoint');
    return _executeRequest(
      () => _client.post(
        uri,
        headers: _buildHeaders(additionalHeaders: headers),
        body: body != null ? jsonEncode(body) : null,
      ),
    );
  }

  Map<String, String> _buildHeaders({Map<String, String>? additionalHeaders}) {
    final headers = Map<String, String>.from(YpsiumApiConstants.defaultHeaders);
    if (additionalHeaders != null) {
      headers.addAll(additionalHeaders);
    }
    return headers;
  }

  Future<dynamic> _executeRequest(
    Future<http.Response> Function() request,
  ) async {
    try {
      final response = await request().timeout(
        const Duration(seconds: YpsiumApiConstants.connectionTimeout),
      );
      return _handleResponse(response);
    } on SocketException {
      throw const NetworkException(
        message: 'Impossible de joindre le serveur Ypsium. Vérifiez votre connexion.',
      );
    } on TimeoutException {
      throw const NetworkException(
        message: 'Le serveur Ypsium ne répond pas. Veuillez réessayer.',
      );
    } on http.ClientException {
      throw const NetworkException(
        message: 'Connexion interrompue avec le serveur Ypsium. Veuillez réessayer.',
      );
    } on FormatException {
      throw const ServerException(
        message: 'Erreur de format de réponse du serveur Ypsium.',
      );
    }
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode == 200 || response.statusCode == 201) {
      if (response.body.isEmpty) return <String, dynamic>{};
      try {
        return jsonDecode(response.body);
      } catch (_) {
        throw const ServerException(
          message: 'Erreur de format de réponse du serveur Ypsium.',
        );
      }
    }

    throw ServerException(
      message: 'Erreur serveur Ypsium (${response.statusCode}).',
      statusCode: response.statusCode,
    );
  }

  void dispose() {
    _client.close();
  }
}
