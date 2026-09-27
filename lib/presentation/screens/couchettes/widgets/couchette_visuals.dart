import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/display_format.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../data/models/models.dart';
import '../../../widgets/widgets.dart';

/// La couchette est-elle celle d'aujourd'hui (date API `yyyy-MM-dd`) ?
bool isTodayCouchette(Couchette c) {
  final date = c.date;
  if (date == null) return false;
  return date == DateFormat('yyyy-MM-dd').format(DateTime.now());
}

/// « Lundi 8 septembre 2025 », la date brute si illisible, sinon
/// « Date non disponible ».
String couchetteDateLabel(Couchette c) {
  final raw = c.date;
  if (raw == null) return 'Date non disponible';
  try {
    final label =
        DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(DateTime.parse(raw));
    return label[0].toUpperCase() + label.substring(1);
  } catch (_) {
    return raw;
  }
}

/// « 12 mars 2025 à 21:04 ».
String couchetteDeclaredAt(DateTime d) =>
    '${DisplayFormat.date(d)} à ${TimeFormat.hm(d)}';

/// Ligne d'une couchette : date, et pastille « Aujourd'hui » pour celle du
/// jour (la seule qu'on peut encore supprimer).
class CouchetteRow extends StatelessWidget {
  const CouchetteRow({
    super.key,
    required this.couchette,
    required this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadius.md)),
  });

  final Couchette couchette;
  final VoidCallback onTap;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isToday = isTodayCouchette(couchette);
    final label = couchetteDateLabel(couchette);

    return AppListRow(
      icon: Icons.hotel_rounded,
      iconColor: isToday ? colors.success : colors.info,
      title: label,
      trailing: isToday
          ? AppStatusChip(
              label: 'Aujourd\'hui',
              color: colors.primary,
              icon: Icons.today_rounded,
            )
          : null,
      onTap: onTap,
      borderRadius: borderRadius,
      semanticsLabel: isToday ? '$label, aujourd\'hui' : label,
    );
  }
}
