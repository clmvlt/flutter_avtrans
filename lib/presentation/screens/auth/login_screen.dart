import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/errors/failures.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../widgets/widgets.dart';
import '../shell/main_shell.dart';
import 'forgot_password_screen.dart';
import 'google_register_screen.dart';
import 'register_screen.dart';
import 'widgets/auth_form_message.dart';
import 'widgets/auth_header.dart';
import 'widgets/auth_link_row.dart';
import 'widgets/auth_scaffold.dart';

/// Page de connexion : logo et nom de l'app, une carte qui porte les champs,
/// le lien « Mot de passe oublié ? » et le bouton « Se connecter » (56 dp),
/// puis Google et le lien d'inscription. Les erreurs du repository
/// s'affichent au-dessus du bouton.
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

  /// Retour de l'inscription (compte activé) ou du mot de passe oublié
  /// (email envoyé).
  String? _successMessage;

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
      _successMessage = null;
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
      _successMessage = null;
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
                : 'Réponse inattendue du serveur. Réessaie dans un instant.');
        }
      },
    );
  }

  /// L'inscription renvoie `true` quand un administrateur a activé le compte
  /// pendant l'attente : on l'annonce ici, au-dessus du bouton.
  Future<void> _goToRegister() async {
    final activated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
    if (!mounted || activated != true) return;
    setState(() {
      _errorMessage = null;
      _successMessage = 'Ton compte est activé. Tu peux te connecter.';
    });
  }

  /// Le mot de passe oublié renvoie l'adresse à laquelle le lien est parti :
  /// on la reprend dans le champ et on annonce l'envoi au-dessus du bouton.
  Future<void> _goToForgotPassword() async {
    final email = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ForgotPasswordScreen(
          initialEmail: _emailController.text.trim(),
        ),
      ),
    );
    if (!mounted || email == null) return;
    _emailController.text = email;
    _passwordController.clear();
    setState(() {
      _errorMessage = null;
      _successMessage = 'Email envoyé à $email. Ouvre le lien reçu (valable '
          '1 heure) pour choisir un nouveau mot de passe, puis connecte-toi '
          'ici.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      busy: _isBusy,
      children: [
        const AuthHeader(
          title: 'Pointage AVTRANS',
          subtitle: 'Gestion du temps de travail',
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
                Align(
                  alignment: Alignment.centerRight,
                  child: AuthTextLink(
                    label: 'Mot de passe oublié ?',
                    onPressed: _isBusy ? null : _goToForgotPassword,
                  ),
                ),
                AuthFormMessage(
                  error: _errorMessage,
                  success: _successMessage,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  text: 'Se connecter',
                  icon: Icons.login_rounded,
                  size: ButtonSize.lg,
                  onPressed: _isGoogleLoading ? null : _login,
                  isLoading: _isLoading,
                ),
              ],
            ),
          ),
        ),

        // Connexion Google (Android / iOS / macOS)
        if (_isGoogleSignInAvailable) ...[
          const SizedBox(height: AppSpacing.lg),
          const AuthOrDivider(),
          const SizedBox(height: AppSpacing.lg),
          GoogleSignInButton(
            onPressed: _isLoading ? null : _signInWithGoogle,
            isLoading: _isGoogleLoading,
          ),
        ],

        const SizedBox(height: AppSpacing.lg),
        AuthLinkRow(
          prompt: 'Pas encore de compte ?',
          actionLabel: 'Créer un compte',
          onPressed: _isBusy ? null : _goToRegister,
        ),
      ],
    );
  }
}
