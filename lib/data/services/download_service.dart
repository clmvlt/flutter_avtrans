import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../core/constants/api_constants.dart';

/// Service pour télécharger des fichiers avec progression
class DownloadService {
  final http.Client _client;
  String? _authToken;

  DownloadService({http.Client? client}) : _client = client ?? http.Client();

  /// Définit le token d'authentification
  void setAuthToken(String? token) => _authToken = token;

  /// Télécharge un fichier avec suivi de progression
  ///
  /// [url] - URL complète ou endpoint relatif
  /// [fileName] - Nom du fichier de destination
  /// [onProgress] - Callback pour la progression (0.0 à 1.0)
  Future<File> downloadFile({
    required String url,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    final fullUrl =
        url.startsWith('http') ? url : '${ApiConstants.baseUrl}$url';

    final request = http.Request('GET', Uri.parse(fullUrl));
    if (_authToken != null) {
      request.headers['Authorization'] = 'Bearer $_authToken';
    }

    final response = await _client.send(request);

    if (response.statusCode != 200) {
      throw HttpException('Erreur de téléchargement: ${response.statusCode}');
    }

    final contentLength = response.contentLength ?? 0;
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    final sink = file.openWrite();

    int received = 0;
    await for (final chunk in response.stream) {
      sink.add(chunk);
      received += chunk.length;
      if (contentLength > 0 && onProgress != null) {
        onProgress(received / contentLength);
      }
    }

    await sink.close();
    return file;
  }

  /// Ferme le client HTTP
  void dispose() => _client.close();
}
