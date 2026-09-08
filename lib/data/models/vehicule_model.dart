import 'package:equatable/equatable.dart';

import 'paginated_response.dart';
import 'user_model.dart';

/// Modèle représentant un véhicule (VehiculeDTO, contrat API §2.11).
///
/// ⚠ L'identifiant est le champ `id` (pas `uuid`) : le domaine véhicules /
/// entretiens / stock utilise `id`, les autres domaines `uuid`.
/// `model` et `brand` peuvent être null côté API ; ils sont exposés en chaîne vide.
class Vehicule extends Equatable {
  final String id;
  final String immat;
  final String? relaiImmat;
  final DateTime createdAt;
  final String model;
  final String brand;
  final String? comment;

  /// Dernier relevé kilométrique
  final int? latestKm;
  final DateTime? latestKmDate;

  /// URL absolue de la photo (ne pas re-préfixer)
  final String? pictureUrl;
  final String? vin;
  final String? numeroCarteGrise;
  final DateTime? dateMiseEnCirculation;
  final String? typeCarburant;
  final int? ptac;
  final String? numeroContratAssurance;
  final String? assureur;
  final DateTime? dateExpirationAssurance;
  final DateTime? dateProchainControleTechnique;

  const Vehicule({
    required this.id,
    required this.immat,
    this.relaiImmat,
    required this.createdAt,
    this.model = '',
    this.brand = '',
    this.comment,
    this.latestKm,
    this.latestKmDate,
    this.pictureUrl,
    this.vin,
    this.numeroCarteGrise,
    this.dateMiseEnCirculation,
    this.typeCarburant,
    this.ptac,
    this.numeroContratAssurance,
    this.assureur,
    this.dateExpirationAssurance,
    this.dateProchainControleTechnique,
  });

  static DateTime? _parseDate(dynamic value) =>
      value is String && value.isNotEmpty ? DateTime.tryParse(value) : null;

  factory Vehicule.fromJson(Map<String, dynamic> json) {
    return Vehicule(
      id: json['id'] as String,
      immat: json['immat'] as String,
      relaiImmat: json['relaiImmat'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      model: json['model'] as String? ?? '',
      brand: json['brand'] as String? ?? '',
      comment: json['comment'] as String?,
      latestKm: (json['latestKm'] as num?)?.toInt(),
      latestKmDate: _parseDate(json['latestKmDate']),
      pictureUrl: json['pictureUrl'] as String?,
      vin: json['vin'] as String?,
      numeroCarteGrise: json['numeroCarteGrise'] as String?,
      dateMiseEnCirculation: _parseDate(json['dateMiseEnCirculation']),
      typeCarburant: json['typeCarburant'] as String?,
      ptac: (json['ptac'] as num?)?.toInt(),
      numeroContratAssurance: json['numeroContratAssurance'] as String?,
      assureur: json['assureur'] as String?,
      dateExpirationAssurance: _parseDate(json['dateExpirationAssurance']),
      dateProchainControleTechnique:
          _parseDate(json['dateProchainControleTechnique']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'immat': immat,
      if (relaiImmat != null) 'relaiImmat': relaiImmat,
      'createdAt': createdAt.toIso8601String(),
      'model': model,
      'brand': brand,
      if (comment != null) 'comment': comment,
      if (latestKm != null) 'latestKm': latestKm,
      if (latestKmDate != null) 'latestKmDate': latestKmDate!.toIso8601String(),
      if (pictureUrl != null) 'pictureUrl': pictureUrl,
      if (vin != null) 'vin': vin,
      if (numeroCarteGrise != null) 'numeroCarteGrise': numeroCarteGrise,
      if (dateMiseEnCirculation != null)
        'dateMiseEnCirculation': formatApiDate(dateMiseEnCirculation!),
      if (typeCarburant != null) 'typeCarburant': typeCarburant,
      if (ptac != null) 'ptac': ptac,
      if (numeroContratAssurance != null)
        'numeroContratAssurance': numeroContratAssurance,
      if (assureur != null) 'assureur': assureur,
      if (dateExpirationAssurance != null)
        'dateExpirationAssurance': formatApiDate(dateExpirationAssurance!),
      if (dateProchainControleTechnique != null)
        'dateProchainControleTechnique':
            formatApiDate(dateProchainControleTechnique!),
    };
  }

  @override
  List<Object?> get props => [
        id,
        immat,
        relaiImmat,
        createdAt,
        model,
        brand,
        comment,
        latestKm,
        latestKmDate,
        pictureUrl,
        vin,
        numeroCarteGrise,
        dateMiseEnCirculation,
        typeCarburant,
        ptac,
        numeroContratAssurance,
        assureur,
        dateExpirationAssurance,
        dateProchainControleTechnique,
      ];
}

/// Modèle représentant un relevé de kilométrage (VehiculeKilometrageDTO, contrat API §2.12).
/// `user` peut être null côté API.
class Kilometrage extends Equatable {
  final String id;
  final String vehiculeId;
  final int km;
  final User? user;
  final DateTime createdAt;

  const Kilometrage({
    required this.id,
    required this.vehiculeId,
    required this.km,
    this.user,
    required this.createdAt,
  });

  factory Kilometrage.fromJson(Map<String, dynamic> json) {
    return Kilometrage(
      id: json['id'] as String,
      vehiculeId: json['vehiculeId'] as String,
      km: (json['km'] as num).toInt(),
      user: json['user'] != null
          ? User.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vehiculeId': vehiculeId,
      'km': km,
      if (user != null) 'user': user!.toJson(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, vehiculeId, km, user, createdAt];
}

/// Modèle représentant une information d'ajustement
class AdjustInfo extends Equatable {
  final String id;
  final String vehiculeId;
  final User? user;
  final String comment;
  final DateTime createdAt;

  const AdjustInfo({
    required this.id,
    required this.vehiculeId,
    this.user,
    required this.comment,
    required this.createdAt,
  });

  factory AdjustInfo.fromJson(Map<String, dynamic> json) {
    return AdjustInfo(
      id: (json['id'] ?? json['uuid']) as String,
      vehiculeId: json['vehiculeId'] as String,
      user: json['user'] != null
          ? User.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      comment: (json['comment'] ?? '') as String,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vehiculeId': vehiculeId,
      if (user != null) 'user': user!.toJson(),
      'comment': comment,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, vehiculeId, user, comment, createdAt];
}

/// Modèle représentant une photo d'ajustement
class AdjustPicture extends Equatable {
  final String id;
  final String adjustInfoId;
  final String pictureUrl;
  final DateTime createdAt;

  const AdjustPicture({
    required this.id,
    required this.adjustInfoId,
    required this.pictureUrl,
    required this.createdAt,
  });

  factory AdjustPicture.fromJson(Map<String, dynamic> json) {
    return AdjustPicture(
      id: (json['id'] ?? json['uuid']) as String,
      adjustInfoId: json['adjustInfoId'] as String,
      pictureUrl: json['pictureUrl'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'adjustInfoId': adjustInfoId,
      'pictureUrl': pictureUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, adjustInfoId, pictureUrl, createdAt];
}

/// Modèle représentant un fichier de véhicule (images, PDF, documents)
class VehiculeFile extends Equatable {
  final String id;
  final String vehiculeId;
  final String originalName;
  final String mimeType;
  final int fileSize;
  final DateTime createdAt;
  final String fileUrl;

  const VehiculeFile({
    required this.id,
    required this.vehiculeId,
    required this.originalName,
    required this.mimeType,
    required this.fileSize,
    required this.createdAt,
    required this.fileUrl,
  });

  factory VehiculeFile.fromJson(Map<String, dynamic> json) {
    return VehiculeFile(
      id: (json['id'] ?? json['uuid']) as String,
      vehiculeId: json['vehiculeId'] as String,
      originalName: json['originalName'] as String,
      mimeType: json['mimeType'] as String,
      fileSize: json['fileSize'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      fileUrl: json['fileUrl'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vehiculeId': vehiculeId,
      'originalName': originalName,
      'mimeType': mimeType,
      'fileSize': fileSize,
      'createdAt': createdAt.toIso8601String(),
      'fileUrl': fileUrl,
    };
  }

  /// Retourne true si ce fichier est une image
  bool get isImage => mimeType.startsWith('image/');

  /// Retourne true si ce fichier est un PDF
  bool get isPdf => mimeType == 'application/pdf';

  /// Retourne la taille du fichier formatée
  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Retourne l'extension du fichier
  String get extension {
    final parts = originalName.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  @override
  List<Object?> get props => [
        id,
        vehiculeId,
        originalName,
        mimeType,
        fileSize,
        createdAt,
        fileUrl,
      ];
}

/// Body de `POST /vehicules/kilometrages` (contrat API §4.11).
/// Aucune validation côté serveur (pas de contrôle de cohérence avec le relevé
/// précédent) : le client doit vérifier `km >= latestKm` avant l'appel.
class AddKilometrageRequest {
  final String vehiculeId;
  final int km;

  const AddKilometrageRequest({
    required this.vehiculeId,
    required this.km,
  });

  Map<String, dynamic> toJson() {
    return {
      'vehiculeId': vehiculeId,
      'km': km,
    };
  }
}

/// Request pour créer une information d'ajustement
class CreateAdjustInfoRequest {
  final String vehiculeId;
  final String comment;
  final List<String>? picturesB64;

  const CreateAdjustInfoRequest({
    required this.vehiculeId,
    required this.comment,
    this.picturesB64,
  });

  Map<String, dynamic> toJson() {
    return {
      'vehiculeId': vehiculeId,
      if (comment.isNotEmpty) 'comment': comment,
      if (picturesB64 != null && picturesB64!.isNotEmpty)
        'picturesB64': picturesB64,
    };
  }
}

/// Request pour uploader un fichier de véhicule
class UploadVehiculeFileRequest {
  final String fileB64;
  final String originalName;
  final String mimeType;

  const UploadVehiculeFileRequest({
    required this.fileB64,
    required this.originalName,
    required this.mimeType,
  });

  Map<String, dynamic> toJson() {
    return {
      'fileB64': fileB64,
      'originalName': originalName,
      'mimeType': mimeType,
    };
  }
}

/// Réponse pour le dernier kilométrage de l'utilisateur
class LastKilometrageResponse extends Equatable {
  final Kilometrage? lastKilometrage;
  final bool hasEnteredToday;

  const LastKilometrageResponse({
    this.lastKilometrage,
    required this.hasEnteredToday,
  });

  factory LastKilometrageResponse.fromJson(Map<String, dynamic> json) {
    return LastKilometrageResponse(
      lastKilometrage: json['lastKilometrage'] != null
          ? Kilometrage.fromJson(json['lastKilometrage'] as Map<String, dynamic>)
          : null,
      hasEnteredToday: json['hasEnteredToday'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [lastKilometrage, hasEnteredToday];
}
