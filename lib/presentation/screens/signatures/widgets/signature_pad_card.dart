import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_list_row.dart';
import 'signature_paper.dart';

/// Section « Ta signature » : le pavé sur sa feuille blanche, une consigne
/// tant qu'il est vide, une ligne de signature, et « Effacer » en en-tête.
class SignaturePadCard extends StatelessWidget {
  const SignaturePadCard({
    super.key,
    required this.controller,
    required this.onClear,
    this.height = 260,
  });

  final SignatureController controller;

  /// `null` pendant l'envoi : « Effacer » disparaît.
  final VoidCallback? onClear;
  final double height;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(
          title: 'Ta signature',
          actionLabel: 'Effacer',
          onAction: onClear,
        ),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Semantics(
            label: 'Zone de signature',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: SizedBox(
                height: height,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Signature(
                      controller: controller,
                      backgroundColor: SignaturePaper.paper,
                    ),
                    // Repères non interactifs : consigne et ligne de signature.
                    IgnorePointer(
                      child: ValueListenableBuilder<List<Point>>(
                        valueListenable: controller,
                        builder: (context, points, _) => AnimatedOpacity(
                          opacity: points.isEmpty ? 1 : 0,
                          duration: AppDuration.fast,
                          child: Center(
                            child: Text(
                              'Signe ici avec ton doigt',
                              style: textTheme.bodyLarge?.copyWith(
                                color: SignaturePaper.hint,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: AppSpacing.lg,
                      right: AppSpacing.lg,
                      bottom: AppSpacing.xxl,
                      child: IgnorePointer(
                        child: Container(height: 1, color: SignaturePaper.line),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
