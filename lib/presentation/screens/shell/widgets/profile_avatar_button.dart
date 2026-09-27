import 'package:flutter/material.dart';

import '../../../../data/models/models.dart';
import '../../../widgets/app_avatar.dart';

/// Initiales d'un utilisateur (« CV »), « U » à défaut.
String userInitials(User? user) {
  final f = (user?.firstName ?? '').trim();
  final l = (user?.lastName ?? '').trim();
  final s = '${f.isNotEmpty ? f[0] : ''}${l.isNotEmpty ? l[0] : ''}'
      .toUpperCase();
  return s.isEmpty ? 'U' : s;
}

/// Avatar tapable de la barre de titre (cible 48 dp) : ouvre l'onglet Moi.
class ProfileAvatarButton extends StatelessWidget {
  const ProfileAvatarButton({
    super.key,
    required this.user,
    required this.onPressed,
  });

  final User? user;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Mon profil',
      onTap: onPressed,
      excludeSemantics: true,
      child: Tooltip(
        message: 'Mon profil',
        child: InkResponse(
          onTap: onPressed,
          radius: 24,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: AppAvatar(
                imageUrl: user?.pictureUrl,
                fallbackText: userInitials(user),
                size: 34,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
