import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/display_format.dart';
import '../../../../data/models/vehicule_model.dart';
import '../../../widgets/widgets.dart';
import 'file_type_visual.dart';

/// Onglet « Fichiers » de la fiche véhicule : liste des documents avec leur
/// type (icône teintée ou vignette pour une image), taille et date.
class VehiculeFilesTab extends StatelessWidget {
  const VehiculeFilesTab({
    super.key,
    required this.files,
    required this.error,
    required this.onRetry,
    required this.onOpen,
  });

  final List<VehiculeFile> files;

  /// Échec du chargement des fichiers (la fiche, elle, est chargée).
  final String? error;
  final VoidCallback onRetry;
  final ValueChanged<VehiculeFile> onOpen;

  @override
  Widget build(BuildContext context) {
    if (error != null && files.isEmpty) {
      return AppErrorState(
        title: 'Fichiers indisponibles',
        message: error!,
        onRetry: onRetry,
      );
    }
    if (files.isEmpty) {
      return const AppEmptyCard(
        icon: Icons.folder_open_rounded,
        message: 'Aucun fichier',
        detail: 'Ajoute un document ou une photo pour ce véhicule.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(
          title: 'Documents',
          summary: DisplayFormat.plural(files.length, 'fichier'),
        ),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            children: [
              for (final file in files)
                _FileRow(
                  key: ValueKey(file.id),
                  file: file,
                  onTap: () => onOpen(file),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({super.key, required this.file, required this.onTap});

  final VehiculeFile file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final visual = FileTypeVisual.of(
      colors,
      mimeType: file.mimeType,
      extension: file.extension,
    );
    final icon = AppIconBox(icon: visual.icon, color: visual.color);
    final action = file.isImage
        ? 'Ouvrir l\'image'
        : 'Ouvrir dans une autre application';

    return AppListRow(
      leading: file.isImage
          ? _ImageThumb(url: file.fileUrl, fallback: icon)
          : icon,
      title: file.originalName,
      subtitle: '${visual.label} · ${DisplayFormat.fileSize(file.fileSize)} · '
          '${DisplayFormat.dateSmart(file.createdAt)}',
      subtitleMaxLines: 1,
      onTap: onTap,
      trailing: file.isImage
          ? null
          : Icon(
              Icons.open_in_new_rounded,
              size: 18,
              color: colors.mutedForeground,
            ),
      semanticsLabel: '${file.originalName}, ${visual.label}. $action',
    );
  }
}

/// Vignette 40 dp d'une image (icône du type en secours).
class _ImageThumb extends StatelessWidget {
  const _ImageThumb({required this.url, required this.fallback});

  final String url;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: SizedBox(
        width: AppLayout.iconBox,
        height: AppLayout.iconBox,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          cacheWidth: 120,
          errorBuilder: (_, _, _) => fallback,
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : ColoredBox(color: colors.surfaceSunken),
        ),
      ),
    );
  }
}
