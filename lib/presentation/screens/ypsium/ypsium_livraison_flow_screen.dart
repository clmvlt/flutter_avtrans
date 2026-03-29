import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/ypsium_models.dart';
import '../../widgets/app_alert.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/widgets.dart';
import 'ypsium_signature_fullscreen.dart';

/// Flux de livraison en 3 étapes :
/// 1. Récapitulatif — infos livraison + colis
/// 2. Photos — prendre des photos (optionnel)
/// 3. Validation — signature, nom réceptionnaire, dates
class YpsiumLivraisonFlowScreen extends StatefulWidget {
  final YpsiumTransportOrder order;

  const YpsiumLivraisonFlowScreen({super.key, required this.order});

  @override
  State<YpsiumLivraisonFlowScreen> createState() =>
      _YpsiumLivraisonFlowScreenState();
}

class _YpsiumLivraisonFlowScreenState
    extends State<YpsiumLivraisonFlowScreen> with WidgetsBindingObserver {
  int _currentStep = 0;
  bool _isLoading = false;
  bool _isInFullscreenSignature = false;
  bool _dismissedFullscreen = false;
  String? _errorMessage;

  // Step 2 — Photos (base64)
  final List<String> _photos = [];

  // Step 3 — Validation
  final _nomReceptController = TextEditingController();
  late final SignatureController _signatureController;
  late DateTime _heureArrivee;
  late DateTime _heureDepart;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _heureArrivee = DateTime.now();
    _heureDepart = DateTime.now();
    _signatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nomReceptController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final size = WidgetsBinding.instance.platformDispatcher.views.first.physicalSize;
    final isLandscape = size.width > size.height;

    if (!isLandscape) {
      _dismissedFullscreen = false;
    }

    if (_currentStep == 2 && isLandscape && !_isInFullscreenSignature && !_dismissedFullscreen) {
      _isInFullscreenSignature = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openSignatureFullscreen();
      });
    }
  }

  void _openSignatureFullscreen() async {
    _isInFullscreenSignature = true;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => YpsiumSignatureFullscreen(
          controller: _signatureController,
        ),
      ),
    );
    _isInFullscreenSignature = false;
    _dismissedFullscreen = true;
    if (mounted) setState(() {});
  }

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() {
        _currentStep++;
        _errorMessage = null;
      });
      if (_currentStep == 2) {
        _heureDepart = DateTime.now();
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _errorMessage = null;
      });
    }
  }

  /// Envoyer les photos (step 2)
  Future<void> _sendPhotos() async {
    if (_photos.isEmpty) {
      _nextStep();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await sl.ypsiumTransportRepository.setPhotoLivDepart(
      idOrdre: widget.order.idOrdre,
      photosBase64: _photos,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    result.fold(
      (failure) => setState(() => _errorMessage = failure.message),
      (_) => _nextStep(),
    );
  }

  /// Valider la livraison (step 3)
  Future<void> _validate() async {
    if (_nomReceptController.text.trim().isEmpty) {
      setState(
          () => _errorMessage = 'Veuillez renseigner le nom du réceptionnaire');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    String? signatureBase64;
    if (_signatureController.isNotEmpty) {
      final Uint8List? bytes = await _signatureController.toPngBytes();
      if (bytes != null) {
        signatureBase64 = base64Encode(bytes);
      }
    }

    final result = await sl.ypsiumTransportRepository.setPointLivre(
      idOrdre: widget.order.idOrdre,
      request: YpsiumSetPointEnleveRequest(
        nomRemettant: _nomReceptController.text.trim(),
        heureArriveeSurSite: _heureArrivee.toIso8601String(),
        heureDepartSite: _heureDepart.toIso8601String(),
        signature: signatureBase64,
      ),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    result.fold(
      (failure) => setState(() => _errorMessage = failure.message),
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Livraison validée avec succès')),
        );
        Navigator.of(context).pop(true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.foreground, size: 20),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Livraison #${widget.order.idOrdre}',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: colors.foreground,
          ),
        ),
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: Column(
          children: [
            _buildStepIndicator(colors),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.base),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_errorMessage != null) ...[
                      AppAlert(
                        description: _errorMessage!,
                        variant: AlertVariant.destructive,
                      ),
                      const SizedBox(height: AppSpacing.base),
                    ],
                    if (_currentStep == 0) _buildStep1Recap(colors),
                    if (_currentStep == 1) _buildStep2Photos(colors),
                    if (_currentStep == 2) _buildStep3Validation(colors),
                  ],
                ),
              ),
            ),
            _buildBottomBar(colors),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // Step Indicator
  // ==========================================================

  Widget _buildStepIndicator(AppColors colors) {
    const labels = ['Récapitulatif', 'Photos', 'Validation'];

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: List.generate(3, (index) {
          final isActive = index == _currentStep;
          final isDone = index < _currentStep;
          final color = isActive
              ? colors.primary
              : isDone
                  ? colors.success
                  : colors.mutedForeground;

          return Expanded(
            child: Row(
              children: [
                if (index > 0)
                  Expanded(
                    flex: 0,
                    child: Container(
                      width: 20,
                      height: 1,
                      color: isDone ? colors.success : colors.border,
                    ),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isDone
                              ? colors.success
                              : isActive
                                  ? colors.primary
                                  : colors.muted,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: isDone
                              ? Icon(Icons.check,
                                  size: 16, color: colors.successForeground)
                              : Text(
                                  '${index + 1}',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: isActive
                                        ? colors.primaryForeground
                                        : colors.mutedForeground,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        labels[index],
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight:
                              isActive ? FontWeight.w600 : FontWeight.w400,
                          color: color,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ==========================================================
  // Step 1 — Récapitulatif livraison
  // ==========================================================

  Widget _buildStep1Recap(AppColors colors) {
    final order = widget.order;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Infos livraison
        _buildInfoCard(
          colors: colors,
          icon: Icons.download_outlined,
          iconColor: colors.success,
          children: [
            Text(
              order.lNom,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.foreground,
              ),
            ),
            if (order.lAdresseComplete.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                order.lAdresseComplete,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.mutedForeground),
              ),
            ],
            if (order.lHeureFormatted.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(Icons.access_time,
                      size: 20, color: colors.mutedForeground),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    order.lHeureFormatted,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.foreground),
                  ),
                ],
              ),
            ],
            if (order.lContact.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(Icons.person_outline,
                      size: 20, color: colors.mutedForeground),
                  const SizedBox(width: AppSpacing.xs),
                  Text(order.lContact,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.mutedForeground)),
                ],
              ),
            ],
            if (order.lTelephone1.isNotEmpty)
              Row(
                children: [
                  Icon(Icons.phone_outlined,
                      size: 20, color: colors.mutedForeground),
                  const SizedBox(width: AppSpacing.xs),
                  Text(order.lTelephone1,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.mutedForeground)),
                ],
              ),
            if (order.lTelephone1.isNotEmpty || order.lAdresseComplete.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  if (order.lTelephone1.isNotEmpty)
                    _buildActionChip(colors, Icons.phone, 'Appeler', colors.success,
                        () => _launchPhone(order.lTelephone1)),
                  if (order.lAdresseComplete.isNotEmpty)
                    _buildActionChip(colors, Icons.navigation, 'Itinéraire', colors.info,
                        () => _launchMaps(order.lAdresseComplete)),
                ],
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.base),

        // Provenance (enlèvement déjà fait)
        _buildInfoCard(
          colors: colors,
          icon: Icons.upload_outlined,
          iconColor: colors.mutedForeground,
          children: [
            Text(
              'Provenance',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.mutedForeground,
                letterSpacing: 0.3,
              ),
            ),
            Text(
              order.eNom,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colors.foreground,
              ),
            ),
            Text(
              '${order.eCodePostal} ${order.eVille}'.trim(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.mutedForeground),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.base),

        // Client
        Row(
          children: [
            Text('Client',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.mutedForeground)),
            const Spacer(),
            AppBadge(text: order.client, variant: BadgeVariant.secondary),
          ],
        ),
      ],
    );
  }

  // ==========================================================
  // Step 2 — Photos
  // ==========================================================

  Widget _buildStep2Photos(AppColors colors) {
    final order = widget.order;
    final hasRequired = order.photoLivDebut || order.photoLivFin;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoCard(
          colors: colors,
          icon: Icons.camera_alt_outlined,
          iconColor: colors.chart4,
          children: [
            Text(
              'Photos de livraison',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.foreground,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              hasRequired
                  ? 'Des photos sont demandées pour cette livraison'
                  : 'Aucune photo requise — vous pouvez passer cette étape',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.mutedForeground),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.base),

        if (_photos.isNotEmpty) ...[
          Text(
            '${_photos.length} photo(s)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: colors.foreground,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: _photos.asMap().entries.map((entry) {
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Image.memory(
                      base64Decode(entry.value),
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => setState(() => _photos.removeAt(entry.key)),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: colors.destructive,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close,
                            size: 14, color: colors.destructiveForeground),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.base),
        ],

        if (_photos.isEmpty)
          AppEmptyState(
            icon: Icons.add_a_photo_outlined,
            title: 'Aucune photo pour le moment',
          ),
        const SizedBox(height: AppSpacing.md),

        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: colors.infoBg,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 20, color: colors.info),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'La prise de photo sera disponible via la caméra de l\'appareil',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.info),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // Step 3 — Validation
  // ==========================================================

  Widget _buildStep3Validation(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoCard(
          colors: colors,
          icon: Icons.check_circle_outline,
          iconColor: colors.success,
          children: [
            Text(
              'Valider la livraison',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.foreground,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Renseignez les informations de livraison',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.mutedForeground),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.base),

        AppTextField(
          controller: _nomReceptController,
          label: 'Nom du réceptionnaire',
          hint: 'Personne qui réceptionne la marchandise',
          prefixIcon: const Icon(Icons.person_outline, size: 18),
        ),
        const SizedBox(height: AppSpacing.base),

        Row(
          children: [
            Expanded(
              child: _buildTimeField(
                colors: colors,
                label: 'Arrivée sur site',
                time: _heureArrivee,
                onTap: () => _pickTime(isArrivee: true),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildTimeField(
                colors: colors,
                label: 'Départ du site',
                time: _heureDepart,
                onTap: () => _pickTime(isArrivee: false),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        Row(
          children: [
            Text(
              'Signature',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colors.foreground,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _openSignatureFullscreen,
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                alignment: Alignment.center,
                child: Row(
                  children: [
                    Icon(Icons.fullscreen, size: 20, color: colors.primary),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Plein écran',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.primary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: colors.foreground.withValues(alpha: 0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: colors.foreground.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Signature(
              controller: _signatureController,
              backgroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Dessinez votre signature ci-dessus',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.mutedForeground),
            ),
            GestureDetector(
              onTap: () => _signatureController.clear(),
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                alignment: Alignment.center,
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 20, color: colors.mutedForeground),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Effacer',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.mutedForeground),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeField({
    required AppColors colors,
    required String label,
    required DateTime time,
    required VoidCallback onTap,
  }) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.foreground)),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time,
                    size: 20, color: colors.mutedForeground),
                const SizedBox(width: AppSpacing.sm),
                Text('$hh:$mm',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.foreground)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickTime({required bool isArrivee}) async {
    final current = isArrivee ? _heureArrivee : _heureDepart;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (picked == null || !mounted) return;

    final updated = DateTime(
      current.year, current.month, current.day, picked.hour, picked.minute,
    );
    setState(() {
      if (isArrivee) {
        _heureArrivee = updated;
      } else {
        _heureDepart = updated;
      }
    });
  }

  // ==========================================================
  // Bottom Bar
  // ==========================================================

  Widget _buildBottomBar(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: AppButton(
                  text: 'Précédent',
                  variant: ButtonVariant.outline,
                  onPressed: _previousStep,
                  icon: Icons.arrow_back,
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _currentStep == 2
                  ? AppButton(
                      text: 'Valider la livraison',
                      icon: Icons.check,
                      onPressed: _validate,
                    )
                  : _currentStep == 1
                      ? AppButton(
                          text: _photos.isEmpty ? 'Passer' : 'Suivant',
                          icon: Icons.arrow_forward,
                          onPressed:
                              _photos.isEmpty ? _nextStep : _sendPhotos,
                        )
                      : AppButton(
                          text: 'Suivant',
                          icon: Icons.arrow_forward,
                          onPressed: _nextStep,
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // Shared
  // ==========================================================

  void _launchPhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.isNotEmpty) launchUrl(Uri.parse('tel:$cleaned'));
  }

  void _launchMaps(String address) {
    final encoded = Uri.encodeComponent(address);
    launchUrl(
      Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded'),
      mode: LaunchMode.externalApplication,
    );
  }

  Widget _buildActionChip(
    AppColors colors,
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: AppSpacing.sm),
            Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required AppColors colors,
    required IconData icon,
    Color? iconColor,
    required List<Widget> children,
  }) {
    final color = iconColor ?? colors.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}
