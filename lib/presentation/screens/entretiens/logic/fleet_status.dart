import '../../../../core/utils/display_format.dart';
import '../../../../data/models/entretien_model.dart';
import '../../../../data/models/vehicule_model.dart';

/// Seuils du palier « à prévoir » (identiques à l'app web) : une échéance
/// à moins de 10 000 km ou de 90 jours.
abstract final class FleetThresholds {
  static const int km = 10000;
  static const int days = 90;
}

/// Urgence d'une échéance ou d'un véhicule.
enum FleetLevel {
  /// Au moins une échéance dépassée.
  late,

  /// Une échéance sous les seuils.
  soon,

  /// Rien d'urgent (ou aucun suivi).
  ok,
}

/// Une échéance d'un véhicule, au kilométrage ou à la date.
class FleetAlert {
  const FleetAlert._({
    required this.isKm,
    required this.alerte,
    required this.remaining,
    required this.level,
  });

  factory FleetAlert.km(AlerteEntretien a) {
    final remaining = a.kmRestants ?? 0;
    return FleetAlert._(
      isKm: true,
      alerte: a,
      remaining: remaining,
      level: a.enRetard
          ? FleetLevel.late
          : (remaining >= 0 && remaining <= FleetThresholds.km
              ? FleetLevel.soon
              : FleetLevel.ok),
    );
  }

  factory FleetAlert.date(AlerteEntretien a) {
    final remaining = a.joursRestants ?? 0;
    return FleetAlert._(
      isKm: false,
      alerte: a,
      remaining: remaining,
      level: a.enRetard
          ? FleetLevel.late
          : (remaining >= 0 && remaining <= FleetThresholds.days
              ? FleetLevel.soon
              : FleetLevel.ok),
    );
  }

  /// Échéance au kilométrage (sinon à la date).
  final bool isKm;
  final AlerteEntretien alerte;

  /// Km ou jours restants ; négatif = dépassé.
  final int remaining;
  final FleetLevel level;

  String get typeLabel => alerte.typeEntretien?.nom ?? 'Entretien';

  /// « En retard de 1 200 km », « Dans 3 400 km », « Dans 12 jours »,
  /// « Aujourd'hui ». Le libellé suit le signe (jamais « en retard » pour
  /// une échéance à venir).
  String get dueLabel {
    final late = level == FleetLevel.late || remaining < 0;
    final n = remaining.abs();
    if (isKm) {
      return late ? 'En retard de ${DisplayFormat.km(n)}' : 'Dans ${DisplayFormat.km(n)}';
    }
    if (!late && n == 0) return 'Aujourd\'hui';
    final days = DisplayFormat.plural(n, 'jour');
    return late ? 'En retard de $days' : 'Dans $days';
  }

  /// Cible : « à 153 000 km », « le 12 mars 2026 ».
  String? get targetLabel {
    if (isKm) {
      final km = alerte.prochainKilometrage;
      return km == null ? null : 'à ${DisplayFormat.km(km)}';
    }
    final d = alerte.prochaineDate;
    return d == null ? null : 'le ${DisplayFormat.date(d)}';
  }
}

/// Statut d'entretien d'un véhicule du parc.
class FleetVehicleStatus {
  const FleetVehicleStatus({
    required this.vehicule,
    required this.level,
    required this.alerts,
  });

  final Vehicule vehicule;
  final FleetLevel level;

  /// Échéances (0 à 2), la plus urgente d'abord.
  final List<FleetAlert> alerts;

  bool get isTracked => alerts.isNotEmpty;
}

/// Échéances d'un véhicule, la plus urgente d'abord.
List<FleetAlert> alertsOf(VehiculeProchainEntretien? data) {
  final alerts = <FleetAlert>[
    if (data?.prochainKm != null) FleetAlert.km(data!.prochainKm!),
    if (data?.prochaineDate != null) FleetAlert.date(data!.prochaineDate!),
  ];
  alerts.sort((a, b) => a.level.index.compareTo(b.level.index));
  return alerts;
}

/// Niveau d'un véhicule : le pire de ses échéances.
FleetLevel levelOf(List<FleetAlert> alerts) => alerts.isEmpty
    ? FleetLevel.ok
    : alerts.map((a) => a.level).reduce((a, b) => a.index <= b.index ? a : b);

/// Statut de CHAQUE véhicule du parc (pas seulement ceux qui ont un suivi),
/// trié : en retard, puis à prévoir, puis à jour ; à niveau égal, par
/// immatriculation.
List<FleetVehicleStatus> computeFleetStatus(
  List<Vehicule> vehicules,
  List<VehiculeProchainEntretien> prochains,
) {
  final byVehicle = <String, VehiculeProchainEntretien>{
    for (final p in prochains)
      if (p.vehicule != null) p.vehicule!.id: p,
  };

  final list = [
    for (final v in vehicules)
      () {
        final alerts = alertsOf(byVehicle[v.id]);
        return FleetVehicleStatus(
          vehicule: v,
          level: levelOf(alerts),
          alerts: alerts,
        );
      }(),
  ];

  list.sort((a, b) {
    final byLevel = a.level.index.compareTo(b.level.index);
    if (byLevel != 0) return byLevel;
    return a.vehicule.immat.compareTo(b.vehicule.immat);
  });
  return list;
}

/// Unité de saisie d'une périodicité temporelle (l'API stocke des jours).
enum PeriodUnit {
  days(1, 'jours'),
  months(30, 'mois'),
  years(365, 'ans');

  const PeriodUnit(this.dayCount, this.label);

  /// Nombre de jours d'une unité (mois = 30 j, an = 365 j).
  final int dayCount;
  final String label;

  /// Meilleure unité pour afficher [totalDays] sans perte.
  static PeriodUnit bestFor(int totalDays) {
    if (totalDays > 0 && totalDays % 365 == 0) return PeriodUnit.years;
    if (totalDays > 0 && totalDays % 30 == 0) return PeriodUnit.months;
    return PeriodUnit.days;
  }
}

/// « Tous les 30 000 km », « Tous les ans », « Tous les 6 mois »,
/// « Tous les 45 jours ». Exact : on ne convertit en mois ou en années que
/// sans reste.
String formatPeriodicite(PeriodiciteType type, int value) {
  if (type == PeriodiciteType.kilometrage) {
    return 'Tous les ${DisplayFormat.km(value)}';
  }
  final unit = PeriodUnit.bestFor(value);
  final n = value ~/ unit.dayCount;
  switch (unit) {
    case PeriodUnit.years:
      return n == 1 ? 'Tous les ans' : 'Tous les $n ans';
    case PeriodUnit.months:
      return n == 1 ? 'Tous les mois' : 'Tous les $n mois';
    case PeriodUnit.days:
      return n == 1 ? 'Tous les jours' : 'Tous les $n jours';
  }
}
