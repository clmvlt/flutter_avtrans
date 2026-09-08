import 'package:equatable/equatable.dart';

import 'app_version_model.dart';

/// Réponse de `GET /app-versions/check?currentVersion=<int>` (contrat API §3.11).
///
/// `latestVersionCode` est null s'il n'existe aucune version active.
/// `latestVersion` n'est renseignée QUE si `updateAvailable == true`.
class UpdateCheckResponse extends Equatable {
  final bool updateAvailable;
  final int currentVersionCode;
  final int? latestVersionCode;
  final AppVersion? latestVersion;

  const UpdateCheckResponse({
    required this.updateAvailable,
    required this.currentVersionCode,
    this.latestVersionCode,
    this.latestVersion,
  });

  factory UpdateCheckResponse.fromJson(Map<String, dynamic> json) {
    return UpdateCheckResponse(
      updateAvailable: json['updateAvailable'] as bool? ?? false,
      currentVersionCode: (json['currentVersionCode'] as num?)?.toInt() ?? 0,
      latestVersionCode: (json['latestVersionCode'] as num?)?.toInt(),
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
