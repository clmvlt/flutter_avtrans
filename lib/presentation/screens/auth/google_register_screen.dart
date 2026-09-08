import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../widgets/widgets.dart';

/// Création de compte après un `NEEDS_REGISTRATION` de `POST /auth/google`
/// (fiche d'intégration §3) : email Google non modifiable, prénom / nom
/// pré-remplis et modifiables, puis `POST /auth/google/register` avec le
/// **même** `idToken`. Aucun token API n'est renvoyé : le compte doit être
/// activé par un administrateur avant la première connexion.
class GoogleRegisterScreen extends StatefulWidget {
  /// ID token Google déjà validé par `POST /auth/google` (valable 1 h).
  final String idToken;

  /// Profil Google renvoyé par l'API pour pré-remplir le formulaire.
  final GoogleProfile profile;

  const GoogleRegisterScreen({
    super.key,
    required this.idToken,
    required this.profile,
  });

  @override
  State<GoogleRegisterScreen> createState() => _GoogleRegisterScreenState();
}

class _GoogleRegisterScreenState extends State<GoogleRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  final _lastNameFocusNode = FocusNode();

  bool _isLoading = false;
  String? _errorMessage;

  /// Message serveur reçu avec `PENDING_ACTIVATION` — bascule sur l'écran
  /// d'attente d'activation.
  String? _pendingActivationMessage;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.profile.email);
    _firstNameController =
        TextEditingController(text: widget.profile.firstName);
    _lastNameController = TextEditingController(text: widget.profile.lastName);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _lastNameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await sl.authRepository.registerWithGoogle(
      GoogleRegisterRequest(
        idToken: widget.idToken,
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
      ),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    result.fold(
      (failure) => setState(() => _errorMessage = failure.message),
      (response) {
        if (response.status == GoogleAuthStatus.pendingActivation) {
          setState(() => _pendingActivationMessage = response.message);
          return;
        }
        // Tout autre statut n'est pas prévu par la fiche §3 : on affiche le
        // message serveur et on laisse l'utilisateur repasser par le login.
        setState(() {
          _errorMessage = response.message.isNotEmpty
              ? response.message
              : 'Réponse inattendue du serveur. Veuillez réessayer.';
        });
      },
    );
  }

  void _backToLogin() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (_pendingActivationMessage != null) {
      return _buildPendingActivationScreen(colors);
    }

    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Inscription'),
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: LoadingOverlay(
          isLoading: _isLoading,
          message: 'Création du compte...',
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: AppAvatar(
                          imageUrl: widget.profile.pictureUrl,
                          fallbackText: widget.profile.initials,
                          size: 72,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.base),

                      Text(
                        'Finaliser votre inscription',
                        textAlign: TextAlign.center,
                        style: textTheme.headlineSmall?.copyWith(
                          color: colors.foreground,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Aucun compte n\'existe pour ce compte Google. Vérifiez vos informations avant de créer votre compte.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),

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

                            // Email : toujours extrait du token côté API,
                            // jamais du formulaire — non modifiable.
                            AppTextField(
                              controller: _emailController,
                              label: 'Email',
                              prefixIcon:
                                  const Icon(Icons.mail_outline, size: 20),
                              enabled: false,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Adresse fournie par Google, non modifiable.',
                              style: textTheme.bodySmall?.copyWith(
                                color: colors.mutedForeground,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.base),

                            AppTextField(
                              controller: _firstNameController,
                              label: 'Prénom',
                              hint: 'Jean',
                              prefixIcon: const Icon(Icons.person_outline),
                              enabled: !_isLoading,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) =>
                                  _lastNameFocusNode.requestFocus(),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Veuillez entrer votre prénom';
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
                              prefixIcon: const Icon(Icons.person_outline),
                              enabled: !_isLoading,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _register(),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Veuillez entrer votre nom';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.lg),

                            AppButton(
                              text: 'Créer mon compte',
                              onPressed: _register,
                              isLoading: _isLoading,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Déjà un compte ?',
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.mutedForeground,
                            ),
                          ),
                          AppTextButton(
                            text: 'Se connecter',
                            onPressed: _isLoading ? null : _backToLogin,
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

  /// Écran d'attente : le compte existe mais doit être activé par un
  /// administrateur. Aucun identifiant utilisateur n'est renvoyé par l'API
  /// (fiche §3), il n'y a donc pas de polling possible : l'utilisateur relance
  /// « Continuer avec Google » une fois activé.
  Widget _buildPendingActivationScreen(AppColors colors) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Compte créé'),
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: colors.warningMuted,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.admin_panel_settings_outlined,
                        size: 48,
                        color: colors.warning,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  Text(
                    'Compte créé !',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineSmall?.copyWith(
                      color: colors.foreground,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.base),

                  Text(
                    _pendingActivationMessage!,
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.mutedForeground,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  AppAlert(
                    variant: AlertVariant.info,
                    description:
                        'Une fois votre compte activé, revenez sur l\'application et appuyez à nouveau sur « Continuer avec Google » avec ${widget.profile.email}.',
                  ),

                  const Spacer(),

                  AppButton(
                    text: 'Retour à la connexion',
                    onPressed: _backToLogin,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
