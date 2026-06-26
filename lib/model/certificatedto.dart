class CertificateDto {
  final int id;
  final String certificateNumber;
  final String projectTitle;
  final String clientName;
  final String jobNumber;
  final String type;
  final String createdBy;
  final DateTime createdDate;
  final String status;

  CertificateDto({
    required this.id,
    required this.certificateNumber,
    required this.projectTitle,
    required this.clientName,
    required this.jobNumber,
    required this.type,
    required this.createdBy,
    required this.createdDate,
    required this.status,
  });

  factory CertificateDto.fromJson(Map<String, dynamic> json) {
    return CertificateDto(
      id: json['id'] ?? 0,
      certificateNumber: json['certificateNumber'] ?? 'N/A',
      projectTitle: json['projectTitle'] ?? 'N/A',
      clientName: json['clientName'] ?? 'N/A',
      jobNumber: json['jobNumber'] ?? 'N/A',
      type: json['type'] ?? 'Unknown',
      createdBy: json['createdBy'] ?? 'System',
      createdDate:
          DateTime.tryParse(json['createdDate'] ?? '') ?? DateTime.now(),
      status: json['status'] ?? 'Pending',
    );
  }
}
