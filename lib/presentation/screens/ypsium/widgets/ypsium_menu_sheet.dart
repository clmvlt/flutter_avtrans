import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/display_format.dart';
import '../../../widgets/widgets.dart';

/// Choix de la feuille « Ypsium » de l'accueil.
enum YpsiumMenuAction { spooler, vehicule, logout }

/// Feuille des options Ypsium (remplace le menu « ⋮ ») : envois en attente,
/// choix du véhicule, déconnexion. Retourne le choix, `null` si fermée.
abstract final class YpsiumMenuSheet {
  static Future<YpsiumMenuAction?> show(
    BuildContext context, {
    required int pendingCount,
  }) {
    return AppSheet.show<YpsiumMenuAction>(
      context,
      title: 'Ypsium',
      builder: (ctx) => _MenuBody(pendingCount: pendingCount),
    );
  }
}

class _MenuBody extends StatelessWidget {
  const _MenuBody({required this.pendingCount});

  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasPending = pendingCount > 0;
    void choose(YpsiumMenuAction action) => Navigator.of(context).pop(action);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSection(
          children: [
            AppTile(
              icon: Icons.outbox_rounded,
              label: 'Envois en attente',
              subtitle: hasPending
                  ? '${DisplayFormat.plural(pendingCount, 'envoi')} à envoyer'
                  : 'Tout est envoyé',
              color: hasPending ? colors.warning : colors.success,
              badgeText: hasPending ? '$pendingCount' : null,
              badgeColor: colors.warning,
              isFirst: true,
              onTap: () => choose(YpsiumMenuAction.spooler),
            ),
            AppTile(
              icon: Icons.directions_car_rounded,
              label: 'Choix du véhicule',
              subtitle: 'Véhicule du jour et kilométrage',
              color: colors.domainVehicule,
              isLast: true,
              onTap: () => choose(YpsiumMenuAction.vehicule),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppSection(
          children: [
            AppTile(
              icon: Icons.logout_rounded,
              label: 'Se déconnecter d\'Ypsium',
              color: colors.destructive,
              isFirst: true,
              isLast: true,
              onTap: () => choose(YpsiumMenuAction.logout),
            ),
          ],
        ),
      ],
    );
  }
}
