import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/models.dart';
import '../../../widgets/widgets.dart';
import '../../absences/widgets/request_blocks.dart';
import 'couchette_visuals.dart';

/// Action choisie dans le détail d'une couchette.
enum CouchetteDetailAction { delete }

/// Détail d'une couchette : date et heure de déclaration, et « Supprimer la
/// couchette » pour celle du jour uniquement.
abstract final class CouchetteDetailSheet {
  static Future<CouchetteDetailAction?> show(
    BuildContext context,
    Couchette couchette,
  ) {
    return AppSheet.show<CouchetteDetailAction>(
      context,
      title: 'Couchette',
      builder: (ctx) => _Body(
        couchette: couchette,
        onDelete: () => Navigator.of(ctx).pop(CouchetteDetailAction.delete),
      ),
    );
  }
}

/// Récapitulatif d'une couchette, repris dans la confirmation.
class CouchetteRecap extends StatelessWidget {
  const CouchetteRecap({super.key, required this.couchette});

  final Couchette couchette;

  @override
  Widget build(BuildContext context) {
    final declared = couchette.createdAt;
    return AppRecapBox(
      rows: [
        AppRecapRow(
          icon: Icons.event_rounded,
          label: 'Date',
          value: couchetteDateLabel(couchette),
        ),
        if (declared != null)
          AppRecapRow(
            icon: Icons.schedule_rounded,
            label: 'Déclarée le',
            value: couchetteDeclaredAt(declared),
          ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.couchette, required this.onDelete});

  final Couchette couchette;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CouchetteRecap(couchette: couchette),
        if (isTodayCouchette(couchette)) ...[
          const SizedBox(height: AppSpacing.lg),
          SheetDangerAction(
            label: 'Supprimer la couchette',
            icon: Icons.delete_outline_rounded,
            hint: 'Possible le jour même uniquement.',
            onPressed: onDelete,
          ),
        ],
      ],
    );
  }
}
