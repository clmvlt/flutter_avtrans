import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/display_format.dart';
import '../../../../data/models/entretien_model.dart';
import '../../../widgets/widgets.dart';
import '../logic/entretien_files.dart';

/// Fichiers d'un entretien, ouvrables d'un tap. Le contenu (base64) n'est
/// téléchargé qu'au premier tap, pour tous les fichiers de l'entretien.
/// Avec [onDelete], chaque ligne porte une corbeille (formulaire d'édition).
class EntretienFilesList extends StatefulWidget {
  const EntretienFilesList({
    super.key,
    required this.entretienId,
    required this.files,
    this.onDelete,
    this.deletingId,
  });

  final String entretienId;
  final List<EntretienFile> files;
  final ValueChanged<EntretienFile>? onDelete;

  /// Fichier en cours de suppression (indicateur à la place de la corbeille).
  final String? deletingId;

  @override
  State<EntretienFilesList> createState() => _EntretienFilesListState();
}

class _EntretienFilesListState extends State<EntretienFilesList> {
  Map<String, EntretienFile>? _withContent;
  String? _openingId;
  String? _error;

  Future<void> _open(EntretienFile file) async {
    if (_openingId != null) return;
    setState(() {
      _openingId = file.id;
      _error = null;
    });

    var content = _withContent?[file.id];
    if (content?.fileB64 == null) {
      final result = await sl.entretienRepository.getFiles(widget.entretienId);
      if (!mounted) return;
      result.fold(
        (failure) => _error = failure.message,
        (files) => _withContent = {for (final f in files) f.id: f},
      );
      content = _withContent?[file.id];
    }

    String? error = _error;
    if (error == null) {
      final b64 = content?.fileB64;
      if (b64 == null) {
        error = 'Ce fichier est introuvable sur le serveur.';
      } else {
        error = await openBase64File(
          context,
          base64: b64,
          name: file.originalName,
          mimeType: file.mimeType,
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _openingId = null;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: colors.surfaceSunken,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            children: [
              for (var i = 0; i < widget.files.length; i++) ...[
                if (i > 0)
                  Divider(height: 1, color: colors.border, indent: 68),
                _FileRow(
                  file: widget.files[i],
                  opening: _openingId == widget.files[i].id,
                  deleting: widget.deletingId == widget.files[i].id,
                  onOpen: () => _open(widget.files[i]),
                  onDelete: widget.onDelete == null
                      ? null
                      : () => widget.onDelete!(widget.files[i]),
                ),
              ],
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              _error!,
              style: textTheme.bodySmall?.copyWith(color: colors.destructive),
            ),
          ),
      ],
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.file,
    required this.opening,
    required this.deleting,
    required this.onOpen,
    this.onDelete,
  });

  final EntretienFile file;
  final bool opening;
  final bool deleting;
  final VoidCallback onOpen;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (icon, color) = fileVisual(file.mimeType, file.originalName, colors);
    final subtitle = [
      if (file.fileSize > 0) DisplayFormat.fileSize(file.fileSize),
      if (file.createdAt != null) DisplayFormat.dateSmart(file.createdAt!),
    ].join(' · ');

    Widget? trailing;
    if (opening || deleting) {
      trailing = SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: deleting ? colors.destructive : colors.primary,
            ),
          ),
        ),
      );
    } else if (onDelete != null) {
      trailing = IconButton(
        onPressed: onDelete,
        tooltip: 'Supprimer le fichier',
        icon: Icon(Icons.delete_outline_rounded, color: colors.destructive),
      );
    }

    return AppListRow(
      title: file.originalName,
      subtitle: subtitle,
      subtitleMaxLines: 1,
      icon: icon,
      iconColor: color,
      trailing: trailing,
      showChevron: trailing == null,
      onTap: deleting ? null : onOpen,
      semanticsLabel: 'Ouvrir ${file.originalName}',
    );
  }
}

/// Fichiers choisis dans le formulaire, pas encore envoyés : nom, poids,
/// croix pour retirer.
class PendingFilesList extends StatelessWidget {
  const PendingFilesList({
    super.key,
    required this.files,
    required this.onRemove,
  });

  final List<PendingFile> files;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          for (var i = 0; i < files.length; i++) ...[
            if (i > 0) Divider(height: 1, color: colors.border, indent: 68),
            Builder(
              builder: (context) {
                final f = files[i];
                final (icon, color) = fileVisual(f.mimeType, f.name, colors);
                return AppListRow(
                  title: f.name,
                  subtitle: '${DisplayFormat.fileSize(f.size)} · à envoyer',
                  subtitleMaxLines: 1,
                  icon: icon,
                  iconColor: color,
                  trailing: IconButton(
                    onPressed: () => onRemove(i),
                    tooltip: 'Retirer',
                    icon: Icon(
                      Icons.close_rounded,
                      color: colors.mutedForeground,
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// Boutons d'ajout d'un fichier : photo, galerie, document.
class AddFileButtons extends StatelessWidget {
  const AddFileButtons({super.key, required this.onPick, this.enabled = true});

  final ValueChanged<FileSource> onPick;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    Widget button(FileSource source, IconData icon, String label) => Expanded(
          child: AppButton(
            text: label,
            icon: icon,
            size: ButtonSize.sm,
            variant: ButtonVariant.secondary,
            onPressed: enabled ? () => onPick(source) : null,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          ),
        );

    return Row(
      children: [
        button(FileSource.camera, Icons.photo_camera_rounded, 'Photo'),
        const SizedBox(width: AppSpacing.sm),
        button(FileSource.gallery, Icons.photo_library_rounded, 'Galerie'),
        const SizedBox(width: AppSpacing.sm),
        button(FileSource.document, Icons.attach_file_rounded, 'Fichier'),
      ],
    );
  }
}
