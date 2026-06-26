import 'dart:convert';

class IhmCheckpointSubmission {
  final int id;
  final int checkpointId;
  final int surveyorUserId;
  final String surveyorName;
  final String status;
  final DateTime? submittedAt;
  final Map<String, dynamic> data;

  const IhmCheckpointSubmission({
    required this.id,
    required this.checkpointId,
    required this.surveyorUserId,
    required this.surveyorName,
    required this.status,
    required this.submittedAt,
    required this.data,
  });

  bool get isConflict => status.toLowerCase() == 'conflict';

  factory IhmCheckpointSubmission.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> values = {};
    final rawData = json['dataJson']?.toString();
    if (rawData != null && rawData.isNotEmpty) {
      final decoded = jsonDecode(rawData);
      if (decoded is Map<String, dynamic>) values = decoded;
    }

    return IhmCheckpointSubmission(
      id: int.tryParse(json['id'].toString()) ?? 0,
      checkpointId:
          int.tryParse(json['ihmCheckpointId'].toString()) ?? 0,
      surveyorUserId:
          int.tryParse(json['surveyorUserId'].toString()) ?? 0,
      surveyorName:
          json['surveyorName']?.toString() ??
          'User ${int.tryParse(json['surveyorUserId'].toString()) ?? 0}',
      status: json['status']?.toString() ?? '',
      submittedAt: DateTime.tryParse(json['submittedAt']?.toString() ?? ''),
      data: values,
    );
  }
}
