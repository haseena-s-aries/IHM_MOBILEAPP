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
  final DateTime? createdAt;
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
    this.createdAt,
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
    this.assignments = const [],
  });

  factory SurveyJob.fromJson(Map<String, dynamic> json) {
    return SurveyJob(
      id: json['id'] ?? 0,
      moduleType: json['moduleType'] ?? '',
      jobNumber: json['jobNumber'] ?? '',
      clientName: json['clientName'],
      projectName: json['projectName'],
      vesselName: json['vesselName'],
      imoNumber: json['imoNumber'],
      siteName: json['siteName'],
      status: json['status'] ?? '',
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt'].toString()),
      vesselId: json['vesselId'],
      vesselSnapshotJson: json['vesselSnapshotJson']?.toString(),
      assignedSurveyorName: json['assignedSurveyorName']?.toString(),

      assignedAt: json['assignedAt'] == null
          ? null
          : DateTime.tryParse(json['assignedAt'].toString()),
      auditPort: json['auditPort']?.toString(),
      auditAddress: json['auditAddress']?.toString(),
      startDate: json['startDate'] == null
          ? null
          : DateTime.tryParse(json['startDate'].toString()),
      surveyDate: json['surveyDate'] == null
          ? null
          : DateTime.tryParse(json['surveyDate'].toString()),
      endDate: json['endDate'] == null
          ? null
          : DateTime.tryParse(json['endDate'].toString()),
      assignedUserId: int.tryParse(json['assignedUserId']?.toString() ?? ''),
      assignedManagerId:
          int.tryParse(json['assignedManagerId']?.toString() ?? ''),
      assignedManagerName: json['assignedManagerName']?.toString(),
      assignments: (json['assignments'] as List? ?? [])
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
      'createdAt': createdAt?.toIso8601String(),
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
    return SurveyAssignment(
      surveyorUserId: int.tryParse(json['surveyorUserId'].toString()) ?? 0,
      surveyorName: json['surveyorName']?.toString() ?? '',
      assignedByUserId: int.tryParse(json['assignedByUserId'].toString()) ?? 0,
      assignedByName: json['assignedByName']?.toString() ?? '',
      assignedAt: json['assignedAt'] == null
          ? null
          : DateTime.tryParse(json['assignedAt'].toString()),
      status: json['status']?.toString() ?? '',
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
