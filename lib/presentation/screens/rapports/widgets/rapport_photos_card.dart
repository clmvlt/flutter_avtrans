import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_list_row.dart';
import '../../../widgets/app_sheet.dart';

/// Nombre minimal de photos d'un rapport (avant + arrière).
const int kRapportMinPhotos = 2;

/// Carte « Photos » du rapport : consigne tant qu'il manque des photos, puis
/// une grille de deux colonnes (photo + libellé « Photo avant »,
/// « Photo arrière »…) terminée par la case « Ajouter une photo ».
class RapportPhotosCard extends StatelessWidget {
  const RapportPhotosCard({
    super.key,
    required this.images,
    required this.onAdd,
    required this.onRemove,
  });

  final List<File> images;

  /// `null` pendant l'envoi : ajout et retrait désactivés.
  final VoidCallback? onAdd;
  final ValueChanged<int>? onRemove;

  static String labelFor(int index) => switch (index) {
        0 => 'Photo avant',
        1 => 'Photo arrière',
        _ => 'Photo ${index + 1}',
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final missing = kRapportMinPhotos - images.length;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (missing > 0) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 20, color: colors.warning),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    images.isEmpty
                        ? 'Ajoute 2 photos : l\'avant et l\'arrière du véhicule.'
                        : 'Ajoute encore $missing photo '
                            '(l\'arrière du véhicule).',
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.foreground,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          GridView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
              childAspectRatio: 0.85,
            ),
            itemCount: images.length + 1,
            itemBuilder: (context, index) {
              if (index == images.length) {
                return _AddTile(onTap: onAdd);
              }
              return _PhotoTile(
                file: images[index],
                label: labelFor(index),
                onRemove: onRemove == null ? null : () => onRemove!(index),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.file,
    required this.label,
    required this.onRemove,
  });

  final File file;
  final String label;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Image.file(file, fit: BoxFit.cover),
              ),
              Positioned(
                top: AppSpacing.xs,
                right: AppSpacing.xs,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: colors.cardShadow,
                  ),
                  child: Material(
                    color: colors.card,
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'Retirer ${label.toLowerCase()}',
                      onPressed: onRemove,
                      constraints:
                          const BoxConstraints(minWidth: 40, minHeight: 40),
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        size: 20,
                        color: onRemove == null
                            ? colors.disabled
                            : colors.destructive,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.labelMedium,
        ),
      ],
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final fg = onTap == null ? colors.disabled : colors.mutedForeground;

    return Semantics(
      button: true,
      enabled: onTap != null,
      label: 'Ajouter une photo',
      excludeSemantics: true,
      child: Material(
        color: colors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_a_photo_rounded, size: 32, color: fg),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Ajouter une photo',
                textAlign: TextAlign.center,
                style: textTheme.labelMedium?.copyWith(color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Feuille « Ajouter une photo » : appareil photo ou galerie.
abstract final class PhotoSourceSheet {
  static Future<ImageSource?> show(BuildContext context) {
    return AppSheet.show<ImageSource>(
      context,
      title: 'Ajouter une photo',
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        0,
        AppSpacing.sm,
        AppSpacing.lg,
      ),
      builder: (ctx) {
        final colors = ctx.colors;
        const padding = EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppListRow(
              title: 'Prendre une photo',
              subtitle: 'Avec l\'appareil photo',
              icon: Icons.photo_camera_rounded,
              iconColor: colors.primary,
              padding: padding,
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            AppListRow(
              title: 'Choisir dans la galerie',
              subtitle: 'Une photo déjà prise',
              icon: Icons.photo_library_rounded,
              iconColor: colors.primary,
              padding: padding,
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
          ],
        );
      },
    );
  }
}
