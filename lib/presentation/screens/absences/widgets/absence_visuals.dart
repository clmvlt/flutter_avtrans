import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/display_format.dart';
import '../../../../data/models/models.dart';
import '../../../widgets/widgets.dart';

/// Libellé, teinte et icône d'un statut d'absence : un état = icône + mot.
({String label, Color color, IconData icon}) absenceStatusVisual(
  AbsenceStatus status,
  AppColors colors,
) {
  return switch (status) {
    AbsenceStatus.pending => (
        label: status.displayName,
        color: colors.warning,
        icon: Icons.hourglass_top_rounded,
      ),
    AbsenceStatus.approved => (
        label: status.displayName,
        color: colors.success,
        icon: Icons.check_circle_rounded,
      ),
    AbsenceStatus.rejected => (
        label: status.displayName,
        color: colors.destructive,
        icon: Icons.cancel_rounded,
      ),
  };
}

/// Pastille de statut d'une absence.
class AbsenceStatusChip extends StatelessWidget {
  const AbsenceStatusChip({super.key, required this.status});

  final AbsenceStatus status;

  @override
  Widget build(BuildContext context) {
    final v = absenceStatusVisual(status, context.colors);
    return AppStatusChip(label: v.label, color: v.color, icon: v.icon);
  }
}

/// Couleur d'un type d'absence (donnée API `#RRGGBB`) ; type personnalisé ou
/// couleur illisible → accent du domaine Absences.
Color absenceTypeColor(String? hex, AppColors colors) {
  if (hex == null) return colors.domainAbsence;
  try {
    if (hex.startsWith('#')) {
      return Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);
    }
    return colors.domainAbsence;
  } catch (_) {
    return colors.domainAbsence;
  }
}

/// « 12 mars » ou « 12 mars → 14 mars ».
String absenceDateRange(Absence a) {
  final sameDay = DateUtils.isSameDay(a.startDate, a.endDate);
  if (sameDay) return DisplayFormat.dateSmart(a.startDate);
  return '${DisplayFormat.dateSmart(a.startDate)} → '
      '${DisplayFormat.dateSmart(a.endDate)}';
}

/// « 3 jours ».
String absenceDuration(Absence a) =>
    DisplayFormat.plural(a.durationInDays, 'jour');

/// Sous-ligne d'une absence : dates · durée · demi-journée.
String absenceSummary(Absence a) => [
      absenceDateRange(a),
      absenceDuration(a),
      if (a.period.isHalfDay) a.period.label,
    ].join(' · ');

/// Ligne d'une absence : type (icône à sa couleur), dates, statut.
class AbsenceRow extends StatelessWidget {
  const AbsenceRow({
    super.key,
    required this.absence,
    required this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadius.md)),
  });

  final Absence absence;
  final VoidCallback onTap;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final summary = absenceSummary(absence);
    return AppListRow(
      icon: Icons.event_busy_rounded,
      iconColor: absenceTypeColor(absence.typeColor, colors),
      title: absence.typeName,
      subtitle: summary,
      trailing: AbsenceStatusChip(status: absence.status),
      onTap: onTap,
      borderRadius: borderRadius,
      semanticsLabel:
          '${absence.typeName}. $summary. ${absence.status.displayName}',
    );
  }
}
