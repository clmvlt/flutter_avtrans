import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/display_format.dart';
import '../../../../data/models/models.dart';
import '../../../widgets/widgets.dart';
import '../../absences/widgets/request_blocks.dart';
import 'acompte_visuals.dart';

/// Action choisie dans le détail d'un acompte.
enum AcompteDetailAction { cancel }

/// Détail d'une demande d'acompte : statut, récapitulatif (demande,
/// validation, paiement, montant), raison, motif du refus, et « Annuler la
/// demande » tant qu'elle est en attente.
abstract final class AcompteDetailSheet {
  static Future<AcompteDetailAction?> show(
    BuildContext context,
    Acompte acompte,
  ) {
    return AppSheet.show<AcompteDetailAction>(
      context,
      title: 'Demande d\'acompte',
      builder: (ctx) => _Body(
        acompte: acompte,
        onCancel: () => Navigator.of(ctx).pop(AcompteDetailAction.cancel),
      ),
    );
  }
}

/// Récapitulatif d'un acompte, repris dans la confirmation d'annulation.
class AcompteRecap extends StatelessWidget {
  const AcompteRecap({super.key, required this.acompte, this.full = false});

  final Acompte acompte;

  /// Détail complet (validation, paiement) ou résumé (date, montant).
  final bool full;

  @override
  Widget build(BuildContext context) {
    final a = acompte;
    final created = a.createdAt;
    final validated = a.validatedAt;
    final paid = a.paidDate;

    return AppRecapBox(
      rows: [
        AppRecapRow(
          icon: Icons.send_rounded,
          label: 'Demandé le',
          value: created != null ? acompteDateTime(created) : '—',
        ),
        if (full && a.status == AcompteStatus.approved && validated != null)
          AppRecapRow(
            icon: Icons.check_circle_outline_rounded,
            label: 'Approuvé le',
            value: acompteDateTime(validated),
          ),
        if (full && a.isPaid)
          AppRecapRow(
            icon: Icons.paid_outlined,
            label: paid != null ? 'Payé le' : 'Paiement',
            value: paid != null ? acompteDateTime(paid) : 'Payé',
          ),
        AppRecapRow(
          icon: Icons.euro_rounded,
          label: 'Montant',
          value: DisplayFormat.euros(a.montant),
          emphasized: true,
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.acompte, required this.onCancel});

  final Acompte acompte;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final a = acompte;
    final raison = a.raison;
    final rejection = a.rejectionReason;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: AcompteStatusChip(status: a.status),
        ),
        const SizedBox(height: AppSpacing.base),
        AcompteRecap(acompte: a, full: true),
        if (raison != null && raison.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          NoteBlock(label: 'Raison', text: raison),
        ],
        if (a.status == AcompteStatus.rejected &&
            rejection != null &&
            rejection.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          NoteBlock(
            label: 'Motif du refus',
            text: rejection,
            icon: Icons.info_outline_rounded,
            iconColor: colors.destructive,
          ),
        ],
        if (a.status == AcompteStatus.pending) ...[
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
