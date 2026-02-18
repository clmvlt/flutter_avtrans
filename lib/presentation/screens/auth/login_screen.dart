import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../widgets/widgets.dart';
import '../home/home_screen.dart';
import 'register_screen.dart';

/// Page de connexion
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await sl.authRepository.login(
      LoginRequest(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      ),
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    result.fold(
      (failure) {
        setState(() => _errorMessage = failure.message);
      },
      (user) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      },
    );
  }

  void _goToRegister() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bgPrimary,
      body: SafeArea(
        child: LoadingOverlay(
          isLoading: _isLoading,
          message: 'Connexion en cours...',
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        child: Image.asset(
                          'lib/assets/icons/icon-512x512.png',
                          width: 80,
                          height: 80,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Titre
                    Text(
                      'Pointage',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Connectez-vous pour continuer',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxxl),

                    // Card de connexion
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      decoration: BoxDecoration(
                        color: colors.bgSecondary,
                        borderRadius: BorderRadius.circular(AppRadius.base),
                        border: Border.all(color: colors.borderPrimary),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Message d'erreur
                          if (_errorMessage != null) ...[
                            _buildErrorMessage(_errorMessage!, colors),
                            const SizedBox(height: AppSpacing.base),
                          ],

                          // Email
                          EmailTextField(
                            controller: _emailController,
                            enabled: !_isLoading,
                            onSubmitted: (_) => _passwordFocusNode.requestFocus(),
                          ),
                          const SizedBox(height: AppSpacing.base),

                          // Mot de passe
                          PasswordTextField(
                            controller: _passwordController,
                            focusNode: _passwordFocusNode,
                            enabled: !_isLoading,
                            onSubmitted: (_) => _login(),
                          ),
                          const SizedBox(height: AppSpacing.xl),

                          // Bouton de connexion
                          AppButton(
                            text: 'Se connecter',
                            onPressed: _login,
                            isLoading: _isLoading,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Lien vers inscription
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Pas encore de compte ?',
                          style: TextStyle(color: colors.textSecondary),
                        ),
                        AppTextButton(
                          text: 'S\'inscrire',
                          onPressed: _isLoading ? null : _goToRegister,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorMessage(String message, AppColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.errorBg,
        borderRadius: BorderRadius.circular(AppRadius.base),
        border: Border(
          left: BorderSide(color: colors.error, width: 4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: colors.error,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
