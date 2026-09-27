import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_list_row.dart';
import '../../../widgets/app_page.dart';

/// Couleurs posées SUR l'image caméra : fixes (claires sur voile sombre),
/// quel que soit le thème, tirées de la palette sombre.
abstract final class ScannerOverlay {
  static const AppColors _c = AppColors.dark;

  static Color get line => _c.foreground;
  static Color get scrim => _c.background.withValues(alpha: 0.55);
}

/// Viseur du scanner : cadre qui délimite la zone réellement analysée, et
/// pastille d'aide en haut à gauche. À poser sur l'aperçu caméra.
class ScannerViewfinder extends StatelessWidget {
  const ScannerViewfinder({
    super.key,
    required this.widthFactor,
    required this.heightFactor,
  });

  final double widthFactor;
  final double heightFactor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: FractionallySizedBox(
            widthFactor: widthFactor,
            heightFactor: heightFactor,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: ScannerOverlay.line, width: 2),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
        ),
        Positioned(
          left: AppSpacing.md,
          top: AppSpacing.md,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: ScannerOverlay.scrim,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.center_focus_strong_rounded,
                  size: 14,
                  color: ScannerOverlay.line,
                ),
                const SizedBox(width: 6),
                Text(
                  'Vise une adresse',
                  style: textTheme.labelMedium
                      ?.copyWith(color: ScannerOverlay.line),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Bas du scanner : « Recherche d'une adresse… » puis l'adresse reconnue et
/// son bouton d'ajout.
class ScannerCandidate extends StatelessWidget {
  const ScannerCandidate({
    super.key,
    required this.candidate,
    required this.onConfirm,
  });

  /// Adresse reconnue ; `null` ou vide tant que rien n'est détecté.
  final String? candidate;

  /// `null` pendant la confirmation (analyse suspendue).
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final value = candidate;

    if (value == null || value.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Semantics(
          liveRegion: true,
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.mutedForeground,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Recherche d\'une adresse…',
                  style: textTheme.bodyMedium
                      ?.copyWith(color: colors.mutedForeground),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: Row(
              children: [
                AppIconBox(
                  icon: Icons.location_on_rounded,
                  color: colors.primary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Adresse détectée', style: textTheme.bodySmall),
                      Text(
                        value,
                        style: textTheme.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Bouton tonal : l'action principale de la page reste dans le dock.
          AppButton(
            text: 'Ajouter cette adresse',
            icon: Icons.add_location_alt_outlined,
            backgroundColor: colors.primarySoft,
            foregroundColor: colors.primary,
            onPressed: onConfirm,
          ),
        ],
      ),
    );
  }
}

/// Zone du scanner à la hauteur de l'aperçu, pendant le démarrage caméra.
class ScannerStarting extends StatelessWidget {
  const ScannerStarting({super.key, required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      height: height,
      color: colors.surfaceSunken,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Démarrage de la caméra…', style: textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Caméra indisponible ou refusée : explication et action de reprise.
class ScannerFallback extends StatelessWidget {
  const ScannerFallback({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              AppIconBox(
                icon: icon,
                color: colors.warning,
                size: AppLayout.heroIconBox,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(title, style: textTheme.titleMedium)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            subtitle,
            style: textTheme.bodyMedium?.copyWith(color: colors.mutedForeground),
          ),
          const SizedBox(height: AppSpacing.base),
          AppButton(
            text: actionLabel,
            variant: ButtonVariant.secondary,
            onPressed: onAction,
          ),
        ],
      ),
    );
  }
}
