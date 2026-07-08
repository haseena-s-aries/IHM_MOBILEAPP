import 'dart:convert';
import 'dart:typed_data';

import 'package:Auras/Db/database_helper.dart';
import 'package:Auras/ex_survey/ex_file_storage_stub.dart'
    if (dart.library.io) 'package:Auras/ex_survey/ex_file_storage_io.dart';
import 'package:Auras/ex_survey/ex_survey_models.dart';
import 'package:Auras/ex_survey/ex_survey_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

class ExSurveyOfflineService {
  static bool _syncing = false;

  static String publicUrl(String path) => ExSurveyService.publicUrl(path);

  static Future<bool> get isOnline async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  // static Future<ExSurveySummary> fetchSummary(int jobId) async {
  //   if (await isOnline) {
  //     try {
  //       await syncPendingExData();
  //       final summary = await ExSurveyService.fetchSummary(jobId);
  //       await Future.wait([
  //         fetchEquipment(jobId),
  //         fetchDefects(jobId),
  //         fetchPhotos(jobId),
  //         fetchDocuments(jobId),
  //       ]);
  //       return summary;
  //     } catch (_) {}
  //   }

  //   final equipment = await getLocalEquipment(jobId);
  //   final defects = await getLocalDefects(jobId);
  //   final photos = await getLocalPhotos(jobId);
  //   final answers = await _getLocalAnswersForJob(jobId);

  //   return ExSurveySummary(
  //     status: 'Offline',
  //     areaCount: equipment.map((x) => x.area).toSet().length,
  //     equipmentCount: equipment.length,
  //     answeredEquipmentCount: answers.map((x) => x.exEquipmentId).toSet().length,
  //     answerCount: answers.length,
  //     failedAnswerCount: answers.where((x) => x.result == 'Fail').length,
  //     openDefectCount: defects.where((x) => x.status == 'Open').length,
  //     photoCount: photos.length,
  //   );
  // }

  static Future<List<ExEquipment>> fetchEquipment(int jobId) async {
    if (await isOnline) {
      try {
        await syncPendingExData();
        final equipment = await ExSurveyService.fetchEquipment(jobId);
        await _cacheEquipment(jobId, equipment);
      } catch (_) {}
    }
    return getLocalEquipment(jobId);
  }

  static Future<ExEquipment> createEquipment(
    int jobId,
    Map<String, dynamic> payload,
  ) async {
    if (await isOnline) {
      try {
        final created = await ExSurveyService.createEquipment(jobId, payload);
        await _cacheEquipment(jobId, [created]);
        await syncPendingExData();
        return created;
      } catch (_) {}
    }

    final db = await DatabaseHelper.instance.database;
    final localId = _localId();
    final now = DateTime.now().toIso8601String();
    final values = {
      'id': localId,
      'serverId': null,
      'surveyJobId': jobId,
      'equipmentId': payload['equipmentId']?.toString() ?? '',
      'rfidTag': payload['rfidTag']?.toString(),
      'area': payload['area']?.toString() ?? 'Unassigned',
      'location': payload['location']?.toString(),
      'equipmentType': payload['equipmentType']?.toString(),
      'description': payload['description']?.toString(),
      'manufacturer': payload['manufacturer']?.toString(),
      'model': payload['model']?.toString(),
      'serialNumber': payload['serialNumber']?.toString(),
      'isActive': 1,
      'deleted': 0,
      'synced': 0,
      'updatedAt': now,
    };

    await db.insert('ex_equipment', values);
    await _enqueue(
      entityType: 'equipment',
      entityLocalId: localId,
      operation: 'create',
      payload: {'jobId': jobId, 'payload': payload},
    );
    await syncPendingExData();
    return _equipmentFromLocal(values);
  }

  static Future<List<ExChecklistQuestion>> fetchQuestions(
    String inspectionType,
  ) async {
    if (await isOnline) {
      try {
        final questions = await ExSurveyService.fetchQuestions(inspectionType);
        await _cacheQuestions(questions);
      } catch (_) {}
    }
    return getLocalQuestions(inspectionType);
  }

  static Future<List<ExChecklistAnswer>> fetchAnswers(
    int equipmentId,
    String inspectionType,
  ) async {
    if (await isOnline && equipmentId > 0) {
      try {
        await syncPendingExData();
        final answers = await ExSurveyService.fetchAnswers(
          equipmentId,
          inspectionType,
        );
        await _cacheAnswers(equipmentId, inspectionType, answers);
      } catch (_) {}
    }
    return getLocalAnswers(equipmentId, inspectionType);
  }

  static Future<void> saveAnswer({
    required int equipmentId,
    required int questionId,
    required String result,
    String? comment,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();
    final localId = await _answerLocalId(equipmentId, questionId);
    await db.insert('ex_checklist_answers', {
      'id': localId,
      'serverId': localId > 0 ? localId : null,
      'exEquipmentId': equipmentId,
      'exChecklistQuestionId': questionId,
      'inspectionType': await _questionType(questionId),
      'result': result,
      'comment': comment,
      'deleted': 0,
      'synced': 0,
      'updatedAt': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await _enqueue(
      entityType: 'answer',
      entityLocalId: localId,
      operation: 'upsert',
      payload: {'equipmentId': equipmentId, 'questionId': questionId},
    );
    await syncPendingExData();
  }

  static Future<List<ExDefect>> fetchDefects(int jobId) async {
    if (await isOnline) {
      try {
        await syncPendingExData();
        final defects = await ExSurveyService.fetchDefects(jobId);
        await _cacheDefects(jobId, defects);
      } catch (_) {}
    }
    return getLocalDefects(jobId);
  }

  static Future<void> createDefect({
    required int equipmentId,
    required String description,
    required String severity,
    String? defectNumber,
    String? recommendation,
  }) async {
    final equipment = await _localEquipmentById(equipmentId);
    final db = await DatabaseHelper.instance.database;
    final localId = _localId();
    final now = DateTime.now().toIso8601String();
    await db.insert('ex_defects', {
      'id': localId,
      'serverId': null,
      'surveyJobId': equipment.surveyJobId,
      'exEquipmentId': equipmentId,
      'equipmentCode': equipment.equipmentId,
      'defectNumber': defectNumber,
      'description': description,
      'severity': severity,
      'recommendation': recommendation,
      'status': 'Open',
      'deleted': 0,
      'synced': 0,
      'updatedAt': now,
    });

    await _enqueue(
      entityType: 'defect',
      entityLocalId: localId,
      operation: 'create',
      payload: {'localId': localId},
    );
    await syncPendingExData();
  }

  static Future<void> updateDefectStatus(int defectId, String status) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'ex_defects',
      {
        'status': status,
        'synced': 0,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [defectId],
    );
    await _enqueue(
      entityType: 'defectStatus',
      entityLocalId: defectId,
      operation: 'update',
      payload: {'localId': defectId, 'status': status},
    );
    await syncPendingExData();
  }

  static Future<List<ExSurveyPhoto>> fetchPhotos(
    int jobId, {
    int? equipmentId,
  }) async {
    if (await isOnline) {
      try {
        await syncPendingExData();
        final photos = await ExSurveyService.fetchPhotos(
          jobId,
          equipmentId: equipmentId,
        );
        await _cachePhotos(jobId, photos);
      } catch (_) {}
    }
    return getLocalPhotos(jobId, equipmentId: equipmentId);
  }

  static Future<void> uploadPhoto({
    required int jobId,
    required int equipmentId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (await isOnline && equipmentId > 0) {
      try {
        await ExSurveyService.uploadPhoto(
          jobId: jobId,
          equipmentId: equipmentId,
          bytes: bytes,
          fileName: fileName,
        );
        await fetchPhotos(jobId, equipmentId: equipmentId);
        await syncPendingExData();
        return;
      } catch (_) {}
    }

    final localPath = await writeExLocalFile(
      bytes,
      fileName,
      folder: 'ex_survey_photos',
    );
    final db = await DatabaseHelper.instance.database;
    final localId = _localId();
    await db.insert('ex_photos', {
      'id': localId,
      'serverId': null,
      'surveyJobId': jobId,
      'exEquipmentId': equipmentId,
      'originalFileName': fileName,
      'filePath': localPath,
      'localFilePath': localPath,
      'uploadedAt': DateTime.now().toIso8601String(),
      'deleted': 0,
      'synced': 0,
      'updatedAt': DateTime.now().toIso8601String(),
    });
    await _enqueue(
      entityType: 'photo',
      entityLocalId: localId,
      operation: 'upload',
      payload: {'localId': localId},
    );
    await syncPendingExData();
  }

  static Future<List<ExSurveyDocument>> fetchDocuments(int jobId) async {
    if (await isOnline) {
      try {
        await syncPendingExData();
        final documents = await ExSurveyService.fetchDocuments(jobId);
        await _cacheDocuments(jobId, documents);
      } catch (_) {}
    }
    return getLocalDocuments(jobId);
  }

  static Future<void> uploadDocument({
    required int jobId,
    required String documentType,
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (await isOnline) {
      try {
        await ExSurveyService.uploadDocument(
          jobId: jobId,
          documentType: documentType,
          bytes: bytes,
          fileName: fileName,
        );
        await fetchDocuments(jobId);
        await syncPendingExData();
        return;
      } catch (_) {}
    }

    final localPath = await writeExLocalFile(
      bytes,
      fileName,
      folder: 'ex_survey_documents',
    );
    final db = await DatabaseHelper.instance.database;
    final localId = _localId();
    await db.insert('ex_documents', {
      'id': localId,
      'serverId': null,
      'surveyJobId': jobId,
      'documentType': documentType,
      'originalFileName': fileName,
      'filePath': localPath,
      'localFilePath': localPath,
      'sizeBytes': bytes.length,
      'deleted': 0,
      'synced': 0,
      'updatedAt': DateTime.now().toIso8601String(),
    });
    await _enqueue(
      entityType: 'document',
      entityLocalId: localId,
      operation: 'upload',
      payload: {'localId': localId},
    );
    await syncPendingExData();
  }

  static Future<void> submitForQc(int jobId) async {
    if (!await isOnline) {
      await _enqueue(
        entityType: 'job',
        entityLocalId: jobId,
        operation: 'submit',
        payload: {'jobId': jobId},
      );
      return;
    }
    await syncPendingExData();
    await ExSurveyService.submitForQc(jobId);
  }

  static Future<void> review(int jobId, String status) async {
    if (!await isOnline) {
      await _enqueue(
        entityType: 'job',
        entityLocalId: jobId,
        operation: 'review',
        payload: {'jobId': jobId, 'status': status},
      );
      return;
    }
    await syncPendingExData();
    await ExSurveyService.review(jobId, status);
  }

  static Future<Uint8List> generateReport(int jobId) async {
    if (!await isOnline) {
      throw Exception(
        'Report generation needs internet. Sync pending data first.',
      );
    }
    await syncPendingExData();
    return ExSurveyService.generateReport(jobId);
  }

  static Future<void> syncPendingExData() async {
    if (kIsWeb) return;
    if (_syncing || !await isOnline) return;
    _syncing = true;
    final db = await DatabaseHelper.instance.database;

    try {
      final queue = await db.query(
        'ex_sync_queue',
        where: 'status IN (0, 2)',
        orderBy: 'id ASC',
      );
      for (final item in queue) {
        final queueId = _int(item['id']);
        try {
          await db.update(
            'ex_sync_queue',
            {'status': -1, 'updatedAt': DateTime.now().toIso8601String()},
            where: 'id = ?',
            whereArgs: [queueId],
          );
          await _syncQueueItem(db, item);
          await db.update(
            'ex_sync_queue',
            {
              'status': 1,
              'lastError': null,
              'updatedAt': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [queueId],
          );
        } catch (error) {
          await db.update(
            'ex_sync_queue',
            {
              'status': 2,
              'lastError': error.toString(),
              'retryCount': _int(item['retryCount']) + 1,
              'updatedAt': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [queueId],
          );
        }
      }
    } finally {
      _syncing = false;
    }
  }

  static Future<int> pendingSyncCount() async {
    if (kIsWeb) return 0;
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM ex_sync_queue WHERE status IN (0, 2, -1)',
    );
    return _int(rows.first['count']);
  }

  static Future<List<ExEquipment>> getLocalEquipment(int jobId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'ex_equipment',
      where: 'surveyJobId = ? AND deleted = 0',
      whereArgs: [jobId],
      orderBy: 'area ASC, equipmentId ASC',
    );
    return rows.map(_equipmentFromLocal).toList();
  }

  static Future<List<ExChecklistQuestion>> getLocalQuestions(
    String inspectionType,
  ) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'ex_checklist_questions',
      where: 'LOWER(inspectionType) = ?',
      whereArgs: [inspectionType.toLowerCase()],
      orderBy: 'sortOrder ASC, id ASC',
    );
    return rows.map(_questionFromLocal).toList();
  }

  static Future<List<ExChecklistAnswer>> getLocalAnswers(
    int equipmentId,
    String inspectionType,
  ) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'ex_checklist_answers',
      where: 'exEquipmentId = ? AND LOWER(inspectionType) = ? AND deleted = 0',
      whereArgs: [equipmentId, inspectionType.toLowerCase()],
      orderBy: 'id ASC',
    );
    return rows.map(_answerFromLocal).toList();
  }

  static Future<List<ExDefect>> getLocalDefects(int jobId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'ex_defects',
      where: 'surveyJobId = ? AND deleted = 0',
      whereArgs: [jobId],
      orderBy: 'updatedAt DESC, id DESC',
    );
    return rows.map(_defectFromLocal).toList();
  }

  static Future<List<ExSurveyPhoto>> getLocalPhotos(
    int jobId, {
    int? equipmentId,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'ex_photos',
      where: equipmentId == null
          ? 'surveyJobId = ? AND deleted = 0'
          : 'surveyJobId = ? AND exEquipmentId = ? AND deleted = 0',
      whereArgs: equipmentId == null ? [jobId] : [jobId, equipmentId],
      orderBy: 'uploadedAt DESC, id DESC',
    );
    return rows.map(_photoFromLocal).toList();
  }

  static Future<List<ExSurveyDocument>> getLocalDocuments(int jobId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'ex_documents',
      where: 'surveyJobId = ? AND deleted = 0',
      whereArgs: [jobId],
      orderBy: 'updatedAt DESC, id DESC',
    );
    return rows.map(_documentFromLocal).toList();
  }

  static Future<void> _syncQueueItem(
    Database db,
    Map<String, Object?> item,
  ) async {
    final entityType = item['entityType']?.toString();
    final operation = item['operation']?.toString();
    final payload = jsonDecode(item['payloadJson']?.toString() ?? '{}');
    final localId = _int(payload['localId'] ?? item['entityLocalId']);

    if (entityType == 'equipment') {
      final rows = await db.query(
        'ex_equipment',
        where: 'id = ? AND deleted = 0',
        whereArgs: [localId],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final local = rows.first;
      final created = await ExSurveyService.createEquipment(
        _int(local['surveyJobId']),
        _equipmentPayload(local),
      );
      await _replaceEquipmentId(db, localId, created);
      return;
    }

    if (entityType == 'answer') {
      final rows = await db.query(
        'ex_checklist_answers',
        where: 'id = ? AND deleted = 0',
        whereArgs: [localId],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final row = rows.first;
      final serverEquipmentId = await _serverEquipmentId(
        db,
        _int(row['exEquipmentId']),
      );
      await ExSurveyService.saveAnswer(
        equipmentId: serverEquipmentId,
        questionId: _int(row['exChecklistQuestionId']),
        result: row['result']?.toString() ?? 'NA',
        comment: row['comment']?.toString(),
      );
      await db.update(
        'ex_checklist_answers',
        {'synced': 1, 'updatedAt': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [localId],
      );
      return;
    }

    if (entityType == 'defect') {
      final rows = await db.query(
        'ex_defects',
        where: 'id = ? AND deleted = 0',
        whereArgs: [localId],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final row = rows.first;
      final serverEquipmentId = await _serverEquipmentId(
        db,
        _int(row['exEquipmentId']),
      );
      await ExSurveyService.createDefect(
        equipmentId: serverEquipmentId,
        defectNumber: row['defectNumber']?.toString(),
        description: row['description']?.toString() ?? '',
        severity: row['severity']?.toString() ?? 'Minor',
        recommendation: row['recommendation']?.toString(),
      );
      await db.update(
        'ex_defects',
        {'synced': 1, 'updatedAt': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [localId],
      );
      return;
    }

    if (entityType == 'defectStatus') {
      final rows = await db.query(
        'ex_defects',
        where: 'id = ?',
        whereArgs: [localId],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final serverId = _int(rows.first['serverId']);
      if (serverId <= 0) {
        throw Exception('Defect must sync before status can update.');
      }
      await ExSurveyService.updateDefectStatus(
        serverId,
        payload['status']?.toString() ?? 'Open',
      );
      await db.update(
        'ex_defects',
        {'synced': 1, 'updatedAt': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [localId],
      );
      return;
    }

    if (entityType == 'photo') {
      final rows = await db.query(
        'ex_photos',
        where: 'id = ? AND deleted = 0',
        whereArgs: [localId],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final row = rows.first;
      final serverEquipmentId = await _serverEquipmentId(
        db,
        _int(row['exEquipmentId']),
      );
      final localPath = row['localFilePath']?.toString() ?? '';
      await ExSurveyService.uploadPhoto(
        jobId: _int(row['surveyJobId']),
        equipmentId: serverEquipmentId,
        bytes: await readExLocalFile(localPath),
        fileName: row['originalFileName']?.toString() ?? 'photo.jpg',
      );
      await db.update(
        'ex_photos',
        {'synced': 1, 'updatedAt': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [localId],
      );
      return;
    }

    if (entityType == 'document') {
      final rows = await db.query(
        'ex_documents',
        where: 'id = ? AND deleted = 0',
        whereArgs: [localId],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final row = rows.first;
      final localPath = row['localFilePath']?.toString() ?? '';
      await ExSurveyService.uploadDocument(
        jobId: _int(row['surveyJobId']),
        documentType: row['documentType']?.toString() ?? 'Document',
        bytes: await readExLocalFile(localPath),
        fileName: row['originalFileName']?.toString() ?? 'document',
      );
      await db.update(
        'ex_documents',
        {'synced': 1, 'updatedAt': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [localId],
      );
      return;
    }

    if (entityType == 'job' && operation == 'submit') {
      await ExSurveyService.submitForQc(_int(payload['jobId']));
      return;
    }

    if (entityType == 'job' && operation == 'review') {
      await ExSurveyService.review(
        _int(payload['jobId']),
        payload['status']?.toString() ?? 'QcReturned',
      );
    }
  }

  static Future<void> _cacheEquipment(
    int jobId,
    List<ExEquipment> equipment,
  ) async {
    final db = await DatabaseHelper.instance.database;
    for (final item in equipment) {
      final existing = await db.query(
        'ex_equipment',
        where: 'id = ? AND synced = 0',
        whereArgs: [item.id],
        limit: 1,
      );
      if (existing.isNotEmpty) continue;

      await db.insert('ex_equipment', {
        'id': item.id,
        'serverId': item.id,
        'surveyJobId': jobId,
        'equipmentId': item.equipmentId,
        'rfidTag': item.rfidTag,
        'area': item.area,
        'location': item.location,
        'equipmentType': item.equipmentType,
        'description': item.description,
        'manufacturer': item.manufacturer,
        'model': item.model,
        'serialNumber': item.serialNumber,
        'isActive': item.isActive ? 1 : 0,
        'deleted': 0,
        'synced': 1,
        'updatedAt': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  static Future<void> _cacheQuestions(
    List<ExChecklistQuestion> questions,
  ) async {
    final db = await DatabaseHelper.instance.database;
    for (final question in questions) {
      await db.insert('ex_checklist_questions', {
        'id': question.id,
        'questionCode': question.questionCode,
        'inspectionType': question.inspectionType,
        'questionText': question.questionText,
        'sortOrder': question.sortOrder,
        'updatedAt': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  static Future<void> _cacheAnswers(
    int equipmentId,
    String inspectionType,
    List<ExChecklistAnswer> answers,
  ) async {
    final db = await DatabaseHelper.instance.database;
    for (final answer in answers) {
      await db.insert('ex_checklist_answers', {
        'id': answer.id,
        'serverId': answer.id,
        'exEquipmentId': equipmentId,
        'exChecklistQuestionId': answer.questionId,
        'inspectionType': inspectionType,
        'result': answer.result,
        'comment': answer.comment,
        'deleted': 0,
        'synced': 1,
        'updatedAt': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  static Future<void> _cacheDefects(int jobId, List<ExDefect> defects) async {
    final db = await DatabaseHelper.instance.database;
    for (final defect in defects) {
      await db.insert('ex_defects', {
        'id': defect.id,
        'serverId': defect.id,
        'surveyJobId': jobId,
        'exEquipmentId': defect.equipmentId,
        'equipmentCode': defect.equipmentCode,
        'defectNumber': defect.defectNumber,
        'description': defect.description,
        'severity': defect.severity,
        'recommendation': defect.recommendation,
        'status': defect.status,
        'deleted': 0,
        'synced': 1,
        'updatedAt': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  static Future<void> _cachePhotos(
    int jobId,
    List<ExSurveyPhoto> photos,
  ) async {
    final db = await DatabaseHelper.instance.database;
    for (final photo in photos) {
      await db.insert('ex_photos', {
        'id': photo.id,
        'serverId': photo.id,
        'surveyJobId': jobId,
        'exEquipmentId': photo.equipmentId,
        'originalFileName': photo.originalFileName,
        'filePath': photo.filePath,
        'localFilePath': photo.localFilePath,
        'uploadedAt': photo.uploadedAt?.toIso8601String(),
        'deleted': 0,
        'synced': 1,
        'updatedAt': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  static Future<void> _cacheDocuments(
    int jobId,
    List<ExSurveyDocument> documents,
  ) async {
    final db = await DatabaseHelper.instance.database;
    for (final document in documents) {
      await db.insert('ex_documents', {
        'id': document.id,
        'serverId': document.id,
        'surveyJobId': jobId,
        'documentType': document.documentType,
        'originalFileName': document.originalFileName,
        'filePath': document.filePath,
        'localFilePath': document.localFilePath,
        'sizeBytes': document.sizeBytes,
        'deleted': 0,
        'synced': 1,
        'updatedAt': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  static Future<void> _replaceEquipmentId(
    Database db,
    int localId,
    ExEquipment serverEquipment,
  ) async {
    await db.update(
      'ex_checklist_answers',
      {'exEquipmentId': serverEquipment.id},
      where: 'exEquipmentId = ?',
      whereArgs: [localId],
    );
    await db.update(
      'ex_defects',
      {'exEquipmentId': serverEquipment.id},
      where: 'exEquipmentId = ?',
      whereArgs: [localId],
    );
    await db.update(
      'ex_photos',
      {'exEquipmentId': serverEquipment.id},
      where: 'exEquipmentId = ?',
      whereArgs: [localId],
    );
    await db.delete('ex_equipment', where: 'id = ?', whereArgs: [localId]);
    await db.insert('ex_equipment', {
      'id': serverEquipment.id,
      'serverId': serverEquipment.id,
      'surveyJobId': serverEquipment.surveyJobId,
      'equipmentId': serverEquipment.equipmentId,
      'rfidTag': serverEquipment.rfidTag,
      'area': serverEquipment.area,
      'location': serverEquipment.location,
      'equipmentType': serverEquipment.equipmentType,
      'description': serverEquipment.description,
      'manufacturer': serverEquipment.manufacturer,
      'model': serverEquipment.model,
      'serialNumber': serverEquipment.serialNumber,
      'isActive': serverEquipment.isActive ? 1 : 0,
      'deleted': 0,
      'synced': 1,
      'updatedAt': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<int> _serverEquipmentId(
    Database db,
    int localOrServerId,
  ) async {
    final rows = await db.query(
      'ex_equipment',
      columns: ['serverId'],
      where: 'id = ?',
      whereArgs: [localOrServerId],
      limit: 1,
    );
    final serverId = rows.isEmpty
        ? localOrServerId
        : _int(rows.first['serverId']);
    if (serverId <= 0) {
      throw Exception('Equipment must sync before related data can sync.');
    }
    return serverId;
  }

  static Future<ExEquipment> _localEquipmentById(int equipmentId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'ex_equipment',
      where: '(id = ? OR serverId = ?) AND deleted = 0',
      whereArgs: [equipmentId, equipmentId],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('Equipment not found locally.');
    return _equipmentFromLocal(rows.first);
  }

  static Future<List<ExChecklistAnswer>> _getLocalAnswersForJob(
    int jobId,
  ) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery(
      '''
      SELECT a.* FROM ex_checklist_answers a
      INNER JOIN ex_equipment e ON e.id = a.exEquipmentId
      WHERE e.surveyJobId = ? AND a.deleted = 0
      ''',
      [jobId],
    );
    return rows.map(_answerFromLocal).toList();
  }

  static Future<int> _answerLocalId(int equipmentId, int questionId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'ex_checklist_answers',
      columns: ['id'],
      where: 'exEquipmentId = ? AND exChecklistQuestionId = ?',
      whereArgs: [equipmentId, questionId],
      limit: 1,
    );
    if (rows.isNotEmpty) return _int(rows.first['id']);
    return _localId();
  }

  static Future<String?> _questionType(int questionId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'ex_checklist_questions',
      columns: ['inspectionType'],
      where: 'id = ?',
      whereArgs: [questionId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['inspectionType']?.toString();
  }

  static Future<void> _enqueue({
    required String entityType,
    required int entityLocalId,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();
    await db.insert('ex_sync_queue', {
      'entityType': entityType,
      'entityLocalId': entityLocalId,
      'operation': operation,
      'payloadJson': jsonEncode(payload),
      'status': 0,
      'retryCount': 0,
      'createdAt': now,
      'updatedAt': now,
    });
  }

  static Map<String, dynamic> _equipmentPayload(Map<String, Object?> row) => {
    'equipmentId': row['equipmentId']?.toString() ?? '',
    'rfidTag': row['rfidTag']?.toString(),
    'area': row['area']?.toString() ?? 'Unassigned',
    'location': row['location']?.toString(),
    'equipmentType': row['equipmentType']?.toString(),
    'description': row['description']?.toString(),
    'manufacturer': row['manufacturer']?.toString(),
    'model': row['model']?.toString(),
    'serialNumber': row['serialNumber']?.toString(),
  };

  static ExEquipment _equipmentFromLocal(Map<String, Object?> row) {
    return ExEquipment(
      id: _int(row['serverId']) > 0 ? _int(row['serverId']) : _int(row['id']),
      surveyJobId: _int(row['surveyJobId']),
      equipmentId: row['equipmentId']?.toString() ?? '',
      rfidTag: row['rfidTag']?.toString(),
      area: row['area']?.toString() ?? 'Unassigned',
      location: row['location']?.toString(),
      equipmentType: row['equipmentType']?.toString(),
      description: row['description']?.toString(),
      manufacturer: row['manufacturer']?.toString(),
      model: row['model']?.toString(),
      serialNumber: row['serialNumber']?.toString(),
      isActive: _int(row['isActive']) != 0,
    );
  }

  static ExChecklistQuestion _questionFromLocal(Map<String, Object?> row) {
    return ExChecklistQuestion(
      id: _int(row['id']),
      questionCode: row['questionCode']?.toString() ?? '',
      inspectionType: row['inspectionType']?.toString() ?? 'Visual',
      questionText: row['questionText']?.toString() ?? '',
      sortOrder: _int(row['sortOrder']),
    );
  }

  static ExChecklistAnswer _answerFromLocal(Map<String, Object?> row) {
    return ExChecklistAnswer(
      id: _int(row['serverId']) > 0 ? _int(row['serverId']) : _int(row['id']),
      questionId: _int(row['exChecklistQuestionId']),
      result: row['result']?.toString() ?? '',
      comment: row['comment']?.toString(),
    );
  }

  static ExDefect _defectFromLocal(Map<String, Object?> row) {
    return ExDefect(
      id: _int(row['serverId']) > 0 ? _int(row['serverId']) : _int(row['id']),
      equipmentId: _int(row['exEquipmentId']),
      equipmentCode: row['equipmentCode']?.toString(),
      defectNumber: row['defectNumber']?.toString(),
      description: row['description']?.toString() ?? '',
      severity: row['severity']?.toString(),
      recommendation: row['recommendation']?.toString(),
      status: row['status']?.toString() ?? 'Open',
    );
  }

  static ExSurveyPhoto _photoFromLocal(Map<String, Object?> row) {
    final localFilePath = row['localFilePath']?.toString();
    return ExSurveyPhoto(
      id: _int(row['serverId']) > 0 ? _int(row['serverId']) : _int(row['id']),
      equipmentId: row['exEquipmentId'] == null
          ? null
          : _int(row['exEquipmentId']),
      originalFileName: row['originalFileName']?.toString() ?? 'Photo',
      filePath: row['filePath']?.toString() ?? localFilePath ?? '',
      localFilePath: localFilePath,
      uploadedAt: DateTime.tryParse(row['uploadedAt']?.toString() ?? ''),
    );
  }

  static ExSurveyDocument _documentFromLocal(Map<String, Object?> row) {
    final localFilePath = row['localFilePath']?.toString();
    return ExSurveyDocument(
      id: _int(row['serverId']) > 0 ? _int(row['serverId']) : _int(row['id']),
      documentType: row['documentType']?.toString() ?? 'Document',
      originalFileName: row['originalFileName']?.toString() ?? 'Document',
      filePath: row['filePath']?.toString() ?? localFilePath ?? '',
      localFilePath: localFilePath,
      sizeBytes: _int(row['sizeBytes']),
    );
  }

  static int _localId() => -DateTime.now().microsecondsSinceEpoch;

  static int _int(Object? value) => int.tryParse(value?.toString() ?? '') ?? 0;
}
