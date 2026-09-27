import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/display_format.dart';
import '../../../../data/models/models.dart';
import '../../../widgets/widgets.dart';
import 'absence_visuals.dart';
import 'request_blocks.dart';

/// Action choisie dans le détail d'une absence.
enum AbsenceDetailAction { cancel }

/// Détail d'une demande d'absence : statut, récapitulatif, motif, motif du
/// refus, et « Annuler la demande » tant qu'elle est en attente.
abstract final class AbsenceDetailSheet {
  static Future<AbsenceDetailAction?> show(
    BuildContext context,
    Absence absence,
  ) {
    return AppSheet.show<AbsenceDetailAction>(
      context,
      title: absence.typeName,
      builder: (ctx) => _Body(
        absence: absence,
        onCancel: () => Navigator.of(ctx).pop(AbsenceDetailAction.cancel),
      ),
    );
  }
}

/// Récapitulatif type + dates, repris dans la confirmation d'annulation.
class AbsenceRecap extends StatelessWidget {
  const AbsenceRecap({super.key, required this.absence, this.full = false});

  final Absence absence;

  /// Détail complet (du, au, durée, période) ou résumé (type, dates).
  final bool full;

  @override
  Widget build(BuildContext context) {
    final a = absence;
    if (!full) {
      return AppRecapBox(
        rows: [
          AppRecapRow(
            icon: Icons.category_rounded,
            label: 'Type',
            value: a.typeName,
          ),
          AppRecapRow(
            icon: Icons.event_rounded,
            label: 'Dates',
            value: absenceDateRange(a),
          ),
        ],
      );
    }
    return AppRecapBox(
      rows: [
        AppRecapRow(
          icon: Icons.play_arrow_rounded,
          label: 'Du',
          value: DisplayFormat.date(a.startDate),
        ),
        AppRecapRow(
          icon: Icons.stop_rounded,
          label: 'Au',
          value: DisplayFormat.date(a.endDate),
        ),
        AppRecapRow(
          icon: Icons.wb_twilight_rounded,
          label: 'Période',
          value: a.period.label,
        ),
        AppRecapRow(
          icon: Icons.schedule_rounded,
          label: 'Durée',
          value: absenceDuration(a),
          emphasized: true,
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.absence, required this.onCancel});

  final Absence absence;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final a = absence;
    final rejection = a.rejectionReason;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: AbsenceStatusChip(status: a.status),
        ),
        const SizedBox(height: AppSpacing.base),
        AbsenceRecap(absence: a, full: true),
        if (a.reason.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          NoteBlock(label: 'Motif', text: a.reason),
        ],
        if (rejection != null && rejection.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          NoteBlock(
            label: 'Motif du refus',
            text: rejection,
            icon: Icons.info_outline_rounded,
            iconColor: colors.destructive,
          ),
        ],
        if (a.canBeCancelled) ...[
          const SizedBox(height: AppSpacing.lg),
          SheetDangerAction(
            label: 'Annuler la demande',
            icon: Icons.close_rounded,
            hint: 'Possible tant que la demande est en attente.',
            onPressed: onCancel,
          ),
        ],
      ],
    );
  }
}
