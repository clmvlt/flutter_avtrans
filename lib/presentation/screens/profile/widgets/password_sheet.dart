import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../widgets/app_alert.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_sheet.dart';
import '../../../widgets/app_text_field.dart';

/// Vérifie puis enregistre le nouveau mot de passe ; retourne le message
/// d'erreur à afficher, ou `null` si c'est fait.
typedef PasswordSubmit = Future<String?> Function(
  String current,
  String next,
  String confirm,
);

/// Feuille « Changer le mot de passe » : mot de passe actuel, nouveau,
/// confirmation. L'erreur s'affiche dans la feuille ; « Annuler » la ferme
/// sans rien envoyer.
abstract final class PasswordSheet {
  /// Retourne `true` si le mot de passe a été changé.
  static Future<bool> show(
    BuildContext context, {
    required PasswordSubmit onSubmit,
  }) async {
    final result = await AppSheet.show<bool>(
      context,
      title: 'Changer le mot de passe',
      builder: (_) => _PasswordForm(onSubmit: onSubmit),
    );
    return result ?? false;
  }
}

class _PasswordForm extends StatefulWidget {
  const _PasswordForm({required this.onSubmit});

  final PasswordSubmit onSubmit;

  @override
  State<_PasswordForm> createState() => _PasswordFormState();
}

class _PasswordFormState extends State<_PasswordForm> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });

    final error =
        await widget.onSubmit(_current.text, _next.text, _confirm.text);
    if (!mounted) return;

    if (error == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  Widget _visibilityToggle() {
    return IconButton(
      onPressed: () => setState(() => _obscure = !_obscure),
      tooltip: _obscure ? 'Afficher' : 'Masquer',
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      icon: Icon(
        _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        size: 20,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final error = _error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Saisis ton mot de passe actuel, puis le nouveau (6 caractères '
          'minimum).',
          style: textTheme.bodyMedium?.copyWith(color: colors.mutedForeground),
        ),
        const SizedBox(height: AppSpacing.base),
        AppTextField(
          controller: _current,
          label: 'Mot de passe actuel',
          obscureText: _obscure,
          keyboardType: TextInputType.visiblePassword,
          prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
          suffixIcon: _visibilityToggle(),
          enabled: !_busy,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _next,
          label: 'Nouveau mot de passe',
          obscureText: _obscure,
          keyboardType: TextInputType.visiblePassword,
          prefixIcon: const Icon(Icons.lock_reset_rounded, size: 20),
          suffixIcon: _visibilityToggle(),
          enabled: !_busy,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _confirm,
          label: 'Confirmer le mot de passe',
          obscureText: _obscure,
          keyboardType: TextInputType.visiblePassword,
          textInputAction: TextInputAction.done,
          prefixIcon: const Icon(Icons.lock_reset_rounded, size: 20),
          suffixIcon: _visibilityToggle(),
          enabled: !_busy,
          onSubmitted: (_) => _submit(),
        ),
        if (error != null) ...[
          const SizedBox(height: AppSpacing.base),
          AppAlert(variant: AlertVariant.destructive, description: error),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          text: 'Changer le mot de passe',
          icon: Icons.check_rounded,
          size: ButtonSize.lg,
          isLoading: _busy,
          onPressed: _submit,
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 52,
          child: TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(foregroundColor: colors.foreground),
            child: const Text('Annuler'),
          ),
        ),
      ],
    );
  }
}
