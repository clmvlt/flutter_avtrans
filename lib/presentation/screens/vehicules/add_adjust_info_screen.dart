import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/vehicule_model.dart';
import '../../widgets/widgets.dart';

/// Écran pour ajouter des informations d'ajustement sur un véhicule
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

class _AddAdjustInfoScreenState extends State<AddAdjustInfoScreen> {
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

      if (image != null) {
        setState(() {
          _images.add(File(image.path));
        });
      }
    } catch (e) {
      _showError('Erreur lors de la sélection de l\'image');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  Future<void> _submit() async {
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
          setState(() => _isSubmitting = false);
          _showError('Erreur lors de la lecture des images');
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
        _showError(failure.message);
      },
      (adjustInfo) {
        Navigator.of(context).pop(true);
      },
    );
  }

  void _showError(String message) {
    final colors = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: colors.destructive, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: colors.card,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.base),
          side: BorderSide(color: colors.destructive),
        ),
      ),
    );
  }

  void _showImageSourceBottomSheet() {
    final colors = context.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.base),
                alignment: Alignment.center,
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Ajouter une photo',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colors.foreground,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.base),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.base),
                  ),
                  child: Icon(Icons.camera_alt, color: colors.primary),
                ),
                title: Text(
                  'Prendre une photo',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: colors.foreground,
                  ),
                ),
                subtitle: Text(
                  'Utiliser l\'appareil photo',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.mutedForeground),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: colors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.base),
                  ),
                  child: Icon(Icons.photo_library, color: colors.info),
                ),
                title: Text(
                  'Choisir depuis la galerie',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: colors.foreground,
                  ),
                ),
                subtitle: Text(
                  'Sélectionner une image existante',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.mutedForeground),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(widget.vehiculeImmat ?? 'Ajouter des informations'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildInfoCard(colors),
              const SizedBox(height: AppSpacing.lg),
              _buildCommentField(colors),
              const SizedBox(height: AppSpacing.lg),
              _buildImageSection(colors),
              const SizedBox(height: AppSpacing.lg),
              _buildSubmitButton(colors),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(AppColors colors) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: colors.warningMuted,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.warning),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: colors.warning, size: 22),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Signaler un ajustement',
                  style: textTheme.titleMedium?.copyWith(
                    color: colors.foreground,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Décrivez le problème ou l\'ajustement nécessaire pour ce véhicule. Vous pouvez ajouter des photos pour illustrer.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentField(AppColors colors) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description',
          style: textTheme.titleSmall?.copyWith(
            color: colors.foreground,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: _commentController,
          maxLines: 5,
          style: textTheme.bodyMedium?.copyWith(
            color: colors.foreground,
          ),
          decoration: InputDecoration(
            hintText: 'Décrivez le problème ou l\'ajustement nécessaire...',
            hintStyle: TextStyle(
              color: colors.mutedForeground,
            ),
            filled: true,
            fillColor: colors.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.base),
              borderSide: BorderSide(color: colors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.base),
              borderSide: BorderSide(color: colors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.base),
              borderSide: BorderSide(color: colors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.base),
              borderSide: BorderSide(color: colors.destructive),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.base),
              borderSide: BorderSide(color: colors.destructive, width: 2),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Veuillez saisir une description';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildImageSection(AppColors colors) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Photos',
              style: textTheme.titleSmall?.copyWith(
                color: colors.foreground,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: colors.muted,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                'Optionnel',
                style: textTheme.labelSmall?.copyWith(
                  color: colors.mutedForeground,
                ),
              ),
            ),
            const Spacer(),
            Text(
              '${_images.length}/5',
              style: textTheme.bodySmall?.copyWith(
                color: colors.mutedForeground,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            ..._images.asMap().entries.map((entry) {
              final index = entry.key;
              final image = entry.value;
              return _buildImageTile(image, index, colors);
            }),
            if (_images.length < 5) _buildAddImageTile(colors),
          ],
        ),
      ],
    );
  }

  Widget _buildImageTile(File image, int index, AppColors colors) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Image.file(
            image,
            width: 100,
            height: 100,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _removeImage(index),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colors.destructive,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.close,
                color: colors.primaryForeground,
                size: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddImageTile(AppColors colors) {
    return GestureDetector(
      onTap: _showImageSourceBottomSheet,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: colors.border,
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              color: colors.primary,
              size: 32,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Ajouter',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton(AppColors colors) {
    return AppButton(
      text: 'Envoyer l\'information',
      icon: Icons.send,
      onPressed: _submit,
      isLoading: _isSubmitting,
      backgroundColor: colors.warning,
      foregroundColor: colors.primaryForeground,
    );
  }
}
