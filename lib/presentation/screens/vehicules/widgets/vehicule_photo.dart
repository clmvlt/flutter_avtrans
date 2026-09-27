import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../widgets/widgets.dart';

/// Choix de la feuille « Photo du véhicule ».
enum VehiculePhotoAction { view, camera, gallery }

/// Photo en tête de la carte hero de la fiche véhicule.
///
/// Avec une photo : image arrondie 16:10, un tap l'agrandit (ou ouvre les
/// choix pour l'atelier, qui voit aussi « Changer » posé dessus). Sans
/// photo, pour l'atelier : un emplacement « Ajouter une photo ».
class VehiculePhotoHeader extends StatelessWidget {
  const VehiculePhotoHeader({
    super.key,
    required this.url,
    required this.canEdit,
    required this.uploading,
    required this.onTap,
  });

  final String? url;

  /// Administrateur ou Mécanicien : la photo peut être changée.
  final bool canEdit;

  /// Envoi en cours : voile et indicateur sur l'image.
  final bool uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(AppRadius.lg);

    if (url == null) {
      return Semantics(
        button: true,
        label: 'Ajouter une photo du véhicule',
        excludeSemantics: true,
        child: Material(
          color: colors.surfaceSunken,
          borderRadius: radius,
          child: InkWell(
            onTap: uploading ? null : onTap,
            borderRadius: radius,
            child: SizedBox(
              height: 128,
              width: double.infinity,
              child: uploading
                  ? Center(child: _Spinner(color: colors.primary))
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AppIconBox(
                          icon: Icons.add_a_photo_rounded,
                          color: colors.primary,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text('Ajouter une photo', style: textTheme.titleSmall),
                        Text(
                          'Pour reconnaître le véhicule d\'un coup d\'œil',
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      label: canEdit
          ? 'Photo du véhicule. Agrandir ou changer la photo'
          : 'Photo du véhicule. Agrandir',
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: radius,
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: colors.surfaceSunken),
              Image.network(
                url!,
                fit: BoxFit.cover,
                cacheWidth: 1200,
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : Center(child: _Spinner(color: colors.mutedForeground)),
                errorBuilder: (_, _, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.broken_image_rounded,
                        color: colors.mutedForeground,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Photo indisponible',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              Material(
                type: MaterialType.transparency,
                child: InkWell(onTap: uploading ? null : onTap),
              ),
              if (canEdit && !uploading)
                Positioned(
                  right: AppSpacing.sm,
                  bottom: AppSpacing.sm,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colors.card.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.photo_camera_rounded,
                            size: 16,
                            color: colors.foreground,
                          ),
                          const SizedBox(width: 6),
                          Text('Changer', style: textTheme.labelMedium),
                        ],
                      ),
                    ),
                  ),
                ),
              if (uploading)
                ColoredBox(
                  color: colors.background.withValues(alpha: 0.6),
                  child: Center(child: _Spinner(color: colors.primary)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: CircularProgressIndicator(strokeWidth: 2.5, color: color),
    );
  }
}

/// Choix pour la photo : l'agrandir, en prendre une, en choisir une.
abstract final class VehiculePhotoSheet {
  static Future<VehiculePhotoAction?> show(
    BuildContext context, {
    required bool hasPhoto,
  }) {
    return AppSheet.show<VehiculePhotoAction>(
      context,
      title: 'Photo du véhicule',
      builder: (ctx) {
        final colors = ctx.colors;
        final textTheme = Theme.of(ctx).textTheme;
        void choose(VehiculePhotoAction a) => Navigator.of(ctx).pop(a);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Column(
                children: [
                  if (hasPhoto) ...[
                    AppListRow(
                      icon: Icons.zoom_in_rounded,
                      iconColor: colors.domainVehicule,
                      title: 'Voir en grand',
                      onTap: () => choose(VehiculePhotoAction.view),
                    ),
                    Divider(height: 1, color: colors.border, indent: 68),
                  ],
                  AppListRow(
                    icon: Icons.photo_camera_rounded,
                    iconColor: colors.primary,
                    title: hasPhoto ? 'Reprendre une photo' : 'Prendre une photo',
                    onTap: () => choose(VehiculePhotoAction.camera),
                  ),
                  Divider(height: 1, color: colors.border, indent: 68),
                  AppListRow(
                    icon: Icons.photo_library_rounded,
                    iconColor: colors.primary,
                    title: 'Choisir dans la galerie',
                    onTap: () => choose(VehiculePhotoAction.gallery),
                  ),
                ],
              ),
            ),
            if (hasPhoto) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'La nouvelle photo remplace l\'actuelle. Une photo ne peut pas '
                'être retirée, seulement remplacée.',
                style: textTheme.bodySmall,
              ),
            ],
          ],
        );
      },
    );
  }
}
