import 'dart:convert';
import 'package:Auras/Db/database_helper.dart';
import 'package:Auras/app_config.dart';
import 'package:Auras/ihm_area.dart';
import 'package:Auras/model/PendingUser.dart';
import 'package:Auras/model/TotalCertificateCountDto.dart';
import 'package:Auras/model/certificatedto.dart';
import 'package:Auras/model/seafastening.dart';
import 'package:Auras/model/vessel.dart';
import 'package:Auras/screen/screen/TaskManager_screen.dart';
import 'package:Auras/model/survey_job.dart';
import 'package:Auras/model/ihm_checkpoint_submission.dart';
import 'package:Auras/model/app_notification.dart';
import 'package:Auras/model/assigned_report.dart';
import 'package:Auras/model/client_dashboard.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  static const String _genericOtpError =
      'Unable to generate OTP. Please try again later.';

  static Map<String, dynamic> _safeJsonMessage(
    http.Response response, {
    required String fallbackMessage,
  }) {
    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    final body = response.body.trim();
    final looksLikeHtml =
        body.startsWith('<!DOCTYPE html') ||
        body.startsWith('<html') ||
        body.toLowerCase().contains('<html');

    if (!contentType.contains('application/json') || looksLikeHtml) {
      return {'status': response.statusCode, 'message': fallbackMessage};
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        return {
          'status': response.statusCode,
          ...decoded.cast<String, dynamic>(),
        };
      }
    } catch (_) {
      // Fall through to a safe generic message.
    }

    return {'status': response.statusCode, 'message': fallbackMessage};
  }

  static Future<List<AppNotification>> fetchUserNotifications(
    int userId, {
    bool unreadOnly = false,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/notifications/users/$userId?unreadOnly=$unreadOnly'),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load notifications: ${response.body}');
    }

    final List<dynamic> rows = jsonDecode(response.body);
    return rows
        .map((row) => AppNotification.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  static Future<void> markNotificationRead(int notificationId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/notifications/$notificationId/read'),
    );
    if (response.statusCode != 200) throw Exception(response.body);
  }

  static Future<void> markAllNotificationsRead(int userId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/notifications/users/$userId/read-all'),
    );
    if (response.statusCode != 200) throw Exception(response.body);
  }

  static Future<List<AssignedReport>> fetchMyAssignedReports() async {
    final response = await http.get(
      Uri.parse('$baseUrl/report-assignments/my-reports'),
      headers: await _authHeaders(),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load assigned reports: ${response.body}');
    }

    final List<dynamic> rows = jsonDecode(response.body);
    return rows
        .map((row) => AssignedReport.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  static Future<ClientDashboardSummary> fetchClientDashboardSummary() async {
    final response = await http.get(
      Uri.parse('$baseUrl/client-dashboard/summary'),
      headers: await _authHeaders(),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load client dashboard: ${response.body}');
    }

    return ClientDashboardSummary.fromJson(
      Map<String, dynamic>.from(jsonDecode(response.body) as Map),
    );
  }

  static Future<ClientJobSummary> fetchClientJobSummary(int jobId) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'client_job_summary_$jobId';

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/client-dashboard/jobs/$jobId/summary'),
        headers: await _authHeaders(),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to load survey summary: ${response.body}');
      }

      await prefs.setString(cacheKey, response.body);
      return ClientJobSummary.fromJson(
        Map<String, dynamic>.from(jsonDecode(response.body) as Map),
      );
    } catch (error) {
      final cached = prefs.getString(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        return ClientJobSummary.fromJson(
          Map<String, dynamic>.from(jsonDecode(cached) as Map),
          fromCache: true,
        );
      }
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchSavedReports() async {
    final response = await http.get(
      Uri.parse('$baseUrl/AdminDashboard/saved-reports'),
      headers: await _authHeaders(),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load reports: ${response.body}');
    }

    final List<dynamic> rows = jsonDecode(response.body);
    return rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  static Future<List<Map<String, dynamic>>> fetchReportClients({
    required String projectType,
    String search = '',
  }) async {
    final uri = Uri.parse('$baseUrl/report-assignments/clients').replace(
      queryParameters: {
        'projectType': projectType,
        if (search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    final response = await http.get(uri, headers: await _authHeaders());
    if (response.statusCode != 200) {
      throw Exception('Failed to load Client users: ${response.body}');
    }

    final List<dynamic> rows = jsonDecode(response.body);
    return rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  static Future<List<Map<String, dynamic>>> fetchReportAssignments({
    required String reportType,
    required int reportId,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/report-assignments/$reportType/$reportId'),
      headers: await _authHeaders(),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load assignments: ${response.body}');
    }

    final List<dynamic> rows = jsonDecode(response.body);
    return rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  static Future<String> assignReportToClient({
    required String reportType,
    required int reportId,
    required int clientUserId,
    int? surveyJobId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/report-assignments'),
      headers: await _authHeaders(json: true),
      body: jsonEncode({
        'reportType': reportType,
        'reportId': reportId,
        'surveyJobId': surveyJobId ?? reportId,
        'clientUserId': clientUserId,
      }),
    );

    final body = response.body.trim();
    if (response.statusCode != 200) {
      final payload = _safeJsonMessage(
        response,
        fallbackMessage: 'Unable to send report. Please try again.',
      );
      throw Exception(
        payload['message']?.toString() ?? 'Unable to send report.',
      );
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] != null) {
        return decoded['message'].toString();
      }
    } catch (_) {}
    return 'Report assigned successfully.';
  }

  static Future<String> revokeReportAssignment(int assignmentId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/report-assignments/$assignmentId/revoke'),
      headers: await _authHeaders(json: true),
      body: '{}',
    );

    final body = response.body.trim();
    if (response.statusCode != 200) {
      final payload = _safeJsonMessage(
        response,
        fallbackMessage: 'Unable to remove assignment. Please try again.',
      );
      throw Exception(
        payload['message']?.toString() ?? 'Unable to remove assignment.',
      );
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] != null) {
        return decoded['message'].toString();
      }
    } catch (_) {}
    return 'Report assignment removed.';
  }

  static Future<Uint8List> downloadSavedReportPdf({
    required String reportType,
    required int reportId,
  }) async {
    final type = reportType.toLowerCase();
    final path = type == 'ihm'
        ? '$baseUrl/ihm-survey/jobs/$reportId/report-pdf'
        : type == 'exsurvey'
        ? '$baseUrl/ex-survey/jobs/$reportId/report'
        : '$baseUrl/AdminDashboard/view-pdf/$type/$reportId';

    final response = await http.get(
      Uri.parse(path),
      headers: await _authHeaders(),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to download report: ${response.body}');
    }

    return response.bodyBytes;
  }

  static Future<Uint8List> downloadAssignedReportPdf(
    AssignedReport report,
  ) async {
    final type = report.reportType.toLowerCase();
    final path = type == 'ihm'
        ? '$baseUrl/ihm-survey/jobs/${report.reportId}/report-pdf'
        : '$baseUrl/ex-survey/jobs/${report.reportId}/report';

    final response = await http.get(
      Uri.parse(path),
      headers: await _authHeaders(),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to download report: ${response.body}');
    }

    return response.bodyBytes;
  }

  static Future<List<IhmCheckpointSubmission>> fetchIhmCheckpointSubmissions(
    int jobId,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/ihm-survey/jobs/$jobId/checkpoint-submissions'),
    );
    if (response.statusCode != 200) throw Exception(response.body);

    final List<dynamic> rows = jsonDecode(response.body);
    return rows
        .map(
          (row) =>
              IhmCheckpointSubmission.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  static Future<void> approveIhmCheckpointSubmission({
    required int submissionId,
    required int reviewerUserId,
    String? notes,
  }) async {
    final response = await http.post(
      Uri.parse(
        '$baseUrl/ihm-survey/checkpoint-submissions/$submissionId/approve',
      ),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'reviewedByUserId': reviewerUserId, 'notes': notes}),
    );
    if (response.statusCode != 200) throw Exception(response.body);
  }

  static Future<List<SurveyJob>> fetchSurveyJobsByVessel(int vesselId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/survey/vessels/$vesselId/jobs'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch vessel jobs: ${response.body}');
    }

    final List<dynamic> data = jsonDecode(response.body);

    return data
        .map((item) => SurveyJob.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<String> uploadIhmReportAsset({
    required int jobId,
    required PlatformFile file,
  }) async {
    final ext = (file.extension ?? '').toLowerCase();
    if (!['jpg', 'jpeg', 'png'].contains(ext)) {
      throw Exception('Only JPG, JPEG, PNG files are allowed.');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/ihm-report-info/jobs/$jobId/assets/upload'),
    );

    request.files.add(
      http.MultipartFile.fromBytes('file', file.bytes!, filename: file.name),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw Exception(response.body);
    }

    final data = jsonDecode(response.body);
    return data['filePath'].toString();
  }

  static Future<String> uploadIhmReportAssetBytes({
    required int jobId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/ihm-report-info/jobs/$jobId/assets/upload'),
    );

    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: fileName),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw Exception(response.body);
    }

    final data = jsonDecode(response.body);
    return data['filePath'].toString();
  }

  static Future<void> uploadIhmAppendixFiles({
    required int jobId,
    required String appendixType,
    String? appendixName,
    int? appendixNo,
    required List<PlatformFile> files,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(
        '$baseUrl/ihm-report-info/jobs/$jobId/appendix-attachments/upload',
      ),
    );

    request.fields['appendixType'] = appendixType;
    if (appendixName != null && appendixName.trim().isNotEmpty) {
      request.fields['appendixName'] = appendixName.trim();
    }
    if (appendixNo != null) {
      request.fields['appendixNo'] = appendixNo.toString();
    }

    for (final file in files) {
      final ext = (file.extension ?? '').toLowerCase();
      if (!['pdf', 'jpg', 'jpeg', 'png'].contains(ext)) {
        throw Exception('Only PDF, JPG, JPEG, PNG files are allowed.');
      }

      request.files.add(
        http.MultipartFile.fromBytes('files', file.bytes!, filename: file.name),
      );
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw Exception(response.body);
    }
  }

  static Future<void> deleteIhmAppendixFile({
    required int jobId,
    required int attachmentId,
  }) async {
    final response = await http.delete(
      Uri.parse(
        '$baseUrl/ihm-report-info/jobs/$jobId/appendix-attachments/$attachmentId',
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(response.body);
    }
  }

  static Future<void> updateCustomAppendixTitle({
    required int jobId,
    required int appendixNo,
    required String appendixTitle,
  }) async {
    final response = await http.put(
      Uri.parse(
        '$baseUrl/ihm-report-info/jobs/$jobId/custom-appendices/$appendixNo',
      ),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'appendixTitle': appendixTitle}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(response.body);
    }
  }

  static Future<void> updateVessel({
    required int vesselId,
    required Map<String, dynamic> data,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/vessels/$vesselId'),
      headers: await _authHeaders(json: true),
      body: jsonEncode(data),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(response.body);
    }
  }

  static Future<List<Map<String, dynamic>>> fetchIhmJobReportOptions({
    String query = '',
  }) async {
    final uri = Uri.parse('$baseUrl/ihm-report-info/jobs/options').replace(
      queryParameters: {if (query.trim().isNotEmpty) 'search': query.trim()},
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception(response.body);
    }

    final List data = jsonDecode(response.body);
    return data.map((x) => Map<String, dynamic>.from(x)).toList();
  }

  static Future<void> copyIhmAppendicesFromJob({
    required int currentJobId,
    required int sourceJobId,
  }) async {
    final response = await http.post(
      Uri.parse(
        '$baseUrl/ihm-report-info/jobs/$currentJobId/copy-appendices-from/$sourceJobId',
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(response.body);
    }
  }

  static Future<String> generateIhmReport(int jobId) async {
    final markerMapResponse = await http.post(
      Uri.parse('$baseUrl/ihm-survey/jobs/$jobId/generate-ga-marker-map'),
    );

    if (markerMapResponse.statusCode != 200) {
      throw Exception(
        markerMapResponse.body.isNotEmpty
            ? markerMapResponse.body
            : 'Unable to prepare marked layout pages.',
      );
    }

    final response = await http.post(
      Uri.parse('$baseUrl/ihm-survey/jobs/$jobId/generate-report'),
    );

    if (response.statusCode != 200) {
      throw Exception(response.body);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    final filePath = data['filePath']?.toString();
    if (filePath != null && filePath.isNotEmpty) {
      return fileUrl(filePath);
    }

    final url = data['fileUrl']?.toString();
    if (url != null && url.isNotEmpty) {
      return fileUrl(url);
    }

    throw Exception('PDF path not found in response');
  }

  static String fileUrl(String path) {
    if (path.startsWith('http')) return path;

    final apiRoot = baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
    final cleanPath = path.startsWith('/') ? path : '/$path';

    return '$apiRoot$cleanPath';
  }

  static Future<Map<String, dynamic>?> fetchIhmReportInfo(int jobId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/ihm-report-info/jobs/$jobId'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch IHM report info: ${response.body}');
    }

    final data = jsonDecode(response.body);
    if (data == null) return null;

    return data as Map<String, dynamic>;
  }

  static Future<void> saveIhmReportInfo({
    required int jobId,
    required Map<String, dynamic> data,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/ihm-report-info/jobs/$jobId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to save IHM report info: ${response.body}');
    }
  }

  static Future<Vessel> fetchVesselById(int id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/vessels/$id'),
      headers: await _authHeaders(),
    );

    if (response.statusCode == 200) {
      return Vessel.fromJson(jsonDecode(response.body));
    }

    throw Exception('Failed to load vessel: ${response.body}');
  }

  static Future<SurveyJob> fetchSurveyJobById(int id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/survey/jobs/$id'),
      headers: await _authHeaders(),
    );

    if (response.statusCode == 200) {
      return SurveyJob.fromJson(jsonDecode(response.body));
    }

    throw Exception('Failed to load survey job: ${response.body}');
  }

  static Future<List<SurveyorOption>> fetchSurveyors() async {
    final response = await http.get(
      Uri.parse('$baseUrl/User/surveyors'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load surveyors: ${response.body}');
    }

    final List<dynamic> data = jsonDecode(response.body);

    return data
        .map((item) {
          final json = item as Map<String, dynamic>;

          return SurveyorOption(
            id: int.tryParse(json['id'].toString()) ?? 0,
            name: json['fullName']?.toString() ?? '',
            email: json['email']?.toString() ?? '',
            role: json['role']?.toString() ?? '',
          );
        })
        .where((x) => x.id > 0)
        .toList();
  }

  static Future<List<SurveyorOption>> fetchManagers() async {
    final response = await http.get(
      Uri.parse('$baseUrl/User/managers'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load managers: ${response.body}');
    }

    final List<dynamic> data = jsonDecode(response.body);

    return data
        .map((item) {
          final json = item as Map<String, dynamic>;
          return SurveyorOption(
            id: int.tryParse(json['id'].toString()) ?? 0,
            name: json['fullName']?.toString() ?? '',
            email: json['email']?.toString() ?? '',
            role: json['role']?.toString() ?? '',
          );
        })
        .where((x) => x.id > 0)
        .toList();
  }

  static Future<void> assignSurveyJob({
    required int surveyJobId,
    required int surveyorUserId,
    required int assignedByUserId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/survey/jobs/$surveyJobId/assign'),
      headers: await _authHeaders(json: true),
      body: jsonEncode({
        'surveyorUserId': surveyorUserId,
        'assignedByUserId': assignedByUserId,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to assign surveyor: ${response.body}');
    }
  }

  // âœ… Change this to your live API when needed
  static String get baseUrl => AppConfig.baseUrl.replaceAll(RegExp(r'/$'), '');

  /// ðŸ“² User login with email & password
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final url = Uri.parse('$baseUrl/User/login');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        if (response.body.trim().isEmpty) {
          throw Exception('The login API returned an empty response.');
        }
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          throw Exception('The login API returned an invalid response.');
        }
        return decoded;
      } else {
        // ðŸ’¡ You can decode error body too
        var message = response.body.trim();
        if (message.isNotEmpty) {
          try {
            final decoded = jsonDecode(message);
            if (decoded is Map<String, dynamic>) {
              message = decoded['message']?.toString() ?? message;
            }
          } on FormatException {
            // Preserve plain-text API errors.
          }
        }
        if (response.statusCode >= 300 && response.statusCode < 400) {
          message =
              'The API redirected login. Restart it using the Development HTTP profile.';
        } else if (message.isEmpty) {
          message = 'Login failed with HTTP ${response.statusCode}.';
        }
        throw Exception('Login failed: $message');
      }
    } catch (e) {
      // ðŸ”¥ Catch network/format errors
      throw Exception('Login error: $e');
    }
  }

  static Future<CertificateReport> fetchCertificateReport() async {
    final url = Uri.parse('$baseUrl/AdminDashboard/certificate-report');

    final response = await http.get(url, headers: await _authHeaders());

    if (response.statusCode == 200) {
      return CertificateReport.fromJson(jsonDecode(response.body));
    } else {
      throw Exception("Failed to fetch certificate report: ${response.body}");
    }
  }

  static Future<Map<String, int>> fetchSurveyorDashboardSummary() async {
    final response = await http.get(
      Uri.parse('$baseUrl/survey/dashboard/my-summary'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch surveyor dashboard summary: ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    int readInt(String key) {
      final value = data[key] ?? data[_toPascalCase(key)];
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return {
      'liveJobs': readInt('liveJobs'),
      'completedJobs': readInt('completedJobs'),
    };
  }

  static Future<Map<String, int>> fetchSurveySummary() async {
    final response = await http.get(
      Uri.parse('$baseUrl/survey/summary'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch survey summary: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    int readInt(String key) {
      final value = data[key] ?? data[_toPascalCase(key)];
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return {
      'totalSurveyJobs': readInt('totalSurveyJobs'),
      'ihmSurveyJobs': readInt('ihmSurveyJobs'),
      'exSurveyJobs': readInt('exSurveyJobs'),
      'approvedJobs': readInt('approvedJobs'),
      'closedJobs': readInt('closedJobs'),
      'liveJobs': readInt('ihmLiveJobs') > 0 || readInt('ihmCompletedJobs') > 0
          ? readInt('ihmLiveJobs')
          : readInt('liveIhmJobs'),
      'ihmLiveJobs':
          readInt('ihmLiveJobs') > 0 || readInt('ihmCompletedJobs') > 0
          ? readInt('ihmLiveJobs')
          : readInt('liveIhmJobs'),
      'completedJobs': readInt('ihmCompletedJobs'),
      'exSurveyLiveJobs': readInt('exSurveyLiveJobs'),
      'exSurveyReports': readInt('exSurveyReports'),
      'ihmUsersCount': readInt('ihmUsersCount'),
      'exSurveyUsersCount': readInt('exSurveyUsersCount'),
    };
  }

  static String _toPascalCase(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  static Future<List<dynamic>> getAllUsers() async {
    final response = await http.get(
      Uri.parse('$baseUrl/AdminDashboard/GetAll'),
      headers: await _authHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      throw Exception('Failed to load users: ${response.body}');
    }
  }

  static Future<String> sendOtp(String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/User/send-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    final json = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return json['message'];
    } else {
      throw Exception(json['message'] ?? "Failed to send OTP");
    }
  }

  // ðŸ“© Verify OTP
  static Future<String> verifyOtp(String email, String otp) async {
    final url = Uri.parse('$baseUrl/User/verify-otp');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim(), 'otp': otp.trim()}),
      );

      final body = response.body.trim();
      print('ðŸ”µ Status Code: ${response.statusCode}');
      print('ðŸŸ¡ Raw Response: "$body"');

      if (response.statusCode == 200) {
        if (body.isEmpty) return "OTP verified (no message from server)";
        final json = jsonDecode(body);
        return json['message'] ?? "OTP verified.";
      } else {
        if (body.isEmpty) throw Exception("OTP verification failed.");
        final json = jsonDecode(body);
        throw Exception(json['message'] ?? "OTP verification failed.");
      }
    } catch (e) {
      throw Exception("âŒ Error verifying OTP: $e");
    }
  }

  static Future<void> uploadIhmExcelChecklist({
    required int surveyJobId,
    required String filePath,
  }) async {
    final url = Uri.parse('$baseUrl/ihm-survey/jobs/$surveyJobId/import-excel');

    final request = http.MultipartRequest('POST', url);
    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw Exception('Failed to upload Excel checklist: ${response.body}');
    }
  }

  static Future<void> deleteSurveyJob(int jobId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/survey/jobs/$jobId'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete survey job: ${response.body}');
    }
  }

  static Future<SurveyJob> updateSurveyJob({
    required int jobId,
    required int vesselId,
    String? clientName,
    String? projectName,
    String? siteName,
    String? startDate,
    String? surveyDate,
    String? endDate,
    String? auditPort,
    String? auditAddress,
    int? assignedManagerId,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/survey/jobs/$jobId'),
      headers: await _authHeaders(json: true),
      body: jsonEncode({
        'vesselId': vesselId,
        'clientName': clientName,
        'projectName': projectName,
        'siteName': siteName,
        'startDate': startDate,
        'surveyDate': surveyDate,
        'endDate': endDate,
        'auditPort': auditPort,
        'auditAddress': auditAddress,
        'assignedManagerId': assignedManagerId,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update survey job: ${response.body}');
    }

    return SurveyJob.fromJson(jsonDecode(response.body));
  }

  static Future<List<Vessel>> fetchVessels() async {
    final response = await http.get(
      Uri.parse('$baseUrl/vessels'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch vessels: ${response.body}');
    }

    final List<dynamic> data = jsonDecode(response.body);

    return data
        .map((item) => Vessel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<Vessel> createVessel({
    required String vesselName,
    String? imoNumber,
    String? officialNumber,
    String? vesselType,
    String? flag,
    String? portOfRegistry,
    String? classSociety,
    String? callSign,
    String? builder,
    String? dateOfBuild,
    double? grossTonnage,
    double? netTonnage,
    double? deadweight,
    double? lengthOverall,
    double? lengthBetweenPerpendiculars,
    double? breadth,
    double? depth,
    double? draughtMoulded,
    int? yearBuilt,
    String? ownerName,
    String? managerName,
    String? clientName,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/vessels'),
      headers: await _authHeaders(json: true),
      body: jsonEncode({
        'vesselName': vesselName,
        'imoNumber': imoNumber,
        'officialNumber': officialNumber,
        'vesselType': vesselType,
        'flag': flag,
        'portOfRegistry': portOfRegistry,
        'classSociety': classSociety,
        'callSign': callSign,
        'builder': builder,
        'dateOfBuild': dateOfBuild,

        'grossTonnage': grossTonnage,
        'netTonnage': netTonnage,
        'deadweight': deadweight,
        'lengthOverall': lengthOverall,
        'lengthBetweenPerpendiculars': lengthBetweenPerpendiculars,
        'breadth': breadth,
        'depth': depth,
        'draughtMoulded': draughtMoulded,

        'ownerName': ownerName,
        'managerName': managerName,
        'clientName': clientName,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to create vessel: ${response.body}');
    }

    return Vessel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  static Future<void> deleteVessel(int vesselId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/vessels/$vesselId/deactivate'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete vessel: ${response.body}');
    }
  }

  static Future<String> uploadIhmLayout({
    required int jobId,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final uploadedByUserId = prefs.getInt('userId') ?? 0;

    final url = Uri.parse('$baseUrl/ihm-survey/jobs/$jobId/ga-layout');

    final request = http.MultipartRequest('POST', url);

    request.fields['relatedModule'] = 'IhmLayout';
    request.fields['uploadedByUserId'] = uploadedByUserId.toString();

    request.files.add(
      http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
    );

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode == 200 || response.statusCode == 201) {
      return body;
    }

    throw Exception('Failed to upload layout: $body');
  }

  static Future<Map<String, dynamic>> register(
    String fullName,
    String email,
    String password,
    String confirmPassword,
    String role,
  ) async {
    final url = Uri.parse('$baseUrl/User/register');

    print("ðŸ“¤ Sending Registration Request...");
    print("ðŸ”¸ Payload: {");
    print("   fullName: $fullName,");
    print("   email: $email,");
    print("   password: $password,");
    print("   confirmPassword: $confirmPassword,");
    print("   role: $role");
    print("}");

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fullName': fullName,
          'email': email,
          'password': password,
          'confirmPassword': confirmPassword,
          'role': role,
        }),
      );

      print("ðŸ”µ Status Code: ${response.statusCode}");
      print("ðŸŸ¡ Raw Response: ${response.body}");

      final responseBody = jsonDecode(response.body);
      final message = responseBody['message'] ?? 'Unexpected error';

      return {'status': response.statusCode, 'message': message};
    } catch (e) {
      print("âŒ Exception during registration: $e");
      return {'status': 500, 'message': 'Error during registration: $e'};
    }
  }

  static Future<Map<String, dynamic>> fetchTowageCertificateById(int id) async {
    final url = Uri.parse('$baseUrl/AdminDashboard/GetTowageById/$id');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception(
          "Failed to fetch towage certificate: ${response.statusCode} â†’ ${response.body}",
        );
      }
    } catch (e) {
      throw Exception("API error: $e");
    }
  }

  static Future<Map<String, dynamic>> getLoadoutById(int id) async {
    final url = Uri.parse('$baseUrl/AdminDashboard/GetLoadoutById/$id');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception(
          "Failed to fetch towage certificate: ${response.statusCode} â†’ ${response.body}",
        );
      }
    } catch (e) {
      throw Exception("API error: $e");
    }
  }

  static Future<Map<String, dynamic>> fetchSeafasteningCertificateById(
    int id,
  ) async {
    final url = Uri.parse('$baseUrl/AdminDashboard/GetSeaFasteningById/$id');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception(
          "Failed to fetch seafastening  certificate: ${response.statusCode} â†’ ${response.body}",
        );
      }
    } catch (e) {
      throw Exception("API error: $e");
    }
  }

  static Future<List<SurveyJob>> fetchSurveyJobsByType({
    required String surveyType,
    required bool isAdmin,
    required int userId,
    String? ihmCompletionFilter,
    String? jobCompletionFilter,
  }) async {
    final moduleType = surveyType == 'IHM Survey' ? 'IhmSurvey' : 'ExSurvey';

    final queryParams = <String, String>{'moduleType': moduleType};

    if (!isAdmin) {
      queryParams['assignedSurveyorUserId'] = userId.toString();
    }

    if (surveyType == 'IHM Survey' &&
        ihmCompletionFilter != null &&
        ihmCompletionFilter.trim().isNotEmpty) {
      queryParams['ihmCompletionFilter'] = ihmCompletionFilter.trim();
    }

    if (surveyType != 'IHM Survey' &&
        jobCompletionFilter != null &&
        jobCompletionFilter.trim().isNotEmpty) {
      queryParams['jobCompletionFilter'] = jobCompletionFilter.trim();
    }

    final uri = Uri.parse(
      '${AppConfig.baseUrl}survey/jobs',
    ).replace(queryParameters: queryParams);

    final response = await http.get(uri, headers: await _authHeaders());

    if (response.statusCode != 200) {
      throw Exception(response.body);
    }

    final List data = jsonDecode(response.body);
    return data.map((e) => SurveyJob.fromJson(e)).toList();
  }

  static Future<void> updateSurveyDate({
    required int surveyJobId,
    required DateTime surveyDate,
  }) async {
    final url = Uri.parse('$baseUrl/survey/jobs/$surveyJobId/survey-date');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json', ...await _authHeaders()},
      body: jsonEncode({'surveyDate': surveyDate.toIso8601String()}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        "Failed to update survey date (${response.statusCode}): ${response.body}",
      );
    }
  }

  static Future<void> updateSurveyJobStatus({
    required int surveyJobId,
    required String status,
  }) async {
    final url = Uri.parse('$baseUrl/survey/jobs/$surveyJobId/status');

    final response = await http.post(
      url,
      headers: await _authHeaders(json: true),
      body: jsonEncode({'status': status}),
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to update survey status: ${response.body}");
    }
  }

  static Future<void> closeSurveyJob(int surveyJobId) async {
    await updateSurveyJobStatus(surveyJobId: surveyJobId, status: 'Closed');
  }

  Future<void> fetchAndSaveSeafasteningCertificatesFromApi() async {
    final response = await http.get(
      Uri.parse('$baseUrl/Seafastening/create-seafastening'),
    );
    if (response.statusCode == 200) {
      List<dynamic> certificates = jsonDecode(response.body);
      for (var cert in certificates) {
        final model = SeaFasteningCertificate.fromJson(cert);
        await insertSeafasteningCertificate(model, markSynced: true);
      }
    }
  }

  Future<void> insertSeafasteningCertificate(
    SeaFasteningCertificate cert, {
    bool markSynced = false,
  }) async {
    final db = await DatabaseHelper.instance.database; // âœ… Correct usage
    await db.insert(
      'seafastening_certificate',
      cert.toMap()..['synced'] = markSynced ? 1 : 0,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> syncSeafasteningCert(SeaFasteningCertificate cert) async {
    final dbHelper = DatabaseHelper.instance;

    try {
      // âœ… Step 1: Ensure recommendations and cargo details are loaded (or default to empty)
      if (cert.recommendations == null || cert.recommendations!.isEmpty) {
        cert.recommendations = await dbHelper.getSeafasteningRecommendations(
          cert.id!,
        );
      }
      cert.recommendations ??= [];

      if (cert.cargoDetails == null || cert.cargoDetails!.isEmpty) {
        cert.cargoDetails = await dbHelper.getCargoDetails(cert.id!);
      }
      cert.cargoDetails ??= [];

      // âœ… Optional debug
      print("ðŸš€ Syncing SeaFasteningCertificate:");
      print("ðŸ“¦ Recommendations count: ${cert.recommendations?.length}");
      print("ðŸ“¦ CargoDetails count: ${cert.cargoDetails?.length}");

      // âœ… Convert to JSON and sync
      final json = cert.toJson();

      final response = await http.post(
        Uri.parse('$baseUrl/SeaFastening/create-seafastening'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(json),
      );

      print("âœ… Status: ${response.statusCode}");
      print("ðŸ“¬ Body: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        await dbHelper.markSeaFasteningCertificateAsSynced(cert.id!);
        print("âœ… Certificate synced successfully");
      } else {
        print("âŒ Failed to sync certificate");
      }
    } catch (e) {
      print("ðŸ”¥ Exception during sync: $e");
    }
  }

  static Future<List<SeaFasteningCertificate>>
  fetchAllSeafasteningCertificates() async {
    final url = Uri.parse('$baseUrl/AdminDashboard/GetCertificates');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);

        // Filter SeaFastening only
        final filtered = jsonList
            .where((e) => e['type']?.toString().toLowerCase() == 'seafastening')
            .toList();

        return filtered
            .map((e) => SeaFasteningCertificate.fromJson(e))
            .toList();
      } else {
        throw Exception("Failed to fetch certificates: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("API error: $e");
    }
  }

  static Future<String> submitTowageCertificate(
    Map<String, dynamic> data,
  ) async {
    final url = Uri.parse('$baseUrl/Certificate/create');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['message'];
    } else {
      throw Exception('Failed to submit certificate: ${response.body}');
    }
  }

  static Future<String> submitSeafasteningCertificate(
    Map<String, dynamic> certJson,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/Seafastening/create-seafastening'),
      headers: {'Content-Type': 'application/json'},

      body: jsonEncode(certJson),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return response.body;
    } else {
      throw Exception("Server Error: ${response.statusCode}\n${response.body}");
    }
  }

  static Future<String> submitLoadoutCertificate(
    Map<String, dynamic> certJson,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/LoadOut/create-Loadout'),
      headers: {'Content-Type': 'application/json'},

      body: jsonEncode(certJson),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return response.body;
    } else {
      throw Exception("Server Error: ${response.statusCode}\n${response.body}");
    }
  }

  static Future<List<Map<String, dynamic>>>
  fetchTowageCertificatesFromServer() async {
    final response = await http.get(
      Uri.parse('$baseUrl/AdminDashboard/GetCertificates'),
    );

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);

      // Filter only Towage certificates (if needed)
      final filtered = jsonList
          .where((e) => e['type']?.toString().toLowerCase() == 'towage')
          .toList();

      return List<Map<String, dynamic>>.from(filtered);
    } else {
      throw Exception('Failed to fetch Towage certificates');
    }
  }

  static Future<List<Map<String, dynamic>>>
  fetchAllLoadoutCertificates() async {
    final response = await http.get(
      Uri.parse('$baseUrl/AdminDashboard/GetCertificates'),
    );

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);

      // Filter only Loadout certificates
      final filtered = jsonList
          .where((e) => e['type']?.toString().toLowerCase() == 'loadout')
          .toList();

      return List<Map<String, dynamic>>.from(filtered);
    } else {
      throw Exception('Failed to fetch Loadout certificates');
    }
  }

  static Future<String> changePassword({
    required int UserId,
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    print("ðŸ“¤ Hitting ChangePassword API...");
    print(
      "Payload: userId=$UserId, current=$currentPassword, new=$newPassword",
    );

    final url = Uri.parse('$baseUrl/User/ChangePassword');
    print("ðŸ“¤ Hitting ChangePassword API...");
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'UserId': UserId,
        'currentPassword': currentPassword,
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      }),
    );

    print("ðŸ”µ Status: ${response.statusCode}");
    print("ðŸŸ¡ Body: ${response.body}");

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return data['message'];
    } else {
      throw Exception(data['message'] ?? 'Failed to change password');
    }
  }

  static Future<Map<String, dynamic>> getProfile(int userId) async {
    final url = Uri.parse('$baseUrl/User/GetProfile/$userId');
    final response = await http.get(url);

    print("ðŸ”µ Status Code: ${response.statusCode}");
    print("ðŸŸ¡ Body: ${response.body}");

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load profile: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> data,
  ) async {
    final url = Uri.parse('$baseUrl/User/UpdateProfile');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );

    final result = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return result;
    } else {
      throw Exception(result['message'] ?? 'Failed to update profile');
    }
  }

  // âœ… Send OTP
  static Future<Map<String, dynamic>> SendOtp(String email) async {
    final url = Uri.parse('$baseUrl/User/send-otp');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim()}),
      );

      return _safeJsonMessage(
        response,
        fallbackMessage: response.statusCode == 400
            ? 'Unable to send OTP. Please check the email address.'
            : _genericOtpError,
      );
    } catch (_) {
      return {'status': 503, 'message': _genericOtpError};
    }
  }

  // âœ… Verify OTP
  static Future<Map<String, dynamic>> VerifyOtp(
    String email,
    String otp,
  ) async {
    final url = Uri.parse('$baseUrl/User/verify-otp');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'otp': otp}),
      );

      final parsed = _safeJsonMessage(
        response,
        fallbackMessage: 'OTP verification failed. Please try again.',
      );
      return {
        ...parsed,
        if (parsed['verificationToken'] != null)
          'verificationToken': parsed['verificationToken'].toString(),
      };
    } catch (e) {
      return {
        'status': 503,
        'message': 'OTP verification failed. Please try again.',
      };
    }
  }

  // âœ… Register
  static Future<Map<String, dynamic>> Register(
    String fullName,
    String email,
    String password,
    String confirmPassword,
    String role, {
    required int projectId,
    required int roleId,
    String? otpVerificationToken,
  }) async {
    final url = Uri.parse('$baseUrl/User/register');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fullName': fullName,
          'email': email,
          'password': password,
          'confirmPassword': confirmPassword,
          'role': role,
          'projectId': projectId,
          'roleId': roleId,
          'otpVerificationToken': otpVerificationToken,
        }),
      );

      return _safeJsonMessage(
        response,
        fallbackMessage: 'Registration failed. Please try again later.',
      );
    } catch (e) {
      return {
        'status': 503,
        'message': 'Registration failed. Please try again later.',
      };
    }
  }

  // Send OTP
  static Future<Map<String, dynamic>> sendForgotPasswordOtp(
    String email,
  ) async {
    final url = Uri.parse('$baseUrl/User/ForgotPassword');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      final body = jsonDecode(response.body);
      return {'message': body['message']?.toString() ?? 'Unexpected error'};
    } catch (e) {
      return {'message': 'Error sending OTP: $e'};
    }
  }

  // Verify OTP & reset password
  static Future<Map<String, dynamic>> verifyForgotPasswordOtp(
    String email,
    String otp,
    String newPassword,
  ) async {
    final url = Uri.parse('$baseUrl/User/ResetPassword');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'otp': otp,
          'newPassword': newPassword,
        }),
      );
      final body = jsonDecode(response.body);
      return {'message': body['message']?.toString() ?? 'Unexpected error'};
    } catch (e) {
      return {'message': 'Error verifying OTP: $e'};
    }
  }

  // static Future<List<dynamic>> getAllUsers() async {
  //   final response = await http.get(
  //     Uri.parse('$baseUrl/AdminDashboard/GetAll'),
  //   );

  //   if (response.statusCode == 200) {
  //     return jsonDecode(response.body) as List<dynamic>;
  //   } else {
  //     throw Exception('Failed to load users');
  //   }
  // }

  static Future<Map<String, String>> _authHeaders({bool json = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    return {
      if (json) 'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<bool> deleteUser(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/User/delete-user/$id'),
      headers: await _authHeaders(),
    );

    if (response.statusCode == 200) {
      final message = response.body; // plain string
      print("âœ… Message: $message");
      return true;
    } else {
      throw Exception('Failed to delete user: ${response.body}');
    }
  }

  static Future<bool> saveUser(Map<String, dynamic> user) async {
    final id = int.tryParse((user['id'] ?? user['Id'] ?? 0).toString()) ?? 0;
    final bool isUpdate = id > 0;
    final payload = <String, dynamic>{
      'id': id,
      'fullName': user['fullName'] ?? user['FullName'],
      'email': user['email'] ?? user['Email'],
      'role': user['role'] ?? user['Role'],
      'projectId': user['projectId'] ?? user['ProjectId'],
      'projectName': user['projectName'] ?? user['ProjectName'],
      'roleId': user['roleId'] ?? user['RoleId'],
      'roleName': user['roleName'] ?? user['RoleName'],
      'requestedRole': user['requestedRole'] ?? user['RequestedRole'],
      'replaceProjectAccesses':
          user['replaceProjectAccesses'] ??
          user['ReplaceProjectAccesses'] ??
          false,
      'projectAccesses':
          user['projectAccesses'] ?? user['ProjectAccesses'] ?? [],
      if ((user['password'] ?? user['Password']) != null)
        'password': user['password'] ?? user['Password'],
    };

    final url = Uri.parse('$baseUrl/AdminDashboard/Save');
    final response = await (isUpdate
        ? http.put(
            url,
            headers: await _authHeaders(json: true),
            body: jsonEncode(payload),
          )
        : http.post(
            url,
            headers: await _authHeaders(json: true),
            body: jsonEncode(payload),
          ));

    debugPrint('User save status: ${response.statusCode}');
    debugPrint('User save body: ${response.body}');

    if (response.statusCode == 200) {
      final res = jsonDecode(response.body);
      return res is Map && res['message'] != null;
    }

    var message = response.body.trim();
    try {
      final decoded = jsonDecode(message);
      if (decoded is Map<String, dynamic>) {
        message = decoded['message']?.toString() ?? message;
      }
    } catch (_) {
      // Preserve plain-text API response.
    }
    throw Exception(message.isEmpty ? 'Failed to save user' : message);
  }

  static Future<List<RoleOption>> fetchPublicRoles(int projectId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/User/projects/$projectId/roles'),
    );

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList
          .map((e) => RoleOption.fromJson(e as Map<String, dynamic>))
          .where((role) => role.id > 0 && role.roleName.isNotEmpty)
          .toList();
    }

    throw Exception("Failed to load roles: ${response.body}");
  }

  static Future<List<PendingUser>> fetchPendingUsers() async {
    final response = await http.get(
      Uri.parse('$baseUrl/User/pending-users'),
      headers: await _authHeaders(),
    );

    print("ðŸ” Status Code: ${response.statusCode}");
    print("ðŸ“¦ Body: ${response.body}");

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((e) => PendingUser.fromJson(e)).toList();
    } else {
      throw Exception("Failed to load pending users");
    }
  }

  static Future<void> assignSurveyJobSurveyors({
    required int surveyJobId,
    int? primarySurveyorUserId,
    int? secondarySurveyorUserId,
    required int assignedByUserId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/survey/jobs/$surveyJobId/assign-surveyors'),
      headers: await _authHeaders(json: true),
      body: jsonEncode({
        'primarySurveyorUserId': primarySurveyorUserId,
        'secondarySurveyorUserId': secondarySurveyorUserId,
        'assignedByUserId': assignedByUserId,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to assign surveyors: ${response.body}');
    }
  }

  static Future<List<ProjectOption>> fetchProjects() async {
    final response = await http.get(
      Uri.parse('$baseUrl/User/projects'),
      headers: await _authHeaders(),
    );

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList
          .map((e) => ProjectOption.fromJson(e as Map<String, dynamic>))
          .where((project) => project.id > 0)
          .toList();
    }

    throw Exception("Failed to load projects: ${response.body}");
  }

  static Future<List<ProjectOption>> fetchManageableProjects() async {
    final response = await http.get(
      Uri.parse('$baseUrl/AdminDashboard/manageable-projects'),
      headers: await _authHeaders(),
    );

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList
          .map((e) => ProjectOption.fromJson(e as Map<String, dynamic>))
          .where((project) => project.id > 0)
          .toList();
    }

    throw Exception("Failed to load manageable projects: ${response.body}");
  }

  static Future<List<RoleOption>> fetchManagedProjectRoles(
    int projectId,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/AdminDashboard/projects/$projectId/roles'),
      headers: await _authHeaders(),
    );

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList
          .map((e) => RoleOption.fromJson(e as Map<String, dynamic>))
          .where((role) => role.id > 0 && role.roleName.isNotEmpty)
          .toList();
    }

    throw Exception("Failed to load project roles: ${response.body}");
  }

  static Future<void> updateSurveyJobAssignedManager({
    required int surveyJobId,
    int? assignedManagerId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/survey/jobs/$surveyJobId/assigned-manager'),
      headers: await _authHeaders(json: true),
      body: jsonEncode({'assignedManagerId': assignedManagerId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update assigned manager: ${response.body}');
    }
  }

  // static Future<void> deleteSurveyJob(int jobId) async {
  //   final response = await http.delete(
  //     Uri.parse('$baseUrl/survey/jobs/$jobId'),
  //   );

  //   if (response.statusCode != 200 && response.statusCode != 204) {
  //     throw Exception('Failed to delete survey job: ${response.body}');
  //   }
  // }

  static Future<IhmCheckpoint> updateIhmCheckpointProcedure({
    required int checkpointId,
    required String procedureType,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/ihm-survey/checkpoints/$checkpointId/procedure'),
      headers: await _authHeaders(json: true),
      body: jsonEncode({'procedureType': procedureType}),
    );

    if (response.statusCode != 200) {
      throw Exception(response.body);
    }

    return IhmCheckpoint.fromJson(jsonDecode(response.body));
  }

  static Future<List<IhmArea>> fetchIhmAreasWithCheckpoints(int jobId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/ihm-survey/jobs/$jobId/areas-with-checkpoints'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load IHM areas: ${response.body}');
    }

    final List data = jsonDecode(response.body);

    return data
        .map((e) => IhmArea.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<SurveyJob> createIhmSurveyJob({
    required String jobNumber,
    required String clientName,
    required String projectName,
    required int vesselId,
    required String siteName,
    required String startDate,

    required String endDate,
    required int createdByUserId,
    int? assignedManagerId,
    String? auditPort,
    String? auditAddress,
  }) async {
    final url = Uri.parse('$baseUrl/survey/jobs');

    final response = await http.post(
      url,
      headers: await _authHeaders(json: true),
      body: jsonEncode({
        'moduleType': 2,
        'jobNumber': jobNumber,
        'clientName': clientName,
        'projectName': projectName,
        'vesselId': vesselId,
        'siteName': siteName,
        'startDate': startDate,
        'endDate': endDate,
        'createdByUserId': createdByUserId,
        'assignedManagerId': assignedManagerId,
        'auditPort': auditPort,
        'auditAddress': auditAddress,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to create IHM job: ${response.body}');
    }

    return SurveyJob.fromJson(jsonDecode(response.body));
  }

  static Future<String> uploadIhmExcel({
    required int jobId,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    final url = Uri.parse('$baseUrl/ihm-survey/jobs/$jobId/import-excel');

    final request = http.MultipartRequest('POST', url);
    request.headers.addAll(await _authHeaders());

    request.files.add(
      http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
    );

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode == 200 || response.statusCode == 201) {
      return body;
    }

    throw Exception('Excel upload failed: ${response.statusCode} - $body');
  }

  static Future<Uint8List> downloadVscpChecklist(int jobId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/ihm-survey/jobs/$jobId/vscp-checklist'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to download VSCP Checklist: ${response.body}');
    }

    return response.bodyBytes;
  }

  // static Future<String> uploadIhmLayout({
  //   required int jobId,
  //   required Uint8List fileBytes,
  //   required String fileName,
  // }) async {
  //   final url = Uri.parse('$baseUrl/ihm-survey/jobs/$jobId/upload-layout');

  //   final request = http.MultipartRequest('POST', url);

  //   request.files.add(
  //     http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
  //   );

  //   final response = await request.send();
  //   final body = await response.stream.bytesToString();

  //   if (response.statusCode == 200 || response.statusCode == 201) {
  //     return body;
  //   }

  //   throw Exception('Layout upload failed: ${response.statusCode} - $body');
  // }

  static Future<String> uploadIhmImage({
    required int jobId,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    final url = Uri.parse('$baseUrl/ihm-survey/jobs/$jobId/upload-image');

    final request = http.MultipartRequest('POST', url);
    request.headers.addAll(await _authHeaders());

    request.files.add(
      http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
    );

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode == 200 || response.statusCode == 201) {
      return body;
    }

    throw Exception('Image upload failed: ${response.statusCode} - $body');
  }

  static Future<IhmCheckpoint> updateIhmCheckpointDetails({
    required IhmCheckpoint checkpoint,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('userId');
    final payload = _checkpointUpdatePayload(checkpoint);
    if (userId != null && userId > 0) {
      payload['updatedByUserId'] = userId;
    }

    debugPrint(
      '[IHM] save checkpoint ${checkpoint.id} payload: ${jsonEncode(payload)}',
    );

    final response = await http.put(
      Uri.parse('$baseUrl/ihm-survey/checkpoints/${checkpoint.id}/details'),
      headers: await _authHeaders(json: true),
      body: jsonEncode(payload),
    );

    debugPrint(
      '[IHM] save checkpoint ${checkpoint.id} response '
      '${response.statusCode}: ${response.body}',
    );

    if (response.statusCode == 409) {
      throw Exception(
        'Another surveyor submitted different data for this checkpoint. '
        'Primary surveyor review is required.',
      );
    }

    if (response.statusCode != 200) {
      throw Exception(response.body);
    }

    return IhmCheckpoint.fromJson(jsonDecode(response.body));
  }

  static Map<String, dynamic> _checkpointUpdatePayload(
    IhmCheckpoint checkpoint,
  ) => {
    'sampleNo': checkpoint.sampleNo,
    'description': checkpoint.description ?? '',
    'tableType': checkpoint.tableType,
    'location': checkpoint.location,
    'equipmentName': checkpoint.equipmentName,
    'component': checkpoint.component,
    'materialCategory': checkpoint.materialCategory,
    'hazardousMaterial': checkpoint.hazardousMaterial,
    'quantityUnitKg': checkpoint.quantityUnitKg,
    'quantityNo': checkpoint.quantityNo,
    'quantityTotalKg': checkpoint.quantityTotalKg,
    'manufacturerBrandName': checkpoint.manufacturerBrandName,
    'documentAnalysisResult': checkpoint.documentAnalysisResult,
    'samplingCheck': checkpoint.samplingCheck,
    'visualCheck': checkpoint.visualCheck,
    'checkResult': checkpoint.checkResult,
    'result': _checkpointResultValue(checkpoint.result),
    'isPchm': checkpoint.isPchm,
    'remarks': checkpoint.remarks,
    'locationRemarks': checkpoint.locationRemarks,
  };

  static int _checkpointResultValue(String result) {
    switch (result.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]'), '')) {
      case 'present':
        return 2;
      case 'notpresent':
        return 3;
      case 'notapplicable':
        return 4;
      case 'samplerequired':
        return 5;
      default:
        return 1;
    }
  }

  // static String fileUrl(String path) {
  //   if (path.startsWith('http')) return path;

  //   final apiRoot = baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
  //   final cleanPath = path.startsWith('/') ? path : '/$path';

  //   return '$apiRoot$cleanPath';
  // }
  static Future<void> uploadAreaLayout({
    required int jobId,
    required int areaId,
    required PlatformFile file,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/ihm-survey/jobs/$jobId/areas/$areaId/layout'),
    );
    request.headers.addAll(await _authHeaders());

    if (file.bytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes('file', file.bytes!, filename: file.name),
      );
    } else if (file.path != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path!,
          filename: file.name,
        ),
      );
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(response.body);
    }
  }

  static Future<String> fetchIhmLayoutPath({
    required int jobId,
    required int areaId,
  }) async {
    final res = await http.get(
      Uri.parse('$baseUrl/ihm-survey/jobs/$jobId/areas/$areaId/layout'),
      headers: await _authHeaders(),
    );

    if (res.statusCode != 200) {
      throw Exception(res.body);
    }

    return jsonDecode(res.body)['filePath'].toString();
  }

  static Future<List<IhmLayoutImage>> fetchIhmLayouts({
    required int jobId,
    required int areaId,
  }) async {
    final res = await http.get(
      Uri.parse('$baseUrl/ihm-survey/jobs/$jobId/areas/$areaId/layouts'),
      headers: await _authHeaders(),
    );
    if (res.statusCode != 200) throw Exception(res.body);
    final List data = jsonDecode(res.body);
    return data.map((x) => IhmLayoutImage.fromJson(x)).toList();
  }

  static Future<void> deleteIhmMarker(int markerId) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/ihm-survey/markers/$markerId'),
      headers: await _authHeaders(),
    );

    if (res.statusCode != 200) {
      throw Exception(res.body);
    }
  }

  static Future<List<IhmMarker>> fetchIhmMarkers(int jobId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/ihm-survey/jobs/$jobId/markers'),
      headers: await _authHeaders(),
    );

    if (res.statusCode != 200) {
      throw Exception(res.body);
    }

    final List data = jsonDecode(res.body);
    return data.map((x) => IhmMarker.fromJson(x)).toList();
  }

  static Future<IhmMarker> saveIhmMarker({
    required IhmCheckpoint checkpoint,
    required String imagePath,
    required double xPercent,
    required double yPercent,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/ihm-survey/markers'),
      headers: await _authHeaders(json: true),
      body: jsonEncode({
        'surveyJobId': checkpoint.surveyJobId,
        'ihmAreaId': checkpoint.ihmAreaId,
        'ihmCheckpointId': checkpoint.id,
        'imagePath': imagePath,
        'xPercent': xPercent,
        'yPercent': yPercent,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception(res.body);
    }

    return IhmMarker.fromJson(jsonDecode(res.body));
  }

  static Future<List<IhmSamplingPhoto>> fetchCheckpointPhotos(
    int checkpointId,
  ) async {
    final res = await http.get(
      Uri.parse('$baseUrl/ihm-survey/checkpoints/$checkpointId/photos'),
      headers: await _authHeaders(),
    );

    if (res.statusCode != 200) {
      throw Exception(res.body);
    }

    final List data = jsonDecode(res.body);
    return data.map((x) => IhmSamplingPhoto.fromJson(x)).toList();
  }

  static Future<IhmSamplingPhoto> uploadCheckpointPhoto({
    required IhmCheckpoint checkpoint,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    final url = Uri.parse(
      '$baseUrl/ihm-survey/jobs/${checkpoint.surveyJobId}/checkpoints/${checkpoint.id}/photos',
    );

    final request = http.MultipartRequest('POST', url);
    request.headers.addAll(await _authHeaders());
    request.files.add(
      http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw Exception(response.body);
    }

    return IhmSamplingPhoto.fromJson(jsonDecode(response.body));
  }

  static Future<void> deleteCheckpointPhoto(int photoId) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/ihm-survey/sampling-photos/$photoId'),
      headers: await _authHeaders(),
    );

    if (res.statusCode != 200) {
      throw Exception(res.body);
    }
  }

  static Future<SurveyJob> createExSurveyJob({
    required String jobNumber,
    required String clientName,
    required String projectName,
    required int vesselId,
    required String siteName,
    required String startDate,
    required String endDate,
    required int createdByUserId,
    int? assignedManagerId,
  }) async {
    final url = Uri.parse('$baseUrl/survey/jobs');

    final response = await http.post(
      url,
      headers: await _authHeaders(json: true),
      body: jsonEncode({
        'moduleType': 1,
        'jobNumber': jobNumber,
        'clientName': clientName,
        'projectName': projectName,
        'vesselId': vesselId,
        'siteName': siteName,
        'startDate': startDate,
        'endDate': endDate,
        'createdByUserId': createdByUserId,
        'assignedManagerId': assignedManagerId,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to create Ex-Survey job: ${response.body}');
    }

    return SurveyJob.fromJson(jsonDecode(response.body));
  }

  static Future<void> approveUser(int id, {required int projectId}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/User/approve-user/$id'),
      headers: await _authHeaders(json: true),
      body: jsonEncode({'projectId': projectId}),
    );
    if (res.statusCode != 200) throw Exception("Approve failed: ${res.body}");
  }

  static Future<void> rejectUser(int id) async {
    final res = await http.post(
      Uri.parse('$baseUrl/User/reject-user/$id'),
      headers: await _authHeaders(),
    );
    if (res.statusCode != 200) throw Exception("Delete failed: ${res.body}");
  }

  static Future<PagedCertificateResult> fetchCertificatesPaged({
    required String type,
    String search = '',
    int page = 1,
    int pageSize = 10,
  }) async {
    final url = Uri.parse(
      '$baseUrl/AdminDashboard/GetCertificates?type=$type&search=$search&page=$page&pageSize=$pageSize',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final jsonBody = jsonDecode(response.body);
      final List<dynamic> list = jsonBody['data'] ?? [];
      final int totalCount = jsonBody['totalCount'] ?? list.length;

      final certificates = list.map((e) => CertificateDto.fromJson(e)).toList();

      return PagedCertificateResult(data: certificates, totalCount: totalCount);
    } else {
      throw Exception("Failed to load certificates: ${response.body}");
    }
  }
}

class SurveyorOption {
  final int id;
  final String name;
  final String email;
  final String role;

  SurveyorOption({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  String get displayName {
    if (email.trim().isEmpty) return name;
    return '$name - $email';
  }
}
