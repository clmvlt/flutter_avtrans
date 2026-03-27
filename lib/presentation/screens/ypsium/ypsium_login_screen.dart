import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/widgets.dart';
import 'ypsium_home_screen.dart';

/// Page de connexion Ypsium - authentification vers l'API de transport
class YpsiumLoginScreen extends StatefulWidget {
  const YpsiumLoginScreen({super.key});

  @override
  State<YpsiumLoginScreen> createState() => _YpsiumLoginScreenState();
}

class _YpsiumLoginScreenState extends State<YpsiumLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();

  bool _isLoading = false;
  bool _isRestoringSession = true;
  bool _rememberMe = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tryRestoreSession();
  }

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _tryRestoreSession() async {
    final session = await sl.ypsiumAuthRepository.tryRestoreSession();
    if (!mounted) return;

    if (session != null) {
      // Session encore valide → aller directement au home
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const YpsiumHomeScreen()),
      );
      return;
    }

    // Pas de session valide → afficher le formulaire
    setState(() => _isRestoringSession = false);
    _loadSavedCredentials();
  }

  void _loadSavedCredentials() {
    final repo = sl.ypsiumAuthRepository;
    if (repo.isRememberMeEnabled) {
      _loginController.text = repo.savedLogin ?? '';
      _passwordController.text = repo.savedPassword ?? '';
      setState(() => _rememberMe = true);
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await sl.ypsiumAuthRepository.login(
      login: _loginController.text.trim(),
      password: _passwordController.text,
      rememberMe: _rememberMe,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    result.fold(
      (failure) => setState(() => _errorMessage = failure.message),
      (session) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const YpsiumHomeScreen()),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (_isRestoringSession) {
      return Scaffold(
        backgroundColor: colors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: colors.primary, strokeWidth: 2),
              const SizedBox(height: AppSpacing.base),
              Text(
                'Connexion à Ypsium...',
                style: TextStyle(fontSize: 14, color: colors.mutedForeground),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.foreground, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Ypsium',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.3,
            color: colors.foreground,
          ),
        ),
      ),
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
                    // Icon
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: colors.chart4.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        child: Icon(
                          Icons.local_shipping,
                          size: 36,
                          color: colors.chart4,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Title
                    Text(
                      'Ypsium Transport',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: colors.foreground,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Connectez-vous pour accéder aux commandes',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: colors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    // Login card
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.xl),
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

                          // Identifiant
                          AppTextField(
                            controller: _loginController,
                            label: 'Identifiant',
                            hint: 'Votre identifiant Ypsium',
                            prefixIcon: const Icon(Icons.person_outline, size: 18),
                            enabled: !_isLoading,
                            textInputAction: TextInputAction.next,
                            onSubmitted: (_) => _passwordFocusNode.requestFocus(),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Veuillez entrer votre identifiant';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.base),

                          // Mot de passe
                          _YpsiumPasswordField(
                            controller: _passwordController,
                            focusNode: _passwordFocusNode,
                            enabled: !_isLoading,
                            onSubmitted: (_) => _login(),
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // Remember me
                          GestureDetector(
                            onTap: _isLoading
                                ? null
                                : () => setState(() => _rememberMe = !_rememberMe),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Checkbox(
                                    value: _rememberMe,
                                    onChanged: _isLoading
                                        ? null
                                        : (value) =>
                                            setState(() => _rememberMe = value ?? false),
                                    activeColor: colors.primary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    side: BorderSide(color: colors.border, width: 1.5),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  'Se souvenir de moi',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: colors.foreground,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),

                          AppButton(
                            text: 'Se connecter',
                            onPressed: _login,
                            isLoading: _isLoading,
                          ),
                        ],
                      ),
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
}

/// Champ mot de passe Ypsium sans contrainte de longueur minimale
class _YpsiumPasswordField extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool enabled;
  final void Function(String)? onSubmitted;

  const _YpsiumPasswordField({
    this.controller,
    this.focusNode,
    this.enabled = true,
    this.onSubmitted,
  });

  @override
  State<_YpsiumPasswordField> createState() => _YpsiumPasswordFieldState();
}

class _YpsiumPasswordFieldState extends State<_YpsiumPasswordField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: widget.controller,
      label: 'Mot de passe',
      obscureText: _obscureText,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: TextInputAction.done,
      prefixIcon: const Icon(Icons.lock_outline, size: 18),
      suffixIcon: IconButton(
        icon: Icon(
          _obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          size: 18,
        ),
        onPressed: () => setState(() => _obscureText = !_obscureText),
      ),
      enabled: widget.enabled,
      onSubmitted: widget.onSubmitted,
      focusNode: widget.focusNode,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Veuillez entrer votre mot de passe';
        }
        return null;
      },
    );
  }
}
