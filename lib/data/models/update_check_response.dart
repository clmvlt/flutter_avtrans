import 'package:equatable/equatable.dart';

import 'app_version_model.dart';

/// Réponse de vérification de mise à jour
class UpdateCheckResponse extends Equatable {
  final bool updateAvailable;
  final int currentVersionCode;
  final int latestVersionCode;
  final AppVersion? latestVersion;

  const UpdateCheckResponse({
    required this.updateAvailable,
    required this.currentVersionCode,
    required this.latestVersionCode,
    this.latestVersion,
  });

  factory UpdateCheckResponse.fromJson(Map<String, dynamic> json) {
    return UpdateCheckResponse(
      updateAvailable: json['updateAvailable'] as bool,
      currentVersionCode: json['currentVersionCode'] as int,
      latestVersionCode: json['latestVersionCode'] as int,
      latestVersion: json['latestVersion'] != null
          ? AppVersion.fromJson(json['latestVersion'] as Map<String, dynamic>)
          : null,
    );
  }

  @override
  List<Object?> get props => [
        updateAvailable,
        currentVersionCode,
        latestVersionCode,
      ];
}
