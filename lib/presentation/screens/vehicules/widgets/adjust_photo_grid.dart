import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Grille des photos d'un signalement : vignettes 100 dp avec une croix pour
/// retirer, puis une case « Ajouter » tant que [maxPhotos] n'est pas atteint.
class AdjustPhotoGrid extends StatelessWidget {
  const AdjustPhotoGrid({
    super.key,
    required this.images,
    required this.maxPhotos,
    required this.onAdd,
    required this.onRemove,
    this.enabled = true,
  });

  final List<File> images;
  final int maxPhotos;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final bool enabled;

  static const double _tile = 100;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (var i = 0; i < images.length; i++)
          _PhotoTile(
            key: ObjectKey(images[i]),
            image: images[i],
            index: i,
            onRemove: enabled ? () => onRemove(i) : null,
          ),
        if (images.length < maxPhotos) _AddTile(onTap: enabled ? onAdd : null),
      ],
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    super.key,
    required this.image,
    required this.index,
    required this.onRemove,
  });

  final File image;
  final int index;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: AdjustPhotoGrid._tile,
      height: AdjustPhotoGrid._tile,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Image.file(image, fit: BoxFit.cover, cacheWidth: 300),
            ),
          ),
          // Cible de 44 dp dans le coin, pastille visible de 26 dp.
          Positioned(
            top: 0,
            right: 0,
            child: Semantics(
              button: true,
              label: 'Retirer la photo ${index + 1}',
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onRemove,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: colors.destructive,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.card, width: 2),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: colors.destructiveForeground,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
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
    return Semantics(
      button: true,
      label: 'Ajouter une photo',
      excludeSemantics: true,
      child: Material(
        color: colors.surfaceSunken,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: colors.border, width: 1.5),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: SizedBox(
            width: AdjustPhotoGrid._tile,
            height: AdjustPhotoGrid._tile,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_photo_alternate_rounded,
                  size: 30,
                  color: colors.primary,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text('Ajouter', style: textTheme.labelMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
