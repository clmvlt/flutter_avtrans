import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/display_format.dart';
import '../../../widgets/widgets.dart';

/// Étape « Photos » d'un parcours : grande tuile « Prendre une photo » tant
/// qu'il n'y en a pas, puis une grille de vignettes (croix pour retirer)
/// terminée par une tuile d'ajout.
class YpsiumPhotoSection extends StatelessWidget {
  const YpsiumPhotoSection({
    super.key,
    required this.photos,
    required this.onAdd,
    required this.onRemove,
  });

  /// Photos encodées en base64.
  final List<String> photos;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(
          title: 'Photos',
          summary: photos.isEmpty
              ? null
              : DisplayFormat.plural(photos.length, 'photo'),
        ),
        if (photos.isEmpty)
          _AddPhotoTile(
            height: 140,
            label: 'Prendre une photo',
            detail: 'Aucune photo pour le moment',
            onTap: onAdd,
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = AppSpacing.sm;
              final size = ((constraints.maxWidth - 2 * gap) / 3).floorToDouble();
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (var i = 0; i < photos.length; i++)
                    _PhotoThumb(
                      key: ValueKey('photo-$i-${photos[i].length}'),
                      base64: photos[i],
                      size: size,
                      index: i,
                      onRemove: () => onRemove(i),
                    ),
                  _AddPhotoTile(
                    width: size,
                    height: size,
                    label: 'Ajouter',
                    onTap: onAdd,
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({
    super.key,
    required this.base64,
    required this.size,
    required this.index,
    required this.onRemove,
  });

  final String base64;
  final double size;
  final int index;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Image.memory(
                base64Decode(base64),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                semanticLabel: 'Photo ${index + 1}',
              ),
            ),
          ),
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
                  width: 48,
                  height: 48,
                  child: Center(
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: colors.destructive,
                        shape: BoxShape.circle,
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

/// Tuile enfoncée « prendre une photo » (icône appareil + libellé).
class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({
    this.width,
    required this.height,
    required this.label,
    this.detail,
    required this.onTap,
  });

  final double? width;
  final double height;
  final String label;
  final String? detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: 'Prendre une photo',
      excludeSemantics: true,
      child: SizedBox(
        width: width,
        height: height,
        child: Material(
          color: colors.surfaceSunken,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIconBox(
                    icon: Icons.add_a_photo_rounded,
                    color: colors.primary,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(label, style: textTheme.titleSmall),
                  if (detail != null)
                    Text(detail!, style: textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
