import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../data/models/models.dart';
import '../../../widgets/app_hero_card.dart';
import '../../services/widgets/pointage_status.dart';

/// Carte hero de l'Accueil : l'état du pointage, sur les règles de la carte
/// de la page Pointage. La carte reste sur `card` : l'état vit dans l'icône
/// (et le point pulsant), le mot d'état reste en `foreground`.
///
/// Tapable : ouvre l'onglet Pointage.
class HomePointageCard extends StatelessWidget {
  const HomePointageCard({
    super.key,
    required this.activeService,
    required this.hoursToday,
    required this.onTap,
  });

  /// Pointage ouvert (service ou pause), `null` hors service.
  final Service? activeService;

  /// Heures travaillées aujourd'hui (décimales de l'API).
  final double? hoursToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final s = activeService;
    final worked = hoursToday ?? 0;

    final (label, icon, accent, live) = switch (s) {
      null => (
          'Hors service',
          Icons.bedtime_outlined,
          colors.mutedForeground,
          false,
        ),
      Service(isBreak: true) => (
          'En pause',
          Icons.pause_circle_outline_rounded,
          colors.warning,
          true,
        ),
      Service() => ('En service', Icons.bolt_rounded, colors.success, true),
    };

    final subtitle = switch (s) {
      null => worked > 0
          ? 'Aucun service en cours'
          : 'Aucun pointage aujourd\'hui',
      Service(isBreak: true) => 'Pause depuis ${TimeFormat.hm(s.debut)}',
      Service() => 'Depuis ${TimeFormat.hm(s.debut)}',
    };

    final workedLabel = TimeFormat.hoursDecimal(hoursToday);

    return Semantics(
      button: true,
      label: 'Pointage : $label. $subtitle. '
          'Travaillé aujourd\'hui : $workedLabel',
      hint: 'Ouvre la page Pointage',
      onTap: onTap,
      excludeSemantics: true,
      child: AppHeroCard(
        icon: icon,
        accent: accent,
        title: label,
        subtitle: subtitle,
        onTap: onTap,
        trailing: live
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PulseDot(color: accent),
                  const SizedBox(width: AppSpacing.sm),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colors.mutedForeground,
                  ),
                ],
              )
            : null,
        child: AppHeroFigure(
          label: 'Travaillé aujourd\'hui',
          value: workedLabel,
          muted: worked <= 0,
        ),
      ),
    );
  }
}
