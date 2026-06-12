import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Helper de bottom sheet standardisé — direction *soft & chaleureux*.
///
/// Dans le redesign, toute action courte (filtres, ajout rapide, sélection,
/// confirmation) passe par une feuille plutôt qu'une nouvelle page.
///
/// ```dart
/// final result = await AppSheet.show<bool>(
///   context,
///   title: 'Filtrer',
///   builder: (ctx) => MesFiltres(),
/// );
/// ```
abstract class AppSheet {
  /// Affiche une feuille modale standard (poignée, titre optionnel, scroll,
  /// respect du clavier et des safe areas).
  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    String? title,
    Widget? trailing,
    bool isScrollControlled = true,
    bool showHandle = true,
    EdgeInsetsGeometry contentPadding = const EdgeInsets.fromLTRB(
      AppSpacing.screen,
      AppSpacing.sm,
      AppSpacing.screen,
      AppSpacing.lg,
    ),
  }) {
    final colors = context.colors;

    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: colors.surfaceElevated,
      // La poignée est gérée ici pour pouvoir la masquer au besoin.
      showDragHandle: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        return Padding(
          // Laisse remonter le contenu au-dessus du clavier.
          padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: media.size.height * 0.92,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showHandle) _Handle(color: colors.border),
                  if (title != null)
                    _Header(title: title, trailing: trailing),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: contentPadding,
                      child: builder(ctx),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.sm,
        AppSpacing.base,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: textTheme.titleLarge),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
