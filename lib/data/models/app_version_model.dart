import 'package:equatable/equatable.dart';

/// Modèle représentant une version de l'application
class AppVersion extends Equatable {
  final String id;
  final int versionCode;
  final String versionName;
  final String originalFileName;
  final int fileSize;
  final String? changelog;
  final bool isActive;
  final int downloadCount;
  final String downloadUrl;
  final DateTime createdAt;
  final String createdByUuid;
  final String? createdByName;

  const AppVersion({
    required this.id,
    required this.versionCode,
    required this.versionName,
    required this.originalFileName,
    required this.fileSize,
    this.changelog,
    required this.isActive,
    required this.downloadCount,
    required this.downloadUrl,
    required this.createdAt,
    required this.createdByUuid,
    this.createdByName,
  });

  /// Formate la taille du fichier en lecture humaine
  String get formattedFileSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} Ko';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }

  factory AppVersion.fromJson(Map<String, dynamic> json) {
    return AppVersion(
      id: json['id'] as String,
      versionCode: json['versionCode'] as int,
      versionName: json['versionName'] as String,
      originalFileName: json['originalFileName'] as String,
      fileSize: json['fileSize'] as int,
      changelog: json['changelog'] as String?,
      isActive: json['isActive'] as bool,
      downloadCount: json['downloadCount'] as int,
      downloadUrl: json['downloadUrl'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      createdByUuid: json['createdByUuid'] as String,
      createdByName: json['createdByName'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'versionCode': versionCode,
        'versionName': versionName,
        'originalFileName': originalFileName,
        'fileSize': fileSize,
        'changelog': changelog,
        'isActive': isActive,
        'downloadCount': downloadCount,
        'downloadUrl': downloadUrl,
        'createdAt': createdAt.toIso8601String(),
        'createdByUuid': createdByUuid,
        'createdByName': createdByName,
      };

  @override
  List<Object?> get props => [id, versionCode, versionName, isActive];
}
