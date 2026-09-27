import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/widgets.dart';
import 'ypsium_home_screen.dart';

/// Connexion à Ypsium (API de transport).
///
/// Au montage, tente de reprendre la session (hero « Connexion… ») ; sinon
/// affiche le formulaire. Le bouton « Se connecter » vit dans le dock, et
/// une erreur de connexion s'y affiche.
class YpsiumLoginScreen extends StatefulWidget {
  const YpsiumLoginScreen({super.key, this.onExit});

  /// Appelé quand l'utilisateur quitte l'onglet Ypsium via la flèche retour
  /// (revient à l'onglet Accueil). `null` en usage autonome → simple `pop`.
  final VoidCallback? onExit;

  @override
  State<YpsiumLoginScreen> createState() => _YpsiumLoginScreenState();
}

class _YpsiumLoginScreenState extends State<YpsiumLoginScreen>
    with DockNoticeMixin {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();

  bool _isLoading = false;
  bool _isRestoringSession = true;
  bool _rememberMe = false;

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
        MaterialPageRoute(
          builder: (_) => YpsiumHomeScreen(onExit: widget.onExit),
        ),
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

    clearDockNotice();
    setState(() => _isLoading = true);

    final result = await sl.ypsiumAuthRepository.login(
      login: _loginController.text.trim(),
      password: _passwordController.text,
      rememberMe: _rememberMe,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    result.fold(
      (failure) => showDockError(failure.message),
      (session) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => YpsiumHomeScreen(onExit: widget.onExit),
          ),
        );
      },
    );
  }

  void _exit() {
    if (widget.onExit != null) {
      widget.onExit!();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final leading = IconButton(
      icon: Icon(Icons.arrow_back_rounded, color: colors.foreground),
      tooltip: 'Retour',
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      onPressed: _exit,
    );

    if (_isRestoringSession) {
      return AppPage(
        title: 'Ypsium',
        leading: leading,
        body: AppScrollView(
          children: [
            AppHeroCard(
              icon: Icons.local_shipping_rounded,
              accent: colors.domainYpsium,
              title: 'Connexion…',
              subtitle: 'Reprise de ta session Ypsium',
              trailing: SizedBox(
                width: 24,
                height: 24,
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
        dock: const AppDock(skeleton: true, bottomGap: AppSpacing.lg),
      );
    }

    return AppPage(
      title: 'Ypsium',
      leading: leading,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: AppScrollView(
          children: [
            AppHeroCard(
              icon: Icons.local_shipping_rounded,
              accent: colors.domainYpsium,
              title: 'Ypsium Transport',
              subtitle: 'Connecte-toi pour voir tes commandes',
            ),
            const SizedBox(height: AppSpacing.lg),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    controller: _loginController,
                    label: 'Identifiant',
                    hint: 'Ton identifiant Ypsium',
                    prefixIcon:
                        const Icon(Icons.person_outline_rounded, size: 20),
                    enabled: !_isLoading,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _passwordFocusNode.requestFocus(),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Saisis ton identifiant';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.base),
                  _YpsiumPasswordField(
                    controller: _passwordController,
                    focusNode: _passwordFocusNode,
                    enabled: !_isLoading,
                    onSubmitted: (_) => _login(),
                  ),
                  const SizedBox(height: AppSpacing.base),
                  AppCard(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    child: AppListRow(
                      icon: Icons.key_rounded,
                      iconColor: colors.domainYpsium,
                      title: 'Se souvenir de moi',
                      subtitle: 'Identifiants gardés sur ce téléphone',
                      showChevron: false,
                      trailing: Switch(
                        value: _rememberMe,
                        onChanged: _isLoading
                            ? null
                            : (value) => setState(() => _rememberMe = value),
                      ),
                      onTap: _isLoading
                          ? null
                          : () => setState(() => _rememberMe = !_rememberMe),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      dock: AppDock(
        actions: [
          DockAction(
            label: 'Se connecter',
            icon: Icons.login_rounded,
            isLoading: _isLoading,
            onPressed: _isLoading ? null : _login,
          ),
        ],
        notice: dockNotice,
        onDismissNotice: clearDockNotice,
        absorbing: _isLoading,
        bottomGap: AppSpacing.lg,
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
      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
      suffixIcon: IconButton(
        icon: Icon(
          _obscureText
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          size: 20,
        ),
        tooltip: _obscureText
            ? 'Afficher le mot de passe'
            : 'Masquer le mot de passe',
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        onPressed: () => setState(() => _obscureText = !_obscureText),
      ),
      enabled: widget.enabled,
      onSubmitted: widget.onSubmitted,
      focusNode: widget.focusNode,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Saisis ton mot de passe';
        }
        return null;
      },
    );
  }
}
