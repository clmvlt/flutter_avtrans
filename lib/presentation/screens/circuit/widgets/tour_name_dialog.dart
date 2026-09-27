import 'package:flutter/material.dart';

import '../../../widgets/app_confirm_sheet.dart';
import '../../../widgets/app_sheet.dart';
import '../../../widgets/app_text_field.dart';

/// Demande un nom de tournée (création ou renommage), dans une feuille.
///
/// Renvoie le texte saisi (éventuellement vide → nom par défaut côté service),
/// ou `null` si l'utilisateur annule ou ferme la feuille.
Future<String?> showTourNameDialog(
  BuildContext context, {
  required String title,
  required String actionLabel,
  String? initialName,
}) {
  return AppSheet.show<String>(
    context,
    title: title,
    builder: (_) => _TourNameForm(
      actionLabel: actionLabel,
      initialName: initialName,
    ),
  );
}

class _TourNameForm extends StatefulWidget {
  const _TourNameForm({required this.actionLabel, this.initialName});

  final String actionLabel;
  final String? initialName;

  @override
  State<_TourNameForm> createState() => _TourNameFormState();
}

class _TourNameFormState extends State<_TourNameForm> {
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
    return AppConfirmBody(
      details: AppTextField(
        controller: _controller,
        hint: 'Ex. Tournée matin — Rennes Nord',
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        prefixIcon: const Icon(Icons.local_shipping_outlined, size: 20),
      ),
      confirmLabel: widget.actionLabel,
      confirmIcon: Icons.check_rounded,
      tone: AppConfirmTone.primary,
      onConfirm: _submit,
      onCancel: () => Navigator.of(context).pop(),
    );
  }
}
