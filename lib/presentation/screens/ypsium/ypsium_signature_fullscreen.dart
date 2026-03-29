import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:signature/signature.dart';

import '../../../core/theme/app_theme.dart';

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

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Toolbar
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: colors.card,
                border: Border(bottom: BorderSide(color: colors.border)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.close, size: 22, color: colors.foreground),
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    onPressed: () => Navigator.of(context).pop(false),
                    tooltip: 'Fermer',
                  ),
                  Text(
                    'Signature',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.foreground,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.refresh, size: 20, color: colors.mutedForeground),
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    onPressed: () => widget.controller.clear(),
                    tooltip: 'Effacer',
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(true),
                    icon: const Icon(Icons.check, size: 20),
                    label: Text('OK', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: colors.primaryForeground)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.primaryForeground,
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.base,
                        vertical: AppSpacing.sm,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
              ),
            ),

            // Zone de signature
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: colors.foreground.withValues(alpha: 0.25),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: Signature(
                    controller: widget.controller,
                    backgroundColor: Colors.white,
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
