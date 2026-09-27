import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/display_format.dart';
import '../../../data/models/vehicule_model.dart';
import '../../widgets/widgets.dart';

/// Feuille « Mettre à jour le kilométrage » d'un véhicule.
///
/// L'API (`POST /vehicules/kilometrages`) n'effectue aucun contrôle de
/// cohérence : [show] reçoit `latestKm` pour refuser côté client un relevé
/// inférieur au précédent.
abstract final class AddKilometrageSheet {
  /// Retourne `true` si un relevé a été enregistré.
  static Future<bool> show(
    BuildContext context, {
    required String vehiculeId,
    int? latestKm,
    DateTime? latestKmDate,
  }) async {
    final saved = await AppSheet.show<bool>(
      context,
      title: 'Mettre à jour le kilométrage',
      builder: (_) => _AddKilometrageForm(
        vehiculeId: vehiculeId,
        latestKm: latestKm,
        latestKmDate: latestKmDate,
      ),
    );
    return saved ?? false;
  }
}

class _AddKilometrageForm extends StatefulWidget {
  const _AddKilometrageForm({
    required this.vehiculeId,
    this.latestKm,
    this.latestKmDate,
  });

  final String vehiculeId;
  final int? latestKm;
  final DateTime? latestKmDate;

  @override
  State<_AddKilometrageForm> createState() => _AddKilometrageFormState();
}

class _AddKilometrageFormState extends State<_AddKilometrageForm> {
  final _formKey = GlobalKey<FormState>();
  final _kmController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _kmController.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    if (value == null || value.isEmpty) return 'Saisis le kilométrage';
    final km = int.tryParse(value);
    if (km == null || km <= 0) return 'Kilométrage invalide';
    final latest = widget.latestKm;
    if (latest != null && km < latest) {
      return 'Doit être au moins égal au dernier relevé '
          '(${DisplayFormat.km(latest)})';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final request = AddKilometrageRequest(
      vehiculeId: widget.vehiculeId,
      km: int.parse(_kmController.text),
    );
    final result = await sl.vehiculeRepository.addKilometrage(request);

    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        _isLoading = false;
        _error = failure.message;
      }),
      (_) => Navigator.of(context).pop(true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final latest = widget.latestKm;
    final latestDate = widget.latestKmDate;

    return AppConfirmBody(
      message: 'Saisis la valeur affichée au compteur du véhicule.',
      details: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (latest != null) ...[
              AppRecapBox(
                rows: [
                  AppRecapRow(
                    icon: Icons.history_rounded,
                    label: 'Dernier relevé',
                    value: DisplayFormat.km(latest),
                  ),
                  if (latestDate != null)
                    AppRecapRow(
                      icon: Icons.event_rounded,
                      label: 'Relevé le',
                      value: DisplayFormat.date(latestDate),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.base),
            ],
            const AppFieldLabel('Nouveau kilométrage'),
            TextFormField(
              controller: _kmController,
              autofocus: true,
              enabled: !_isLoading,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: textTheme.titleLarge?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              decoration: InputDecoration(
                hintText: latest != null ? '$latest' : 'Ex. 125000',
                prefixIcon: const Icon(Icons.speed_rounded, size: 20),
                suffixText: 'km',
              ),
              validator: _validate,
              onFieldSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              AppAlert(
                variant: AlertVariant.destructive,
                description: _error!,
              ),
            ],
          ],
        ),
      ),
      confirmLabel: 'Enregistrer le kilométrage',
      confirmIcon: Icons.check_rounded,
      tone: AppConfirmTone.primary,
      isLoading: _isLoading,
      onConfirm: _submit,
      onCancel: () => Navigator.of(context).pop(false),
    );
  }
}
