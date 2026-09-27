import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../widgets/app_alert.dart';

/// Message inline d'un formulaire d'authentification, placé juste au-dessus
/// du bouton principal : succès puis erreur (message du repository tel
/// quel). Apparaît et disparaît en douceur ; annoncé aux lecteurs d'écran.
class AuthFormMessage extends StatelessWidget {
  const AuthFormMessage({super.key, this.error, this.success});

  final String? error;
  final String? success;

  @override
  Widget build(BuildContext context) {
    final hasMessage = error != null || success != null;

    return AnimatedSize(
      duration: AppDuration.base,
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: !hasMessage
          ? const SizedBox(width: double.infinity)
          : Semantics(
              liveRegion: true,
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.base),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (success != null)
                      AppAlert(
                        description: success!,
                        variant: AlertVariant.success,
                      ),
                    if (success != null && error != null)
                      const SizedBox(height: AppSpacing.sm),
                    if (error != null)
                      AppAlert(
                        description: error!,
                        variant: AlertVariant.destructive,
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
