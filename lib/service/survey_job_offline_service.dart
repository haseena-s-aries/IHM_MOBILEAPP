import 'dart:convert';

import 'package:Auras/Db/database_helper.dart';
import 'package:Auras/model/survey_job.dart';
import 'package:Auras/service/api_service.dart';
import 'package:sqflite/sqflite.dart';

class SurveyJobOfflineService {
  static Future<List<SurveyJob>> getSurveyJobsByType({
    required String surveyType,
    required bool isAdmin,
    required int userId,
  }) async {
    try {
      final jobs = await ApiService.fetchSurveyJobsByType(
        surveyType: surveyType,
        isAdmin: isAdmin,
        userId: userId,
      );
      await cacheSurveyJobs(
        surveyType: surveyType,
        isAdmin: isAdmin,
        userId: userId,
        jobs: jobs,
      );
      return jobs;
    } catch (_) {
      final cachedJobs = await getCachedSurveyJobs(
        surveyType: surveyType,
        isAdmin: isAdmin,
        userId: userId,
      );
      if (cachedJobs.isNotEmpty) {
        return cachedJobs;
      }
      rethrow;
    }
  }

  static Future<void> cacheSurveyJobs({
    required String surveyType,
    required bool isAdmin,
    required int userId,
    required List<SurveyJob> jobs,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final scopeUserId = isAdmin ? 0 : userId;
    final scopeIsAdmin = isAdmin ? 1 : 0;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      await txn.delete(
        'survey_jobs_cache',
        where: 'surveyType = ? AND userId = ? AND isAdmin = ?',
        whereArgs: [surveyType, scopeUserId, scopeIsAdmin],
      );

      final batch = txn.batch();
      for (final job in jobs) {
        batch.insert(
          'survey_jobs_cache',
          {
            'id': job.id,
            'surveyType': surveyType,
            'userId': scopeUserId,
            'isAdmin': scopeIsAdmin,
            'payloadJson': jsonEncode(job.toJson()),
            'updatedAt': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  static Future<List<SurveyJob>> getCachedSurveyJobs({
    required String surveyType,
    required bool isAdmin,
    required int userId,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final scopeUserId = isAdmin ? 0 : userId;
    final scopeIsAdmin = isAdmin ? 1 : 0;
    final rows = await db.query(
      'survey_jobs_cache',
      where: 'surveyType = ? AND userId = ? AND isAdmin = ?',
      whereArgs: [surveyType, scopeUserId, scopeIsAdmin],
      orderBy: 'id DESC',
    );

    return rows
        .map((row) {
          final payloadJson = row['payloadJson']?.toString();
          if (payloadJson == null || payloadJson.isEmpty) {
            return null;
          }
          final payload = jsonDecode(payloadJson) as Map<String, dynamic>;
          return SurveyJob.fromJson(payload);
        })
        .whereType<SurveyJob>()
        .toList();
  }
}
