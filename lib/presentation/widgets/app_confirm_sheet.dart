import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'app_sheet.dart';

/// Tonalité du bouton de confirmation.
enum AppConfirmTone { primary, success, danger }

/// Feuille de confirmation, sur le modèle de « Terminer le service ? » :
/// titre en question, une phrase qui dit la conséquence, un récapitulatif
/// optionnel, puis un gros bouton qui nomme l'action et un « Annuler » texte.
/// Remplace les `AlertDialog` de confirmation.
abstract final class AppConfirmSheet {
  /// Retourne `true` si l'utilisateur confirme.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    String? message,
    Widget? details,
    required String confirmLabel,
    IconData? confirmIcon,
    AppConfirmTone tone = AppConfirmTone.danger,
    String cancelLabel = 'Annuler',
  }) async {
    final result = await AppSheet.show<bool>(
      context,
      title: title,
      builder: (ctx) => AppConfirmBody(
        message: message,
        details: details,
        confirmLabel: confirmLabel,
        confirmIcon: confirmIcon,
        tone: tone,
        cancelLabel: cancelLabel,
        onConfirm: () => Navigator.of(ctx).pop(true),
        onCancel: () => Navigator.of(ctx).pop(false),
      ),
    );
    return result ?? false;
  }
}

/// Corps d'une feuille de confirmation, réutilisable dans une feuille
/// maison (ex. quand la confirmation porte aussi un champ).
class AppConfirmBody extends StatelessWidget {
  const AppConfirmBody({
    super.key,
    this.message,
    this.details,
    required this.confirmLabel,
    this.confirmIcon,
    this.tone = AppConfirmTone.danger,
    this.cancelLabel = 'Annuler',
    required this.onConfirm,
    required this.onCancel,
    this.isLoading = false,
  });

  final String? message;
  final Widget? details;
  final String confirmLabel;
  final IconData? confirmIcon;
  final AppConfirmTone tone;
  final String cancelLabel;
  final VoidCallback? onConfirm;
  final VoidCallback onCancel;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    final (bg, fg) = switch (tone) {
      AppConfirmTone.primary => (colors.primary, colors.primaryForeground),
      AppConfirmTone.success => (colors.success, colors.successForeground),
      AppConfirmTone.danger => (colors.destructive, colors.destructiveForeground),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (message != null)
          Text(
            message!,
            style: textTheme.bodyMedium?.copyWith(color: colors.mutedForeground),
          ),
        if (details != null) ...[
          const SizedBox(height: AppSpacing.base),
          details!,
        ],
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          height: 56,
          child: FilledButton(
            onPressed: isLoading ? null : onConfirm,
            style: FilledButton.styleFrom(
              backgroundColor: bg,
              foregroundColor: fg,
              disabledBackgroundColor: bg.withValues(alpha: 0.6),
              disabledForegroundColor: fg,
              textStyle: textTheme.titleMedium?.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: isLoading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (confirmIcon != null) ...[
                        Icon(confirmIcon, size: 22),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      Flexible(
                        child: Text(
                          confirmLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 52,
          child: TextButton(
            onPressed: isLoading ? null : onCancel,
            style: TextButton.styleFrom(foregroundColor: colors.foreground),
            child: Text(cancelLabel),
          ),
        ),
      ],
    );
  }
}

/// Bloc récapitulatif enfoncé (fond `surfaceSunken`) de lignes libellé →
/// valeur, comme celui de « Terminer le service ? ».
class AppRecapBox extends StatelessWidget {
  const AppRecapBox({super.key, required this.rows});

  final List<AppRecapRow> rows;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(children: rows),
    );
  }
}

/// Ligne d'un [AppRecapBox] : icône discrète, libellé, valeur tabulaire.
class AppRecapRow extends StatelessWidget {
  const AppRecapRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: colors.mutedForeground),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                color: emphasized ? colors.foreground : colors.mutedForeground,
                fontWeight: emphasized ? FontWeight.w600 : null,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Valeur calée à droite, sur sa propre part de la ligne.
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: (emphasized ? textTheme.titleLarge : textTheme.titleSmall)
                    ?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
