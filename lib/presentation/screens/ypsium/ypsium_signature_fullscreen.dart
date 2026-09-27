import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:signature/signature.dart';

import '../../../core/theme/app_theme.dart';
import '../../widgets/widgets.dart';
import 'widgets/ypsium_signature_form.dart';

/// Écran de signature en plein écran (paysage forcé)
/// Retourne `true` si l'utilisateur a confirmé sa signature
class YpsiumSignatureFullscreen extends StatefulWidget {
  final SignatureController controller;

  const YpsiumSignatureFullscreen({super.key, required this.controller});

  @override
  State<YpsiumSignatureFullscreen> createState() =>
      _YpsiumSignatureFullscreenState();
}

class _YpsiumSignatureFullscreenState extends State<YpsiumSignatureFullscreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Barre d'outils : fermer · titre · effacer · terminer
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xs,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: Row(
                children: [
                  AppIconButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Fermer',
                    color: colors.foreground,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Signature', style: textTheme.titleMedium),
                        Text(
                          'Fais signer dans le cadre',
                          style: textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => widget.controller.clear(),
                    style: TextButton.styleFrom(
                      foregroundColor: colors.foreground,
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      textStyle: textTheme.labelLarge,
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    label: const Text('Effacer'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(true),
                    icon: const Icon(Icons.check_rounded, size: 20),
                    label: const Text('Terminer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.primaryForeground,
                      elevation: 0,
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      textStyle: textTheme.labelLarge,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Zone de signature
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: Semantics(
                  label: 'Zone de signature',
                  child: Container(
                    decoration: BoxDecoration(
                      color: ypsiumSignaturePaper,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: colors.border, width: 1.5),
                      boxShadow: colors.cardShadow,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      child: Signature(
                        controller: widget.controller,
                        backgroundColor: ypsiumSignaturePaper,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
