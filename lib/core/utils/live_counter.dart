import 'dart:async';

import 'package:flutter/foundation.dart';

/// Compteurs en direct : l'API donne une valeur (`duree`, `dureeTravail`,
/// `secondes`…) et dit si elle avance ; l'app la fait seulement avancer
/// entre deux appels.
///
/// Une seule règle :
///
/// ```
/// à la réception d'une réponse : démarrer un Stopwatch (horloge monotone)
/// valeur affichée = base + (avance ? stopwatch.elapsed.inSeconds : 0)
/// ```
///
/// L'horloge du téléphone n'intervient jamais : elle peut être décalée ou
/// changer en cours de route. `calculeLe` ne sert qu'à l'affichage.
abstract final class LiveClock {
  static final Stopwatch _stopwatch = Stopwatch()..start();
  static Duration Function() _source = _defaultSource;

  static Duration _defaultSource() => _stopwatch.elapsed;

  /// Temps monotone écoulé depuis le lancement de l'app.
  static Duration get elapsed => _source();

  /// Remplace l'horloge monotone (tests) ; `null` rétablit le Stopwatch.
  @visibleForTesting
  static set debugSource(Duration Function()? source) =>
      _source = source ?? _defaultSource;
}

/// Instant de réception d'une réponse, sur l'horloge monotone.
///
/// Toutes les valeurs d'une même réponse partagent leur ancre.
@immutable
class LiveAnchor {
  /// Ancre posée maintenant (à la réception d'une réponse).
  LiveAnchor.now() : _start = LiveClock.elapsed;

  /// Ancre figée : rien n'avance (valeurs construites à la main).
  const LiveAnchor.frozen() : _start = null;

  final Duration? _start;

  /// Temps écoulé depuis la réception, jamais négatif.
  Duration get elapsed {
    final start = _start;
    if (start == null) return Duration.zero;
    final d = LiveClock.elapsed - start;
    return d.isNegative ? Duration.zero : d;
  }
}

/// Valeur de l'API qui avance d'une seconde par seconde quand [running].
@immutable
class LiveCounter {
  const LiveCounter(
    this.base, {
    this.running = false,
    this.anchor = const LiveAnchor.frozen(),
  });

  /// Valeur figée.
  const LiveCounter.fixed(this.base)
      : running = false,
        anchor = const LiveAnchor.frozen();

  static const LiveCounter zero = LiveCounter.fixed(Duration.zero);

  /// Valeur reçue de l'API.
  final Duration base;

  /// La valeur avance (service ou pause en cours).
  final bool running;
  final LiveAnchor anchor;

  /// Valeur à afficher maintenant, à la seconde.
  Duration get value {
    if (!running) return base;
    return base + Duration(seconds: anchor.elapsed.inSeconds);
  }
}

/// Horloge d'affichage partagée : notifie une fois par seconde, et ne tourne
/// que tant qu'au moins un compteur en direct l'écoute.
class LiveTicker extends ChangeNotifier {
  LiveTicker._();

  static final LiveTicker instance = LiveTicker._();

  Timer? _timer;
  int _listeners = 0;

  /// Le ticker tourne (au moins un écouteur).
  bool get isRunning => _timer != null;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    if (_listeners++ == 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        notifyListeners();
      });
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (_listeners > 0 && --_listeners == 0) {
      _timer?.cancel();
      _timer = null;
    }
  }
}
