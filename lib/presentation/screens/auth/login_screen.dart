import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/errors/failures.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../widgets/widgets.dart';
import '../shell/main_shell.dart';
import 'google_register_screen.dart';
import 'register_screen.dart';

/// Page de connexion — Z-pattern, CTA en bas, accessibilite
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
  bool _isGoogleLoading = false;
  String? _errorMessage;

  /// Le SDK Google n'est disponible que sur Android / iOS / macOS.
  late final bool _isGoogleSignInAvailable;

  bool get _isBusy => _isLoading || _isGoogleLoading;

  @override
  void initState() {
    super.initState();
    _isGoogleSignInAvailable = sl.googleSignInService.isSupported;
  }

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
      (failure) => setState(() => _errorMessage = failure.message),
      (user) => _navigateToHome(),
    );
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  /// Fiche Google §5 : SDK → `POST /auth/google` → `AUTHENTICATED` (accueil)
  /// ou `NEEDS_REGISTRATION` (inscription pré-remplie). Une annulation du
  /// sélecteur de compte n'affiche aucune erreur.
  Future<void> _signInWithGoogle() async {
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
    });

    final result = await sl.authRepository.signInWithGoogle();

    if (!mounted) return;
    setState(() => _isGoogleLoading = false);

    result.fold(
      (failure) {
        if (failure is CancelledFailure) return;
        setState(() => _errorMessage = failure.message);
      },
      (auth) {
        switch (auth.status) {
          case GoogleAuthStatus.authenticated:
            _navigateToHome();
          case GoogleAuthStatus.needsRegistration:
            final profile = auth.googleProfile;
            if (profile == null) {
              setState(() => _errorMessage =
                  'Réponse inattendue du serveur : profil Google manquant.');
              return;
            }
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => GoogleRegisterScreen(
                  idToken: auth.idToken,
                  profile: profile,
                ),
              ),
            );
          case GoogleAuthStatus.pendingActivation:
          case GoogleAuthStatus.unknown:
            setState(() => _errorMessage = auth.message.isNotEmpty
                ? auth.message
                : 'Réponse inattendue du serveur. Veuillez réessayer.');
        }
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
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: LoadingOverlay(
          isLoading: _isBusy,
          message: _isGoogleLoading
              ? 'Connexion Google en cours...'
              : 'Connexion en cours...',
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xl,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Z-pattern: logo en haut-gauche (zone primaire optique)
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          child: Image.asset(
                            'lib/assets/icons/icon-512x512.png',
                            width: 80,
                            height: 80,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Titre
                      Text(
                        'Pointage AVTRANS',
                        textAlign: TextAlign.center,
                        style: textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Connectez-vous pour continuer',
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // Carte de connexion
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: colors.card,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: colors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_errorMessage != null) ...[
                              AppAlert(
                                description: _errorMessage!,
                                variant: AlertVariant.destructive,
                              ),
                              const SizedBox(height: AppSpacing.base),
                            ],

                            EmailTextField(
                              controller: _emailController,
                              enabled: !_isBusy,
                              onSubmitted: (_) => _passwordFocusNode.requestFocus(),
                            ),
                            const SizedBox(height: AppSpacing.base),

                            PasswordTextField(
                              controller: _passwordController,
                              focusNode: _passwordFocusNode,
                              enabled: !_isBusy,
                              onSubmitted: (_) => _login(),
                            ),
                            const SizedBox(height: AppSpacing.lg),

                            // CTA principal — zone terminale du Z-pattern
                            AppButton(
                              text: 'Se connecter',
                              onPressed: _isGoogleLoading ? null : _login,
                              isLoading: _isLoading,
                            ),

                            // Connexion Google (Android / iOS / macOS)
                            if (_isGoogleSignInAvailable) ...[
                              const SizedBox(height: AppSpacing.lg),
                              _buildOrDivider(colors, textTheme),
                              const SizedBox(height: AppSpacing.lg),
                              GoogleSignInButton(
                                onPressed:
                                    _isLoading ? null : _signInWithGoogle,
                                isLoading: _isGoogleLoading,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Lien inscription
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Pas encore de compte ?',
                            style: textTheme.bodySmall,
                          ),
                          AppTextButton(
                            text: 'S\'inscrire',
                            onPressed: _isBusy ? null : _goToRegister,
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
      ),
    );
  }

  /// Séparateur « ou » entre la connexion classique et Google
  Widget _buildOrDivider(AppColors colors, TextTheme textTheme) {
    return Row(
      children: [
        const Expanded(child: AppSeparator()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            'ou',
            style: textTheme.bodySmall?.copyWith(color: colors.mutedForeground),
          ),
        ),
        const Expanded(child: AppSeparator()),
      ],
    );
  }
}
