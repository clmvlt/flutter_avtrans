import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/services/address_ocr_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_card.dart';

/// Bloc caméra **live** intégré à la page de tournée.
///
/// La caméra reste active tant que la page est ouverte et analyse le flux en
/// temps réel (ML Kit on-device). Dès qu'une adresse est reconnue, elle est
/// proposée ; un appui sur « Ajouter cette adresse » déclenche [onConfirm]
/// (le parent ouvre la confirmation geocoding puis ajoute l'arrêt).
///
/// L'analyse est suspendue pendant l'exécution de [onConfirm], puis reprend.
class LiveAddressScanner extends StatefulWidget {
  const LiveAddressScanner({super.key, required this.onConfirm});

  /// Appelé avec la requête d'adresse détectée. Le `Future` est attendu :
  /// l'analyse reprend une fois terminé.
  final Future<void> Function(String query) onConfirm;

  @override
  State<LiveAddressScanner> createState() => _LiveAddressScannerState();
}

enum _ScannerStatus { initializing, ready, denied, error }

class _LiveAddressScannerState extends State<LiveAddressScanner>
    with WidgetsBindingObserver {
  static const Duration _minInterval = Duration(milliseconds: 500);
  static const double _previewHeight = 220;

  // Zone de scan active (fractions de l'image redressée). Doit correspondre au
  // viseur blanc : seul le texte dont le centre tombe dedans est analysé, pour
  // éviter de lire des adresses hors champ.
  static const double _roiLeft = 0.10;
  static const double _roiRight = 0.90;
  static const double _roiTop = 0.30;
  static const double _roiBottom = 0.70;

  // Anti-rebond : une adresse doit être détectée [_requiredHits] fois d'affilée
  // avant d'être proposée, et l'adresse affichée est maintenue au moins
  // [_holdDuration] avant de pouvoir être remplacée — sinon ça « clignote ».
  static const int _requiredHits = 2;
  static const Duration _holdDuration = Duration(milliseconds: 2500);

  static const Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  CameraController? _controller;
  CameraDescription? _camera;

  _ScannerStatus _status = _ScannerStatus.initializing;
  String? _errorMessage;

  bool _busy = false; // une frame est en cours d'analyse
  bool _paused = false; // analyse suspendue (confirmation ouverte)
  String? _candidate;
  DateTime _lastRun = DateTime.fromMillisecondsSinceEpoch(0);

  // État de l'anti-rebond.
  String? _pending; // dernière adresse détectée (pas encore validée)
  int _pendingHits = 0; // nombre de détections consécutives identiques
  DateTime _lastChange = DateTime.fromMillisecondsSinceEpoch(0);

  // Largeur réellement rendue de l'aperçu (mesurée au layout) — nécessaire pour
  // projeter le viseur écran vers les coordonnées image (recadrage cover).
  double? _previewWidth;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _paused = true;
    final controller = _controller;
    _controller = null;
    controller?.dispose();
    _recognizer.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (state == AppLifecycleState.resumed) {
      if (controller == null) _start();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _disposeController();
    }
  }

  Future<void> _disposeController() async {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      try {
        await controller.dispose();
      } catch (_) {/* déjà libérée */}
    }
  }

  Future<void> _start() async {
    if (mounted) {
      setState(() {
        _status = _ScannerStatus.initializing;
        _errorMessage = null;
      });
    }

    // Permission caméra (le plugin la demande aussi, mais on gère le refus).
    final permission = await Permission.camera.request();
    if (!mounted) return;
    if (!permission.isGranted) {
      setState(() => _status = _ScannerStatus.denied);
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _status = _ScannerStatus.error;
            _errorMessage = 'Aucune caméra disponible.';
          });
        }
        return;
      }

      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _camera = camera;

      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup:
            Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      _controller = controller;
      await controller.startImageStream(_onFrame);
      if (!mounted) return;
      setState(() => _status = _ScannerStatus.ready);
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _status = e.code == 'CameraAccessDenied'
            ? _ScannerStatus.denied
            : _ScannerStatus.error;
        _errorMessage = e.description;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _ScannerStatus.error;
        _errorMessage = 'Caméra indisponible.';
      });
    }
  }

  void _onFrame(CameraImage image) {
    if (_busy || _paused || !mounted) return;
    final now = DateTime.now();
    if (now.difference(_lastRun) < _minInterval) return;
    _lastRun = now;
    _busy = true;
    _process(image).whenComplete(() => _busy = false);
  }

  Future<void> _process(CameraImage image) async {
    final controller = _controller;
    final camera = _camera;
    if (controller == null || camera == null) return;

    final rotation = _rotation(controller, camera);
    if (rotation == null) return;

    final input = _toInputImage(image, rotation);
    if (input == null) return;

    try {
      final recognized = await _recognizer.processImage(input);
      if (!mounted || _paused) return;
      final roi = _viewfinderNormalizedRect(controller.value.previewSize);
      final imageSize = Size(image.width.toDouble(), image.height.toDouble());
      final lens = camera.lensDirection;
      final candidate = AddressOcrService.extractAddress(
        recognized,
        accept: roi == null
            ? null
            : (box) => roi.contains(
                  _normalizedCenter(box, imageSize, rotation, lens),
                ),
      );
      _updateCandidate(candidate);
    } catch (_) {
      // Erreur transitoire d'analyse d'une frame — on ignore.
    }
  }

  /// Met à jour l'adresse proposée avec anti-rebond (stabilité + maintien).
  void _updateCandidate(String candidate) {
    if (candidate.isEmpty) return; // on ne vide pas une adresse déjà affichée
    if (candidate == _candidate) {
      _pending = candidate;
      _pendingHits = 0;
      return;
    }

    if (candidate == _pending) {
      _pendingHits++;
    } else {
      _pending = candidate;
      _pendingHits = 1;
    }
    if (_pendingHits < _requiredHits) return;

    // L'adresse affichée est maintenue un minimum de temps avant de changer.
    if (_candidate != null &&
        DateTime.now().difference(_lastChange) < _holdDuration) {
      return;
    }

    setState(() => _candidate = candidate);
    _lastChange = DateTime.now();
    _pendingHits = 0;
  }

  /// Zone du viseur, exprimée en **fractions normalisées [0,1] de l'image
  /// affichée** (et non en pixels), pour pouvoir la comparer au centre normalisé
  /// des boîtes de texte.
  ///
  /// Le viseur blanc occupe les fractions [_roiLeft]..[_roiBottom] de l'aperçu
  /// **écran**. Comme l'aperçu est en `BoxFit.cover`, seule une bande centrale
  /// de l'image est visible : on convertit donc les fractions écran en fractions
  /// d'image en tenant compte de ce recadrage. Renvoie `null` tant que la
  /// largeur d'aperçu n'a pas été mesurée.
  Rect? _viewfinderNormalizedRect(Size? previewSize) {
    final dispW = _previewWidth;
    if (previewSize == null || dispW == null) return null;

    // Aperçu redressé en portrait (cf. le FittedBox du build).
    final childW = previewSize.height; // largeur affichée (px)
    final childH = previewSize.width; // hauteur affichée (px)
    const dispH = _previewHeight;

    // BoxFit.cover : on retient l'échelle qui couvre la boîte ; le reste déborde.
    final scale =
        (dispW / childW > dispH / childH) ? dispW / childW : dispH / childH;
    // Fraction de l'image réellement visible (l'autre axe vaut 1.0).
    final visW = (dispW / (childW * scale)).clamp(0.0, 1.0);
    final visH = (dispH / (childH * scale)).clamp(0.0, 1.0);
    final uLeft = 0.5 - visW / 2;
    final vTop = 0.5 - visH / 2;

    return Rect.fromLTRB(
      uLeft + _roiLeft * visW,
      vTop + _roiTop * visH,
      uLeft + _roiRight * visW,
      vTop + _roiBottom * visH,
    );
  }

  /// Centre de [box] en fractions normalisées [0,1] de l'image affichée.
  ///
  /// Le repère des boîtes ML Kit dépend de la plateforme et de la rotation
  /// (cf. `coordinates_translator.dart` officiel) : sur iOS la coordonnée X est
  /// rapportée à `imageSize.width`, sur Android à `imageSize.height` (et
  /// inversement pour Y). On reproduit exactement cette logique.
  Offset _normalizedCenter(
    Rect box,
    Size imageSize,
    InputImageRotation rotation,
    CameraLensDirection lens,
  ) {
    final cx = box.center.dx;
    final cy = box.center.dy;
    final iw = imageSize.width;
    final ih = imageSize.height;

    double u;
    double v;
    switch (rotation) {
      case InputImageRotation.rotation90deg:
        u = cx / (Platform.isIOS ? iw : ih);
        v = cy / (Platform.isIOS ? ih : iw);
        break;
      case InputImageRotation.rotation270deg:
        u = 1 - cx / (Platform.isIOS ? iw : ih);
        v = cy / (Platform.isIOS ? ih : iw);
        break;
      case InputImageRotation.rotation0deg:
      case InputImageRotation.rotation180deg:
        u = cx / iw;
        v = cy / ih;
        break;
    }
    return Offset(u.clamp(0.0, 1.0), v.clamp(0.0, 1.0));
  }

  InputImage? _toInputImage(CameraImage image, InputImageRotation rotation) {
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  InputImageRotation? _rotation(
    CameraController controller,
    CameraDescription camera,
  ) {
    final sensor = camera.sensorOrientation;
    if (Platform.isIOS) {
      return InputImageRotationValue.fromRawValue(sensor);
    }
    var compensation = _orientations[controller.value.deviceOrientation] ?? 0;
    if (camera.lensDirection == CameraLensDirection.front) {
      compensation = (sensor + compensation) % 360;
    } else {
      compensation = (sensor - compensation + 360) % 360;
    }
    return InputImageRotationValue.fromRawValue(compensation);
  }

  Future<void> _confirm() async {
    final candidate = _candidate;
    if (candidate == null || candidate.isEmpty) return;
    setState(() => _paused = true);
    await widget.onConfirm(candidate);
    if (!mounted) return;
    _pending = null;
    _pendingHits = 0;
    _lastChange = DateTime.fromMillisecondsSinceEpoch(0);
    setState(() {
      _candidate = null;
      _paused = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      clip: true,
      child: switch (_status) {
        _ScannerStatus.ready => _buildReady(context),
        _ScannerStatus.initializing => _buildPlaceholder(
            context,
            child: const CircularProgressIndicator(),
            label: 'Démarrage de la caméra…',
          ),
        _ScannerStatus.denied => _buildFallback(
            context,
            icon: Icons.no_photography_outlined,
            title: 'Caméra non autorisée',
            subtitle: 'Autorise l\'accès pour scanner les adresses.',
            actionLabel: 'Ouvrir les réglages',
            onAction: openAppSettings,
          ),
        _ScannerStatus.error => _buildFallback(
            context,
            icon: Icons.videocam_off_outlined,
            title: _errorMessage ?? 'Caméra indisponible',
            subtitle: 'Tu peux saisir les adresses manuellement.',
            actionLabel: 'Réessayer',
            onAction: _start,
          ),
      },
    );
  }

  Widget _buildReady(BuildContext context) {
    final colors = context.colors;
    final controller = _controller!;
    final preview = controller.value.previewSize;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _previewHeight,
          width: double.infinity,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Mémorise la largeur affichée pour le calcul de la ROI.
              _previewWidth = constraints.maxWidth;
              return Stack(
                fit: StackFit.expand,
                children: [
              if (preview != null)
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: preview.height,
                    height: preview.width,
                    child: CameraPreview(controller),
                  ),
                ),
              // Viseur de scan — délimite la zone réellement analysée (ROI).
              Center(
                child: FractionallySizedBox(
                  widthFactor: _roiRight - _roiLeft,
                  heightFactor: _roiBottom - _roiTop,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: AppSpacing.md,
                top: AppSpacing.md,
                child: _Pill(
                  icon: Icons.center_focus_strong_rounded,
                  label: 'Vise une adresse',
                ),
              ),
                ],
              );
            },
          ),
        ),
        Container(
          color: colors.card,
          padding: const EdgeInsets.all(AppSpacing.base),
          child: _buildStatus(context),
        ),
      ],
    );
  }

  Widget _buildStatus(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final candidate = _candidate;

    if (candidate == null || candidate.isEmpty) {
      return Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.mutedForeground,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Recherche d\'une adresse…',
              style: textTheme.bodyMedium
                  ?.copyWith(color: colors.mutedForeground),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.location_on_rounded, size: 20, color: colors.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                candidate,
                style: textTheme.titleSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          text: 'Ajouter cette adresse',
          icon: Icons.add_location_alt_outlined,
          size: ButtonSize.sm,
          onPressed: _paused ? null : _confirm,
        ),
      ],
    );
  }

  Widget _buildPlaceholder(
    BuildContext context, {
    required Widget child,
    required String label,
  }) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      height: _previewHeight,
      color: colors.surfaceSunken,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          child,
          const SizedBox(height: AppSpacing.md),
          Text(label, style: textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildFallback(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      color: colors.surfaceSunken,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: colors.mutedForeground),
          const SizedBox(height: AppSpacing.sm),
          Text(title, style: textTheme.titleSmall, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            style: textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            text: actionLabel,
            variant: ButtonVariant.secondary,
            size: ButtonSize.sm,
            fullWidth: false,
            onPressed: onAction,
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
