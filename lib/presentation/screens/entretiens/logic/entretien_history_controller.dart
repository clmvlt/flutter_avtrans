import 'package:flutter/foundation.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../data/models/entretien_model.dart';

/// Historique paginé des entretiens (défilement infini), partagé par la page
/// Entretiens et la page d'un véhicule.
class EntretienHistoryController extends ChangeNotifier {
  EntretienHistoryController({String? vehiculeId})
      : _query = EntretienHistoryQuery(vehiculeId: vehiculeId);

  EntretienHistoryQuery _query;
  final List<Entretien> _items = [];
  int _total = 0;
  bool _hasMore = true;
  bool _loading = false;
  bool _loadingMore = false;
  bool _loaded = false;
  String? _error;
  String? _loadMoreError;

  /// Incrémenté à chaque rechargement : une réponse d'une ancienne requête
  /// (filtres changés entre-temps) est ignorée.
  int _generation = 0;

  EntretienHistoryQuery get query => _query;
  List<Entretien> get items => List.unmodifiable(_items);
  int get total => _total;
  bool get hasMore => _hasMore;
  bool get isLoading => _loading;
  bool get isLoadingMore => _loadingMore;

  /// Au moins une page a été reçue.
  bool get isLoaded => _loaded;
  String? get error => _error;

  /// Échec du chargement de la page suivante (la liste reste affichée).
  String? get loadMoreError => _loadMoreError;

  /// Remplace les filtres (page remise à 0) et recharge.
  Future<void> applyQuery(EntretienHistoryQuery query) {
    _query = query.withPage(0);
    return refresh();
  }

  /// Recharge depuis la première page.
  Future<void> refresh() async {
    final generation = ++_generation;
    _loading = true;
    _loadingMore = false;
    _error = null;
    _loadMoreError = null;
    notifyListeners();

    final result =
        await sl.entretienRepository.searchHistory(_query.withPage(0));
    if (generation != _generation) return;

    result.fold(
      (failure) => _error = failure.message,
      (page) {
        _items
          ..clear()
          ..addAll(page.content);
        _total = page.totalElements;
        _hasMore = !page.last && page.content.isNotEmpty;
        _query = _query.withPage(0);
        _loaded = true;
      },
    );
    _loading = false;
    notifyListeners();
  }

  /// Page suivante (sans effet si déjà en cours ou tout est chargé).
  Future<void> loadMore() async {
    if (_loading || _loadingMore || !_hasMore || !_loaded) return;
    final generation = _generation;
    _loadingMore = true;
    _loadMoreError = null;
    notifyListeners();

    final next = _query.withPage(_query.page + 1);
    final result = await sl.entretienRepository.searchHistory(next);
    if (generation != _generation) return;

    result.fold(
      (failure) => _loadMoreError = failure.message,
      (page) {
        final known = _items.map((e) => e.id).toSet();
        _items.addAll(page.content.where((e) => !known.contains(e.id)));
        _total = page.totalElements;
        _hasMore = !page.last && page.content.isNotEmpty;
        _query = next;
      },
    );
    _loadingMore = false;
    notifyListeners();
  }
}
