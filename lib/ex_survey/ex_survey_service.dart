import 'dart:convert';
import 'dart:typed_data';

import 'package:Auras/app_config.dart';
import 'package:Auras/ex_survey/ex_survey_models.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ExSurveyService {
  static String get _baseUrl =>
      AppConfig.baseUrl.replaceAll(RegExp(r'/$'), '');

  static String publicUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final root = _baseUrl.replaceFirst(RegExp(r'/api$'), '');
    return '$root${path.startsWith('/') ? path : '/$path'}';
  }

  static Future<Map<String, String>> _headers({bool json = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    return {
      if (json) 'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<ExSurveySummary> fetchSummary(int jobId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/ex-survey/jobs/$jobId/summary'),
      headers: await _headers(),
    );
    _ensureSuccess(response);
    return ExSurveySummary.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  static Future<List<ExEquipment>> fetchEquipment(int jobId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/ex-survey/jobs/$jobId/equipment'),
      headers: await _headers(),
    );
    _ensureSuccess(response);
    return (jsonDecode(response.body) as List)
        .map((item) => ExEquipment.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<ExEquipment> createEquipment(
    int jobId,
    Map<String, dynamic> payload,
  ) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/ex-survey/jobs/$jobId/equipment'),
      headers: await _headers(json: true),
      body: jsonEncode(payload),
    );
    _ensureSuccess(response);
    return ExEquipment.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  static Future<List<ExChecklistQuestion>> fetchQuestions(
    String inspectionType,
  ) async {
    final uri = Uri.parse('$_baseUrl/ex-survey/checklist/questions').replace(
      queryParameters: {'inspectionType': inspectionType},
    );
    final response = await http.get(uri, headers: await _headers());
    _ensureSuccess(response);
    return (jsonDecode(response.body) as List)
        .map(
          (item) =>
              ExChecklistQuestion.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  static Future<List<ExChecklistAnswer>> fetchAnswers(
    int equipmentId,
    String inspectionType,
  ) async {
    final uri = Uri.parse(
      '$_baseUrl/ex-survey/equipment/$equipmentId/answers',
    ).replace(queryParameters: {'inspectionType': inspectionType});
    final response = await http.get(uri, headers: await _headers());
    _ensureSuccess(response);
    return (jsonDecode(response.body) as List)
        .map((item) => ExChecklistAnswer.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<void> saveAnswer({
    required int equipmentId,
    required int questionId,
    required String result,
    String? comment,
  }) async {
    const resultValues = {'Pass': 1, 'Fail': 2, 'NA': 3};
    final prefs = await SharedPreferences.getInstance();
    final response = await http.post(
      Uri.parse('$_baseUrl/ex-survey/checklist/answers'),
      headers: await _headers(json: true),
      body: jsonEncode({
        'exEquipmentId': equipmentId,
        'exChecklistQuestionId': questionId,
        'result': resultValues[result],
        'comment': comment,
        'answeredByUserId': prefs.getInt('userId') ?? 0,
      }),
    );
    _ensureSuccess(response);
  }

  static Future<List<ExDefect>> fetchDefects(int jobId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/ex-survey/jobs/$jobId/defects'),
      headers: await _headers(),
    );
    _ensureSuccess(response);
    return (jsonDecode(response.body) as List)
        .map((item) => ExDefect.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<void> createDefect({
    required int equipmentId,
    required String description,
    required String severity,
    String? defectNumber,
    String? recommendation,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final response = await http.post(
      Uri.parse('$_baseUrl/ex-survey/defects'),
      headers: await _headers(json: true),
      body: jsonEncode({
        'exEquipmentId': equipmentId,
        'defectNumber': defectNumber,
        'description': description,
        'severity': severity,
        'recommendation': recommendation,
        'createdByUserId': prefs.getInt('userId') ?? 0,
      }),
    );
    _ensureSuccess(response);
  }

  static Future<void> updateDefectStatus(int defectId, String status) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/ex-survey/defects/$defectId/status'),
      headers: await _headers(json: true),
      body: jsonEncode({'status': status}),
    );
    _ensureSuccess(response);
  }

  static Future<List<ExSurveyPhoto>> fetchPhotos(
    int jobId, {
    int? equipmentId,
  }) async {
    final uri = Uri.parse('$_baseUrl/ex-survey/jobs/$jobId/photos').replace(
      queryParameters: {
        if (equipmentId != null) 'equipmentId': equipmentId.toString(),
      },
    );
    final response = await http.get(uri, headers: await _headers());
    _ensureSuccess(response);
    return (jsonDecode(response.body) as List)
        .map((item) => ExSurveyPhoto.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<void> uploadPhoto({
    required int jobId,
    required int equipmentId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(
        '$_baseUrl/ex-survey/jobs/$jobId/equipment/$equipmentId/photos',
      ),
    );
    request.headers.addAll(await _headers());
    request.fields['uploadedByUserId'] =
        (prefs.getInt('userId') ?? 0).toString();
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: fileName),
    );
    final response = await http.Response.fromStream(await request.send());
    _ensureSuccess(response);
  }

  static Future<List<ExSurveyDocument>> fetchDocuments(int jobId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/ex-survey/jobs/$jobId/documents'),
      headers: await _headers(),
    );
    _ensureSuccess(response);
    return (jsonDecode(response.body) as List)
        .map((item) => ExSurveyDocument.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<void> uploadDocument({
    required int jobId,
    required String documentType,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/ex-survey/jobs/$jobId/documents'),
    );
    request.headers.addAll(await _headers());
    request.fields['documentType'] = documentType;
    request.fields['uploadedByUserId'] =
        (prefs.getInt('userId') ?? 0).toString();
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: fileName),
    );
    final response = await http.Response.fromStream(await request.send());
    _ensureSuccess(response);
  }

  static Future<void> submitForQc(int jobId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/ex-survey/jobs/$jobId/submit'),
      headers: await _headers(),
    );
    _ensureSuccess(response);
  }

  static Future<void> review(int jobId, String status) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/ex-survey/jobs/$jobId/review'),
      headers: await _headers(json: true),
      body: jsonEncode({'status': status}),
    );
    _ensureSuccess(response);
  }

  static Future<Uint8List> generateReport(int jobId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/ex-survey/jobs/$jobId/report'),
      headers: await _headers(),
    );
    _ensureSuccess(response);
    return response.bodyBytes;
  }

  static void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    var message = response.body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['message'] != null) {
        message = decoded['message'].toString();
      }
    } catch (_) {}
    throw Exception(message.replaceFirst('Exception: ', ''));
  }
}
