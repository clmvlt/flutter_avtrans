import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/errors/exceptions.dart';
import '../models/ypsium_spooler_entry.dart';
import 'ypsium_http_service.dart';

/// Service de spooler pour les requêtes Ypsium.
///
/// Toutes les requêtes d'écriture sont mises en file d'attente (FIFO),
/// exécutées dans l'ordre. En cas d'erreur, le traitement s'arrête
/// et reprend automatiquement toutes les 30 secondes.
class YpsiumSpoolerService extends ChangeNotifier {
  final YpsiumHttpService _httpService;
  final List<YpsiumSpoolerEntry> _entries = [];
  Timer? _retryTimer;
  bool _isProcessing = false;

  List<YpsiumSpoolerEntry> get entries => List.unmodifiable(_entries);
  int get pendingCount =>
      _entries.where((e) => e.status != SpoolerEntryStatus.sending).length;
  bool get isProcessing => _isProcessing;
  bool get isEmpty => _entries.isEmpty;
  bool get hasEntries => _entries.isNotEmpty;

  YpsiumSpoolerService({required YpsiumHttpService httpService})
      : _httpService = httpService;

  /// Charge le spooler depuis le fichier persisté
  Future<void> init() async {
    await _loadFromDisk();
    // Remettre les entrées "sending" en "pending" (crash recovery)
    for (final entry in _entries) {
      if (entry.status == SpoolerEntryStatus.sending) {
        entry.status = SpoolerEntryStatus.pending;
      }
    }
    await _saveToDisk();
    _startRetryTimer();
    // Tenter d'envoyer immédiatement
    unawaited(processQueue());
  }

  /// Ajoute une requête au spooler et lance le traitement
  Future<void> enqueue({
    required String method,
    required String endpoint,
    Map<String, dynamic>? body,
    required String label,
  }) async {
    final entry = YpsiumSpoolerEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      method: method,
      endpoint: endpoint,
      body: body,
      label: label,
      createdAt: DateTime.now(),
    );
    _entries.add(entry);
    notifyListeners();
    await _saveToDisk();
    unawaited(processQueue());
  }

  /// Traite la file d'attente séquentiellement.
  /// S'arrête à la première erreur.
  Future<void> processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;
    notifyListeners();

    while (_entries.isNotEmpty) {
      final entry = _entries.first;
      if (entry.status == SpoolerEntryStatus.sending) break;

      entry.status = SpoolerEntryStatus.sending;
      entry.lastError = null;
      notifyListeners();

      try {
        if (entry.method == 'POST') {
          await _httpService.post(entry.endpoint, body: entry.body);
        } else {
          await _httpService.get(entry.endpoint);
        }

        // Succès : retirer de la queue
        _entries.remove(entry);
        notifyListeners();
        await _saveToDisk();
      } on NetworkException catch (e) {
        entry.status = SpoolerEntryStatus.failed;
        entry.lastError = e.message;
        entry.retryCount++;
        notifyListeners();
        await _saveToDisk();
        break; // Arrêt — on réessaiera plus tard
      } on ServerException catch (e) {
        entry.status = SpoolerEntryStatus.failed;
        entry.lastError = e.message;
        entry.retryCount++;
        notifyListeners();
        await _saveToDisk();
        break;
      } catch (e) {
        entry.status = SpoolerEntryStatus.failed;
        entry.lastError = e.toString();
        entry.retryCount++;
        notifyListeners();
        await _saveToDisk();
        break;
      }
    }

    _isProcessing = false;
    notifyListeners();
  }

  /// Relance manuellement le traitement de la queue
  Future<void> retryAll() async {
    // Remettre toutes les entrées failed en pending
    for (final entry in _entries) {
      if (entry.status == SpoolerEntryStatus.failed) {
        entry.status = SpoolerEntryStatus.pending;
      }
    }
    notifyListeners();
    await _saveToDisk();
    await processQueue();
  }

  /// Supprime une entrée spécifique
  Future<void> removeEntry(String id) async {
    _entries.removeWhere((e) => e.id == id);
    notifyListeners();
    await _saveToDisk();
  }

  /// Vide tout le spooler
  Future<void> clearAll() async {
    _entries.clear();
    notifyListeners();
    await _saveToDisk();
  }

  // ─── Timer de retry automatique ──────────────────────────

  void _startRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_entries.isNotEmpty && !_isProcessing) {
        // Remettre les failed en pending avant de réessayer
        for (final entry in _entries) {
          if (entry.status == SpoolerEntryStatus.failed) {
            entry.status = SpoolerEntryStatus.pending;
          }
        }
        processQueue();
      }
    });
  }

  // ─── Persistence sur disque ──────────────────────────────

  Future<File> get _file async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/ypsium_spooler.json');
  }

  Future<void> _saveToDisk() async {
    try {
      final file = await _file;
      await file.writeAsString(YpsiumSpoolerEntry.encodeList(_entries));
    } catch (e) {
      debugPrint('[YpsiumSpooler] Erreur sauvegarde: $e');
    }
  }

  Future<void> _loadFromDisk() async {
    try {
      final file = await _file;
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          _entries.addAll(YpsiumSpoolerEntry.decodeList(content));
        }
      }
    } catch (e) {
      debugPrint('[YpsiumSpooler] Erreur chargement: $e');
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }
}
