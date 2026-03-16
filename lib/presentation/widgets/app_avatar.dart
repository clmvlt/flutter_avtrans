import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Avatar shadcn/ui avec fallback initiales
class AppAvatar extends StatelessWidget {
  final String? imageUrl;
  final String fallbackText;
  final double size;
  final Color? backgroundColor;

  const AppAvatar({
    super.key,
    this.imageUrl,
    required this.fallbackText,
    this.size = 40,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bg = backgroundColor ?? colors.muted;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: colors.border, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl != null
          ? Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              width: size,
              height: size,
              errorBuilder: (_, __, ___) => _buildFallback(colors),
            )
          : _buildFallback(colors),
    );
  }

  Widget _buildFallback(AppColors colors) {
    return Center(
      child: Text(
        fallbackText,
        style: TextStyle(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w600,
          color: colors.mutedForeground,
        ),
      ),
    );
  }
}
