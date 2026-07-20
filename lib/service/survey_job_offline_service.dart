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
    String? ihmCompletionFilter,
    String? jobCompletionFilter,
  }) async {
    try {
      final jobs = await ApiService.fetchSurveyJobsByType(
        surveyType: surveyType,
        isAdmin: isAdmin,
        userId: userId,
        ihmCompletionFilter: ihmCompletionFilter,
        jobCompletionFilter: jobCompletionFilter,
      );

      await cacheSurveyJobs(
        surveyType: surveyType,
        isAdmin: isAdmin,
        userId: userId,
        jobs: jobs,
        ihmCompletionFilter: ihmCompletionFilter,
        jobCompletionFilter: jobCompletionFilter,
      );
      return jobs;
    } catch (_) {
      final cachedJobs = await getCachedSurveyJobs(
        surveyType: surveyType,
        isAdmin: isAdmin,
        userId: userId,
        ihmCompletionFilter: ihmCompletionFilter,
        jobCompletionFilter: jobCompletionFilter,
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
    String? ihmCompletionFilter,
    String? jobCompletionFilter,
  }) async {
    final hasIhmCompletionFilter =
        ihmCompletionFilter != null && ihmCompletionFilter.trim().isNotEmpty;
    final hasJobCompletionFilter =
        jobCompletionFilter != null && jobCompletionFilter.trim().isNotEmpty;

    await _cacheSurveyJobsInPrefs(
      surveyType: surveyType,
      isAdmin: isAdmin,
      userId: userId,
      jobs: jobs,
      ihmCompletionFilter: ihmCompletionFilter,
      jobCompletionFilter: jobCompletionFilter,
    );

    if (hasIhmCompletionFilter || hasJobCompletionFilter) {
      return;
    }

    final scopeUserId = userId;
    final scopeIsAdmin = isAdmin ? 1 : 0;
    final now = DateTime.now().toIso8601String();

    try {
      final db = await DatabaseHelper.instance.database;
      final pendingSurveyDates = await _pendingSurveyDates(db);
      await db.transaction((txn) async {
        await txn.delete(
          'survey_jobs_cache',
          where: 'surveyType = ? AND userId = ? AND isAdmin = ?',
          whereArgs: [surveyType, scopeUserId, scopeIsAdmin],
        );

        final batch = txn.batch();
        for (final job in jobs) {
          final payload = job.toJson();
          final pendingSurveyDate = pendingSurveyDates[job.id];
          if (pendingSurveyDate != null) {
            payload['surveyDate'] = pendingSurveyDate;
          }
          batch.insert('survey_jobs_cache', {
            'id': job.id,
            'surveyType': surveyType,
            'userId': scopeUserId,
            'isAdmin': scopeIsAdmin,
            'payloadJson': jsonEncode(payload),
            'updatedAt': now,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
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
    String? ihmCompletionFilter,
    String? jobCompletionFilter,
  }) async {
    final hasIhmCompletionFilter =
        ihmCompletionFilter != null && ihmCompletionFilter.trim().isNotEmpty;
    final hasJobCompletionFilter =
        jobCompletionFilter != null && jobCompletionFilter.trim().isNotEmpty;
    if (hasIhmCompletionFilter || hasJobCompletionFilter) {
      return _getCachedSurveyJobsFromPrefs(
        surveyType: surveyType,
        isAdmin: isAdmin,
        userId: userId,
        ihmCompletionFilter: ihmCompletionFilter,
        jobCompletionFilter: jobCompletionFilter,
      );
    }

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

  static Future<void> updateSurveyDate({
    required SurveyJob job,
    required DateTime surveyDate,
  }) async {
    Object? apiError;
    try {
      await ApiService.updateSurveyDate(
        surveyJobId: job.id,
        surveyDate: surveyDate,
      );
      await _tryUpdateCachedSurveyJobDate(job.id, surveyDate, synced: true);
      return;
    } catch (error) {
      apiError = error;
    }

    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now().toIso8601String();
      await _tryUpdateCachedSurveyJobDate(job.id, surveyDate, synced: false);
      await db.delete(
        'survey_job_sync_queue',
        where: 'surveyJobId = ? AND entityType = ? AND status IN (0, 2, -1)',
        whereArgs: [job.id, 'surveyDate'],
      );
      await db.insert(
        'survey_job_sync_queue',
        {
          'surveyJobId': job.id,
          'entityType': 'surveyDate',
          'operation': 'update',
          'payloadJson': jsonEncode({
            'surveyJobId': job.id,
            'surveyDate': surveyDate.toIso8601String(),
          }),
          'status': 0,
          'retryCount': 0,
          'createdAt': now,
          'updatedAt': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {
      await _updateCachedSurveyJobDateInPrefs(job.id, surveyDate);
      throw apiError ?? Exception('Unable to save survey date offline.');
    }
  }

  static Future<void> _tryUpdateCachedSurveyJobDate(
    int jobId,
    DateTime surveyDate, {
    required bool synced,
  }) async {
    try {
      await _updateCachedSurveyJobDate(jobId, surveyDate, synced: synced);
    } catch (_) {
      await _updateCachedSurveyJobDateInPrefs(jobId, surveyDate);
    }
  }

  static Future<Map<int, String>> _pendingSurveyDates(Database db) async {
    try {
      final rows = await db.query(
        'survey_job_sync_queue',
        where: 'entityType = ? AND status IN (0, 2, -1)',
        whereArgs: ['surveyDate'],
        orderBy: 'id ASC',
      );
      final result = <int, String>{};
      for (final row in rows) {
        final payload = jsonDecode(row['payloadJson']?.toString() ?? '{}');
        final jobId = int.tryParse(payload['surveyJobId']?.toString() ?? '');
        final surveyDate = payload['surveyDate']?.toString();
        if (jobId != null && surveyDate != null && surveyDate.isNotEmpty) {
          result[jobId] = surveyDate;
        }
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  static Future<void> _updateCachedSurveyJobDate(
    int jobId,
    DateTime surveyDate, {
    required bool synced,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'survey_jobs_cache',
      where: 'id = ?',
      whereArgs: [jobId],
    );
    final dateValue = surveyDate.toIso8601String();
    for (final row in rows) {
      final payloadJson = row['payloadJson']?.toString();
      if (payloadJson == null || payloadJson.isEmpty) continue;
      final payload = jsonDecode(payloadJson) as Map<String, dynamic>;
      payload['surveyDate'] = dateValue;
      await _applyCachedIhmProgress(db, jobId, payload);
      await db.update(
        'survey_jobs_cache',
        {
          'payloadJson': jsonEncode(payload),
          'updatedAt': DateTime.now().toIso8601String(),
        },
        where: 'id = ? AND surveyType = ? AND userId = ? AND isAdmin = ?',
        whereArgs: [
          row['id'],
          row['surveyType'],
          row['userId'],
          row['isAdmin'],
        ],
      );
    }

    if (synced) {
      await db.update(
        'survey_job_sync_queue',
        {'status': 1, 'updatedAt': DateTime.now().toIso8601String()},
        where: 'surveyJobId = ? AND entityType = ? AND status IN (0, 2, -1)',
        whereArgs: [jobId, 'surveyDate'],
      );
    }
  }

  static Future<void> _updateCachedSurveyJobDateInPrefs(
    int jobId,
    DateTime surveyDate,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final dateValue = surveyDate.toIso8601String();

    for (final key in prefs
        .getKeys()
        .where((item) => item.startsWith('survey_jobs_cache_'))) {
      final value = prefs.getString(key);
      if (value == null || value.isEmpty) continue;

      try {
        final decoded = jsonDecode(value);
        if (decoded is! List) continue;

        var changed = false;
        final updated = decoded.map((item) {
          if (item is! Map) return item;
          final payload = Map<String, dynamic>.from(item);
          if (int.tryParse(payload['id']?.toString() ?? '') != jobId) {
            return payload;
          }

          payload['surveyDate'] = dateValue;
          final completedItems =
              int.tryParse(payload['completedItems']?.toString() ?? '') ?? 0;
          final totalItems =
              int.tryParse(payload['totalItems']?.toString() ?? '') ?? 0;
          payload['displayStatus'] = totalItems > 0 &&
                  completedItems >= totalItems
              ? 'Completed'
              : (completedItems > 0 ? 'Pending' : 'In Progress');
          changed = true;
          return payload;
        }).toList();

        if (changed) {
          await prefs.setString(key, jsonEncode(updated));
        }
      } catch (_) {
        continue;
      }
    }
  }

  static Future<void> refreshCachedIhmDisplayStatus(int jobId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'survey_jobs_cache',
      where: 'id = ?',
      whereArgs: [jobId],
    );

    for (final row in rows) {
      final payloadJson = row['payloadJson']?.toString();
      if (payloadJson == null || payloadJson.isEmpty) continue;
      final payload = jsonDecode(payloadJson) as Map<String, dynamic>;
      await _applyCachedIhmProgress(db, jobId, payload);
      await db.update(
        'survey_jobs_cache',
        {
          'payloadJson': jsonEncode(payload),
          'updatedAt': DateTime.now().toIso8601String(),
        },
        where: 'id = ? AND surveyType = ? AND userId = ? AND isAdmin = ?',
        whereArgs: [
          row['id'],
          row['surveyType'],
          row['userId'],
          row['isAdmin'],
        ],
      );
    }

    await _refreshCachedIhmStatusInPrefs(jobId, db);
  }

  static Future<void> _applyCachedIhmProgress(
    Database db,
    int jobId,
    Map<String, dynamic> payload,
  ) async {
    final rows = await db.query(
      'ihm_checkpoints',
      columns: ['result', 'checkResult'],
      where: 'surveyJobId = ?',
      whereArgs: [jobId],
    );
    final totalItems = rows.length;
    final completedItems = rows
        .where(
          (row) =>
              _isCompletedAuditValue(row['result']?.toString()) ||
              _isCompletedAuditValue(row['checkResult']?.toString()),
        )
        .length;

    payload['totalItems'] = totalItems;
    payload['completedItems'] = completedItems;
    payload['completionPercentage'] = totalItems == 0
        ? 0
        : double.parse(((completedItems * 100) / totalItems).toStringAsFixed(2));
    payload['displayStatus'] = _displayStatus(
      surveyDate: payload['surveyDate']?.toString(),
      totalItems: totalItems,
      completedItems: completedItems,
    );
  }

  static String _displayStatus({
    required String? surveyDate,
    required int totalItems,
    required int completedItems,
  }) {
    if (totalItems > 0 && completedItems >= totalItems) return 'Completed';
    if (completedItems > 0) return 'Pending';
    if (surveyDate != null && surveyDate.trim().isNotEmpty) {
      return 'In Progress';
    }
    return 'Not Started';
  }

  static bool _isCompletedAuditValue(String? value) {
    final normalized = (value ?? '')
        .trim()
        .toLowerCase()
        .replaceAll(' ', '')
        .replaceAll('_', '')
        .replaceAll('-', '');
    return {
      'present',
      'notpresent',
      'notapplicable',
      'samplerequired',
      '2',
      '3',
      '4',
      '5',
      'audited',
      'completed',
    }.contains(normalized);
  }

  static Future<void> _refreshCachedIhmStatusInPrefs(
    int jobId,
    Database db,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where((x) => x.startsWith('survey_jobs_cache_'))) {
      final value = prefs.getString(key);
      if (value == null || value.isEmpty) continue;
      final decoded = jsonDecode(value);
      if (decoded is! List) continue;

      var changed = false;
      final updated = decoded.map((item) {
        if (item is! Map) return item;
        final payload = Map<String, dynamic>.from(item);
        if (int.tryParse(payload['id']?.toString() ?? '') != jobId) {
          return payload;
        }
        changed = true;
        return payload;
      }).toList();

      if (!changed) continue;
      for (final item in updated.whereType<Map<String, dynamic>>()) {
        if (int.tryParse(item['id']?.toString() ?? '') == jobId) {
          await _applyCachedIhmProgress(db, jobId, item);
        }
      }
      await prefs.setString(key, jsonEncode(updated));
    }
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
    String? ihmCompletionFilter,
    String? jobCompletionFilter,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _prefsKey(
      surveyType: surveyType,
      isAdmin: isAdmin,
      userId: userId,
      ihmCompletionFilter: ihmCompletionFilter,
      jobCompletionFilter: jobCompletionFilter,
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
    String? ihmCompletionFilter,
    String? jobCompletionFilter,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = <String>[
      _prefsKey(
        surveyType: surveyType,
        isAdmin: isAdmin,
        userId: userId,
        ihmCompletionFilter: ihmCompletionFilter,
        jobCompletionFilter: jobCompletionFilter,
      ),
      if (isAdmin)
        _prefsKey(
          surveyType: surveyType,
          isAdmin: isAdmin,
          userId: 0,
          ihmCompletionFilter: ihmCompletionFilter,
          jobCompletionFilter: jobCompletionFilter,
        ),
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
    String? ihmCompletionFilter,
    String? jobCompletionFilter,
  }) {
    final normalizedType = surveyType.toLowerCase().replaceAll(' ', '_');
    final normalizedIhmFilter = ihmCompletionFilter?.trim().toLowerCase() ?? '';
    final normalizedJobFilter = jobCompletionFilter?.trim().toLowerCase() ?? '';
    if (normalizedIhmFilter.isEmpty && normalizedJobFilter.isEmpty) {
      return 'survey_jobs_cache_${normalizedType}_${isAdmin ? 1 : 0}_$userId';
    }

    final normalizedFilter = normalizedIhmFilter.isNotEmpty
        ? normalizedIhmFilter
        : normalizedJobFilter;
    return 'survey_jobs_cache_${normalizedType}_${isAdmin ? 1 : 0}_${userId}_$normalizedFilter';
  }
}
