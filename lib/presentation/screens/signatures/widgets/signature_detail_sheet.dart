import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/display_format.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../data/models/signature_model.dart';
import '../../../widgets/app_confirm_sheet.dart';
import '../../../widgets/app_list_row.dart';
import '../../../widgets/app_sheet.dart';
import 'signature_paper.dart';

/// « 03/09/2026 à 08:42 »
String _dateTime(DateTime d) =>
    '${DisplayFormat.dateShort(d)} à ${TimeFormat.hm(d)}';

/// Ligne d'une signature passée : date, heure, heures signées ; un tap
/// ouvre son détail.
class SignatureRow extends StatelessWidget {
  const SignatureRow({super.key, required this.signature});

  final Signature signature;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final hours = TimeFormat.hoursDecimal(signature.heuresSignees);
    final date = DisplayFormat.date(signature.date);
    final time = TimeFormat.hm(signature.date);

    return AppListRow(
      title: date,
      subtitle: 'Signée à $time',
      icon: Icons.draw_rounded,
      iconColor: colors.domainHours,
      trailing: Text(
        hours,
        style: textTheme.titleMedium?.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      showChevron: true,
      onTap: () => SignatureDetailSheet.show(context, signature),
      semanticsLabel: 'Signature du $date à $time, $hours signées',
    );
  }
}

/// Détail d'une signature : l'image signée et le récapitulatif.
abstract final class SignatureDetailSheet {
  static Future<void> show(BuildContext context, Signature signature) {
    return AppSheet.show<void>(
      context,
      title: 'Signature du ${DisplayFormat.date(signature.date)}',
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SignatureImage(base64: signature.signatureBase64, height: 180),
          const SizedBox(height: AppSpacing.base),
          AppRecapBox(
            rows: [
              AppRecapRow(
                icon: Icons.schedule_rounded,
                label: 'Heures signées',
                value: TimeFormat.hoursDecimal(signature.heuresSignees),
                emphasized: true,
              ),
              AppRecapRow(
                icon: Icons.event_rounded,
                label: 'Date',
                value: _dateTime(signature.date),
              ),
              if (signature.createdAt != null)
                AppRecapRow(
                  icon: Icons.history_rounded,
                  label: 'Enregistrée le',
                  value: _dateTime(signature.createdAt!),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
