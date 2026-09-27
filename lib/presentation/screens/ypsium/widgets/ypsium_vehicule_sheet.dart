import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/ypsium_models.dart';
import '../../../widgets/widgets.dart';

/// Saisie de la feuille véhicule : kilométrage, note d'état (1 à 5),
/// commentaire.
class YpsiumVehiculeChoice {
  const YpsiumVehiculeChoice({
    required this.kilometrage,
    required this.noteEtat,
    required this.commentaire,
  });

  final int kilometrage;
  final int noteEtat;
  final String commentaire;
}

/// Feuille de confirmation d'un véhicule (titre = immatriculation).
/// Retourne la saisie, `null` si annulée ou fermée.
abstract final class YpsiumVehiculeSheet {
  static Future<YpsiumVehiculeChoice?> show(
    BuildContext context,
    YpsiumVehicule vehicule,
  ) {
    return AppSheet.show<YpsiumVehiculeChoice>(
      context,
      title: vehicule.immatriculation,
      builder: (_) => _VehiculeForm(vehicule: vehicule),
    );
  }
}

class _VehiculeForm extends StatefulWidget {
  const _VehiculeForm({required this.vehicule});

  final YpsiumVehicule vehicule;

  @override
  State<_VehiculeForm> createState() => _VehiculeFormState();
}

class _VehiculeFormState extends State<_VehiculeForm> {
  late final _kmController = TextEditingController(
    text: widget.vehicule.kilometrage.toString(),
  );
  final _commentController = TextEditingController();
  int _noteEtat = 3;

  @override
  void dispose() {
    _kmController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          controller: _kmController,
          label: 'Kilométrage',
          keyboardType: TextInputType.number,
          prefixIcon: const Icon(Icons.speed_rounded, size: 20),
        ),
        const SizedBox(height: AppSpacing.base),
        const AppFieldLabel('État du véhicule'),
        _StarRating(
          value: _noteEtat,
          onChanged: (note) => setState(() => _noteEtat = note),
        ),
        const SizedBox(height: AppSpacing.base),
        AppTextField(
          controller: _commentController,
          label: 'Commentaire',
          hint: 'Facultatif',
          maxLines: 2,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          text: 'Confirmer ce véhicule',
          icon: Icons.check_rounded,
          size: ButtonSize.lg,
          onPressed: () => Navigator.of(context).pop(
            YpsiumVehiculeChoice(
              kilometrage: int.tryParse(_kmController.text) ?? 0,
              noteEtat: _noteEtat,
              commentaire: _commentController.text,
            ),
          ),
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

/// Cinq étoiles de 48 dp, la note en clair à droite.
class _StarRating extends StatelessWidget {
  const _StarRating({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        for (var note = 1; note <= 5; note++)
          Semantics(
            button: true,
            selected: note == value,
            label: 'État $note sur 5',
            excludeSemantics: true,
            child: IconButton(
              onPressed: () => onChanged(note),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: Icon(
                note <= value ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 30,
                color: note <= value ? colors.warning : colors.mutedForeground,
              ),
            ),
          ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            '$value sur 5',
            style: textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
