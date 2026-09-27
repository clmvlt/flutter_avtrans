import 'package:equatable/equatable.dart';

import 'paginated_response.dart';
import 'vehicule_model.dart';

/// Modèles du domaine « entretiens » (atelier) : entretiens réalisés, types
/// et dossiers de types, suivi périodique par véhicule, échéances.
///
/// ⚠ Comme les véhicules, ce domaine utilise `id` (pas `uuid`). Toutes les
/// routes exigent le rôle Mécanicien (l'Administrateur en hérite).
/// Les dates `ZonedDateTime` arrivent au format ISO avec offset (heure de
/// Paris) ; une date envoyée sans offset est lue en heure de Paris.

DateTime? _date(dynamic v) =>
    v is String && v.isNotEmpty ? DateTime.tryParse(v)?.toLocal() : null;

int? _int(dynamic v) => v is num ? v.toInt() : null;

double? _double(dynamic v) => v is num ? v.toDouble() : null;

String? _str(dynamic v) => v is String && v.isNotEmpty ? v : null;

/// Date d'entretien au format attendu par l'API : jour local à midi, sans
/// offset (lu en heure de Paris) — évite tout glissement de jour.
String formatEntretienDate(DateTime d) => '${formatApiDate(d)}T12:00:00';

/// Type de périodicité d'un suivi.
enum PeriodiciteType {
  kilometrage('KILOMETRAGE'),
  temporel('TEMPOREL');

  const PeriodiciteType(this.value);

  final String value;

  static PeriodiciteType fromValue(String? v) =>
      v == 'TEMPOREL' ? PeriodiciteType.temporel : PeriodiciteType.kilometrage;
}

/// Dossier (catégorie) de types d'entretien : « Freinage », « Moteur »…
class DossierTypeEntretien extends Equatable {
  final String id;
  final String nom;
  final String? description;
  final DateTime? createdAt;

  const DossierTypeEntretien({
    required this.id,
    required this.nom,
    this.description,
    this.createdAt,
  });

  factory DossierTypeEntretien.fromJson(Map<String, dynamic> json) {
    return DossierTypeEntretien(
      id: json['id'] as String,
      nom: json['nom'] as String? ?? '',
      description: _str(json['description']),
      createdAt: _date(json['createdAt']),
    );
  }

  @override
  List<Object?> get props => [id, nom, description, createdAt];
}

/// Type d'entretien générique : « Vidange », « Plaquettes avant »…
class TypeEntretien extends Equatable {
  final String id;
  final String nom;
  final String? description;
  final DossierTypeEntretien? dossier;
  final DateTime? createdAt;

  const TypeEntretien({
    required this.id,
    required this.nom,
    this.description,
    this.dossier,
    this.createdAt,
  });

  factory TypeEntretien.fromJson(Map<String, dynamic> json) {
    final dossier = json['dossier'];
    return TypeEntretien(
      id: json['id'] as String,
      nom: json['nom'] as String? ?? '',
      description: _str(json['description']),
      dossier: dossier is Map<String, dynamic> && dossier['id'] != null
          ? DossierTypeEntretien.fromJson(dossier)
          : null,
      createdAt: _date(json['createdAt']),
    );
  }

  /// « Freinage › Plaquettes avant », ou le nom seul hors dossier.
  String get fullLabel => dossier == null ? nom : '${dossier!.nom} › $nom';

  @override
  List<Object?> get props => [id, nom, description, dossier, createdAt];
}

/// Mécanicien ayant saisi l'entretien (extrait du UserDTO).
class EntretienAuteur extends Equatable {
  final String uuid;
  final String firstName;
  final String lastName;

  const EntretienAuteur({
    required this.uuid,
    required this.firstName,
    required this.lastName,
  });

  static EntretienAuteur? tryParse(dynamic json) {
    if (json is! Map<String, dynamic> || json['uuid'] == null) return null;
    return EntretienAuteur(
      uuid: json['uuid'] as String,
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
    );
  }

  String get fullName => '$firstName $lastName'.trim();

  @override
  List<Object?> get props => [uuid, firstName, lastName];
}

/// Fichier joint à un entretien (facture, photo, PDF…).
///
/// La liste de l'historique donne les métadonnées et `fileUrl` ;
/// `GET /entretiens/{id}/files` renvoie en plus le contenu en base64
/// (`fileB64`), seul moyen fiable de l'ouvrir.
class EntretienFile extends Equatable {
  final String id;
  final String? entretienId;
  final String originalName;
  final String mimeType;
  final int fileSize;
  final DateTime? createdAt;
  final String? fileB64;
  final String? fileUrl;

  const EntretienFile({
    required this.id,
    this.entretienId,
    required this.originalName,
    required this.mimeType,
    required this.fileSize,
    this.createdAt,
    this.fileB64,
    this.fileUrl,
  });

  factory EntretienFile.fromJson(Map<String, dynamic> json) {
    return EntretienFile(
      id: json['id'] as String,
      entretienId: json['entretienId'] as String?,
      originalName: json['originalName'] as String? ?? 'fichier',
      mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
      fileSize: _int(json['fileSize']) ?? 0,
      createdAt: _date(json['createdAt']),
      fileB64: _str(json['fileB64']),
      fileUrl: _str(json['fileUrl']),
    );
  }

  bool get isImage => mimeType.startsWith('image/');
  bool get isPdf => mimeType == 'application/pdf';

  String get extension {
    final dot = originalName.lastIndexOf('.');
    return dot > 0 ? originalName.substring(dot + 1).toLowerCase() : '';
  }

  @override
  List<Object?> get props => [
        id,
        entretienId,
        originalName,
        mimeType,
        fileSize,
        createdAt,
        fileB64,
        fileUrl,
      ];
}

/// Entretien réalisé sur un véhicule.
class Entretien extends Equatable {
  final String id;
  final String vehiculeId;
  final String? vehiculeImmat;
  final TypeEntretien? typeEntretien;
  final EntretienAuteur? mecanicien;
  final DateTime dateEntretien;
  final int? kilometrage;
  final String? commentaire;

  /// Coût hors taxes, en euros.
  final double? cout;
  final DateTime? createdAt;

  /// Métadonnées des fichiers joints (sans contenu).
  final List<EntretienFile> files;

  const Entretien({
    required this.id,
    required this.vehiculeId,
    this.vehiculeImmat,
    this.typeEntretien,
    this.mecanicien,
    required this.dateEntretien,
    this.kilometrage,
    this.commentaire,
    this.cout,
    this.createdAt,
    this.files = const [],
  });

  factory Entretien.fromJson(Map<String, dynamic> json) {
    final type = json['typeEntretien'];
    final files = json['files'];
    return Entretien(
      id: json['id'] as String,
      vehiculeId: json['vehiculeId'] as String? ?? '',
      vehiculeImmat: _str(json['vehiculeImmat']),
      typeEntretien: type is Map<String, dynamic> && type['id'] != null
          ? TypeEntretien.fromJson(type)
          : null,
      mecanicien: EntretienAuteur.tryParse(json['mecanicien']),
      dateEntretien: _date(json['dateEntretien']) ??
          _date(json['createdAt']) ??
          DateTime.now(),
      kilometrage: _int(json['kilometrage']),
      commentaire: _str(json['commentaire']),
      cout: _double(json['cout']),
      createdAt: _date(json['createdAt']),
      files: files is List
          ? files
              .whereType<Map<String, dynamic>>()
              .where((f) => f['id'] != null)
              .map(EntretienFile.fromJson)
              .toList()
          : const [],
    );
  }

  String get typeLabel => typeEntretien?.nom ?? 'Entretien';

  @override
  List<Object?> get props => [
        id,
        vehiculeId,
        vehiculeImmat,
        typeEntretien,
        mecanicien,
        dateEntretien,
        kilometrage,
        commentaire,
        cout,
        createdAt,
        files,
      ];
}

/// Suivi périodique d'un type d'entretien pour un véhicule : « Vidange tous
/// les 30 000 km », « Contrôle extincteur tous les 365 jours ».
class VehiculeTypeEntretien extends Equatable {
  final String id;
  final String vehiculeId;
  final String? vehiculeImmat;
  final TypeEntretien? typeEntretien;
  final PeriodiciteType periodiciteType;

  /// Kilomètres (KILOMETRAGE) ou jours (TEMPOREL).
  final int periodiciteValeur;
  final bool actif;
  final DateTime? createdAt;

  const VehiculeTypeEntretien({
    required this.id,
    required this.vehiculeId,
    this.vehiculeImmat,
    this.typeEntretien,
    required this.periodiciteType,
    required this.periodiciteValeur,
    required this.actif,
    this.createdAt,
  });

  factory VehiculeTypeEntretien.fromJson(Map<String, dynamic> json) {
    final type = json['typeEntretien'];
    return VehiculeTypeEntretien(
      id: json['id'] as String,
      vehiculeId: json['vehiculeId'] as String? ?? '',
      vehiculeImmat: _str(json['vehiculeImmat']),
      typeEntretien: type is Map<String, dynamic> && type['id'] != null
          ? TypeEntretien.fromJson(type)
          : null,
      periodiciteType: PeriodiciteType.fromValue(json['periodiciteType'] as String?),
      periodiciteValeur: _int(json['periodiciteValeur']) ?? 0,
      actif: json['actif'] as bool? ?? true,
      createdAt: _date(json['createdAt']),
    );
  }

  @override
  List<Object?> get props => [
        id,
        vehiculeId,
        vehiculeImmat,
        typeEntretien,
        periodiciteType,
        periodiciteValeur,
        actif,
        createdAt,
      ];
}

/// Prochaine échéance d'un véhicule (par kilométrage ou par date).
class AlerteEntretien extends Equatable {
  final TypeEntretien? typeEntretien;
  final Entretien? dernierEntretien;
  final int? prochainKilometrage;
  final DateTime? prochaineDate;

  /// Négatif = dépassé.
  final int? kmRestants;
  final int? joursRestants;
  final bool enRetard;
  final String? message;

  const AlerteEntretien({
    this.typeEntretien,
    this.dernierEntretien,
    this.prochainKilometrage,
    this.prochaineDate,
    this.kmRestants,
    this.joursRestants,
    this.enRetard = false,
    this.message,
  });

  static AlerteEntretien? tryParse(dynamic json) {
    if (json is! Map<String, dynamic>) return null;
    final type = json['typeEntretien'];
    final dernier = json['dernierEntretien'];
    return AlerteEntretien(
      typeEntretien: type is Map<String, dynamic> && type['id'] != null
          ? TypeEntretien.fromJson(type)
          : null,
      dernierEntretien: dernier is Map<String, dynamic> && dernier['id'] != null
          ? Entretien.fromJson(dernier)
          : null,
      prochainKilometrage: _int(json['prochainKilometrage']),
      prochaineDate: _date(json['prochaineDateTemporelle']),
      kmRestants: _int(json['kmRestants']),
      joursRestants: _int(json['joursRestants']),
      enRetard: json['enRetard'] as bool? ?? false,
      message: _str(json['message']),
    );
  }

  @override
  List<Object?> get props => [
        typeEntretien,
        dernierEntretien,
        prochainKilometrage,
        prochaineDate,
        kmRestants,
        joursRestants,
        enRetard,
        message,
      ];
}

/// Véhicule et ses deux prochaines échéances (au km et à la date).
class VehiculeProchainEntretien extends Equatable {
  final Vehicule? vehicule;
  final AlerteEntretien? prochainKm;
  final AlerteEntretien? prochaineDate;

  const VehiculeProchainEntretien({
    this.vehicule,
    this.prochainKm,
    this.prochaineDate,
  });

  factory VehiculeProchainEntretien.fromJson(Map<String, dynamic> json) {
    Vehicule? vehicule;
    final v = json['vehicule'];
    if (v is Map<String, dynamic>) {
      try {
        vehicule = Vehicule.fromJson(v);
      } catch (_) {
        vehicule = null;
      }
    }
    return VehiculeProchainEntretien(
      vehicule: vehicule,
      prochainKm: AlerteEntretien.tryParse(json['prochainEntretienKm']),
      prochaineDate: AlerteEntretien.tryParse(json['prochainEntretienDate']),
    );
  }

  @override
  List<Object?> get props => [vehicule, prochainKm, prochaineDate];
}

// ---------------------------------------------------------------------------
// Requêtes
// ---------------------------------------------------------------------------

/// Fichier à envoyer (base64 dans le JSON, pas de multipart).
class EntretienFileUpload {
  final String fileB64;
  final String originalName;
  final String mimeType;

  const EntretienFileUpload({
    required this.fileB64,
    required this.originalName,
    required this.mimeType,
  });

  Map<String, dynamic> toJson() => {
        'fileB64': fileB64,
        'originalName': originalName,
        'mimeType': mimeType,
      };
}

/// Corps de `POST /entretiens`.
class EntretienCreateRequest {
  final String vehiculeId;
  final String typeEntretienId;
  final DateTime dateEntretien;
  final int kilometrage;
  final String? commentaire;
  final double? cout;
  final List<EntretienFileUpload> files;

  const EntretienCreateRequest({
    required this.vehiculeId,
    required this.typeEntretienId,
    required this.dateEntretien,
    required this.kilometrage,
    this.commentaire,
    this.cout,
    this.files = const [],
  });

  Map<String, dynamic> toJson() => {
        'vehiculeId': vehiculeId,
        'typeEntretienId': typeEntretienId,
        'dateEntretien': formatEntretienDate(dateEntretien),
        'kilometrage': kilometrage,
        if (commentaire != null && commentaire!.isNotEmpty)
          'commentaire': commentaire,
        if (cout != null) 'cout': cout,
        if (files.isNotEmpty) 'files': files.map((f) => f.toJson()).toList(),
      };
}

/// Corps de `PUT /entretiens/{id}`. ⚠ L'API ignore les champs absents ou
/// `null` : un coût ne peut pas être retiré (mettre 0) ; un commentaire vide
/// (`''`) efface l'existant.
class EntretienUpdateRequest {
  final String? typeEntretienId;
  final DateTime? dateEntretien;
  final int? kilometrage;
  final String? commentaire;
  final double? cout;

  const EntretienUpdateRequest({
    this.typeEntretienId,
    this.dateEntretien,
    this.kilometrage,
    this.commentaire,
    this.cout,
  });

  Map<String, dynamic> toJson() => {
        if (typeEntretienId != null) 'typeEntretienId': typeEntretienId,
        if (dateEntretien != null)
          'dateEntretien': formatEntretienDate(dateEntretien!),
        if (kilometrage != null) 'kilometrage': kilometrage,
        if (commentaire != null) 'commentaire': commentaire,
        if (cout != null) 'cout': cout,
      };
}

/// Tri de l'historique (champs triables côté serveur).
enum EntretienSort {
  date('dateEntretien', 'Date'),
  kilometrage('kilometrage', 'Kilométrage'),
  cout('cout', 'Coût');

  const EntretienSort(this.value, this.label);

  final String value;
  final String label;
}

/// Filtres et pagination de `POST /entretiens/history`. Les dates sont des
/// jours (`yyyy-MM-dd`), fin incluse côté serveur.
class EntretienHistoryQuery extends Equatable {
  final int page;
  final int size;
  final EntretienSort sort;
  final bool ascending;
  final String? vehiculeId;
  final String? dossierId;
  final String? typeEntretienId;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? kmMin;
  final int? kmMax;
  final double? coutMin;
  final double? coutMax;

  const EntretienHistoryQuery({
    this.page = 0,
    this.size = 20,
    this.sort = EntretienSort.date,
    this.ascending = false,
    this.vehiculeId,
    this.dossierId,
    this.typeEntretienId,
    this.startDate,
    this.endDate,
    this.kmMin,
    this.kmMax,
    this.coutMin,
    this.coutMax,
  });

  /// Nombre de filtres actifs (hors véhicule imposé par la page, tri, page).
  int get activeFilterCount => [
        dossierId,
        typeEntretienId,
        startDate ?? endDate,
        kmMin ?? kmMax,
        coutMin ?? coutMax,
      ].where((v) => v != null).length;

  EntretienHistoryQuery withPage(int page) => EntretienHistoryQuery(
        page: page,
        size: size,
        sort: sort,
        ascending: ascending,
        vehiculeId: vehiculeId,
        dossierId: dossierId,
        typeEntretienId: typeEntretienId,
        startDate: startDate,
        endDate: endDate,
        kmMin: kmMin,
        kmMax: kmMax,
        coutMin: coutMin,
        coutMax: coutMax,
      );

  Map<String, dynamic> toJson() => {
        'page': page,
        'size': size,
        'sortBy': sort.value,
        'sortDirection': ascending ? 'asc' : 'desc',
        if (vehiculeId != null) 'vehiculeId': vehiculeId,
        if (dossierId != null) 'dossierId': dossierId,
        if (typeEntretienId != null) 'typeEntretienId': typeEntretienId,
        if (startDate != null) 'startDate': formatApiDate(startDate!),
        if (endDate != null) 'endDate': formatApiDate(endDate!),
        if (kmMin != null) 'kmMin': kmMin,
        if (kmMax != null) 'kmMax': kmMax,
        if (coutMin != null) 'coutMin': coutMin,
        if (coutMax != null) 'coutMax': coutMax,
      };

  @override
  List<Object?> get props => [
        page,
        size,
        sort,
        ascending,
        vehiculeId,
        dossierId,
        typeEntretienId,
        startDate,
        endDate,
        kmMin,
        kmMax,
        coutMin,
        coutMax,
      ];
}

/// Corps de création / modification d'un type d'entretien. Une description
/// vide (`''`) efface l'existante ; `null` la laisse telle quelle. Le dossier
/// ne peut pas être retiré (l'API ignore un `dossierId` absent).
class TypeEntretienRequest {
  final String nom;
  final String? description;
  final String? dossierId;

  const TypeEntretienRequest({
    required this.nom,
    this.description,
    this.dossierId,
  });

  Map<String, dynamic> toJson() => {
        'nom': nom,
        if (description != null) 'description': description,
        if (dossierId != null) 'dossierId': dossierId,
      };
}

/// Corps de création / modification d'un dossier (description vide = effacée).
class DossierTypeEntretienRequest {
  final String nom;
  final String? description;

  const DossierTypeEntretienRequest({required this.nom, this.description});

  Map<String, dynamic> toJson() => {
        'nom': nom,
        if (description != null) 'description': description,
      };
}

/// Corps de `POST /vehicules-types-entretien`.
class VehiculeTypeEntretienCreateRequest {
  final String vehiculeId;
  final String typeEntretienId;
  final PeriodiciteType periodiciteType;
  final int periodiciteValeur;

  const VehiculeTypeEntretienCreateRequest({
    required this.vehiculeId,
    required this.typeEntretienId,
    required this.periodiciteType,
    required this.periodiciteValeur,
  });

  Map<String, dynamic> toJson() => {
        'vehiculeId': vehiculeId,
        'typeEntretienId': typeEntretienId,
        'periodiciteType': periodiciteType.value,
        'periodiciteValeur': periodiciteValeur,
      };
}

/// Corps de `PUT /vehicules-types-entretien/{id}`.
class VehiculeTypeEntretienUpdateRequest {
  final PeriodiciteType periodiciteType;
  final int periodiciteValeur;
  final bool actif;

  const VehiculeTypeEntretienUpdateRequest({
    required this.periodiciteType,
    required this.periodiciteValeur,
    required this.actif,
  });

  Map<String, dynamic> toJson() => {
        'periodiciteType': periodiciteType.value,
        'periodiciteValeur': periodiciteValeur,
        'actif': actif,
      };
}
