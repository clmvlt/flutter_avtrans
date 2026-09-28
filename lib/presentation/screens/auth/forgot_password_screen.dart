import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../widgets/widgets.dart';
import 'widgets/auth_form_message.dart';
import 'widgets/auth_header.dart';
import 'widgets/auth_link_row.dart';
import 'widgets/auth_scaffold.dart';

/// Mot de passe oublié : l'API envoie par email un lien (valable 1 h) vers
/// la page web de réinitialisation (`POST /auth/password-reset/request`).
///
/// Une fois l'email envoyé, la page se ferme avec l'adresse utilisée : la
/// connexion la reprend et annonce l'envoi au-dessus de son bouton.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  /// Email déjà saisi sur la connexion.
  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _emailController = TextEditingController(
    text: widget.initialEmail,
  );

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await sl.authRepository.requestPasswordReset(
      PasswordResetRequest(email: email),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    result.fold(
      (failure) => setState(() => _errorMessage = failure.message),
      (_) => Navigator.of(context).pop(email),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBack: true,
      busy: _isLoading,
      children: [
        const AuthHeader(
          title: 'Mot de passe oublié',
          subtitle: 'Reçois un lien par email pour en choisir un nouveau',
        ),
        const SizedBox(height: AppSpacing.xl),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EmailTextField(
                  controller: _emailController,
                  enabled: !_isLoading,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _submit(),
                ),
                AuthFormMessage(error: _errorMessage),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  text: 'Envoyer le lien',
                  icon: Icons.send_rounded,
                  size: ButtonSize.lg,
                  onPressed: _submit,
                  isLoading: _isLoading,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AuthLinkRow(
          prompt: 'Tu t\'en souviens ?',
          actionLabel: 'Se connecter',
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
