import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/vehicule_model.dart';
import '../../widgets/widgets.dart';
import 'widgets/adjust_photo_grid.dart';

/// Écran pour ajouter des informations d'ajustement sur un véhicule
/// (description + jusqu'à 5 photos envoyées en base64). Ouvert en
/// `fullscreenDialog` depuis la fiche ; retourne `true` une fois envoyé.
class AddAdjustInfoScreen extends StatefulWidget {
  final String vehiculeId;
  final String? vehiculeImmat;

  const AddAdjustInfoScreen({
    super.key,
    required this.vehiculeId,
    this.vehiculeImmat,
  });

  @override
  State<AddAdjustInfoScreen> createState() => _AddAdjustInfoScreenState();
}

class _AddAdjustInfoScreenState extends State<AddAdjustInfoScreen>
    with DockNoticeMixin {
  static const int _maxImages = 5;

  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();
  final List<File> _images = [];
  bool _isSubmitting = false;
  final _imagePicker = ImagePicker();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image == null || !mounted) return;
      setState(() => _images.add(File(image.path)));
    } catch (e) {
      if (!mounted) return;
      showDockError('Impossible de récupérer l\'image');
    }
  }

  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
  }

  Future<void> _chooseImageSource() async {
    clearDockNotice();
    FocusScope.of(context).unfocus();
    final source = await AppSheet.show<ImageSource>(
      context,
      title: 'Ajouter une photo',
      builder: (ctx) {
        final colors = ctx.colors;
        const padding = EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.sm,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppListRow(
              icon: Icons.photo_camera_rounded,
              iconColor: colors.primary,
              title: 'Prendre une photo',
              subtitle: 'Utiliser l\'appareil photo',
              padding: padding,
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            AppListRow(
              icon: Icons.photo_library_rounded,
              iconColor: colors.info,
              title: 'Choisir dans la galerie',
              subtitle: 'Une image déjà sur le téléphone',
              padding: padding,
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
          ],
        );
      },
    );
    if (source == null || !mounted) return;
    await _pickImage(source);
  }

  Future<void> _submit() async {
    clearDockNotice();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    // Convertir les images en base64
    List<String>? picturesB64;
    if (_images.isNotEmpty) {
      picturesB64 = [];
      for (final image in _images) {
        try {
          final bytes = await image.readAsBytes();
          final base64String = base64Encode(bytes);
          // Déterminer le type MIME
          final extension = image.path.split('.').last.toLowerCase();
          String mimeType = 'image/jpeg';
          if (extension == 'png') {
            mimeType = 'image/png';
          } else if (extension == 'jpg' || extension == 'jpeg') {
            mimeType = 'image/jpeg';
          }
          picturesB64.add('data:$mimeType;base64,$base64String');
        } catch (e) {
          if (!mounted) return;
          setState(() => _isSubmitting = false);
          showDockError('Impossible de lire les photos');
          return;
        }
      }
    }

    final request = CreateAdjustInfoRequest(
      vehiculeId: widget.vehiculeId,
      comment: _commentController.text.trim(),
      picturesB64: picturesB64,
    );

    final result = await sl.vehiculeRepository.createAdjustInfo(request);

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() => _isSubmitting = false);
        showDockError(failure.message);
      },
      (_) => Navigator.of(context).pop(true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppPage(
      title: 'Ajouter des informations',
      body: Form(
        key: _formKey,
        child: AppScrollView(
          children: [
            _IntroCard(immat: widget.vehiculeImmat),
            const SizedBox(height: AppSpacing.lg),
            const AppFieldLabel('Description'),
            TextFormField(
              controller: _commentController,
              enabled: !_isSubmitting,
              minLines: 4,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              style: textTheme.bodyLarge,
              decoration: const InputDecoration(
                hintText: 'Décris le problème ou l\'ajustement nécessaire…',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Saisis une description';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(child: AppFieldLabel('Photos', optional: true)),
                Text(
                  '${_images.length}/$_maxImages',
                  style: textTheme.bodySmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            AdjustPhotoGrid(
              images: _images,
              maxPhotos: _maxImages,
              onAdd: _chooseImageSource,
              onRemove: _removeImage,
              enabled: !_isSubmitting,
            ),
          ],
        ),
      ),
      dock: AppDock(
        actions: [
          DockAction(
            label: 'Envoyer l\'information',
            icon: Icons.send_rounded,
            isLoading: _isSubmitting,
            onPressed: _isSubmitting ? null : _submit,
          ),
        ],
        notice: dockNotice,
        onDismissNotice: clearDockNotice,
        absorbing: _isSubmitting,
      ),
    );
  }
}

/// Rappel du véhicule concerné et de ce qu'on attend.
class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.immat});

  final String? immat;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      child: Row(
        children: [
          AppIconBox(
            icon: Icons.directions_car_rounded,
            color: colors.domainVehicule,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (immat != null && immat!.isNotEmpty)
                  Text(immat!, style: textTheme.titleSmall),
                Text(
                  'Signale un problème ou un ajustement nécessaire. '
                  'Tu peux ajouter jusqu\'à 5 photos.',
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
