import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/vehicule_model.dart';

/// Dialog pour ajouter un kilométrage
class AddKilometrageDialog extends StatefulWidget {
  final String vehiculeId;

  const AddKilometrageDialog({
    super.key,
    required this.vehiculeId,
  });

  @override
  State<AddKilometrageDialog> createState() => _AddKilometrageDialogState();
}

class _AddKilometrageDialogState extends State<AddKilometrageDialog> {
  final _formKey = GlobalKey<FormState>();
  final _kmController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _kmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final km = int.parse(_kmController.text);
    final request = AddKilometrageRequest(
      vehiculeId: widget.vehiculeId,
      km: km,
    );

    final result = await sl.vehiculeRepository.addKilometrage(request);

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() => _isLoading = false);
        _showError(failure.message);
      },
      (kilometrage) {
        Navigator.of(context).pop(true);
      },
    );
  }

  void _showError(String message) {
    final colors = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: colors.destructive, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: colors.card,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      backgroundColor: colors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      title: Text(
        'Mettre à jour le kilométrage',
        style: textTheme.titleLarge?.copyWith(
          color: colors.foreground,
        ),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kilométrage actuel',
              style: textTheme.titleSmall?.copyWith(
                color: colors.foreground,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _kmController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: textTheme.titleLarge?.copyWith(
                color: colors.foreground,
              ),
              decoration: InputDecoration(
                hintText: 'Ex: 125000',
                hintStyle: TextStyle(
                  color: colors.mutedForeground,
                  fontWeight: FontWeight.normal,
                ),
                prefixIcon: Icon(Icons.speed, color: colors.primary),
                suffixText: 'km',
                suffixStyle: textTheme.labelLarge?.copyWith(
                  color: colors.mutedForeground,
                ),
                filled: true,
                fillColor: colors.muted,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.base),
                  borderSide: BorderSide(color: colors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.base),
                  borderSide: BorderSide(color: colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.base),
                  borderSide: BorderSide(color: colors.primary, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.base),
                  borderSide: BorderSide(color: colors.destructive),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.base),
                  borderSide: BorderSide(color: colors.destructive, width: 2),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez saisir le kilométrage';
                }
                final km = int.tryParse(value);
                if (km == null || km <= 0) {
                  return 'Kilométrage invalide';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.base,
        0,
        AppSpacing.base,
        AppSpacing.base,
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
          ),
          child: Text(
            'Annuler',
            style: textTheme.labelLarge?.copyWith(color: colors.mutedForeground),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: colors.primaryForeground,
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.base,
              vertical: AppSpacing.sm,
            ),
          ),
          child: _isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(colors.primaryForeground),
                  ),
                )
              : const Text('Valider'),
        ),
      ],
    );
  }
}
