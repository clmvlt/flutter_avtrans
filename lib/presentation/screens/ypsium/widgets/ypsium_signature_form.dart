import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/time_format.dart';
import '../../../widgets/widgets.dart';

/// Papier de signature : blanc quel que soit le thème, car l'encre est
/// noire et la signature est exportée sur fond blanc (voir le
/// `SignatureController` des parcours). Seule couleur hors `AppColors`.
const Color ypsiumSignaturePaper = Colors.white;

/// Étape « Signature » d'un parcours : nom de la personne, heures
/// d'arrivée et de départ, zone de signature (effacer, plein écran).
class YpsiumSignatureForm extends StatelessWidget {
  const YpsiumSignatureForm({
    super.key,
    required this.nameController,
    required this.nameLabel,
    required this.arrivee,
    required this.depart,
    required this.onPickArrivee,
    required this.onPickDepart,
    required this.signatureController,
    required this.onClearSignature,
    required this.onFullscreen,
  });

  final TextEditingController nameController;

  /// « Nom du remettant », « Nom du réceptionnaire ».
  final String nameLabel;
  final DateTime arrivee;
  final DateTime depart;
  final VoidCallback onPickArrivee;
  final VoidCallback onPickDepart;
  final SignatureController signatureController;
  final VoidCallback onClearSignature;
  final VoidCallback onFullscreen;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSectionHeader(title: 'Sur place'),
        AppTextField(
          controller: nameController,
          label: nameLabel,
          hint: 'Nom de la personne',
          prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: AppSpacing.base),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppPickerField(
                label: 'Arrivée',
                value: TimeFormat.hm(arrivee),
                placeholder: '--:--',
                icon: Icons.schedule_rounded,
                trailingIcon: Icons.expand_more_rounded,
                onTap: onPickArrivee,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppPickerField(
                label: 'Départ',
                value: TimeFormat.hm(depart),
                placeholder: '--:--',
                icon: Icons.schedule_rounded,
                trailingIcon: Icons.expand_more_rounded,
                onTap: onPickDepart,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AppSectionHeader(
          title: 'Signature',
          actionLabel: 'Plein écran',
          onAction: onFullscreen,
        ),
        Semantics(
          label: 'Zone de signature',
          child: Container(
            height: 300,
            decoration: BoxDecoration(
              color: ypsiumSignaturePaper,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: colors.border, width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Signature(
                controller: signatureController,
                backgroundColor: ypsiumSignaturePaper,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xs),
                child: Text(
                  'Tourne le téléphone pour signer en grand',
                  style: textTheme.bodySmall,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onClearSignature,
              style: TextButton.styleFrom(
                foregroundColor: colors.foreground,
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                textStyle: textTheme.labelLarge,
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Effacer'),
            ),
          ],
        ),
      ],
    );
  }
}
