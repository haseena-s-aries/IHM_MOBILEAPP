class CertificateReport {
  final int totalCertificates;
  final int towageCount;
  final int seaFasteningCount;
  final int loadoutCount;

  CertificateReport({
    required this.totalCertificates,
    required this.towageCount,
    required this.seaFasteningCount,
    required this.loadoutCount,
  });

  factory CertificateReport.fromJson(Map<String, dynamic> json) {
    return CertificateReport(
      totalCertificates: json['totalCertificates'] ?? 0,
      towageCount: json['towageCount'] ?? 0,
      seaFasteningCount: json['seaFasteningCount'] ?? 0,
      loadoutCount: json['loadoutCount'] ?? 0,
    );
  }
}
