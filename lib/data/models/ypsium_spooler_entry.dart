import 'dart:convert';

/// Statut d'une entrée du spooler
enum SpoolerEntryStatus {
  pending,
  sending,
  failed,
}

/// Représente une requête en attente dans le spooler Ypsium
class YpsiumSpoolerEntry {
  final String id;
  final String method; // 'GET' ou 'POST'
  final String endpoint;
  final Map<String, dynamic>? body;
  final String label; // Description lisible pour l'UI
  final DateTime createdAt;
  SpoolerEntryStatus status;
  String? lastError;
  int retryCount;

  YpsiumSpoolerEntry({
    required this.id,
    required this.method,
    required this.endpoint,
    this.body,
    required this.label,
    required this.createdAt,
    this.status = SpoolerEntryStatus.pending,
    this.lastError,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'method': method,
        'endpoint': endpoint,
        'body': body,
        'label': label,
        'createdAt': createdAt.toIso8601String(),
        'status': status.name,
        'lastError': lastError,
        'retryCount': retryCount,
      };

  factory YpsiumSpoolerEntry.fromJson(Map<String, dynamic> json) {
    return YpsiumSpoolerEntry(
      id: json['id'] as String,
      method: json['method'] as String,
      endpoint: json['endpoint'] as String,
      body: json['body'] != null
          ? Map<String, dynamic>.from(json['body'] as Map)
          : null,
      label: json['label'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      status: SpoolerEntryStatus.values.byName(json['status'] as String),
      lastError: json['lastError'] as String?,
      retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
    );
  }

  /// Sérialise la liste complète du spooler en JSON
  static String encodeList(List<YpsiumSpoolerEntry> entries) =>
      jsonEncode(entries.map((e) => e.toJson()).toList());

  /// Désérialise la liste complète du spooler depuis JSON
  static List<YpsiumSpoolerEntry> decodeList(String source) {
    final list = jsonDecode(source) as List<dynamic>;
    return list
        .map((e) => YpsiumSpoolerEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
