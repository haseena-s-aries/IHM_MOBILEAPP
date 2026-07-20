class SurveyJob {
  final int id;
  final String moduleType;
  final String jobNumber;
  final String? clientName;
  final String? projectName;
  final String? vesselName;
  final String? imoNumber;
  final String? siteName;
  final String status;
  final String displayStatus;
  final int completedItems;
  final int totalItems;
  final double completionPercentage;
  final DateTime? createdAt;
  final int? createdByUserId;
  final bool canEdit;
  final int? vesselId;
  final String? vesselSnapshotJson;
  final String? assignedSurveyorName;
  final DateTime? assignedAt;
  final String? auditPort;
  final String? auditAddress;
  final DateTime? startDate;
  final DateTime? surveyDate;
  final DateTime? endDate;
  final int? assignedUserId;
  final int? assignedManagerId;
  final String? assignedManagerName;
  final String? vscpChecklistFilePath;
  final String? vscpChecklistFileName;
  final DateTime? vscpChecklistUploadedAt;
  final List<SurveyAssignment> assignments;

  SurveyJob({
    required this.id,
    required this.moduleType,
    required this.jobNumber,
    this.clientName,
    this.projectName,
    this.vesselName,
    this.imoNumber,
    this.siteName,
    required this.status,
    this.displayStatus = 'Not Started',
    this.completedItems = 0,
    this.totalItems = 0,
    this.completionPercentage = 0,
    this.createdAt,
    this.createdByUserId,
    this.canEdit = false,
    this.vesselId,
    this.vesselSnapshotJson,
    this.assignedSurveyorName,
    this.assignedAt,
    this.auditPort,
    this.auditAddress,
    this.startDate,
    this.surveyDate,
    this.endDate,
    this.assignedUserId,
    this.assignedManagerId,
    this.assignedManagerName,
    this.vscpChecklistFilePath,
    this.vscpChecklistFileName,
    this.vscpChecklistUploadedAt,
    this.assignments = const [],
  });

  factory SurveyJob.fromJson(Map<String, dynamic> json) {
    final createdAt = json['createdAt'] ?? json['CreatedAt'];
    final assignedAt = json['assignedAt'] ?? json['AssignedAt'];
    final startDate = json['startDate'] ?? json['StartDate'];
    final surveyDate = json['surveyDate'] ?? json['SurveyDate'];
    final endDate = json['endDate'] ?? json['EndDate'];
    final vscpChecklistUploadedAt =
        json['vscpChecklistUploadedAt'] ?? json['VscpChecklistUploadedAt'];
    final assignments = json['assignments'] ?? json['Assignments'];

    return SurveyJob(
      id: int.tryParse((json['id'] ?? json['Id'] ?? 0).toString()) ?? 0,
      moduleType: json['moduleType'] ?? json['ModuleType'] ?? '',
      jobNumber: json['jobNumber'] ?? json['JobNumber'] ?? '',
      clientName: json['clientName'] ?? json['ClientName'],
      projectName: json['projectName'] ?? json['ProjectName'],
      vesselName: json['vesselName'] ?? json['VesselName'],
      imoNumber: json['imoNumber'] ?? json['ImoNumber'],
      siteName: json['siteName'] ?? json['SiteName'],
      status: json['status'] ?? json['Status'] ?? '',
      displayStatus:
          json['displayStatus']?.toString() ??
          json['DisplayStatus']?.toString() ??
          json['status']?.toString() ??
          json['Status']?.toString() ??
          'Not Started',
      completedItems:
          int.tryParse(
            (json['completedItems'] ?? json['CompletedItems'] ?? 0).toString(),
          ) ??
          0,
      totalItems:
          int.tryParse(
            (json['totalItems'] ?? json['TotalItems'] ?? 0).toString(),
          ) ??
          0,
      completionPercentage:
          double.tryParse(
            (json['completionPercentage'] ??
                    json['CompletionPercentage'] ??
                    0)
                .toString(),
          ) ??
          0,
      createdAt: createdAt == null
          ? null
          : DateTime.tryParse(createdAt.toString()),
      createdByUserId: int.tryParse(
        (json['createdByUserId'] ?? json['CreatedByUserId'])?.toString() ?? '',
      ),
      canEdit:
          json['canEdit'] == true ||
          json['CanEdit'] == true ||
          json['canEdit']?.toString().toLowerCase() == 'true' ||
          json['CanEdit']?.toString().toLowerCase() == 'true',
      vesselId:
          int.tryParse((json['vesselId'] ?? json['VesselId'])?.toString() ?? ''),
      vesselSnapshotJson:
          (json['vesselSnapshotJson'] ?? json['VesselSnapshotJson'])
              ?.toString(),
      assignedSurveyorName:
          (json['assignedSurveyorName'] ?? json['AssignedSurveyorName'])
              ?.toString(),

      assignedAt: assignedAt == null
          ? null
          : DateTime.tryParse(assignedAt.toString()),
      auditPort: (json['auditPort'] ?? json['AuditPort'])?.toString(),
      auditAddress: (json['auditAddress'] ?? json['AuditAddress'])?.toString(),
      startDate: startDate == null
          ? null
          : DateTime.tryParse(startDate.toString()),
      surveyDate: surveyDate == null
          ? null
          : DateTime.tryParse(surveyDate.toString()),
      endDate: endDate == null
          ? null
          : DateTime.tryParse(endDate.toString()),
      assignedUserId: int.tryParse(
        (json['assignedUserId'] ?? json['AssignedUserId'])?.toString() ?? '',
      ),
      assignedManagerId:
          int.tryParse((json['assignedManagerId'] ?? json['AssignedManagerId'])
                  ?.toString() ??
              ''),
      assignedManagerName:
          (json['assignedManagerName'] ?? json['AssignedManagerName'])
              ?.toString(),
      vscpChecklistFilePath:
          (json['vscpChecklistFilePath'] ?? json['VscpChecklistFilePath'])
              ?.toString(),
      vscpChecklistFileName:
          (json['vscpChecklistFileName'] ?? json['VscpChecklistFileName'])
              ?.toString(),
      vscpChecklistUploadedAt: vscpChecklistUploadedAt == null
          ? null
          : DateTime.tryParse(vscpChecklistUploadedAt.toString()),
      assignments: (assignments as List? ?? [])
          .map((e) => SurveyAssignment.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'moduleType': moduleType,
      'jobNumber': jobNumber,
      'clientName': clientName,
      'projectName': projectName,
      'vesselName': vesselName,
      'imoNumber': imoNumber,
      'siteName': siteName,
      'status': status,
      'displayStatus': displayStatus,
      'completedItems': completedItems,
      'totalItems': totalItems,
      'completionPercentage': completionPercentage,
      'createdAt': createdAt?.toIso8601String(),
      'createdByUserId': createdByUserId,
      'canEdit': canEdit,
      'vesselId': vesselId,
      'vesselSnapshotJson': vesselSnapshotJson,
      'assignedSurveyorName': assignedSurveyorName,
      'assignedAt': assignedAt?.toIso8601String(),
      'auditPort': auditPort,
      'auditAddress': auditAddress,
      'startDate': startDate?.toIso8601String(),
      'surveyDate': surveyDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'assignedUserId': assignedUserId,
      'assignedManagerId': assignedManagerId,
      'assignedManagerName': assignedManagerName,
      'vscpChecklistFilePath': vscpChecklistFilePath,
      'vscpChecklistFileName': vscpChecklistFileName,
      'vscpChecklistUploadedAt': vscpChecklistUploadedAt?.toIso8601String(),
      'assignments': assignments.map((x) => x.toJson()).toList(),
    };
  }

  List<SurveyAssignment> get activeAssignments =>
      assignments
          .where((x) => x.status.toLowerCase() != 'returned')
          .toList()
        ..sort(
          (a, b) => (a.assignedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(
                b.assignedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
              ),
        );

  bool get hasAssignedSurveyors =>
      activeAssignments.isNotEmpty ||
      (assignedSurveyorName != null && assignedSurveyorName!.trim().isNotEmpty);

  String? get primarySurveyorName {
    if (activeAssignments.isEmpty) return assignedSurveyorName;
    return activeAssignments[0].surveyorName;
  }

  String? get secondarySurveyorName {
    if (activeAssignments.length < 2) return null;
    return activeAssignments[1].surveyorName;
  }

  int? get primarySurveyorUserId {
    if (activeAssignments.isEmpty) return null;
    return activeAssignments[0].surveyorUserId;
  }

  int? get secondarySurveyorUserId {
    if (activeAssignments.length < 2) return null;
    return activeAssignments[1].surveyorUserId;
  }
}

class SurveyAssignment {
  final int surveyorUserId;
  final String surveyorName;
  final int assignedByUserId;
  final String assignedByName;
  final DateTime? assignedAt;
  final String status;

  const SurveyAssignment({
    required this.surveyorUserId,
    required this.surveyorName,
    required this.assignedByUserId,
    required this.assignedByName,
    required this.assignedAt,
    required this.status,
  });

  factory SurveyAssignment.fromJson(Map<String, dynamic> json) {
    final surveyorUserId = json['surveyorUserId'] ?? json['SurveyorUserId'];
    final surveyorName = json['surveyorName'] ?? json['SurveyorName'];
    final assignedByUserId =
        json['assignedByUserId'] ?? json['AssignedByUserId'];
    final assignedByName = json['assignedByName'] ?? json['AssignedByName'];
    final assignedAt = json['assignedAt'] ?? json['AssignedAt'];
    final status = json['status'] ?? json['Status'];

    return SurveyAssignment(
      surveyorUserId: int.tryParse(surveyorUserId?.toString() ?? '') ?? 0,
      surveyorName: surveyorName?.toString() ?? '',
      assignedByUserId: int.tryParse(assignedByUserId?.toString() ?? '') ?? 0,
      assignedByName: assignedByName?.toString() ?? '',
      assignedAt: assignedAt == null
          ? null
          : DateTime.tryParse(assignedAt.toString()),
      status: status?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'surveyorUserId': surveyorUserId,
      'surveyorName': surveyorName,
      'assignedByUserId': assignedByUserId,
      'assignedByName': assignedByName,
      'assignedAt': assignedAt?.toIso8601String(),
      'status': status,
    };
  }
}
