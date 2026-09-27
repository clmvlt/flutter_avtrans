import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/display_format.dart';
import '../../../data/models/ypsium_models.dart';
import '../../widgets/widgets.dart';
import 'widgets/ypsium_colis_widgets.dart';
import 'widgets/ypsium_dock_lines.dart';
import 'widgets/ypsium_flow_hero.dart';
import 'widgets/ypsium_flow_steps.dart';
import 'widgets/ypsium_photo_section.dart';
import 'widgets/ypsium_signature_form.dart';
import 'ypsium_signature_fullscreen.dart';

/// Parcours d'enlèvement en 3 étapes :
/// 1. Chargement — voir les infos + gérer les colis
/// 2. Photos — prendre des photos (optionnel)
/// 3. Validation — signature, nom remettant, dates
///
/// Le hero dit l'étape en cours, le bouton du dock dit l'étape suivante et
/// un lien au-dessus permet de revenir en arrière. Les erreurs s'affichent
/// dans le dock.
class YpsiumEnlevementFlowScreen extends StatefulWidget {
  final YpsiumTransportOrder order;

  const YpsiumEnlevementFlowScreen({super.key, required this.order});

  @override
  State<YpsiumEnlevementFlowScreen> createState() =>
      _YpsiumEnlevementFlowScreenState();
}

class _YpsiumEnlevementFlowScreenState
    extends State<YpsiumEnlevementFlowScreen>
    with WidgetsBindingObserver, DockNoticeMixin {
  static const _steps = ['Chargement', 'Photos', 'Signature'];
  static const _stepIcons = [
    Icons.inventory_2_rounded,
    Icons.photo_camera_rounded,
    Icons.draw_rounded,
  ];

  int _currentStep = 0;
  bool _isLoading = false;
  bool _isInFullscreenSignature = false;
  bool _dismissedFullscreen = false;

  // Step 1 — Colis
  final List<YpsiumColisEntry> _colisList = [];

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
    // Encre noire exportée sur fond blanc : données de la signature, pas
    // des couleurs d'interface.
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
      clearDockNotice();
      setState(() => _currentStep++);
      if (_currentStep == 2) {
        _heureDepart = DateTime.now();
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      clearDockNotice();
      setState(() => _currentStep--);
    }
  }

  Future<void> _openAddColis() async {
    final entry = await YpsiumAddColisSheet.show(context);
    if (entry == null || !mounted) return;
    _addColis(entry);
  }

  /// Ajouter un colis au chargement via l'API
  Future<void> _addColis(YpsiumColisEntry entry) async {
    clearDockNotice();
    setState(() => _isLoading = true);

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
      (failure) => showDockError(failure.message),
      (success) {
        if (success) {
          setState(() => _colisList.add(entry));
        } else {
          showDockError('Erreur lors de l\'ajout du colis');
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
    if (!mounted) return;
    setState(() => _photos.add(base64Encode(bytes)));
  }

  /// Envoyer les photos (step 2)
  Future<void> _sendPhotos() async {
    if (_photos.isEmpty) {
      _nextStep();
      return;
    }

    clearDockNotice();
    setState(() => _isLoading = true);

    final result = await sl.ypsiumTransportRepository.setPhotoEnlDepart(
      idOrdre: widget.order.idOrdre,
      photosBase64: _photos,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    result.fold(
      (failure) => showDockError(failure.message),
      (_) => _nextStep(),
    );
  }

  /// Valider l'enlèvement (step 3)
  Future<void> _validate() async {
    if (_nomRemettantController.text.trim().isEmpty) {
      showDockError('Renseigne le nom du remettant');
      return;
    }

    clearDockNotice();
    setState(() => _isLoading = true);

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
      (failure) => showDockError(failure.message),
      // Le succès se voit sur l'accueil (notice du dock et liste à jour).
      (_) => Navigator.of(context).pop(true),
    );
  }

  void _openSignatureFullscreen() async {
    _isInFullscreenSignature = true;
    // Navigator racine : le vrai plein écran passe au-dessus de la tab bar.
    await Navigator.of(context, rootNavigator: true).push(
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
  // Build
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Enlèvement #${widget.order.idOrdre}',
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: AbsorbPointer(
          absorbing: _isLoading,
          child: AppScrollView(
            children: [
              YpsiumFlowHero(
                steps: _steps,
                current: _currentStep,
                icon: _stepIcons[_currentStep],
                detail: widget.order.client,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_currentStep == 0)
                YpsiumChargementStep(
                  order: widget.order,
                  colis: _colisList,
                  onAddColis: _openAddColis,
                  onCall: _launchPhone,
                  onMaps: widget.order.eAdresseComplete.isNotEmpty
                      ? () => _launchMaps(widget.order.eAdresseComplete)
                      : null,
                ),
              if (_currentStep == 1)
                YpsiumPhotoSection(
                  photos: _photos,
                  onAdd: _takePhoto,
                  onRemove: (i) => setState(() => _photos.removeAt(i)),
                ),
              if (_currentStep == 2)
                YpsiumSignatureForm(
                  nameController: _nomRemettantController,
                  nameLabel: 'Nom du remettant',
                  arrivee: _heureArrivee,
                  depart: _heureDepart,
                  onPickArrivee: () => _pickTime(isArrivee: true),
                  onPickDepart: () => _pickTime(isArrivee: false),
                  signatureController: _signatureController,
                  onClearSignature: () => _signatureController.clear(),
                  onFullscreen: _openSignatureFullscreen,
                ),
            ],
          ),
        ),
      ),
      dock: _buildDock(),
    );
  }

  /// Le bouton dit toujours l'étape suivante ; le lien au-dessus revient à
  /// l'étape précédente.
  Widget _buildDock() {
    final DockAction action;
    switch (_currentStep) {
      case 0:
        action = DockAction(
          label: 'Passer aux photos',
          icon: Icons.arrow_forward_rounded,
          onPressed: _nextStep,
        );
      case 1:
        action = _photos.isEmpty
            ? DockAction(
                label: 'Passer à la signature',
                icon: Icons.arrow_forward_rounded,
                onPressed: _nextStep,
              )
            : DockAction(
                label: 'Envoyer ${DisplayFormat.plural(_photos.length, 'photo')}',
                icon: Icons.send_rounded,
                isLoading: _isLoading,
                onPressed: _sendPhotos,
              );
      default:
        action = DockAction(
          label: 'Valider l\'enlèvement',
          icon: Icons.check_rounded,
          tone: DockTone.success,
          isLoading: _isLoading,
          onPressed: _validate,
        );
    }

    Widget? status;
    if (_isLoading && _currentStep == 0) {
      status = const YpsiumBusyLine(text: 'Ajout du colis…');
    } else if (_currentStep > 0) {
      status = YpsiumBackLink(
        label: _currentStep == 1 ? 'Revenir aux colis' : 'Revenir aux photos',
        onPressed: _previousStep,
      );
    }

    return AppDock(
      actions: [action],
      status: status,
      notice: dockNotice,
      onDismissNotice: clearDockNotice,
      absorbing: _isLoading,
      bottomGap: AppSpacing.lg,
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
}
