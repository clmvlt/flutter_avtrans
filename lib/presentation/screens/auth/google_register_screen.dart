import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../widgets/widgets.dart';
import 'widgets/auth_form_message.dart';
import 'widgets/auth_header.dart';
import 'widgets/auth_link_row.dart';
import 'widgets/auth_scaffold.dart';

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
              : 'Réponse inattendue du serveur. Réessaie dans un instant.';
        });
      },
    );
  }

  void _backToLogin() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_pendingActivationMessage != null) {
      return _buildPendingActivationScreen();
    }

    final textTheme = Theme.of(context).textTheme;

    return AuthScaffold(
      showBack: true,
      busy: _isLoading,
      children: [
        AuthHeader(
          leading: _GoogleAvatar(profile: widget.profile),
          title: 'Finalise ton inscription',
          subtitle: 'Aucun compte n\'existe pour ce compte Google. '
              'Vérifie tes informations avant de créer ton compte.',
        ),
        const SizedBox(height: AppSpacing.xl),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Email : toujours extrait du token côté API, jamais du
                // formulaire — non modifiable.
                AppTextField(
                  controller: _emailController,
                  label: 'Email',
                  prefixIcon: const Icon(Icons.mail_outline, size: 20),
                  enabled: false,
                ),
                const SizedBox(height: AppSpacing.xs),
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.xs),
                  child: Text(
                    'Adresse fournie par Google, non modifiable.',
                    style: textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: AppSpacing.base),
                AppTextField(
                  controller: _firstNameController,
                  label: 'Prénom',
                  hint: 'Jean',
                  prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                  enabled: !_isLoading,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _lastNameFocusNode.requestFocus(),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
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
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _register(),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Entre ton nom';
                    }
                    return null;
                  },
                ),
                AuthFormMessage(error: _errorMessage),
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
          onPressed: _isLoading ? null : _backToLogin,
        ),
      ],
    );
  }

  /// Écran d'attente : le compte existe mais doit être activé par un
  /// administrateur. Aucun identifiant utilisateur n'est renvoyé par l'API
  /// (fiche §3), il n'y a donc pas de polling possible : l'utilisateur relance
  /// « Continuer avec Google » une fois activé.
  Widget _buildPendingActivationScreen() {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final message = _pendingActivationMessage!;

    return AuthScaffold(
      title: 'Inscription',
      centered: false,
      dock: AppDock(
        actions: [
          DockAction(
            label: 'Retour à la connexion',
            icon: Icons.arrow_back_rounded,
            onPressed: _backToLogin,
          ),
        ],
      ),
      children: [
        AppHeroCard(
          icon: Icons.admin_panel_settings_rounded,
          accent: colors.warning,
          title: 'Compte créé',
          subtitle: 'En attente d\'activation',
          child: message.isEmpty
              ? null
              : Text(
                  message,
                  style: textTheme.bodyMedium
                      ?.copyWith(color: colors.mutedForeground),
                ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppAlert(
          variant: AlertVariant.info,
          description: 'Une fois ton compte activé, reviens sur l\'application '
              'et appuie à nouveau sur « Continuer avec Google » avec '
              '${widget.profile.email}.',
        ),
      ],
    );
  }
}

/// Photo (ou initiales) du compte Google, marquée du « G » en bas à droite.
class _GoogleAvatar extends StatelessWidget {
  const _GoogleAvatar({required this.profile});

  final GoogleProfile profile;

  static const double _size = 72;
  static const double _badge = 28;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SizedBox(
      width: _size + AppSpacing.xs,
      height: _size + AppSpacing.xs,
      child: Stack(
        children: [
          AppAvatar(
            imageUrl: profile.pictureUrl,
            fallbackText: profile.initials,
            size: _size,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: _badge,
              height: _badge,
              decoration: BoxDecoration(
                color: colors.card,
                shape: BoxShape.circle,
                border: Border.all(color: colors.border),
                boxShadow: colors.cardShadow,
              ),
              alignment: Alignment.center,
              child: const GoogleLogo(size: 16),
            ),
          ),
        ],
      ),
    );
  }
}
