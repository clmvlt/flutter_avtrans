import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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

/// Flux de chargement / enlèvement en 3 étapes :
/// 1. Chargement — voir les infos + gérer les colis
/// 2. Photos — prendre des photos (optionnel)
/// 3. Validation — signature, nom remettant, dates
class YpsiumEnlevementFlowScreen extends StatefulWidget {
  final YpsiumTransportOrder order;

  const YpsiumEnlevementFlowScreen({super.key, required this.order});

  @override
  State<YpsiumEnlevementFlowScreen> createState() =>
      _YpsiumEnlevementFlowScreenState();
}

class _YpsiumEnlevementFlowScreenState
    extends State<YpsiumEnlevementFlowScreen> with WidgetsBindingObserver {
  int _currentStep = 0;
  bool _isLoading = false;
  bool _isInFullscreenSignature = false;
  bool _dismissedFullscreen = false;
  String? _errorMessage;

  // Step 1 — Colis
  final List<_ColisEntry> _colisList = [];

  // Step 2 — Photos (base64)
  final List<String> _photos = [];

  // Step 3 — Validation
  final _nomRemettantController = TextEditingController();
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
    _nomRemettantController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final size = WidgetsBinding.instance.platformDispatcher.views.first.physicalSize;
    final isLandscape = size.width > size.height;

    // Reset le flag quand on repasse en portrait
    if (!isLandscape) {
      _dismissedFullscreen = false;
    }

    // Auto-open fullscreen signature quand on tourne en paysage sur l'étape 3
    if (_currentStep == 2 && isLandscape && !_isInFullscreenSignature && !_dismissedFullscreen) {
      _isInFullscreenSignature = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openSignatureFullscreen();
      });
    }
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

  /// Ajouter un colis au chargement via l'API
  Future<void> _addColis(_ColisEntry entry) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final session = sl.ypsiumAuthRepository.currentSession!;
    final result = await sl.ypsiumTransportRepository.addColisChargement(
      idOrdre: widget.order.idOrdre,
      request: YpsiumAddColisRequest(
        codeBarre: entry.codeBarre,
        refArticle: entry.refArticle,
        designation: entry.designation,
        quantite: entry.quantite,
        dhChargement: DateTime.now().toIso8601String(),
        codeChauffeur: session.login,
      ),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    result.fold(
      (failure) => setState(() => _errorMessage = failure.message),
      (success) {
        if (success) {
          setState(() => _colisList.add(entry));
        } else {
          setState(() => _errorMessage = "Erreur lors de l'ajout du colis");
        }
      },
    );
  }

  /// Prendre une photo via la caméra
  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );
    if (image == null || !mounted) return;

    final bytes = await image.readAsBytes();
    setState(() => _photos.add(base64Encode(bytes)));
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

    final result = await sl.ypsiumTransportRepository.setPhotoEnlDepart(
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

  /// Valider l'enlèvement (step 3)
  Future<void> _validate() async {
    if (_nomRemettantController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Veuillez renseigner le nom du remettant');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Exporter la signature si dessinée
    String? signatureBase64;
    if (_signatureController.isNotEmpty) {
      final Uint8List? bytes = await _signatureController.toPngBytes();
      if (bytes != null) {
        signatureBase64 = base64Encode(bytes);
      }
    }

    final result = await sl.ypsiumTransportRepository.setPointEnleve(
      idOrdre: widget.order.idOrdre,
      request: YpsiumSetPointEnleveRequest(
        nomRemettant: _nomRemettantController.text.trim(),
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
          const SnackBar(content: Text('Enlèvement validé avec succès')),
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
          'Enlèvement #${widget.order.idOrdre}',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: colors.foreground,
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: LoadingOverlay(
        isLoading: _isLoading,
        child: Column(
          children: [
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
                    if (_currentStep == 0) _buildStep1Chargement(colors),
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
      ),
    );
  }

  // ==========================================================
  // Step 1 — Chargement
  // ==========================================================

  Widget _buildStep1Chargement(AppColors colors) {
    final order = widget.order;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Infos enlèvement
        _buildInfoCard(
          colors: colors,
          icon: Icons.upload_outlined,
          iconColor: colors.info,
          children: [
            Text(
              order.eNom,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.foreground,
              ),
            ),
            if (order.eAdresseComplete.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                order.eAdresseComplete,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.mutedForeground),
              ),
            ],
            if (order.eHeureFormatted.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(Icons.access_time, size: 20, color: colors.mutedForeground),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    order.eHeureFormatted,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.foreground),
                  ),
                ],
              ),
            ],
            if (order.eTelephone1.isNotEmpty || order.eAdresseComplete.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  if (order.eTelephone1.isNotEmpty)
                    _buildActionIcon(colors, Icons.phone, colors.success,
                        () => _launchPhone(order.eTelephone1)),
                  if (order.eTelephone1.isNotEmpty && order.eAdresseComplete.isNotEmpty)
                    const SizedBox(width: AppSpacing.sm),
                  if (order.eAdresseComplete.isNotEmpty)
                    _buildActionIcon(colors, Icons.navigation, colors.info,
                        () => _launchMaps(order.eAdresseComplete)),
                ],
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.base),

        // Client
        Row(
          children: [
            Text(
              'Client',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.mutedForeground),
            ),
            const Spacer(),
            AppBadge(text: order.client, variant: BadgeVariant.secondary),
          ],
        ),
        const SizedBox(height: AppSpacing.base),

        // Liste des colis ajoutés
        Row(
          children: [
            Text(
              'Colis chargés',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: colors.foreground,
              ),
            ),
            const Spacer(),
            AppBadge(
              text: '${_colisList.length}',
              variant: BadgeVariant.secondary,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        if (_colisList.isEmpty)
          AppEmptyState(
            icon: Icons.inbox_outlined,
            title: 'Aucun colis ajouté',
          )
        else
          ..._colisList.asMap().entries.map(
                (entry) => _buildColisCard(entry.key, entry.value, colors),
              ),

        const SizedBox(height: AppSpacing.md),
        AppButton(
          text: 'Ajouter un colis',
          icon: Icons.add,
          variant: ButtonVariant.outline,
          onPressed: () => _showAddColisSheet(colors),
        ),
      ],
    );
  }

  Widget _buildColisCard(int index, _ColisEntry colis, AppColors colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.success,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${colis.designation} (${colis.refArticle})',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.foreground,
                  ),
                ),
                Text(
                  'Qté: ${colis.quantite}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.mutedForeground),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle, size: 18, color: colors.success),
        ],
      ),
    );
  }

  void _showAddColisSheet(AppColors colors) {
    final refController = TextEditingController(text: 'COLIS');
    final desController = TextEditingController(text: 'COLIS');
    final qtyController = TextEditingController(text: '1');
    final cbController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Ajouter un colis',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.foreground,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, size: 20, color: colors.mutedForeground),
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.base),
            AppTextField(
              controller: cbController,
              label: 'Code-barres',
              hint: 'Scanner ou saisir (optionnel)',
              prefixIcon: const Icon(Icons.qr_code, size: 18),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: refController,
                    label: 'Référence',
                    hint: 'COLIS',
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppTextField(
                    controller: qtyController,
                    label: 'Quantité',
                    hint: '1',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: desController,
              label: 'Désignation',
              hint: 'Description du colis',
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              text: 'Ajouter',
              icon: Icons.add,
              onPressed: () {
                Navigator.of(ctx).pop();
                _addColis(_ColisEntry(
                  codeBarre: cbController.text,
                  refArticle: refController.text,
                  designation: desController.text,
                  quantite: int.tryParse(qtyController.text) ?? 1,
                ));
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // Step 2 — Photos
  // ==========================================================

  Widget _buildStep2Photos(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Photos',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: colors.foreground,
          ),
        ),
        const SizedBox(height: AppSpacing.base),

        if (_photos.isNotEmpty) ...[
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
                        child: Icon(
                          Icons.close,
                          size: 14,
                          color: colors.destructiveForeground,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.base),
        ],

        // Placeholder when no photos
        if (_photos.isEmpty)
          AppEmptyState(
            icon: Icons.add_a_photo_outlined,
            title: 'Aucune photo pour le moment',
          ),
        const SizedBox(height: AppSpacing.md),

        AppButton(
          text: 'Prendre une photo',
          icon: Icons.camera_alt,
          variant: ButtonVariant.outline,
          onPressed: _takePhoto,
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
        AppTextField(
          controller: _nomRemettantController,
          label: 'Remettant',
          hint: 'Nom de la personne',
          prefixIcon: const Icon(Icons.person_outline, size: 18),
        ),
        const SizedBox(height: AppSpacing.sm),

        Row(
          children: [
            Expanded(
              child: _buildTimeField(
                colors: colors,
                label: 'Arrivée',
                time: _heureArrivee,
                onTap: () => _pickTime(isArrivee: true),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _buildTimeField(
                colors: colors,
                label: 'Départ',
                time: _heureDepart,
                onTap: () => _pickTime(isArrivee: false),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

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
              onTap: () => _signatureController.clear(),
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                alignment: Alignment.center,
                child: Icon(Icons.refresh, size: 20, color: colors.mutedForeground),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            GestureDetector(
              onTap: _openSignatureFullscreen,
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                alignment: Alignment.center,
                child: Icon(Icons.fullscreen, size: 20, color: colors.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          height: 300,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: colors.foreground.withValues(alpha: 0.3), width: 1.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Signature(
              controller: _signatureController,
              backgroundColor: Colors.white,
            ),
          ),
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
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time, size: 18, color: colors.mutedForeground),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '$label  $hh:$mm',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.foreground),
            ),
          ],
        ),
      ),
    );
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

  Future<void> _pickTime({required bool isArrivee}) async {
    final current = isArrivee ? _heureArrivee : _heureDepart;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (picked == null || !mounted) return;

    final updated = DateTime(
      current.year,
      current.month,
      current.day,
      picked.hour,
      picked.minute,
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
        boxShadow: [
          BoxShadow(
            color: colors.foreground.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: AppButton(
                  text: 'Retour',
                  variant: ButtonVariant.outline,
                  onPressed: _previousStep,
                  icon: Icons.arrow_back,
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _currentStep == 2
                  ? AppButton(
                      text: 'Valider',
                      icon: Icons.check,
                      onPressed: _validate,
                    )
                  : _currentStep == 1
                      ? AppButton(
                          text: _photos.isEmpty ? 'Passer' : 'Envoyer (${_photos.length})',
                          icon: Icons.arrow_forward,
                          onPressed: _photos.isEmpty ? _nextStep : _sendPhotos,
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

  Widget _buildActionIcon(
    AppColors colors,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, size: 20, color: color),
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

/// Entrée de colis locale (avant envoi API)
class _ColisEntry {
  final String codeBarre;
  final String refArticle;
  final String designation;
  final int quantite;

  const _ColisEntry({
    this.codeBarre = '',
    required this.refArticle,
    required this.designation,
    this.quantite = 1,
  });
}
