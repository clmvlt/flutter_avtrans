import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/address_suggestion.dart';
import '../models/tour_model.dart';

/// Source de vérité des tournées « Circuit ».
///
/// Conserve les tournées en mémoire et les persiste sur disque à chaque
/// modification : elles survivent au redémarrage de l'app. Les adresses
/// ajoutées restent jusqu'à suppression explicite.
///
/// Expose un [ChangeNotifier] : les écrans s'y abonnent (via `ListenableBuilder`)
/// pour rester synchronisés (liste ↔ détail).
class TourService extends ChangeNotifier {
  final List<Tour> _tours = [];

  /// Tournées, de la plus récente à la plus ancienne.
  List<Tour> get tours {
    final sorted = [..._tours]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(sorted);
  }

  bool get isEmpty => _tours.isEmpty;

  /// Charge les tournées persistées. À appeler au démarrage.
  Future<void> init() async {
    await _loadFromDisk();
    notifyListeners();
  }

  Tour? tourById(String id) {
    for (final tour in _tours) {
      if (tour.id == id) return tour;
    }
    return null;
  }

  /// Crée une tournée et la renvoie. Un nom vide reçoit une valeur par défaut.
  Future<Tour> createTour(String name) async {
    final now = DateTime.now();
    final cleaned = name.trim();
    final tour = Tour(
      id: now.microsecondsSinceEpoch.toString(),
      name: cleaned.isEmpty ? _defaultName(now) : cleaned,
      createdAt: now,
    );
    _tours.add(tour);
    notifyListeners();
    await _saveToDisk();
    return tour;
  }

  Future<void> renameTour(String id, String name) async {
    final tour = tourById(id);
    if (tour == null) return;
    final cleaned = name.trim();
    if (cleaned.isEmpty) return;
    tour.name = cleaned;
    notifyListeners();
    await _saveToDisk();
  }

  Future<void> deleteTour(String id) async {
    _tours.removeWhere((t) => t.id == id);
    notifyListeners();
    await _saveToDisk();
  }

  Future<void> addStop(String tourId, AddressSuggestion stop) async {
    final tour = tourById(tourId);
    if (tour == null) return;
    tour.stops.add(stop);
    notifyListeners();
    await _saveToDisk();
  }

  Future<void> removeStopAt(String tourId, int index) async {
    final tour = tourById(tourId);
    if (tour == null) return;
    if (index < 0 || index >= tour.stops.length) return;
    tour.stops.removeAt(index);
    notifyListeners();
    await _saveToDisk();
  }

  String _defaultName(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return 'Tournée du $d/$m';
  }

  // ─── Persistance sur disque ──────────────────────────────

  Future<File> get _file async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/circuit_tours.json');
  }

  Future<void> _saveToDisk() async {
    try {
      final file = await _file;
      await file.writeAsString(Tour.encodeList(_tours));
    } catch (e) {
      debugPrint('[TourService] Erreur sauvegarde: $e');
    }
  }

  Future<void> _loadFromDisk() async {
    try {
      final file = await _file;
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          _tours
            ..clear()
            ..addAll(Tour.decodeList(content));
        }
      }
    } catch (e) {
      debugPrint('[TourService] Erreur chargement: $e');
    }
  }
}
