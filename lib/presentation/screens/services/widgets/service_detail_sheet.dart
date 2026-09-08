import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../data/models/service_model.dart';
import '../../../widgets/app_badge.dart';
import '../../../widgets/app_sheet.dart';
import '../../../widgets/section_list.dart';

/// Détail d'un pointage en lecture seule : début, fin, durée, position
/// enregistrée, saisie administrateur.
abstract final class ServiceDetailSheet {
  static Future<void> show(
    BuildContext context,
    Service service, {
    required DateTime now,
  }) {
    return AppSheet.show<void>(
      context,
      title: service.isBreak ? 'Pause' : 'Service',
      builder: (_) => _Body(service: service, now: now),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.service, required this.now});

  final Service service;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final s = service;
    final end = s.fin;
    final duration = end != null
        ? Duration(seconds: s.duree ?? end.difference(s.debut).inSeconds)
        : now.difference(s.debut);
    final hasPosition =
        s.latitude != null && s.longitude != null && s.latitude != 0;

    TextStyle? value() => textTheme.titleSmall?.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSection(
          children: [
            AppTile(
              icon: Icons.play_arrow_rounded,
              label: 'Début',
              color: colors.success,
              isFirst: true,
              trailing: Text(TimeFormat.hm(s.debut), style: value()),
            ),
            AppTile(
              icon: Icons.stop_rounded,
              label: 'Fin',
              color: colors.mutedForeground,
              trailing: Text(
                end != null ? TimeFormat.hm(end) : 'en cours',
                style: value(),
              ),
            ),
            AppTile(
              icon: Icons.schedule_rounded,
              label: 'Durée',
              color: colors.domainHours,
              trailing: Text(TimeFormat.durationShort(duration), style: value()),
            ),
            AppTile(
              icon: hasPosition
                  ? Icons.location_on_rounded
                  : Icons.location_off_rounded,
              label: 'Position enregistrée',
              color: hasPosition ? colors.success : colors.mutedForeground,
              isLast: true,
              trailing: Text(hasPosition ? 'Oui' : 'Non', style: value()),
            ),
          ],
        ),
        if (s.isAdmin) ...[
          const SizedBox(height: AppSpacing.md),
          const Align(
            alignment: Alignment.centerLeft,
            child: AppBadge(
              text: 'Saisi par un administrateur',
              variant: BadgeVariant.secondary,
              icon: Icons.admin_panel_settings_rounded,
            ),
          ),
        ],
      ],
    );
  }
}
