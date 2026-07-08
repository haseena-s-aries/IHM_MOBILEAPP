import 'dart:convert';

import 'package:Auras/Db/database_helper.dart';
import 'package:Auras/model/survey_job.dart';
import 'package:Auras/service/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    await _cacheSurveyJobsInPrefs(
      surveyType: surveyType,
      isAdmin: isAdmin,
      userId: userId,
      jobs: jobs,
    );

    final scopeUserId = userId;
    final scopeIsAdmin = isAdmin ? 1 : 0;
    final now = DateTime.now().toIso8601String();

    try {
      final db = await DatabaseHelper.instance.database;
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
    } catch (_) {
      // SharedPreferences cache above is enough for the job-list offline view.
    }
  }

  static Future<List<SurveyJob>> getCachedSurveyJobs({
    required String surveyType,
    required bool isAdmin,
    required int userId,
  }) async {
    final scopeUserId = userId;
    final scopeIsAdmin = isAdmin ? 1 : 0;
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await _queryCachedRows(
        db,
        surveyType: surveyType,
        userId: scopeUserId,
        isAdmin: scopeIsAdmin,
      );
      if (rows.isEmpty && isAdmin) {
        rows.addAll(
          await _queryCachedRows(
            db,
            surveyType: surveyType,
            userId: 0,
            isAdmin: scopeIsAdmin,
          ),
        );
      }

      final cached = rows
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

      if (cached.isNotEmpty) {
        return cached;
      }
    } catch (_) {
      // SQLite can be unavailable in some runtimes; SharedPreferences below is
      // kept as the lightweight offline fallback for the job list.
    }

    return _getCachedSurveyJobsFromPrefs(
      surveyType: surveyType,
      isAdmin: isAdmin,
      userId: userId,
    );
  }

  static Future<List<Map<String, Object?>>> _queryCachedRows(
    Database db, {
    required String surveyType,
    required int userId,
    required int isAdmin,
  }) {
    return db.query(
      'survey_jobs_cache',
      where: 'surveyType = ? AND userId = ? AND isAdmin = ?',
      whereArgs: [surveyType, userId, isAdmin],
      orderBy: 'id DESC',
    );
  }

  static Future<void> _cacheSurveyJobsInPrefs({
    required String surveyType,
    required bool isAdmin,
    required int userId,
    required List<SurveyJob> jobs,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _prefsKey(
      surveyType: surveyType,
      isAdmin: isAdmin,
      userId: userId,
    );
    await prefs.setString(
      key,
      jsonEncode(jobs.map((job) => job.toJson()).toList()),
    );
  }

  static Future<List<SurveyJob>> _getCachedSurveyJobsFromPrefs({
    required String surveyType,
    required bool isAdmin,
    required int userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = <String>[
      _prefsKey(surveyType: surveyType, isAdmin: isAdmin, userId: userId),
      if (isAdmin)
        _prefsKey(surveyType: surveyType, isAdmin: isAdmin, userId: 0),
    ];

    for (final key in keys) {
      final value = prefs.getString(key);
      if (value == null || value.isEmpty) continue;

      final decoded = jsonDecode(value);
      if (decoded is! List) continue;

      return decoded
          .whereType<Map>()
          .map((item) => SurveyJob.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }

    return [];
  }

  static String _prefsKey({
    required String surveyType,
    required bool isAdmin,
    required int userId,
  }) {
    final normalizedType = surveyType.toLowerCase().replaceAll(' ', '_');
    return 'survey_jobs_cache_${normalizedType}_${isAdmin ? 1 : 0}_$userId';
  }
}
