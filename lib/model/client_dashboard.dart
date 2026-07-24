import 'assigned_report.dart';

class ClientDashboardSummary {
  final ClientDashboardKpis kpis;
  final List<ClientJobProgress> assignedJobs;
  final ClientHazardousMaterials hazardousMaterials;
  final List<AssignedReport> assignedReports;

  const ClientDashboardSummary({
    required this.kpis,
    required this.assignedJobs,
    required this.hazardousMaterials,
    required this.assignedReports,
  });

  factory ClientDashboardSummary.fromJson(Map<String, dynamic> json) {
    return ClientDashboardSummary(
      kpis: ClientDashboardKpis.fromJson(_map(json['kpis'] ?? json['Kpis'])),
      assignedJobs: _list(
        json['assignedJobs'] ?? json['AssignedJobs'],
      ).map(ClientJobProgress.fromJson).toList(),
      hazardousMaterials: ClientHazardousMaterials.fromJson(
        _map(json['hazardousMaterials'] ?? json['HazardousMaterials']),
      ),
      assignedReports: _list(
        json['assignedReports'] ?? json['AssignedReports'],
      ).map(AssignedReport.fromJson).toList(),
    );
  }
}

class ClientJobSummary {
  final ClientJobProgress job;
  final ClientHazardousMaterials hazardousMaterials;
  final List<ClientSurveyActivity> surveyDetails;
  final bool fromCache;

  const ClientJobSummary({
    required this.job,
    required this.hazardousMaterials,
    required this.surveyDetails,
    this.fromCache = false,
  });

  factory ClientJobSummary.fromJson(
    Map<String, dynamic> json, {
    bool fromCache = false,
  }) {
    return ClientJobSummary(
      job: ClientJobProgress.fromJson(_map(json['job'] ?? json['Job'])),
      hazardousMaterials: ClientHazardousMaterials.fromJson(
        _map(json['hazardousMaterials'] ?? json['HazardousMaterials']),
      ),
      surveyDetails: _list(
        json['surveyDetails'] ?? json['SurveyDetails'],
      ).map(ClientSurveyActivity.fromJson).toList(),
      fromCache: fromCache,
    );
  }
}

class ClientDashboardKpis {
  final int allAssignedJobs;
  final int completedJobs;
  final int inProgressJobs;
  final int pendingJobs;
  final int assignedReports;
  final int areasCovered;

  const ClientDashboardKpis({
    required this.allAssignedJobs,
    required this.completedJobs,
    required this.inProgressJobs,
    required this.pendingJobs,
    required this.assignedReports,
    required this.areasCovered,
  });

  factory ClientDashboardKpis.fromJson(Map<String, dynamic> json) {
    return ClientDashboardKpis(
      allAssignedJobs: _int(json['allAssignedJobs'] ?? json['AllAssignedJobs']),
      completedJobs: _int(json['completedJobs'] ?? json['CompletedJobs']),
      inProgressJobs: _int(json['inProgressJobs'] ?? json['InProgressJobs']),
      pendingJobs: _int(json['pendingJobs'] ?? json['PendingJobs']),
      assignedReports: _int(json['assignedReports'] ?? json['AssignedReports']),
      areasCovered: _int(json['areasCovered'] ?? json['AreasCovered']),
    );
  }
}

class ClientJobProgress {
  final int jobId;
  final String jobNumber;
  final String vesselName;
  final String imo;
  final DateTime? surveyDate;
  final String surveyorName;
  final String currentStatus;
  final double completionPercentage;
  final int totalAreas;
  final int completedAreas;
  final int pendingAreas;
  final int totalCheckpoints;
  final int completedCheckpoints;

  const ClientJobProgress({
    required this.jobId,
    required this.jobNumber,
    required this.vesselName,
    required this.imo,
    required this.surveyDate,
    required this.surveyorName,
    required this.currentStatus,
    required this.completionPercentage,
    required this.totalAreas,
    required this.completedAreas,
    required this.pendingAreas,
    required this.totalCheckpoints,
    required this.completedCheckpoints,
  });

  factory ClientJobProgress.fromJson(Map<String, dynamic> json) {
    final rawDate = json['surveyDate'] ?? json['SurveyDate'];
    return ClientJobProgress(
      jobId: _int(json['jobId'] ?? json['JobId']),
      jobNumber: _string(json['jobNumber'] ?? json['JobNumber'], '-'),
      vesselName: _string(json['vesselName'] ?? json['VesselName'], '-'),
      imo: _string(json['imo'] ?? json['Imo'], '-'),
      surveyDate: rawDate == null
          ? null
          : DateTime.tryParse(rawDate.toString()),
      surveyorName: _string(json['surveyorName'] ?? json['SurveyorName'], '-'),
      currentStatus: _string(
        json['currentStatus'] ?? json['CurrentStatus'],
        'Not Started',
      ),
      completionPercentage: _double(
        json['completionPercentage'] ?? json['CompletionPercentage'],
      ),
      totalAreas: _int(json['totalAreas'] ?? json['TotalAreas']),
      completedAreas: _int(json['completedAreas'] ?? json['CompletedAreas']),
      pendingAreas: _int(json['pendingAreas'] ?? json['PendingAreas']),
      totalCheckpoints: _int(
        json['totalCheckpoints'] ?? json['TotalCheckpoints'],
      ),
      completedCheckpoints: _int(
        json['completedCheckpoints'] ?? json['CompletedCheckpoints'],
      ),
    );
  }
}

class ClientHazardousMaterials {
  final int totalHazardousMaterialRecords;
  final int visualSamplesCount;
  final int physicalSamplesCount;
  final int positiveFindings;
  final int negativeFindings;
  final int pendingLabResults;
  final int completedLabResults;

  const ClientHazardousMaterials({
    required this.totalHazardousMaterialRecords,
    required this.visualSamplesCount,
    required this.physicalSamplesCount,
    required this.positiveFindings,
    required this.negativeFindings,
    required this.pendingLabResults,
    required this.completedLabResults,
  });

  factory ClientHazardousMaterials.fromJson(Map<String, dynamic> json) {
    return ClientHazardousMaterials(
      totalHazardousMaterialRecords: _int(
        json['totalHazardousMaterialRecords'] ??
            json['TotalHazardousMaterialRecords'],
      ),
      visualSamplesCount: _int(
        json['visualSamplesCount'] ?? json['VisualSamplesCount'],
      ),
      physicalSamplesCount: _int(
        json['physicalSamplesCount'] ?? json['PhysicalSamplesCount'],
      ),
      positiveFindings: _int(
        json['positiveFindings'] ?? json['PositiveFindings'],
      ),
      negativeFindings: _int(
        json['negativeFindings'] ?? json['NegativeFindings'],
      ),
      pendingLabResults: _int(
        json['pendingLabResults'] ?? json['PendingLabResults'],
      ),
      completedLabResults: _int(
        json['completedLabResults'] ?? json['CompletedLabResults'],
      ),
    );
  }
}

class ClientSurveyActivity {
  final String areaName;
  final int checkpointsCompleted;
  final String remarks;
  final String location;
  final String sampleNumber;
  final String visualSampleType;
  final int surveyPhotosCount;
  final DateTime? lastUpdatedDate;
  final String surveyorName;

  const ClientSurveyActivity({
    required this.areaName,
    required this.checkpointsCompleted,
    required this.remarks,
    required this.location,
    required this.sampleNumber,
    required this.visualSampleType,
    required this.surveyPhotosCount,
    required this.lastUpdatedDate,
    required this.surveyorName,
  });

  factory ClientSurveyActivity.fromJson(Map<String, dynamic> json) {
    final rawDate = json['lastUpdatedDate'] ?? json['LastUpdatedDate'];
    return ClientSurveyActivity(
      areaName: _string(json['areaName'] ?? json['AreaName'], '-'),
      checkpointsCompleted: _int(
        json['checkpointsCompleted'] ?? json['CheckpointsCompleted'],
      ),
      remarks: _string(json['remarks'] ?? json['Remarks'], '-'),
      location: _string(json['location'] ?? json['Location'], '-'),
      sampleNumber: _string(json['sampleNumber'] ?? json['SampleNumber'], '-'),
      visualSampleType: _string(
        json['visualSampleType'] ?? json['VisualSampleType'],
        '-',
      ),
      surveyPhotosCount: _int(
        json['surveyPhotosCount'] ?? json['SurveyPhotosCount'],
      ),
      lastUpdatedDate: rawDate == null
          ? null
          : DateTime.tryParse(rawDate.toString()),
      surveyorName: _string(json['surveyorName'] ?? json['SurveyorName'], '-'),
    );
  }
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Map<String, dynamic>> _list(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((x) => Map<String, dynamic>.from(x))
      .toList();
}

int _int(dynamic value) => int.tryParse((value ?? 0).toString()) ?? 0;
double _double(dynamic value) => double.tryParse((value ?? 0).toString()) ?? 0;
String _string(dynamic value, String fallback) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}
