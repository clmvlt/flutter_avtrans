import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../widgets/widgets.dart';
import 'widgets/auth_form_message.dart';
import 'widgets/auth_header.dart';
import 'widgets/auth_link_row.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/register_verification_view.dart';

/// Page d'inscription : formulaire dans une carte, puis attente de la
/// vérification de l'email et de l'activation par un administrateur
/// ([RegisterVerificationView], interrogation de l'API toutes les 5 s).
///
/// Quand le compte est activé, la page se ferme avec `true` : la connexion
/// l'annonce au-dessus de son bouton.
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
            _successMessage = 'Compte créé. Vérifie ton email.';
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

  /// Compte activé : retour à la connexion, qui affiche le message de succès
  /// (plus de snackbar).
  void _navigateToLogin() {
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  void _backToLogin() {
    _statusCheckTimer?.cancel();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // Afficher l'écran de vérification si le compte est créé
    if (_isWaitingForEmailVerification || _isWaitingForAdminActivation) {
      return RegisterVerificationView(
        email: _emailController.text,
        isEmailVerified: _isEmailVerified,
        isWaitingForEmailVerification: _isWaitingForEmailVerification,
        isWaitingForAdminActivation: _isWaitingForAdminActivation,
        onBackToLogin: _backToLogin,
      );
    }

    return AuthScaffold(
      showBack: true,
      busy: _isLoading,
      children: [
        const AuthHeader(
          title: 'Créer un compte',
          subtitle: 'Un administrateur activera ensuite ton compte',
        ),
        const SizedBox(height: AppSpacing.xl),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  controller: _firstNameController,
                  label: 'Prénom',
                  hint: 'Jean',
                  prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                  enabled: !_isLoading,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _lastNameFocusNode.requestFocus(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Entre ton prénom';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.base),
                AppTextField(
                  controller: _lastNameController,
                  focusNode: _lastNameFocusNode,
                  label: 'Nom',
                  hint: 'Dupont',
                  prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                  enabled: !_isLoading,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _emailFocusNode.requestFocus(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Entre ton nom';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.base),
                EmailTextField(
                  controller: _emailController,
                  focusNode: _emailFocusNode,
                  enabled: !_isLoading,
                  onSubmitted: (_) => _passwordFocusNode.requestFocus(),
                ),
                const SizedBox(height: AppSpacing.base),
                PasswordTextField(
                  controller: _passwordController,
                  focusNode: _passwordFocusNode,
                  enabled: !_isLoading,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _confirmPasswordFocusNode.requestFocus(),
                ),
                const SizedBox(height: AppSpacing.base),
                PasswordTextField(
                  controller: _confirmPasswordController,
                  focusNode: _confirmPasswordFocusNode,
                  label: 'Confirmer le mot de passe',
                  enabled: !_isLoading,
                  onSubmitted: (_) => _register(),
                ),
                AuthFormMessage(
                  error: _errorMessage,
                  success: _successMessage,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  text: 'Créer mon compte',
                  icon: Icons.person_add_alt_1_rounded,
                  size: ButtonSize.lg,
                  onPressed: _register,
                  isLoading: _isLoading,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AuthLinkRow(
          prompt: 'Déjà un compte ?',
          actionLabel: 'Se connecter',
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
