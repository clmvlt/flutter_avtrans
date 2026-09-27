import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/vehicule_model.dart';
import '../../widgets/widgets.dart';
import 'widgets/file_type_visual.dart';

/// Feuille « Ajouter un fichier » d'un véhicule : choix de la source
/// (appareil photo, galerie, fichiers), aperçu du fichier choisi, puis envoi
/// en base64 (`uploadVehiculeFile`).
abstract final class UploadVehiculeFileSheet {
  /// Retourne `true` si un fichier a été envoyé.
  static Future<bool> show(
    BuildContext context, {
    required String vehiculeId,
  }) async {
    final uploaded = await AppSheet.show<bool>(
      context,
      title: 'Ajouter un fichier',
      builder: (_) => _UploadForm(vehiculeId: vehiculeId),
    );
    return uploaded ?? false;
  }
}

class _UploadForm extends StatefulWidget {
  const _UploadForm({required this.vehiculeId});

  final String vehiculeId;

  @override
  State<_UploadForm> createState() => _UploadFormState();
}

class _UploadFormState extends State<_UploadForm> {
  File? _selectedFile;
  String? _fileName;
  String? _mimeType;
  bool _isLoading = false;
  String? _error;
  final _imagePicker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    setState(() => _error = null);
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image == null || !mounted) return;
      setState(() {
        _selectedFile = File(image.path);
        _fileName = image.name;
        _mimeType = _getMimeType(image.name);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Impossible de récupérer l\'image');
    }
  }

  Future<void> _pickFile() async {
    setState(() => _error = null);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
      );
      if (!mounted) return;
      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
          _fileName = result.files.single.name;
          _mimeType = _getMimeType(result.files.single.name);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Impossible de récupérer le fichier');
    }
  }

  String _getMimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _submit() async {
    if (_selectedFile == null || _fileName == null || _mimeType == null) {
      setState(() => _error = 'Choisis d\'abord un fichier');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final bytes = await _selectedFile!.readAsBytes();
      final base64String = base64Encode(bytes);

      final request = UploadVehiculeFileRequest(
        fileB64: base64String,
        originalName: _fileName!,
        mimeType: _mimeType!,
      );

      final result = await sl.vehiculeRepository.uploadVehiculeFile(
        widget.vehiculeId,
        request,
      );

      if (!mounted) return;

      result.fold(
        (failure) => setState(() {
          _isLoading = false;
          _error = failure.message;
        }),
        (_) => Navigator.of(context).pop(true),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Envoi impossible : $e';
      });
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedFile = null;
      _fileName = null;
      _mimeType = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _selectedFile == null ? _buildSources(context) : _buildSelected();
  }

  /// Étape 1 : choisir la source.
  Widget _buildSources(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    const rowPadding = EdgeInsets.symmetric(
      horizontal: AppSpacing.xs,
      vertical: AppSpacing.sm,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Photo, PDF ou document Word.',
          style: textTheme.bodyMedium?.copyWith(color: colors.mutedForeground),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppListRow(
          icon: Icons.photo_camera_rounded,
          iconColor: colors.primary,
          title: 'Prendre une photo',
          subtitle: 'Utiliser l\'appareil photo',
          padding: rowPadding,
          onTap: () => _pickImage(ImageSource.camera),
        ),
        AppListRow(
          icon: Icons.photo_library_rounded,
          iconColor: colors.info,
          title: 'Choisir dans la galerie',
          subtitle: 'Une image déjà sur le téléphone',
          padding: rowPadding,
          onTap: () => _pickImage(ImageSource.gallery),
        ),
        AppListRow(
          icon: Icons.folder_rounded,
          iconColor: colors.domainVehicule,
          title: 'Choisir un fichier',
          subtitle: 'PDF, image ou document Word',
          padding: rowPadding,
          onTap: _pickFile,
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          AppAlert(variant: AlertVariant.destructive, description: _error!),
        ],
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 52,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(foregroundColor: colors.foreground),
            child: const Text('Annuler'),
          ),
        ),
      ],
    );
  }

  /// Étape 2 : aperçu du fichier choisi, puis envoi.
  Widget _buildSelected() {
    return AppConfirmBody(
      message: 'Le fichier sera ajouté à la fiche du véhicule.',
      details: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SelectedFile(
            fileName: _fileName ?? '',
            mimeType: _mimeType ?? '',
            onClear: _isLoading ? null : _clearSelection,
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppAlert(variant: AlertVariant.destructive, description: _error!),
          ],
        ],
      ),
      confirmLabel: 'Envoyer le fichier',
      confirmIcon: Icons.upload_rounded,
      tone: AppConfirmTone.primary,
      isLoading: _isLoading,
      onConfirm: _submit,
      onCancel: () => Navigator.of(context).pop(false),
    );
  }
}

/// Fichier choisi : type, nom, bouton pour le retirer.
class _SelectedFile extends StatelessWidget {
  const _SelectedFile({
    required this.fileName,
    required this.mimeType,
    required this.onClear,
  });

  final String fileName;
  final String mimeType;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final visual = FileTypeVisual.of(
      colors,
      mimeType: mimeType,
      extension: FileTypeVisual.extensionOf(fileName),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.base,
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          AppIconBox(icon: visual.icon, color: visual.color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fileName,
                  style: textTheme.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(visual.label, style: textTheme.bodySmall),
              ],
            ),
          ),
          AppIconButton(
            icon: Icons.close_rounded,
            tooltip: 'Retirer le fichier',
            onPressed: onClear,
          ),
        ],
      ),
    );
  }
}
