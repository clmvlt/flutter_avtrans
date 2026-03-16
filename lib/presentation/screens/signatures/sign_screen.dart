import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart' as models;
import '../../widgets/widgets.dart';

/// Page de signature - design shadcn/ui
class SignScreen extends StatefulWidget {
  final double? heuresLastMonth;

  const SignScreen({super.key, this.heuresLastMonth});

  @override
  State<SignScreen> createState() => _SignScreenState();
}

class _SignScreenState extends State<SignScreen> {
  late SignatureController _controller;
  final _heuresController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _controller = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );

    if (widget.heuresLastMonth != null) {
      _heuresController.text = widget.heuresLastMonth!.toStringAsFixed(2);
    } else {
      _loadCurrentMonthHours();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _heuresController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentMonthHours() async {
    final now = DateTime.now();
    final params = models.WorkedHoursParams(
      period: models.WorkedHoursPeriod.month,
      year: now.year,
      month: now.month,
    );

    final result = await sl.serviceRepository.getWorkedHours(params);
    if (!mounted) return;

    result.fold(
      (_) {},
      (workedHours) {
        setState(() {
          _heuresController.text = (workedHours.month ?? 0).toStringAsFixed(1);
        });
      },
    );
  }

  Future<void> _submit() async {
    if (_controller.isEmpty) {
      _showError('Veuillez signer avant de valider');
      return;
    }

    final heures = double.tryParse(_heuresController.text);
    if (heures == null || heures <= 0) {
      _showError('Veuillez saisir un nombre d\'heures valide');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final Uint8List? signatureBytes = await _controller.toPngBytes();
      if (signatureBytes == null) {
        _showError('Erreur lors de la création de la signature');
        setState(() => _isSubmitting = false);
        return;
      }

      final signatureBase64 = base64Encode(signatureBytes);
      final request = models.SignatureCreateRequest(
        signatureBase64: signatureBase64,
        date: DateTime.now(),
        heuresSignees: heures,
      );

      final result = await sl.signatureRepository.createSignature(request);
      if (!mounted) return;

      result.fold(
        (failure) {
          setState(() => _isSubmitting = false);
          _showError(failure.message);
        },
        (signature) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Signature enregistrée avec succès')),
          );
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) Navigator.of(context).pop(signature);
          });
        },
      );
    } catch (e) {
      setState(() => _isSubmitting = false);
      _showError('Erreur: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Signer mes heures')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppAlert(
              description: 'Signez pour valider vos heures du mois en cours',
              variant: AlertVariant.info,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Hours field
            Text(
              'Nombre d\'heures à signer',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colors.foreground,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _heuresController,
              enabled: widget.heuresLastMonth == null,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: 'Heures',
                suffixText: 'h',
                prefixIcon: Icon(Icons.schedule, color: colors.primary, size: 18),
              ),
              style: TextStyle(
                color: colors.foreground,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Signature zone
            Text(
              'Signature',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colors.foreground,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: colors.border, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Signature(
                  controller: _controller,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            AppButton(
              text: 'Effacer',
              variant: ButtonVariant.outline,
              icon: Icons.clear,
              onPressed: () => setState(() => _controller.clear()),
            ),
            const SizedBox(height: AppSpacing.lg),

            AppButton(
              text: 'Valider la signature',
              onPressed: _isSubmitting ? null : _submit,
              isLoading: _isSubmitting,
            ),
          ],
        ),
      ),
    );
  }
}
