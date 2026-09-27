import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// La « feuille » de signature, blanche à encre noire dans les deux thèmes.
///
/// Ces deux couleurs ne sont pas du thème : ce sont celles du PNG exporté et
/// enregistré par l'API (`SignatureController.penColor` /
/// `exportBackgroundColor`). Les repères posés sur la feuille prennent les
/// jetons du thème clair, lisibles sur ce blanc.
abstract final class SignaturePaper {
  static const Color paper = Colors.white;
  static const Color ink = Colors.black;

  static Color get hint => AppColors.light.mutedForeground;
  static Color get line => AppColors.light.border;
}

/// Image d'une signature enregistrée (PNG en base64) sur sa feuille.
/// Une donnée illisible affiche un message au lieu de planter l'écran.
class SignatureImage extends StatelessWidget {
  const SignatureImage({super.key, required this.base64, this.height = 160});

  final String base64;
  final double height;

  Uint8List? _decode() {
    try {
      return base64Decode(base64);
    } on FormatException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final bytes = _decode();

    Widget unreadable() => Center(
          child: Text(
            'Signature illisible',
            style: textTheme.bodySmall?.copyWith(color: SignaturePaper.hint),
          ),
        );

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: SignaturePaper.paper,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: bytes == null
          ? unreadable()
          : Image.memory(
              bytes,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => unreadable(),
            ),
    );
  }
}
