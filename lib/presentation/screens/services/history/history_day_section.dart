import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/display_format.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../data/models/service_model.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_list_row.dart';
import '../../../widgets/app_skeleton.dart';
import '../../../widgets/app_state_views.dart';
import '../../../widgets/live_builder.dart';
import '../pointage_controller.dart';
import '../widgets/day_timeline.dart';
import '../widgets/pointage_layout.dart';
import 'history_filter.dart';

/// Section du jour choisi : en-tête (date + résumé) puis le fil de la
/// journée, au même dessin que « Aujourd'hui » sur la page Pointage. Le
/// résumé donne le temps net du jour : somme des `dureeTravail` des services
/// débutés ce jour-là, en direct si l'un est en cours.
///
/// Gère ses états : mois en chargement (squelette), mois en échec (erreur +
/// « Réessayer »), jour vide (avec « Tout afficher » si un filtre masque
/// tout).
class HistoryDaySection extends StatelessWidget {
  const HistoryDaySection({
    super.key,
    required this.day,
    required this.services,
    required this.entries,
    required this.clock,
    required this.loading,
    required this.error,
    required this.filter,
    required this.onRetry,
    required this.onClearFilter,
    required this.onTapService,
  });

  /// Jour choisi (`null` = aucun).
  final DateTime? day;

  /// Services de travail débutés ce jour (pauses imbriquées), sans filtre.
  final List<Service> services;

  /// Lignes à afficher (services et pauses à plat), filtrées et triées.
  final List<Service> entries;

  /// Horloge des lignes en cours.
  final Listenable clock;

  /// Le mois du jour n'est pas encore chargé.
  final bool loading;

  /// Échec du chargement du mois (et rien en cache).
  final String? error;
  final HistoryTypeFilter filter;
  final VoidCallback onRetry;
  final VoidCallback onClearFilter;
  final ValueChanged<Service> onTapService;

  /// « Aujourd'hui », « Hier », « 24 septembre » (+ l'année si besoin) :
  /// court, le jour de la semaine se lit dans le calendrier juste au-dessus.
  String _title(DateTime d) => DisplayFormat.relativeDay(d);

  /// « 7h30 travaillées · 2 services · 1 pause ».
  String _summary() {
    final serviceCount = services.length;
    final breakCount = services.fold(0, (n, s) => n + s.pauses.length);
    final worked = services.fold(
      Duration.zero,
      (total, s) => total + s.liveTravail.value,
    );
    return [
      if (serviceCount > 0) '${TimeFormat.durationShort(worked)} travaillées',
      if (serviceCount > 1) '$serviceCount services',
      if (breakCount > 0) '$breakCount ${breakCount > 1 ? 'pauses' : 'pause'}',
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final selected = day;
    if (selected == null) {
      return const AppEmptyCard(
        icon: Icons.touch_app_rounded,
        message: 'Choisis un jour',
        detail: 'pour voir ses pointages',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LiveBuilder(
          running: services.any((s) => s.enCours),
          clock: clock,
          builder: (_) =>
              AppSectionHeader(title: _title(selected), summary: _summary()),
        ),
        AnimatedSwitcher(
          duration: AppDuration.base,
          child: KeyedSubtree(
            key: ValueKey('${selected.toIso8601String()}-${entries.length}'
                '-$loading-${error != null}-${filter.name}'),
            child: _body(context),
          ),
        ),
      ],
    );
  }

  Widget _body(BuildContext context) {
    if (entries.isEmpty) {
      if (loading) return const _TimelineSkeleton();
      if (error != null) {
        return AppErrorState(message: error!, onRetry: onRetry);
      }
      final filtered = filter != HistoryTypeFilter.all;
      return AppEmptyCard(
        icon: filtered ? Icons.search_off_rounded : Icons.event_busy_rounded,
        message: switch (filter) {
          HistoryTypeFilter.all => 'Aucun pointage ce jour',
          HistoryTypeFilter.services => 'Aucun service ce jour',
          HistoryTypeFilter.breaks => 'Aucune pause ce jour',
        },
        detail: filtered ? 'Essaie un autre filtre' : null,
        actionLabel: filtered ? 'Tout afficher' : null,
        onAction: filtered ? onClearFilter : null,
      );
    }

    final segments = [for (final s in entries) DaySegment.of(s)];

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      child: DayTimeline(
        segments: segments,
        clock: clock,
        onTap: onTapService,
      ),
    );
  }
}

/// Squelette du fil (trois lignes), à la géométrie de [DayTimeline].
class _TimelineSkeleton extends StatelessWidget {
  const _TimelineSkeleton();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        children: [
          for (var i = 0; i < 3; i++)
            const SizedBox(
              height: PointageLayout.rowMinHeight,
              child: Row(
                children: [
                  AppSkeleton(width: 40, height: 15),
                  SizedBox(width: AppSpacing.md),
                  AppSkeleton(
                    width: PointageLayout.dotSize,
                    height: PointageLayout.dotSize,
                    borderRadius: AppRadius.full,
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(child: AppSkeleton(height: 16)),
                  SizedBox(width: AppSpacing.md),
                  AppSkeleton(
                    width: 48,
                    height: 22,
                    borderRadius: AppRadius.full,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
