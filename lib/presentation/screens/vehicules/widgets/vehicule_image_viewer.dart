import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../widgets/widgets.dart';

/// Image en plein écran, zoomable (pincer pour agrandir), aux couleurs du
/// thème. Ouverte en `fullscreenDialog` : la croix de la barre la ferme.
class VehiculeImageViewer extends StatelessWidget {
  const VehiculeImageViewer({
    super.key,
    required this.imageUrl,
    required this.title,
  });

  final String imageUrl;
  final String title;

  static Future<void> open(
    BuildContext context, {
    required String imageUrl,
    required String title,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => VehiculeImageViewer(imageUrl: imageUrl, title: title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return AppPage(
      title: title,
      body: SafeArea(
        top: false,
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Center(
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                final total = progress.expectedTotalBytes;
                return CircularProgressIndicator(
                  value: total != null
                      ? progress.cumulativeBytesLoaded / total
                      : null,
                  color: colors.primary,
                );
              },
              errorBuilder: (_, _, _) => Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIconBox(
                      icon: Icons.broken_image_rounded,
                      color: colors.mutedForeground,
                      size: AppLayout.heroIconBox,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Impossible de charger l\'image',
                      style: textTheme.bodyLarge
                          ?.copyWith(color: colors.mutedForeground),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
