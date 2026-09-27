import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/display_format.dart';
import '../../../widgets/widgets.dart';
import '../logic/fleet_status.dart';

/// Choix fait dans la feuille « Entretien fait ? ».
enum EcheanceDoneChoice {
  /// Enregistrer tout de suite (aujourd'hui, dernier kilométrage connu).
  now,

  /// Ouvrir le formulaire prérempli (coût, fichiers, autre date…).
  details,
}

/// « Vidange faite ? » : enregistre l'entretien d'une échéance en un geste,
/// ou ouvre le formulaire prérempli. Sans kilométrage connu pour le
/// véhicule, seule la saisie détaillée est proposée (jamais d'entretien à
/// 0 km).
abstract final class EcheanceDoneSheet {
  static Future<EcheanceDoneChoice?> show(
    BuildContext context, {
    required FleetAlert alert,
    required int? latestKm,
  }) {
    return AppSheet.show<EcheanceDoneChoice>(
      context,
      title: 'Entretien fait ?',
      builder: (ctx) => _Body(alert: alert, latestKm: latestKm),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.alert, required this.latestKm});

  final FleetAlert alert;
  final int? latestKm;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final canQuickSave = latestKm != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          canQuickSave
              ? 'Enregistre « ${alert.typeLabel} » à la date du jour, avec le '
                  'dernier kilométrage relevé. La prochaine échéance sera '
                  'recalculée.'
              : 'Aucun kilométrage n\'est connu pour ce véhicule : complète '
                  'la saisie pour enregistrer « ${alert.typeLabel} ».',
          style: textTheme.bodyMedium?.copyWith(color: colors.mutedForeground),
        ),
        const SizedBox(height: AppSpacing.base),
        AppRecapBox(
          rows: [
            AppRecapRow(
              icon: Icons.build_rounded,
              label: 'Entretien',
              value: alert.typeLabel,
            ),
            AppRecapRow(
              icon: Icons.event_rounded,
              label: 'Date',
              value: 'Aujourd\'hui',
            ),
            AppRecapRow(
              icon: Icons.speed_rounded,
              label: 'Kilométrage',
              value: canQuickSave ? DisplayFormat.km(latestKm!) : 'à saisir',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (canQuickSave) ...[
          AppButton(
            text: 'Enregistrer maintenant',
            icon: Icons.check_rounded,
            size: ButtonSize.lg,
            backgroundColor: colors.success,
            foregroundColor: colors.successForeground,
            onPressed: () =>
                Navigator.of(context).pop(EcheanceDoneChoice.now),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        AppButton(
          text: canQuickSave ? 'Ajouter des détails' : 'Compléter la saisie',
          icon: Icons.edit_note_rounded,
          size: ButtonSize.lg,
          variant: canQuickSave ? ButtonVariant.secondary : ButtonVariant.primary,
          onPressed: () =>
              Navigator.of(context).pop(EcheanceDoneChoice.details),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 52,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(foregroundColor: colors.foreground),
            child: const Text('Annuler'),
          ),
        ),
      ],
    );
  }
}
