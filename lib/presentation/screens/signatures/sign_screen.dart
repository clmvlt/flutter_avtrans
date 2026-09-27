import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart' as models;
import '../../widgets/widgets.dart';
import 'widgets/sign_hours_hero.dart';
import 'widgets/signature_pad_card.dart';
import 'widgets/signature_paper.dart';

/// Signature des heures : la carte hero montre le total à signer, le pavé
/// de signature est dans une carte, « Signer mes heures » vit dans le dock.
///
/// Retourne la signature créée (`Navigator.pop(signature)`).
class SignScreen extends StatefulWidget {
  final double? heuresLastMonth;

  const SignScreen({super.key, this.heuresLastMonth});

  @override
  State<SignScreen> createState() => _SignScreenState();
}

class _SignScreenState extends State<SignScreen> with DockNoticeMixin {
  late SignatureController _controller;
  final _heuresController = TextEditingController();
  bool _isSubmitting = false;

  /// Total du mois en cours en chargement (quand [SignScreen.heuresLastMonth]
  /// n'est pas fourni).
  bool _loadingHours = false;

  @override
  void initState() {
    super.initState();
    _controller = SignatureController(
      penStrokeWidth: 3,
      penColor: SignaturePaper.ink,
      exportBackgroundColor: SignaturePaper.paper,
    );

    if (widget.heuresLastMonth != null) {
      _heuresController.text = widget.heuresLastMonth!.toStringAsFixed(2);
    } else {
      _loadingHours = true;
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
      // Échec silencieux (comme avant) : le champ reste vide et modifiable.
      (_) => setState(() => _loadingHours = false),
      (workedHours) {
        setState(() {
          _heuresController.text = (workedHours.month ?? 0).toStringAsFixed(1);
          _loadingHours = false;
        });
      },
    );
  }

  Future<void> _submit() async {
    clearDockNotice();
    if (_controller.isEmpty) {
      showDockError('Signe dans le cadre avant de valider');
      return;
    }

    // « 151,5 » (clavier français) comme « 151.5 ».
    final heures =
        double.tryParse(_heuresController.text.trim().replaceAll(',', '.'));
    if (heures == null || heures <= 0) {
      showDockError(
        widget.heuresLastMonth != null
            ? 'Aucune heure à signer : le total du mois dernier est nul'
            : 'Saisis un nombre d\'heures valide (ex. 151.5)',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final Uint8List? signatureBytes = await _controller.toPngBytes();
      if (!mounted) return;
      if (signatureBytes == null) {
        setState(() => _isSubmitting = false);
        showDockError('Impossible de créer la signature. Réessaie.');
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
          showDockError(failure.message);
        },
        (signature) {
          // Confirmation brève dans le dock, puis retour (bouton toujours en
          // chargement : pas de double envoi).
          showDockSuccess('Signature enregistrée');
          Future.delayed(const Duration(milliseconds: 700), () {
            if (mounted) Navigator.of(context).pop(signature);
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showDockError('Erreur : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Signer mes heures',
      body: AppScrollView(
        children: [
          SignHoursHero(
            fixedHours: widget.heuresLastMonth,
            controller: _heuresController,
            loading: _loadingHours,
            enabled: !_isSubmitting,
          ),
          const SizedBox(height: AppSpacing.lg),
          SignaturePadCard(
            controller: _controller,
            onClear: _isSubmitting ? null : () => setState(_controller.clear),
          ),
        ],
      ),
      dock: AppDock(
        notice: dockNotice,
        onDismissNotice: clearDockNotice,
        actions: [
          DockAction(
            label: 'Signer mes heures',
            icon: Icons.draw_rounded,
            isLoading: _isSubmitting,
            onPressed: _isSubmitting ? null : _submit,
          ),
        ],
      ),
    );
  }
}
