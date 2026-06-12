import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_text_field.dart';

/// Demande un nom de tournée (création ou renommage).
///
/// Renvoie le texte saisi (éventuellement vide → nom par défaut côté service),
/// ou `null` si l'utilisateur annule.
Future<String?> showTourNameDialog(
  BuildContext context, {
  required String title,
  required String actionLabel,
  String? initialName,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TourNameDialog(
      title: title,
      actionLabel: actionLabel,
      initialName: initialName,
    ),
  );
}

class _TourNameDialog extends StatefulWidget {
  const _TourNameDialog({
    required this.title,
    required this.actionLabel,
    this.initialName,
  });

  final String title;
  final String actionLabel;
  final String? initialName;

  @override
  State<_TourNameDialog> createState() => _TourNameDialogState();
}

class _TourNameDialogState extends State<_TourNameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialName ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      title: Text(widget.title, style: textTheme.titleLarge),
      content: AppTextField(
        controller: _controller,
        hint: 'Ex. Tournée matin — Rennes Nord',
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        prefixIcon: const Icon(Icons.local_shipping_outlined, size: 20),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.base,
        0,
        AppSpacing.base,
        AppSpacing.base,
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: AppButton(
                text: 'Annuler',
                variant: ButtonVariant.ghost,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppButton(text: widget.actionLabel, onPressed: _submit),
            ),
          ],
        ),
      ],
    );
  }
}
