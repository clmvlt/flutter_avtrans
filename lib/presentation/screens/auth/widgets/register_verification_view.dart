import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../widgets/widgets.dart';
import 'auth_scaffold.dart';

/// Attente après l'inscription, sur le gabarit de la page Pointage : une
/// carte hero qui dit l'étape en cours (email à vérifier, puis activation par
/// un administrateur), la liste des étapes, et « Retour à la connexion » dans
/// le dock. La page se met à jour seule (le parent interroge l'API).
class RegisterVerificationView extends StatelessWidget {
  const RegisterVerificationView({
    super.key,
    required this.email,
    required this.isEmailVerified,
    required this.isWaitingForEmailVerification,
    required this.isWaitingForAdminActivation,
    required this.onBackToLogin,
  });

  final String email;
  final bool isEmailVerified;
  final bool isWaitingForEmailVerification;
  final bool isWaitingForAdminActivation;
  final VoidCallback onBackToLogin;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final done = 1 + (isEmailVerified ? 1 : 0);

    return AuthScaffold(
      title: 'Inscription',
      centered: false,
      dock: AppDock(
        actions: [
          DockAction(
            label: 'Retour à la connexion',
            icon: Icons.arrow_back_rounded,
            tone: DockTone.secondary,
            onPressed: onBackToLogin,
          ),
        ],
      ),
      children: [
        AnimatedSwitcher(
          duration: reduceMotion ? Duration.zero : AppDuration.base,
          child: KeyedSubtree(
            key: ValueKey(isWaitingForAdminActivation),
            child: isWaitingForAdminActivation
                ? _hero(
                    context,
                    icon: Icons.admin_panel_settings_rounded,
                    accent: colors.warning,
                    title: 'Email vérifié',
                    subtitle: 'En attente d\'activation…',
                    body: const _HeroText(
                      'Un administrateur doit maintenant activer ton compte. '
                      'Tu seras redirigé automatiquement vers la connexion.',
                    ),
                  )
                : _hero(
                    context,
                    icon: Icons.mark_email_unread_rounded,
                    accent: colors.primary,
                    title: 'Vérifie ton email',
                    subtitle: 'En attente de vérification…',
                    body: _EmailSentText(email: email),
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppSectionHeader(title: 'Étapes', summary: '$done sur 3'),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            children: [
              _StepRow(
                icon: Icons.person_add_alt_1_rounded,
                title: 'Compte créé',
                activeLabel: '',
                accent: colors.primary,
                isCompleted: true,
                isActive: false,
              ),
              _StepRow(
                icon: Icons.mark_email_unread_rounded,
                title: 'Email vérifié',
                activeLabel: 'Clique sur le lien reçu par email',
                accent: colors.primary,
                isCompleted: isEmailVerified,
                isActive: isWaitingForEmailVerification,
              ),
              _StepRow(
                icon: Icons.admin_panel_settings_rounded,
                title: 'Compte activé par l\'admin',
                activeLabel: 'En attente d\'un administrateur',
                accent: colors.warning,
                isCompleted: false,
                isActive: isWaitingForAdminActivation,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _hero(
    BuildContext context, {
    required IconData icon,
    required Color accent,
    required String title,
    required String subtitle,
    required Widget body,
  }) {
    return AppHeroCard(
      icon: icon,
      accent: accent,
      title: title,
      subtitle: subtitle,
      // Seul élément animé de la page : la vérification tourne en fond.
      trailing: SizedBox(
        width: 24,
        height: 24,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: accent),
          ),
        ),
      ),
      child: body,
    );
  }
}

class _HeroText extends StatelessWidget {
  const _HeroText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    return Text(
      text,
      style: textTheme.bodyMedium?.copyWith(color: colors.mutedForeground),
    );
  }
}

/// « Un email de vérification a été envoyé à **adresse**. … »
class _EmailSentText extends StatelessWidget {
  const _EmailSentText({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodyMedium?.copyWith(color: colors.mutedForeground);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            style: muted,
            children: [
              const TextSpan(text: 'Un email de vérification a été envoyé à '),
              TextSpan(
                text: email,
                style: TextStyle(
                  color: colors.foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const TextSpan(
                text: '. Clique sur le lien qu\'il contient pour vérifier '
                    'ton compte.',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text('Cette page se met à jour toute seule.', style: textTheme.bodySmall),
      ],
    );
  }
}

/// Une étape : boîte d'icône (verte et cochée si faite, teintée si en cours,
/// grise sinon) · titre · état en toutes lettres.
class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.icon,
    required this.title,
    required this.activeLabel,
    required this.accent,
    required this.isCompleted,
    required this.isActive,
  });

  final IconData icon;
  final String title;

  /// Sous-ligne quand l'étape est en cours.
  final String activeLabel;
  final Color accent;
  final bool isCompleted;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    final (IconData boxIcon, Color color, String subtitle) = isCompleted
        ? (Icons.check_rounded, colors.success, 'Fait')
        : isActive
            ? (icon, accent, activeLabel)
            : (icon, colors.mutedForeground, 'À venir');
    final pending = !isCompleted && !isActive;

    return AppListRow(
      title: title,
      subtitle: subtitle,
      leading: AppIconBox(icon: boxIcon, color: color),
      titleStyle: pending
          ? textTheme.titleSmall?.copyWith(color: colors.mutedForeground)
          : null,
      semanticsLabel: '$title : $subtitle',
    );
  }
}
