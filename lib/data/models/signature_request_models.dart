/// Requête pour créer une signature
class SignatureCreateRequest {
  final String signatureBase64;
  final DateTime date;
  final double heuresSignees;

  const SignatureCreateRequest({
    required this.signatureBase64,
    required this.date,
    required this.heuresSignees,
  });

  Map<String, dynamic> toJson() {
    return {
      'signatureBase64': signatureBase64,
      'date': date.toIso8601String(),
      'heuresSignees': heuresSignees,
    };
  }
}
