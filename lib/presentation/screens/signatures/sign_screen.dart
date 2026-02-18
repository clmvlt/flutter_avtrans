import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart' as models;
import '../../widgets/widgets.dart';

/// Page pour signer les heures
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

    // Si heuresLastMonth est fourni, l'utiliser directement
    if (widget.heuresLastMonth != null) {
      _heuresController.text = widget.heuresLastMonth!.toStringAsFixed(2);
    } else {
      // Sinon, charge les heures du mois en cours
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
    // Récupère les heures du mois en cours depuis l'API
    final now = DateTime.now();
    final params = models.WorkedHoursParams(
      period: models.WorkedHoursPeriod.month,
      year: now.year,
      month: now.month,
    );

    final result = await sl.serviceRepository.getWorkedHours(params);

    if (!mounted) return;

    result.fold(
      (_) {}, // Ignore les erreurs
      (workedHours) {
        setState(() {
          _heuresController.text = (workedHours.month ?? 0).toStringAsFixed(1);
        });
      },
    );
  }

  Future<void> _submit() async {
    final colors = context.colors;

    // Vérifie qu'il y a une signature
    if (_controller.isEmpty) {
      _showError('Veuillez signer avant de valider');
      return;
    }

    // Vérifie le nombre d'heures
    final heures = double.tryParse(_heuresController.text);
    if (heures == null || heures <= 0) {
      _showError('Veuillez saisir un nombre d\'heures valide');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Convertit la signature en PNG
      final Uint8List? signatureBytes = await _controller.toPngBytes();
      if (signatureBytes == null) {
        _showError('Erreur lors de la création de la signature');
        setState(() => _isSubmitting = false);
        return;
      }

      // Convertit en base64
      final signatureBase64 = base64Encode(signatureBytes);

      // Crée la requête
      final request = models.SignatureCreateRequest(
        signatureBase64: signatureBase64,
        date: DateTime.now(),
        heuresSignees: heures,
      );

      // Envoie à l'API
      final result = await sl.signatureRepository.createSignature(request);

      if (!mounted) return;

      result.fold(
        (failure) {
          setState(() => _isSubmitting = false);
          _showError(failure.message);
        },
        (signature) {
          // Affiche le succès d'abord
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Signature enregistrée avec succès'),
              backgroundColor: colors.success,
              duration: const Duration(seconds: 2),
            ),
          );
          // Retourne la signature créée après un court délai
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              Navigator.of(context).pop(signature);
            }
          });
        },
      );
    } catch (e) {
      setState(() => _isSubmitting = false);
      _showError('Erreur: $e');
    }
  }

  void _showError(String message) {
    final colors = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: colors.error, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: colors.bgSecondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.base),
          side: BorderSide(color: colors.error),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bgPrimary,
      appBar: AppBar(
        title: const Text('Signer mes heures'),
        backgroundColor: colors.bgSecondary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info
            Container(
              padding: const EdgeInsets.all(AppSpacing.base),
              decoration: BoxDecoration(
                color: colors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.base),
                border: Border.all(color: colors.info.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: colors.info),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Signez pour valider vos heures du mois en cours',
                      style: TextStyle(
                        fontSize: 14,
                        color: colors.info,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Champ heures
            Text(
              'Nombre d\'heures à signer',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextFormField(
              controller: _heuresController,
              enabled: widget.heuresLastMonth == null,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Heures',
                suffixText: 'h',
                prefixIcon: Icon(Icons.schedule, color: colors.primary),
                filled: true,
                fillColor: widget.heuresLastMonth != null
                    ? colors.bgTertiary
                    : colors.bgSecondary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.base),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.base),
                  borderSide: BorderSide(color: colors.borderPrimary),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.base),
                  borderSide: BorderSide(color: colors.borderPrimary),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.base),
                  borderSide: BorderSide(color: colors.primary, width: 2),
                ),
              ),
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Zone de signature
            Text(
              'Signature',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.base),
                border: Border.all(color: colors.borderPrimary, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.base),
                child: Signature(
                  controller: _controller,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Bouton effacer
            OutlinedButton.icon(
              onPressed: () {
                setState(() => _controller.clear());
              },
              icon: Icon(Icons.clear, size: 16, color: colors.textSecondary),
              label: Text(
                'Effacer',
                style: TextStyle(color: colors.textSecondary),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: colors.borderPrimary),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Bouton valider
            AppButton(
              text: 'Valider la signature',
              onPressed: _isSubmitting ? null : _submit,
              isLoading: _isSubmitting,
              backgroundColor: colors.primary,
              foregroundColor: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}
