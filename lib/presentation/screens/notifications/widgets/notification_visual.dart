import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Icône et accent d'un type de notification (`refType` de l'API), repris
/// par la liste des notifications et par leurs préférences.
(IconData, Color) notificationVisual(String? refType, AppColors colors) {
  return switch (refType) {
    'acompte' => (Icons.payments_rounded, colors.domainAcompte),
    'absence' => (Icons.event_busy_rounded, colors.domainAbsence),
    'rapportVehicule' => (Icons.description_rounded, colors.domainVehicule),
    'todo' => (Icons.checklist_rounded, colors.success),
    'userCreated' => (Icons.person_add_rounded, colors.primary),
    _ => (Icons.notifications_rounded, colors.primary),
  };
}
