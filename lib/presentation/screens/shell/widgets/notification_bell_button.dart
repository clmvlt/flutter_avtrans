import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/display_format.dart';

/// Cloche de la barre de titre avec le nombre de notifications non lues.
class NotificationBellButton extends StatelessWidget {
  const NotificationBellButton({
    super.key,
    required this.count,
    required this.onPressed,
  });

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final label = count > 0
        ? 'Notifications, ${DisplayFormat.plural(count, 'non lue')}'
        : 'Notifications';

    return Semantics(
      button: true,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: IconButton(
        onPressed: onPressed,
        tooltip: 'Notifications',
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: Badge(
          isLabelVisible: count > 0,
          label: Text(count > 99 ? '99+' : '$count'),
          backgroundColor: colors.destructive,
          textColor: colors.destructiveForeground,
          child: Icon(
            Icons.notifications_none_rounded,
            size: 24,
            color: colors.foreground,
          ),
        ),
      ),
    );
  }
}
