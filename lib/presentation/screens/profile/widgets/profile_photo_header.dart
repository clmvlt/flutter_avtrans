import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// En-tête du profil : photo ronde avec son bouton appareil photo, nom et
/// email. Taper la photo ouvre le choix de la source.
///
/// Priorité d'affichage : suppression demandée (`base64 == ''`) → fichier
/// choisi (mobile) → image base64 (web) → photo actuelle → avatar par défaut.
class ProfilePhotoHeader extends StatelessWidget {
  const ProfilePhotoHeader({
    super.key,
    required this.name,
    required this.email,
    required this.selectedFile,
    required this.selectedBase64,
    required this.pictureUrl,
    required this.onEdit,
  });

  final String name;
  final String email;
  final File? selectedFile;
  final String? selectedBase64;
  final String? pictureUrl;
  final VoidCallback onEdit;

  static const double _size = 104;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Semantics(
          button: true,
          label: 'Changer la photo de profil',
          onTap: onEdit,
          excludeSemantics: true,
          child: GestureDetector(
            onTap: onEdit,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: _size,
                  height: _size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.card,
                    border: Border.all(color: colors.border, width: 3),
                    boxShadow: colors.cardShadow,
                  ),
                  child: ClipOval(child: _image(colors)),
                ),
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.background, width: 3),
                    ),
                    child: Icon(
                      Icons.photo_camera_rounded,
                      color: colors.primaryForeground,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (name.isNotEmpty)
          Text(
            name,
            style: textTheme.titleLarge,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        if (email.isNotEmpty)
          Text(
            email,
            style: textTheme.bodySmall,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }

  Widget _defaultAvatar(AppColors colors) {
    return ColoredBox(
      color: colors.muted,
      child: Center(
        child: Icon(
          Icons.person_rounded,
          size: 52,
          color: colors.mutedForeground,
        ),
      ),
    );
  }

  Widget _image(AppColors colors) {
    // Suppression demandée (chaîne vide).
    if (selectedBase64 == '') return _defaultAvatar(colors);

    // 1. Fichier choisi (mobile uniquement).
    final file = selectedFile;
    if (file != null && !kIsWeb) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        width: _size,
        height: _size,
        errorBuilder: (_, _, _) => _defaultAvatar(colors),
      );
    }

    // 2. Image en base64 (web ou repli).
    final base64 = selectedBase64;
    if (base64 != null && base64.isNotEmpty) {
      return Image.memory(
        base64Decode(base64),
        fit: BoxFit.cover,
        width: _size,
        height: _size,
        errorBuilder: (_, _, _) => _defaultAvatar(colors),
      );
    }

    // 3. Photo actuelle du profil.
    final url = pictureUrl;
    if (url != null) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: _size,
        height: _size,
        errorBuilder: (_, _, _) => _defaultAvatar(colors),
      );
    }

    return _defaultAvatar(colors);
  }
}
