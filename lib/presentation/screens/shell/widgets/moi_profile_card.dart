import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/models.dart';
import '../../../widgets/app_avatar.dart';
import '../../../widgets/app_card.dart';
import 'profile_avatar_button.dart';

/// Carte d'identité de l'onglet Moi : avatar, nom, rôle. Tapable : ouvre
/// la modification du profil.
class MoiProfileCard extends StatelessWidget {
  const MoiProfileCard({super.key, required this.user, required this.onTap});

  final User? user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final name = user?.fullName.isNotEmpty == true ? user!.fullName : 'Mon profil';
    final role = user?.role?.nom;
    final detail = role != null ? '$role · AVTRANS' : (user?.email ?? '');

    return Semantics(
      button: true,
      label: '$name. $detail',
      hint: 'Modifier mon profil',
      onTap: onTap,
      excludeSemantics: true,
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Row(
          children: [
            AppAvatar(
              imageUrl: user?.pictureUrl,
              fallbackText: userInitials(user),
              size: 56,
            ),
            const SizedBox(width: AppSpacing.base),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: textTheme.titleLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (detail.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(Icons.chevron_right_rounded, color: colors.mutedForeground),
          ],
        ),
      ),
    );
  }
}
