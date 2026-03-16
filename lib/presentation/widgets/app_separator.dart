import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Separator shadcn/ui
class AppSeparator extends StatelessWidget {
  final bool vertical;
  final double? thickness;
  final Color? color;

  const AppSeparator({
    super.key,
    this.vertical = false,
    this.thickness,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final c = color ?? colors.border;
    final t = thickness ?? 1.0;

    if (vertical) {
      return Container(width: t, color: c);
    }
    return Container(height: t, color: c);
  }
}
