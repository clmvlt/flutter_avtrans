import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/display_format.dart';
import '../../../../data/models/entretien_model.dart';
import '../../../widgets/widgets.dart';
import 'entretien_files_list.dart';

/// Ce que l'utilisateur a demandé depuis la feuille de détail.
enum EntretienDetailAction { edit, deleted }

/// Détail d'un entretien : récapitulatif, commentaire, fichiers (ouvrables),
/// puis « Modifier » et « Supprimer ». Retourne l'action choisie.
abstract final class EntretienDetailSheet {
  static Future<EntretienDetailAction?> show(
    BuildContext context,
    Entretien entretien,
  ) {
    return AppSheet.show<EntretienDetailAction>(
      context,
      title: entretien.typeLabel,
      builder: (_) => _DetailBody(entretien: entretien),
    );
  }
}

class _DetailBody extends StatefulWidget {
  const _DetailBody({required this.entretien});

  final Entretien entretien;

  @override
  State<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends State<_DetailBody> {
  bool _deleting = false;
  String? _error;

  Future<void> _delete() async {
    final e = widget.entretien;
    final confirmed = await AppConfirmSheet.show(
      context,
      title: 'Supprimer cet entretien ?',
      message: '« ${e.typeLabel} » du ${DisplayFormat.date(e.dateEntretien)}'
          '${e.files.isNotEmpty ? ' et ses ${DisplayFormat.plural(e.files.length, 'fichier')}' : ''}'
          ' seront supprimés définitivement.',
      confirmLabel: 'Supprimer l\'entretien',
      confirmIcon: Icons.delete_rounded,
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _deleting = true;
      _error = null;
    });
    final result = await sl.entretienRepository.deleteEntretien(e.id);
    if (!mounted) return;
    result.fold(
      (failure) {
        HapticFeedback.heavyImpact();
        setState(() {
          _deleting = false;
          _error = failure.message;
        });
      },
      (_) {
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop(EntretienDetailAction.deleted);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final e = widget.entretien;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (e.typeEntretien?.dossier != null) ...[
          Text(
            e.typeEntretien!.dossier!.nom,
            style: textTheme.bodyMedium?.copyWith(color: colors.mutedForeground),
          ),
          const SizedBox(height: AppSpacing.base),
        ],
        AppRecapBox(
          rows: [
            if (e.vehiculeImmat != null)
              AppRecapRow(
                icon: Icons.directions_car_rounded,
                label: 'Véhicule',
                value: e.vehiculeImmat!.toUpperCase(),
              ),
            AppRecapRow(
              icon: Icons.event_rounded,
              label: 'Date',
              value: DisplayFormat.date(e.dateEntretien),
            ),
            AppRecapRow(
              icon: Icons.speed_rounded,
              label: 'Kilométrage',
              value: e.kilometrage != null ? DisplayFormat.km(e.kilometrage!) : '—',
            ),
            AppRecapRow(
              icon: Icons.euro_rounded,
              label: 'Coût HT',
              value: e.cout != null ? DisplayFormat.euros(e.cout!) : '—',
            ),
            if (e.mecanicien != null && e.mecanicien!.fullName.isNotEmpty)
              AppRecapRow(
                icon: Icons.person_rounded,
                label: 'Saisi par',
                value: e.mecanicien!.fullName,
              ),
          ],
        ),
        if (e.commentaire != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Text('Commentaire', style: textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(e.commentaire!, style: textTheme.bodyMedium),
        ],
        if (e.files.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(
            DisplayFormat.plural(e.files.length, 'Fichier'),
            style: textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          EntretienFilesList(entretienId: e.id, files: e.files),
        ],
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.base),
          AppAlert(variant: AlertVariant.destructive, description: _error!),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          text: 'Modifier l\'entretien',
          icon: Icons.edit_rounded,
          size: ButtonSize.lg,
          onPressed: _deleting
              ? null
              : () => Navigator.of(context).pop(EntretienDetailAction.edit),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 52,
          child: TextButton.icon(
            onPressed: _deleting ? null : _delete,
            style: TextButton.styleFrom(foregroundColor: colors.destructive),
            icon: _deleting
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.destructive,
                    ),
                  )
                : const Icon(Icons.delete_outline_rounded, size: 20),
            label: const Text('Supprimer'),
          ),
        ),
      ],
    );
  }
}
