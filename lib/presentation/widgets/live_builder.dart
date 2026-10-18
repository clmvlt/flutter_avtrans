import 'package:flutter/widgets.dart';

import '../../core/utils/live_counter.dart';

/// Reconstruit [builder] chaque seconde tant que [running] (au moins un
/// compteur de la zone avance), sinon une seule fois : rien ne tique quand
/// rien ne bouge.
///
/// [clock] par défaut : [LiveTicker.instance]. La page Pointage passe
/// l'horloge de son contrôleur.
class LiveBuilder extends StatelessWidget {
  const LiveBuilder({
    super.key,
    required this.running,
    required this.builder,
    this.clock,
  });

  final bool running;
  final WidgetBuilder builder;
  final Listenable? clock;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: running ? (clock ?? LiveTicker.instance) : const _Silent(),
      builder: (context, _) => builder(context),
    );
  }
}

/// Horloge qui ne notifie jamais.
class _Silent implements Listenable {
  const _Silent();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}
