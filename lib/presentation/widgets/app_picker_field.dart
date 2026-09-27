import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/display_format.dart';

/// Libellé de champ de formulaire (au-dessus du champ, 8 dp d'écart inclus).
class AppFieldLabel extends StatelessWidget {
  const AppFieldLabel(this.text, {super.key, this.optional = false});

  final String text;

  /// Ajoute « (facultatif) » en discret.
  final bool optional;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text.rich(
        TextSpan(
          text: text,
          style: textTheme.titleSmall,
          children: [
            if (optional)
              TextSpan(
                text: '  facultatif',
                style: textTheme.bodySmall
                    ?.copyWith(color: colors.mutedForeground),
              ),
          ],
        ),
      ),
    );
  }
}

/// Champ « à taper » qui ouvre un choix (feuille, calendrier…), au même
/// gabarit que les champs de texte : fond enfoncé, 56 dp, rayon `md`.
class AppPickerField extends StatelessWidget {
  const AppPickerField({
    super.key,
    this.label,
    this.optional = false,
    required this.value,
    required this.placeholder,
    required this.onTap,
    this.icon,
    this.trailingIcon = Icons.unfold_more_rounded,
    this.errorText,
    this.enabled = true,
    this.subtitle,
    this.onClear,
  });

  final String? label;
  final bool optional;

  /// Si fourni, une croix efface la valeur (champs facultatifs, filtres).
  final VoidCallback? onClear;

  /// Valeur affichée ; `null` → [placeholder] en discret.
  final String? value;
  final String? subtitle;
  final String placeholder;
  final VoidCallback? onTap;
  final IconData? icon;
  final IconData trailingIcon;
  final String? errorText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final hasError = errorText != null;
    final hasValue = value != null && value!.isNotEmpty;

    final field = Material(
      color: colors.surfaceSunken,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: hasError
            ? BorderSide(color: colors.destructive, width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.base,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: colors.mutedForeground),
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        hasValue ? value! : placeholder,
                        style: textTheme.bodyLarge?.copyWith(
                          color: !enabled
                              ? colors.disabled
                              : hasValue
                                  ? colors.foreground
                                  : colors.mutedForeground,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (hasValue && subtitle != null)
                        Text(
                          subtitle!,
                          style: textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                if (onClear != null && hasValue && enabled)
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: IconButton(
                      onPressed: onClear,
                      tooltip: 'Effacer',
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: colors.mutedForeground,
                      ),
                    ),
                  )
                else
                  Icon(trailingIcon, size: 20, color: colors.mutedForeground),
              ],
            ),
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) AppFieldLabel(label!, optional: optional),
        Semantics(
          button: true,
          label: label,
          value: hasValue ? value : placeholder,
          child: field,
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: AppSpacing.xs),
            child: Text(
              errorText!,
              style: textTheme.bodySmall?.copyWith(
                color: colors.destructive,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}

/// Champ date : ouvre le calendrier Material (en français), affiche
/// « 12 mars 2025 ».
class AppDateField extends StatelessWidget {
  const AppDateField({
    super.key,
    this.label,
    this.optional = false,
    required this.value,
    required this.onChanged,
    this.placeholder = 'Choisir une date',
    this.firstDate,
    this.lastDate,
    this.errorText,
    this.enabled = true,
    this.clearable = false,
  });

  final String? label;
  final bool optional;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final String placeholder;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String? errorText;
  final bool enabled;

  /// Une croix efface la date (champs facultatifs, filtres).
  final bool clearable;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final first = firstDate ?? DateTime(now.year - 10);
    final last = lastDate ?? DateTime(now.year + 10);
    var initial = value ?? now;
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      locale: const Locale('fr', 'FR'),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return AppPickerField(
      label: label,
      optional: optional,
      value: value == null ? null : DisplayFormat.date(value!),
      placeholder: placeholder,
      icon: Icons.event_rounded,
      trailingIcon: Icons.expand_more_rounded,
      errorText: errorText,
      enabled: enabled,
      onTap: () => _pick(context),
      onClear: clearable ? () => onChanged(null) : null,
    );
  }
}
