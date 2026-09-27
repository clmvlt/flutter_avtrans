import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/entretien_model.dart';

/// Taille max d'un fichier joint : l'envoi se fait en base64 dans le JSON,
/// avec un délai de 30 s.
const int kMaxEntretienFileBytes = 15 * 1024 * 1024;

/// Extensions acceptées (comme l'app web).
const List<String> kEntretienFileExtensions = [
  'pdf', 'jpg', 'jpeg', 'png', 'webp', 'heic', 'doc', 'docx', 'xls', 'xlsx',
];

/// Fichier choisi mais pas encore envoyé.
class PendingFile {
  const PendingFile({
    required this.name,
    required this.mimeType,
    required this.bytes,
  });

  final String name;
  final String mimeType;
  final Uint8List bytes;

  int get size => bytes.length;
  bool get isImage => mimeType.startsWith('image/');

  EntretienFileUpload toUpload() => EntretienFileUpload(
        fileB64: base64Encode(bytes),
        originalName: name,
        mimeType: mimeType,
      );
}

/// Type MIME d'après l'extension.
String mimeTypeFor(String fileName) {
  final ext = fileName.contains('.')
      ? fileName.split('.').last.toLowerCase()
      : '';
  return switch (ext) {
    'pdf' => 'application/pdf',
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'heic' => 'image/heic',
    'doc' => 'application/msword',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls' => 'application/vnd.ms-excel',
    'xlsx' =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    _ => 'application/octet-stream',
  };
}

/// Icône et teinte d'un fichier selon son type (tokens du thème).
(IconData, Color) fileVisual(String mimeType, String name, AppColors c) {
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
  if (mimeType == 'application/pdf') {
    return (Icons.picture_as_pdf_rounded, c.destructive);
  }
  if (mimeType.startsWith('image/')) return (Icons.image_rounded, c.primary);
  if (mimeType.contains('word') || ext == 'doc' || ext == 'docx') {
    return (Icons.description_rounded, c.info);
  }
  if (mimeType.contains('sheet') ||
      mimeType.contains('excel') ||
      ext == 'xls' ||
      ext == 'xlsx') {
    return (Icons.table_chart_rounded, c.success);
  }
  return (Icons.insert_drive_file_rounded, c.mutedForeground);
}

/// Source d'un nouveau fichier.
enum FileSource { camera, gallery, document }

/// Résultat d'un choix de fichier.
sealed class PickResult {
  const PickResult();
}

class PickedFile extends PickResult {
  const PickedFile(this.file);
  final PendingFile file;
}

class PickCancelled extends PickResult {
  const PickCancelled();
}

class PickError extends PickResult {
  const PickError(this.message);
  final String message;
}

/// Ouvre l'appareil photo, la galerie ou le sélecteur de documents.
Future<PickResult> pickEntretienFile(FileSource source) async {
  try {
    PendingFile? file;
    switch (source) {
      case FileSource.camera:
      case FileSource.gallery:
        final image = await ImagePicker().pickImage(
          source: source == FileSource.camera
              ? ImageSource.camera
              : ImageSource.gallery,
          maxWidth: 2400,
          maxHeight: 2400,
          imageQuality: 85,
        );
        if (image == null) return const PickCancelled();
        file = PendingFile(
          name: image.name,
          mimeType: mimeTypeFor(image.name) == 'application/octet-stream'
              ? 'image/jpeg'
              : mimeTypeFor(image.name),
          bytes: await image.readAsBytes(),
        );
      case FileSource.document:
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: kEntretienFileExtensions,
          withData: true,
        );
        final picked = result?.files.single;
        if (picked == null) return const PickCancelled();
        final bytes = picked.bytes ??
            (picked.path != null ? await File(picked.path!).readAsBytes() : null);
        if (bytes == null) return const PickError('Fichier illisible.');
        file = PendingFile(
          name: picked.name,
          mimeType: mimeTypeFor(picked.name),
          bytes: bytes,
        );
    }
    if (file.size > kMaxEntretienFileBytes) {
      return const PickError('Fichier trop lourd : 15 Mo au maximum.');
    }
    return PickedFile(file);
  } catch (_) {
    return const PickError('Impossible d\'ouvrir ce fichier.');
  }
}

/// Ouvre un fichier reçu en base64 : les images dans une visionneuse,
/// le reste dans l'application du téléphone. Retourne un message d'erreur,
/// ou `null` si tout s'est bien passé.
Future<String?> openBase64File(
  BuildContext context, {
  required String base64,
  required String name,
  required String mimeType,
}) async {
  try {
    final bytes = base64Decode(base64);
    if (mimeType.startsWith('image/')) {
      if (!context.mounted) return null;
      await Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => _ImageViewer(bytes: bytes, title: name),
        ),
      );
      return null;
    }
    final dir = await getTemporaryDirectory();
    final safeName = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File('${dir.path}/$safeName');
    await file.writeAsBytes(bytes, flush: true);
    final result = await OpenFilex.open(file.path, type: mimeType);
    if (result.type != ResultType.done) {
      return 'Aucune application pour ouvrir ce fichier.';
    }
    return null;
  } catch (_) {
    return 'Impossible d\'ouvrir ce fichier.';
  }
}

/// Visionneuse d'image plein écran (zoom au pincement).
class _ImageViewer extends StatelessWidget {
  const _ImageViewer({required this.bytes, required this.title});

  final Uint8List bytes;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5,
          child: Image.memory(bytes, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
