import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../widgets/widgets.dart';

/// Page d'inscription
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _lastNameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // États pour le flow de vérification
  bool _isWaitingForEmailVerification = false;
  bool _isEmailVerified = false;
  bool _isWaitingForAdminActivation = false;
  String? _registeredUserId;
  Timer? _statusCheckTimer;

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _lastNameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'Les mots de passe ne correspondent pas');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final result = await sl.authRepository.register(
      RegisterRequest(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
      ),
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    result.fold(
      (failure) {
        setState(() => _errorMessage = failure.message);
      },
      (response) {
        if (response.userId != null) {
          setState(() {
            _registeredUserId = response.userId;
            _isWaitingForEmailVerification = true;
            _successMessage = 'Compte créé ! Veuillez vérifier votre email.';
          });
          _startStatusCheck();
        } else {
          setState(() => _errorMessage = 'Erreur lors de la création du compte');
        }
      },
    );
  }

  void _startStatusCheck() {
    _statusCheckTimer?.cancel();
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkUserStatus();
    });
  }

  Future<void> _checkUserStatus() async {
    if (_registeredUserId == null) return;

    final result = await sl.authRepository.checkUserStatus(_registeredUserId!);

    if (!mounted) return;

    result.fold(
      (failure) {
        // En cas d'erreur, on continue le polling
      },
      (status) {
        if (status.isMailVerified && !_isEmailVerified) {
          setState(() {
            _isEmailVerified = true;
            _isWaitingForEmailVerification = false;
            _isWaitingForAdminActivation = true;
          });
        }

        if (status.isMailVerified && status.isActive) {
          // Compte activé par l'admin, redirection vers login
          _statusCheckTimer?.cancel();
          _navigateToLogin();
        }
      },
    );
  }

  void _navigateToLogin() {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Votre compte a été activé ! Vous pouvez maintenant vous connecter.'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // Afficher l'écran de vérification si le compte est créé
    if (_isWaitingForEmailVerification || _isWaitingForAdminActivation) {
      return _buildVerificationScreen(colors);
    }

    return Scaffold(
      backgroundColor: colors.bgPrimary,
      appBar: AppBar(
        title: const Text('Inscription'),
        backgroundColor: colors.bgPrimary,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: LoadingOverlay(
          isLoading: _isLoading,
          message: 'Inscription en cours...',
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Titre
                  Text(
                    'Créer un compte',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Remplissez les informations ci-dessous',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // Card du formulaire
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
                        // Message de succès
                        if (_successMessage != null) ...[
                          _buildSuccessMessage(_successMessage!, colors),
                          const SizedBox(height: AppSpacing.base),
                        ],

                        // Message d'erreur
                        if (_errorMessage != null) ...[
                          _buildErrorMessage(_errorMessage!, colors),
                          const SizedBox(height: AppSpacing.base),
                        ],

                        // Prénom
                        AppTextField(
                          controller: _firstNameController,
                          label: 'Prénom',
                          hint: 'Jean',
                          prefixIcon: const Icon(Icons.person_outline),
                          enabled: !_isLoading,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => _lastNameFocusNode.requestFocus(),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Veuillez entrer votre prénom';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.base),

                        // Nom
                        AppTextField(
                          controller: _lastNameController,
                          focusNode: _lastNameFocusNode,
                          label: 'Nom',
                          hint: 'Dupont',
                          prefixIcon: const Icon(Icons.person_outline),
                          enabled: !_isLoading,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => _emailFocusNode.requestFocus(),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Veuillez entrer votre nom';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.base),

                        // Email
                        EmailTextField(
                          controller: _emailController,
                          focusNode: _emailFocusNode,
                          enabled: !_isLoading,
                          onSubmitted: (_) => _passwordFocusNode.requestFocus(),
                        ),
                        const SizedBox(height: AppSpacing.base),

                        // Mot de passe
                        PasswordTextField(
                          controller: _passwordController,
                          focusNode: _passwordFocusNode,
                          enabled: !_isLoading,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => _confirmPasswordFocusNode.requestFocus(),
                        ),
                        const SizedBox(height: AppSpacing.base),

                        // Confirmation mot de passe
                        PasswordTextField(
                          controller: _confirmPasswordController,
                          focusNode: _confirmPasswordFocusNode,
                          label: 'Confirmer le mot de passe',
                          enabled: !_isLoading,
                          onSubmitted: (_) => _register(),
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        // Bouton d'inscription
                        AppButton(
                          text: 'S\'inscrire',
                          onPressed: _register,
                          isLoading: _isLoading,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Lien vers connexion
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Déjà un compte ?',
                        style: TextStyle(color: colors.textSecondary),
                      ),
                      AppTextButton(
                        text: 'Se connecter',
                        onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationScreen(AppColors colors) {
    return Scaffold(
      backgroundColor: colors.bgPrimary,
      appBar: AppBar(
        title: const Text('Vérification'),
        backgroundColor: colors.bgPrimary,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icône animée
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: _isWaitingForAdminActivation
                      ? colors.warningBg
                      : colors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isWaitingForAdminActivation
                      ? Icons.admin_panel_settings_outlined
                      : Icons.mark_email_unread_outlined,
                  size: 48,
                  color: _isWaitingForAdminActivation
                      ? colors.warning
                      : colors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              // Titre
              Text(
                _isWaitingForAdminActivation
                    ? 'Email vérifié !'
                    : 'Vérifiez votre email',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.base),

              // Description
              Text(
                _isWaitingForAdminActivation
                    ? 'Votre email a été vérifié avec succès.\n\nVeuillez patienter pendant qu\'un administrateur active votre compte. Vous serez redirigé automatiquement.'
                    : 'Un email de vérification a été envoyé à :\n${_emailController.text}\n\nCliquez sur le lien dans l\'email pour vérifier votre compte.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: colors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              // Indicateur de chargement
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _isWaitingForAdminActivation
                            ? colors.warning
                            : colors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    _isWaitingForAdminActivation
                        ? 'En attente d\'activation...'
                        : 'En attente de vérification...',
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),

              // Étapes de progression
              _buildProgressSteps(colors),

              const Spacer(),

              // Bouton retour à la connexion
              AppTextButton(
                text: 'Retour à la connexion',
                onPressed: () {
                  _statusCheckTimer?.cancel();
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSteps(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: colors.bgSecondary,
        borderRadius: BorderRadius.circular(AppRadius.base),
        border: Border.all(color: colors.borderPrimary),
      ),
      child: Column(
        children: [
          _buildStepItem(
            colors: colors,
            icon: Icons.check_circle,
            title: 'Compte créé',
            isCompleted: true,
            isActive: false,
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildStepItem(
            colors: colors,
            icon: _isEmailVerified ? Icons.check_circle : Icons.radio_button_unchecked,
            title: 'Email vérifié',
            isCompleted: _isEmailVerified,
            isActive: _isWaitingForEmailVerification,
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildStepItem(
            colors: colors,
            icon: Icons.radio_button_unchecked,
            title: 'Compte activé par l\'admin',
            isCompleted: false,
            isActive: _isWaitingForAdminActivation,
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem({
    required AppColors colors,
    required IconData icon,
    required String title,
    required bool isCompleted,
    required bool isActive,
  }) {
    final Color iconColor;
    if (isCompleted) {
      iconColor = colors.success;
    } else if (isActive) {
      iconColor = colors.primary;
    } else {
      iconColor = colors.textMuted;
    }

    return Row(
      children: [
        Icon(
          isCompleted ? Icons.check_circle : icon,
          size: 24,
          color: iconColor,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              color: isCompleted || isActive
                  ? colors.textPrimary
                  : colors.textMuted,
            ),
          ),
        ),
        if (isActive)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
            ),
          ),
      ],
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
          Icon(Icons.error_outline, color: colors.error, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.textPrimary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessMessage(String message, AppColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.successBg,
        borderRadius: BorderRadius.circular(AppRadius.base),
        border: Border(
          left: BorderSide(color: colors.success, width: 4),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: colors.success, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.textPrimary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
