import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/navigation_launcher.dart';

/// Mémorise l'application de navigation GPS préférée (Google Maps, Waze…).
///
/// Persistée dans les SharedPreferences ; modifiable à tout moment. Expose un
/// [ChangeNotifier] pour que l'UI reflète le changement immédiatement.
class NavigationPreferenceService extends ChangeNotifier {
  static const String _prefKey = 'circuit_navigation_app';

  final SharedPreferences _prefs;
  NavigationApp _current;

  NavigationPreferenceService(this._prefs)
      : _current = NavigationAppX.fromKey(_prefs.getString(_prefKey));

  NavigationApp get current => _current;

  Future<void> setApp(NavigationApp app) async {
    if (app == _current) return;
    _current = app;
    notifyListeners();
    await _prefs.setString(_prefKey, app.key);
  }
}
