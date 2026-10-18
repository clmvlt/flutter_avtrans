// Pointages simulés au contrat de l'API (ServiceDTO, HeuresPeriodeDTO) :
// les durées sont calculées ici comme le ferait le serveur à [now].

/// Une pause : début et fin (`null` = en cours).
typedef FakePause = (DateTime debut, DateTime? fin);

int _seconds(DateTime from, DateTime to) {
  final s = to.difference(from).inSeconds;
  return s > 0 ? s : 0;
}

/// Service de travail renvoyé par l'API, pauses imbriquées.
Map<String, dynamic> fakeWorkService(
  String uuid,
  DateTime debut, {
  required DateTime now,
  DateTime? fin,
  List<FakePause> pauses = const [],
}) {
  final end = fin ?? now;
  final pauseRows = [
    for (var i = 0; i < pauses.length; i++)
      fakePause('$uuid-p${i + 1}', pauses[i].$1,
          parent: uuid, now: now, fin: pauses[i].$2),
  ];
  final duree = _seconds(debut, end);
  final dureePauses = pauseRows.fold<int>(0, (n, p) => n + (p['duree'] as int));
  return {
    'uuid': uuid,
    'debut': debut.toIso8601String(),
    'fin': fin?.toIso8601String(),
    'isBreak': false,
    'isAdmin': false,
    'userUuid': 'u-1',
    'latitude': 48.11,
    'longitude': -1.68,
    'duree': duree,
    'calculeLe': now.toIso8601String(),
    'enCours': fin == null,
    'pauses': pauseRows,
    'dureePauses': dureePauses,
    'dureeTravail': duree - dureePauses,
    'enPause': fin == null && pauses.any((p) => p.$2 == null),
  };
}

/// Pause renvoyée par l'API, rattachée à [parent].
Map<String, dynamic> fakePause(
  String uuid,
  DateTime debut, {
  required String parent,
  required DateTime now,
  DateTime? fin,
}) => {
  'uuid': uuid,
  'debut': debut.toIso8601String(),
  'fin': fin?.toIso8601String(),
  'isBreak': true,
  'isAdmin': false,
  'userUuid': 'u-1',
  'duree': _seconds(debut, fin ?? now),
  'calculeLe': now.toIso8601String(),
  'enCours': fin == null,
  'serviceParentUuid': parent,
};

/// Total d'une période (HeuresPeriodeDTO).
Map<String, dynamic> fakeHeures(int secondes, {bool enCours = false}) => {
  'secondes': secondes,
  'heures': secondes / 3600,
  'enCours': enCours,
};

/// Total d'une période en heures décimales.
Map<String, dynamic> fakeHeuresDecimal(double heures, {bool enCours = false}) =>
    fakeHeures((heures * 3600).round(), enCours: enCours);
