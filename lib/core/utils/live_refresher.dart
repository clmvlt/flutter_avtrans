import 'dart:async';

import 'package:flutter/widgets.dart';

/// Rechargements d'un écran à compteurs en direct :
/// - au retour au premier plan (les données ont pu changer, et le Stopwatch
///   n'avance pas forcément pendant la veille) ;
/// - au changement de jour (« Aujourd'hui » repart de zéro) ;
/// - toutes les [interval] tant que [isLive] (resynchronisation).
class LiveRefresher with WidgetsBindingObserver {
  LiveRefresher({
    required this.onRefresh,
    bool Function()? isLive,
    DateTime Function()? now,
    this.interval = const Duration(minutes: 5),
    this.observeLifecycle = true,
  })  : _isLive = isLive ?? _always,
        _now = now ?? DateTime.now;

  static bool _always() => true;

  /// Rechargement demandé.
  final Future<void> Function() onRefresh;

  /// Période de resynchronisation.
  final Duration interval;

  /// Écoute le retour au premier plan (sinon l'écran s'en charge).
  final bool observeLifecycle;

  final bool Function() _isLive;
  final DateTime Function() _now;

  Timer? _periodic;
  Timer? _midnight;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    if (observeLifecycle) WidgetsBinding.instance.addObserver(this);
    _periodic = Timer.periodic(interval, (_) {
      if (_isLive()) unawaited(onRefresh());
    });
    _armMidnight();
  }

  void _armMidnight() {
    _midnight?.cancel();
    final now = _now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    // Une seconde de marge : le serveur est déjà passé au jour suivant.
    final wait = tomorrow.difference(now) + const Duration(seconds: 1);
    _midnight = Timer(wait.isNegative ? Duration.zero : wait, () {
      unawaited(onRefresh());
      _armMidnight();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(onRefresh());
      // L'horloge a pu sauter pendant la veille.
      _armMidnight();
    }
  }

  void dispose() {
    if (!_started) return;
    _started = false;
    if (observeLifecycle) WidgetsBinding.instance.removeObserver(this);
    _periodic?.cancel();
    _midnight?.cancel();
    _periodic = null;
    _midnight = null;
  }
}
