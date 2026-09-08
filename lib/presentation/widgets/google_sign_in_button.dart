import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Bouton « Continuer avec Google » — outline, touch target 48dp, logo « G »
/// vectoriel (aucun asset requis).
class GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final String text;

  const GoogleSignInButton({
    super.key,
    this.onPressed,
    this.isLoading = false,
    this.text = 'Continuer avec Google',
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.foreground,
          backgroundColor: colors.card,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          side: BorderSide(color: colors.input),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(colors.mutedForeground),
                ),
              )
            else
              const GoogleLogo(size: 20),
            const SizedBox(width: AppSpacing.md),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Logo « G » de Google (couleurs officielles), dessiné au CustomPainter.
class GoogleLogo extends StatelessWidget {
  final double size;

  const GoogleLogo({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: const _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  static const Color _blue = Color(0xFF4285F4);
  static const Color _red = Color(0xFFEA4335);
  static const Color _yellow = Color(0xFFFBBC05);
  static const Color _green = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final stroke = side * 0.2;
    final center = Offset(size.width / 2, size.height / 2);
    final ring = Rect.fromCircle(center: center, radius: side / 2 - stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    // Angles Flutter : 0° à droite, sens horaire. Découpage repris du SVG
    // officiel ; l'ouverture du G est en haut à droite (312° → 360°). Chaque
    // arc déborde de 1° sur le précédent pour masquer les jointures.
    void arc(Color color, double startDeg, double endDeg) {
      paint.color = color;
      canvas.drawArc(
        ring,
        _rad(startDeg),
        _rad(endDeg - startDeg),
        false,
        paint,
      );
    }

    arc(_red, 207, 312);
    arc(_yellow, 159, 208);
    arc(_green, 49, 160);
    arc(_blue, 0, 50);

    // Barre horizontale bleue, du centre jusqu'au bord droit.
    canvas.drawRect(
      Rect.fromLTWH(center.dx, center.dy - stroke / 2, side / 2, stroke),
      Paint()..color = _blue,
    );
  }

  double _rad(double degrees) => degrees * math.pi / 180;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
