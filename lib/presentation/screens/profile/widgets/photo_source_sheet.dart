import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../widgets/app_list_row.dart';
import '../../../widgets/app_sheet.dart';

/// Choix fait dans la feuille « Photo de profil ».
enum PhotoAction { camera, gallery, remove }

/// Feuille « Photo de profil » : prendre une photo, choisir dans la
/// galerie, ou supprimer la photo actuelle.
abstract final class PhotoSourceSheet {
  /// Retourne le choix, `null` si la feuille est fermée sans choix.
  static Future<PhotoAction?> show(
    BuildContext context, {
    required bool canRemove,
  }) {
    return AppSheet.show<PhotoAction>(
      context,
      title: 'Photo de profil',
      builder: (ctx) {
        final colors = ctx.colors;
        const padding = EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.sm,
        );
        void pick(PhotoAction a) => Navigator.of(ctx).pop(a);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppListRow(
              icon: Icons.photo_camera_rounded,
              iconColor: colors.primary,
              title: 'Prendre une photo',
              padding: padding,
              showChevron: false,
              onTap: () => pick(PhotoAction.camera),
            ),
            AppListRow(
              icon: Icons.photo_library_rounded,
              iconColor: colors.info,
              title: 'Choisir dans la galerie',
              padding: padding,
              showChevron: false,
              onTap: () => pick(PhotoAction.gallery),
            ),
            if (canRemove)
              AppListRow(
                icon: Icons.delete_outline_rounded,
                iconColor: colors.destructive,
                title: 'Supprimer la photo',
                padding: padding,
                showChevron: false,
                onTap: () => pick(PhotoAction.remove),
              ),
          ],
        );
      },
    );
  }
}
