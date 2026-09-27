import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/display_format.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../data/models/models.dart';
import '../../../widgets/widgets.dart';

/// Libellé, teinte et icône d'un statut d'acompte : un état = icône + mot.
({String label, Color color, IconData icon}) acompteStatusVisual(
  AcompteStatus status,
  AppColors colors,
) {
  return switch (status) {
    AcompteStatus.pending => (
        label: status.label,
        color: colors.warning,
        icon: Icons.hourglass_top_rounded,
      ),
    AcompteStatus.approved => (
        label: status.label,
        color: colors.success,
        icon: Icons.check_circle_rounded,
      ),
    AcompteStatus.rejected => (
        label: status.label,
        color: colors.destructive,
        icon: Icons.cancel_rounded,
      ),
  };
}

/// Pastille de statut d'un acompte.
class AcompteStatusChip extends StatelessWidget {
  const AcompteStatusChip({super.key, required this.status});

  final AcompteStatus status;

  @override
  Widget build(BuildContext context) {
    final v = acompteStatusVisual(status, context.colors);
    return AppStatusChip(label: v.label, color: v.color, icon: v.icon);
  }
}

/// « 12 mars 2025 à 14:30 ».
String acompteDateTime(DateTime d) =>
    '${DisplayFormat.date(d)} à ${TimeFormat.hm(d)}';

/// Sous-ligne d'un acompte : date de demande, et « Payé » s'il l'est.
String acompteSummary(Acompte a) {
  final created = a.createdAt;
  final when = created != null
      ? 'Demandé le ${DisplayFormat.dateSmart(created)} à ${TimeFormat.hm(created)}'
      : 'Date non disponible';
  return a.isPaid ? '$when · Payé' : when;
}

/// Ligne d'un acompte : montant, date de demande, statut.
class AcompteRow extends StatelessWidget {
  const AcompteRow({
    super.key,
    required this.acompte,
    required this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadius.md)),
  });

  final Acompte acompte;
  final VoidCallback onTap;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final amount = DisplayFormat.euros(acompte.montant);
    final summary = acompteSummary(acompte);

    return AppListRow(
      icon: acompte.isPaid ? Icons.paid_rounded : Icons.euro_rounded,
      iconColor: colors.domainAcompte,
      title: amount,
      titleStyle: textTheme.titleSmall?.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      subtitle: summary,
      trailing: AcompteStatusChip(status: acompte.status),
      onTap: onTap,
      borderRadius: borderRadius,
      semanticsLabel: '$amount. $summary. ${acompte.status.label}',
    );
  }
}
