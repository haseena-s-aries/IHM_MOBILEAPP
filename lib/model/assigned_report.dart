class AssignedReport {
  final int assignmentId;
  final int reportId;
  final int? surveyJobId;
  final String reportType;
  final String title;
  final String vesselName;
  final String reference;
  final String status;
  final String createdBy;
  final DateTime? assignedAt;

  const AssignedReport({
    required this.assignmentId,
    required this.reportId,
    this.surveyJobId,
    required this.reportType,
    required this.title,
    required this.vesselName,
    required this.reference,
    required this.status,
    required this.createdBy,
    required this.assignedAt,
  });

  factory AssignedReport.fromJson(Map<String, dynamic> json) {
    DateTime? assignedAt;
    final rawDate = json['assignedAt'] ?? json['AssignedAt'];
    if (rawDate != null) {
      assignedAt = DateTime.tryParse(rawDate.toString());
    }

    return AssignedReport(
      assignmentId:
          int.tryParse(
            (json['assignmentId'] ?? json['AssignmentId'] ?? 0).toString(),
          ) ??
          0,
      reportId:
          int.tryParse(
            (json['reportId'] ?? json['ReportId'] ?? 0).toString(),
          ) ??
          0,
      surveyJobId: int.tryParse(
        (json['surveyJobId'] ?? json['SurveyJobId'] ?? '').toString(),
      ),
      reportType: (json['reportType'] ?? json['ReportType'] ?? '').toString(),
      title: (json['title'] ?? json['Title'] ?? 'Report').toString(),
      vesselName:
          (json['vesselName'] ?? json['VesselName'] ?? 'Vessel not specified')
              .toString(),
      reference: (json['reference'] ?? json['Reference'] ?? '').toString(),
      status: (json['status'] ?? json['Status'] ?? 'Assigned').toString(),
      createdBy:
          (json['createdBy'] ?? json['CreatedBy'] ?? 'Creator unavailable')
              .toString(),
      assignedAt: assignedAt,
    );
  }

  String get label {
    final normalized = reportType.toLowerCase();
    if (normalized == 'ihm') return 'IHM Report';
    if (normalized == 'exsurvey') return 'EX-Survey Report';
    return 'Report';
  }
}
