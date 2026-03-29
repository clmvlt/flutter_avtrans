import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/vehicule_model.dart';

/// Dialog pour uploader un fichier de véhicule
class UploadVehiculeFileDialog extends StatefulWidget {
  final String vehiculeId;

  const UploadVehiculeFileDialog({
    super.key,
    required this.vehiculeId,
  });

  @override
  State<UploadVehiculeFileDialog> createState() =>
      _UploadVehiculeFileDialogState();
}

class _UploadVehiculeFileDialogState extends State<UploadVehiculeFileDialog> {
  File? _selectedFile;
  String? _fileName;
  String? _mimeType;
  bool _isLoading = false;
  final _imagePicker = ImagePicker();

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
          _selectedFile = File(image.path);
          _fileName = image.name;
          _mimeType = _getMimeType(image.name);
        });
      }
    } catch (e) {
      _showError('Erreur lors de la sélection de l\'image');
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
          _fileName = result.files.single.name;
          _mimeType = _getMimeType(result.files.single.name);
        });
      }
    } catch (e) {
      _showError('Erreur lors de la sélection du fichier');
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
      _showError('Veuillez sélectionner un fichier');
      return;
    }

    setState(() => _isLoading = true);

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
        (failure) {
          setState(() => _isLoading = false);
          _showError(failure.message);
        },
        (file) {
          Navigator.of(context).pop(true);
        },
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Erreur lors de l\'upload: ${e.toString()}');
    }
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
      ),
    );
  }

  void _showSourceDialog() {
    final colors = context.colors;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(
          'Choisir une source',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: colors.foreground),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Appareil photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galerie'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('Fichiers'),
              onTap: () {
                Navigator.pop(context);
                _pickFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _clearSelection() {
    setState(() {
      _selectedFile = null;
      _fileName = null;
      _mimeType = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      backgroundColor: colors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      title: Text(
        'Ajouter un fichier',
        style: textTheme.titleLarge?.copyWith(color: colors.foreground),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedFile != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.base),
              decoration: BoxDecoration(
                color: colors.muted,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  Icon(
                    _mimeType?.startsWith('image/') == true
                        ? Icons.image
                        : _mimeType == 'application/pdf'
                            ? Icons.picture_as_pdf
                            : Icons.insert_drive_file,
                    color: _mimeType == 'application/pdf'
                        ? Colors.red
                        : colors.primary,
                    size: 22,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _fileName ?? '',
                      style: textTheme.bodyMedium?.copyWith(color: colors.foreground),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: colors.destructive, size: 20),
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    onPressed: _clearSelection,
                  ),
                ],
              ),
            ),
          ] else ...[
            GestureDetector(
              onTap: _showSourceDialog,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: colors.muted,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.cloud_upload,
                      size: 48,
                      color: colors.mutedForeground,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Appuyez pour sélectionner',
                      style: textTheme.bodyMedium?.copyWith(color: colors.mutedForeground),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Images, PDF, Documents',
                      style: textTheme.labelSmall?.copyWith(
                        color: colors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          child: Text(
            'Annuler',
            style: textTheme.labelLarge?.copyWith(color: colors.mutedForeground),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading || _selectedFile == null ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: colors.primaryForeground,
            minimumSize: const Size(48, 48),
          ),
          child: _isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(colors.primaryForeground),
                  ),
                )
              : const Text('Uploader'),
        ),
      ],
    );
  }
}
