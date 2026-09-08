import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/time_format.dart';

/// Chrono du jour en gros chiffres tabulaires (`5:12` + secondes discrètes).
///
/// Ne se reconstruit qu'au tic de [clock] (une fois par seconde quand un
/// pointage est ouvert), isolé dans un [RepaintBoundary] pour ne pas
/// repeindre le reste de la page.
class LiveTimer extends StatelessWidget {
  const LiveTimer({
    super.key,
    required this.clock,
    required this.duration,
    this.showSeconds = true,
    this.size = LiveTimerSize.large,
    this.color,
    this.alignment = Alignment.centerLeft,
    this.semanticsSuffix = 'travaillées aujourd\'hui',
    this.placeholder,
  });

  /// Texte affiché à la place de la durée (ex. `–:––` hors ligne).
  final String? placeholder;

  /// Horloge du contrôleur — déclenche les reconstructions.
  final ValueListenable<DateTime> clock;

  /// Durée à afficher, recalculée à chaque tic.
  final Duration Function() duration;

  /// Affiche les secondes (masquées hors service : rien ne bouge).
  final bool showSeconds;
  final LiveTimerSize size;
  final Color? color;
  final Alignment alignment;
  final String semanticsSuffix;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    final mainStyle = switch (size) {
      LiveTimerSize.large => textTheme.displayLarge,
      LiveTimerSize.medium => textTheme.displayMedium,
      LiveTimerSize.compact => textTheme.headlineMedium,
    }
        ?.copyWith(
      color: color ?? colors.foreground,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final secondsStyle = switch (size) {
      LiveTimerSize.large => textTheme.headlineSmall,
      LiveTimerSize.medium => textTheme.titleLarge,
      LiveTimerSize.compact => textTheme.titleMedium,
    }
        ?.copyWith(
      color: colors.mutedForeground,
      fontWeight: FontWeight.w600,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    if (placeholder != null) {
      return Semantics(
        label: 'Durée indisponible',
        excludeSemantics: true,
        child: Align(
          alignment: alignment,
          child: Text(placeholder!, style: mainStyle, maxLines: 1),
        ),
      );
    }

    return RepaintBoundary(
      child: ValueListenableBuilder<DateTime>(
        valueListenable: clock,
        builder: (context, _, __) {
          final d = duration();
          final h = d.inHours;
          final m = d.inMinutes.remainder(60);
          final s = d.inSeconds.remainder(60);

          return Semantics(
            label: '$h heures $m minutes $semanticsSuffix',
            excludeSemantics: true,
            child: Align(
              alignment: alignment,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: alignment,
                child: Text.rich(
                  TextSpan(
                    text: TimeFormat.clockHm(d),
                    style: mainStyle,
                    children: [
                      if (showSeconds)
                        TextSpan(
                          // Espace fine (U+2009) entre minutes et secondes.
                          text: '\u2009${s.toString().padLeft(2, '0')}',
                          style: secondsStyle,
                        ),
                    ],
                  ),
                  maxLines: 1,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Tailles du chrono.
enum LiveTimerSize {
  /// 52 sp — point focal de la page.
  large,

  /// 44 sp — carte récapitulative.
  medium,

  /// 26 sp — bandeau épinglé / ligne.
  compact,
}
