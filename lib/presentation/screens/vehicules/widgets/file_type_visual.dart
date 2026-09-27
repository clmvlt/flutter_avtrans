import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Icône, teinte et libellé court d'un type de fichier, en tokens du thème :
/// PDF → `destructive`, image → `primary`, Word → `info`, Excel → `success`,
/// autre → `mutedForeground`.
@immutable
class FileTypeVisual {
  const FileTypeVisual({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  /// Même classement que l'ancienne grille : type MIME d'abord, extension
  /// en secours pour les documents Office.
  static FileTypeVisual of(
    AppColors colors, {
    required String mimeType,
    required String extension,
  }) {
    final ext = extension.toLowerCase();
    if (mimeType == 'application/pdf') {
      return FileTypeVisual(
        icon: Icons.picture_as_pdf_rounded,
        color: colors.destructive,
        label: 'PDF',
      );
    }
    if (mimeType.startsWith('image/')) {
      return FileTypeVisual(
        icon: Icons.image_rounded,
        color: colors.primary,
        label: 'Image',
      );
    }
    if (mimeType.contains('word') || ext == 'doc' || ext == 'docx') {
      return FileTypeVisual(
        icon: Icons.description_rounded,
        color: colors.info,
        label: 'Word',
      );
    }
    if (mimeType.contains('excel') || ext == 'xls' || ext == 'xlsx') {
      return FileTypeVisual(
        icon: Icons.table_chart_rounded,
        color: colors.success,
        label: 'Excel',
      );
    }
    return FileTypeVisual(
      icon: Icons.insert_drive_file_rounded,
      color: colors.mutedForeground,
      label: ext.isEmpty ? 'Fichier' : ext.toUpperCase(),
    );
  }

  /// Extension d'un nom de fichier (`''` s'il n'en a pas).
  static String extensionOf(String fileName) {
    final parts = fileName.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }
}
