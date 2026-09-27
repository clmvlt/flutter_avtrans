import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../widgets/widgets.dart';

/// Échéance d'un véhicule (assurance, contrôle technique) : pastille
/// « Dans 12 j » à 30 jours ou moins, pastille rouge une fois dépassée.
/// Rien au-delà : le silence est la récompense.
abstract final class DeadlineChip {
  /// Seuil d'alerte, comme l'app web (`isExpiringSoon`).
  static const int warningDays = 30;

  /// Jours calendaires entre aujourd'hui et [date] (négatif si dépassé).
  static int daysUntil(DateTime date, DateTime now) {
    final d = date.toLocal();
    final n = now.toLocal();
    // En UTC pour ne pas perdre une heure aux changements d'heure.
    return DateTime.utc(d.year, d.month, d.day)
        .difference(DateTime.utc(n.year, n.month, n.day))
        .inDays;
  }

  /// Pastille à afficher pour [date], ou `null` si l'échéance est lointaine.
  static Widget? of(
    BuildContext context,
    DateTime date, {
    required DateTime now,
    required String overdueLabel,
  }) {
    final colors = context.colors;
    final days = daysUntil(date, now);
    if (days < 0) {
      return AppStatusChip(
        label: overdueLabel,
        color: colors.destructive,
        icon: Icons.error_rounded,
      );
    }
    if (days <= warningDays) {
      final label = switch (days) {
        0 => 'Aujourd\'hui',
        1 => 'Demain',
        _ => 'Dans $days j',
      };
      return AppStatusChip(
        label: label,
        color: colors.warning,
        icon: Icons.schedule_rounded,
      );
    }
    return null;
  }
}
