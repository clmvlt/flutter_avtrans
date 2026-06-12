import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/address_suggestion.dart';
import '../models/geo_point.dart';
import '../models/optimization_models.dart';
import '../models/routing_models.dart';
import '../models/tour_model.dart';
import '../models/tour_stop.dart';

/// Source de vérité des tournées « Circuit ».
///
/// Conserve les tournées en mémoire et les persiste sur disque à chaque
/// modification : elles survivent au redémarrage de l'app. Les adresses
/// ajoutées restent jusqu'à suppression explicite.
///
/// Expose un [ChangeNotifier] : les écrans s'y abonnent (via `ListenableBuilder`)
/// pour rester synchronisés (liste ↔ détail ↔ carte).
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

  // ─── Tournées ────────────────────────────────────────────

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

  Future<void> setDepot(String tourId, GeoPoint depot) async {
    final tour = tourById(tourId);
    if (tour == null) return;
    tour.depot = depot;
    notifyListeners();
    await _saveToDisk();
  }

  /// Bascule la tournée en mode livraison (validée) ou retour en édition.
  Future<void> setStatus(String tourId, TourStatus status) async {
    final tour = tourById(tourId);
    if (tour == null || tour.status == status) return;
    tour.status = status;
    notifyListeners();
    await _saveToDisk();
  }

  // ─── Arrêts ──────────────────────────────────────────────

  Future<void> addStop(String tourId, AddressSuggestion address) async {
    final tour = tourById(tourId);
    if (tour == null) return;
    tour.stops.add(TourStop(id: TourStop.newId(), address: address));
    // L'ajout invalide l'ordre/tracé calculé précédemment.
    _clearRoute(tour);
    notifyListeners();
    await _saveToDisk();
  }

  Future<void> removeStopAt(String tourId, int index) async {
    final tour = tourById(tourId);
    if (tour == null) return;
    if (index < 0 || index >= tour.stops.length) return;
    tour.stops.removeAt(index);
    _clearRoute(tour);
    notifyListeners();
    await _saveToDisk();
  }

  /// Réordonne un arrêt (glisser-déposer). Invalide le tracé jusqu'au recalcul.
  Future<void> reorderStops(String tourId, int oldIndex, int newIndex) async {
    final tour = tourById(tourId);
    if (tour == null) return;
    if (oldIndex < 0 || oldIndex >= tour.stops.length) return;
    // Ajustement standard de ReorderableListView.
    if (newIndex > oldIndex) newIndex -= 1;
    final stop = tour.stops.removeAt(oldIndex);
    tour.stops.insert(newIndex.clamp(0, tour.stops.length), stop);
    _clearRoute(tour);
    notifyListeners();
    await _saveToDisk();
  }

  // ─── Optimisation / itinéraire ───────────────────────────

  /// Applique le résultat d'une optimisation : réordonne les arrêts selon
  /// l'ordre optimal, renseigne cumuls/horaires, marque les arrêts écartés, et
  /// stocke le tracé complet + totaux.
  Future<void> applyOptimization(
    String tourId,
    GeoPoint depot,
    OptimizeResult result,
  ) async {
    final tour = tourById(tourId);
    if (tour == null) return;

    final route = result.primaryRoute;
    final byId = {for (final s in tour.stops) s.id: s};
    final skippedById = {for (final sv in result.skippedVisits) sv.visitId: sv};
    final ordered = <TourStop>[];

    // Arrêts routés, dans l'ordre optimal.
    if (route != null) {
      for (final os in route.stops) {
        final stop = byId.remove(os.visitId);
        if (stop == null) continue;
        stop
          ..cumulativeDistanceMeters = os.cumulativeDistanceMeters
          ..cumulativeDrivingSeconds = os.cumulativeDrivingSeconds
          ..arrivalTime = os.arrivalTime
          ..skipped = false
          ..skipReason = null;
        ordered.add(stop);
      }
    }

    // Arrêts restants (écartés ou non retournés) : conservés, flaggés.
    for (final stop in byId.values) {
      stop.clearRouting();
      final sv = skippedById[stop.id];
      if (sv != null) {
        stop.skipped = true;
        stop.skipReason = sv.reason;
      }
      ordered.add(stop);
    }

    tour.stops
      ..clear()
      ..addAll(ordered);
    tour.depot = depot;
    tour.totalDistanceMeters = result.totalDistanceMeters;
    tour.totalDrivingSeconds = result.totalDrivingTimeSeconds;
    tour.routeGeometry = route?.geometry ?? [];
    tour.optimized = true;

    notifyListeners();
    await _saveToDisk();
  }

  /// Applique un itinéraire recalculé après ajustement manuel (ordre conservé) :
  /// met à jour le tracé et les totaux, sans cumuls par arrêt.
  Future<void> applyManualRoute(String tourId, RouteResult route) async {
    final tour = tourById(tourId);
    if (tour == null) return;
    tour.totalDistanceMeters = route.distanceMeters;
    tour.totalDrivingSeconds = route.durationSeconds;
    tour.routeGeometry = route.geometry;
    tour.optimized = false;
    notifyListeners();
    await _saveToDisk();
  }

  void _clearRoute(Tour tour) {
    tour.optimized = false;
    tour.totalDistanceMeters = null;
    tour.totalDrivingSeconds = null;
    tour.routeGeometry = [];
    for (final stop in tour.stops) {
      stop.clearRouting();
    }
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
