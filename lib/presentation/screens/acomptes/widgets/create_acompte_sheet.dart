import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/models.dart';
import '../../../widgets/widgets.dart';

/// Formulaire court « Demander un acompte » en feuille : montant et raison
/// facultative. Retourne l'acompte créé, ou `null` si on ferme sans envoyer.
/// Une erreur d'envoi s'affiche dans la feuille (le dock est dessous).
abstract final class CreateAcompteSheet {
  static Future<Acompte?> show(BuildContext context) {
    return AppSheet.show<Acompte>(
      context,
      title: 'Demander un acompte',
      builder: (_) => const _CreateAcompteBody(),
    );
  }
}

class _CreateAcompteBody extends StatefulWidget {
  const _CreateAcompteBody();

  @override
  State<_CreateAcompteBody> createState() => _CreateAcompteBodyState();
}

class _CreateAcompteBodyState extends State<_CreateAcompteBody> {
  final _formKey = GlobalKey<FormState>();
  final _montantController = TextEditingController();
  final _raisonController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _montantController.dispose();
    _raisonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final montant = _parseMontant(_montantController.text) ?? 0;
    final raisonText = _raisonController.text.trim();
    final request = AcompteCreateRequest(
      montant: montant,
      raison: raisonText.isEmpty ? null : raisonText,
    );

    final result = await sl.acompteRepository.createAcompte(request);

    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        _isSubmitting = false;
        _error = failure.message;
      }),
      (acompte) => Navigator.of(context).pop(acompte),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppFieldLabel('Montant'),
          AppTextField(
            controller: _montantController,
            hint: 'Ex. 150',
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            prefixIcon: const Icon(Icons.euro_rounded, size: 20),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Saisis un montant';
              }
              final montant = _parseMontant(value);
              if (montant == null || montant <= 0) {
                return 'Saisis un montant valide';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          const AppFieldLabel('Raison', optional: true),
          AppTextField(
            controller: _raisonController,
            hint: 'Explique en quelques mots…',
            maxLines: 3,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.base),
            AppAlert(variant: AlertVariant.destructive, description: _error!),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            text: 'Envoyer la demande',
            icon: Icons.send_rounded,
            size: ButtonSize.lg,
            isLoading: _isSubmitting,
            onPressed: _isSubmitting ? null : _submit,
          ),
        ],
      ),
    );
  }
}

/// Montant saisi au clavier français : « 150,50 » comme « 150.50 ».
double? _parseMontant(String? text) {
  if (text == null) return null;
  final cleaned = text.trim().replaceAll(RegExp(r'[\s\u00A0\u202F€]'), '');
  return double.tryParse(cleaned.replaceAll(',', '.'));
}
