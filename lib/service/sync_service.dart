import 'dart:async';
import 'dart:convert';
import 'package:Auras/Db/database_helper.dart';
import 'package:Auras/app_config.dart';
import 'package:Auras/ex_survey/ex_file_storage_stub.dart'
    if (dart.library.io) 'package:Auras/ex_survey/ex_file_storage_io.dart';
import 'package:Auras/ex_survey/ex_survey_offline_service.dart';
import 'package:Auras/model/loadout.dart';
import 'package:Auras/model/seafastening.dart';
import 'package:Auras/model/survey_job.dart';
import 'package:Auras/model/towage.dart';
import 'package:Auras/network/http_override_initilalizer.dart';
import 'package:Auras/service/IhmOfflineService.dart';
import 'package:Auras/service/api_service.dart';
import 'package:Auras/service/survey_job_offline_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class SyncSnapshot {
  final String state;
  final bool isSyncing;
  final int pendingCount;
  final int failedCount;
  final int downloadedJobCount;
  final int uploadedItemCount;
  final DateTime? lastSyncedAt;
  final String? message;

  const SyncSnapshot({
    required this.state,
    this.isSyncing = false,
    this.pendingCount = 0,
    this.failedCount = 0,
    this.downloadedJobCount = 0,
    this.uploadedItemCount = 0,
    this.lastSyncedAt,
    this.message,
  });

  factory SyncSnapshot.initial() => const SyncSnapshot(state: 'Sync');

  String get label {
    if (isSyncing) return 'Syncing...';
    switch (state) {
      case 'synced':
        return 'Synced';
      case 'offline':
        return 'Offline';
      case 'failed':
        return 'Sync failed';
      default:
        return 'Sync';
    }
  }

  SyncSnapshot copyWith({
    String? state,
    bool? isSyncing,
    int? pendingCount,
    int? failedCount,
    int? downloadedJobCount,
    int? uploadedItemCount,
    DateTime? lastSyncedAt,
    bool clearLastSyncedAt = false,
    String? message,
  }) {
    return SyncSnapshot(
      state: state ?? this.state,
      isSyncing: isSyncing ?? this.isSyncing,
      pendingCount: pendingCount ?? this.pendingCount,
      failedCount: failedCount ?? this.failedCount,
      downloadedJobCount: downloadedJobCount ?? this.downloadedJobCount,
      uploadedItemCount: uploadedItemCount ?? this.uploadedItemCount,
      lastSyncedAt: clearLastSyncedAt
          ? null
          : (lastSyncedAt ?? this.lastSyncedAt),
      message: message ?? this.message,
    );
  }
}

class SyncService {
  static bool _isSyncing = false;
  static bool _cancelRequested = false;
  static StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  static final ValueNotifier<SyncSnapshot> syncStatus =
      ValueNotifier<SyncSnapshot>(SyncSnapshot.initial());

  static void startAutoSync() {
    refreshSyncStatus();
    _connectivitySubscription ??=
        Connectivity().onConnectivityChanged.listen((result) async {
      if (result == ConnectivityResult.none) {
        syncStatus.value = await _buildSnapshot(
          state: 'offline',
          message: 'No internet connection.',
        );
        return;
      }
      await syncAllOfflineData(auto: true);
    });
  }

  static Future<void> stopAutoSync() async {
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  static Future<bool> _hasActiveSession() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final token = prefs.getString('token') ?? '';
    final userId = prefs.getInt('userId') ?? 0;
    return isLoggedIn && token.isNotEmpty && userId > 0;
  }

  static Future<void> logoutAndClearUserData() async {
    requestCancel();
    try {
      await stopAutoSync();
    } catch (error) {
      debugPrint('Logout: failed to stop auto sync: $error');
    }

    var waitCycles = 0;
    while (_isSyncing && waitCycles < 50) {
      await Future.delayed(const Duration(milliseconds: 100));
      waitCycles++;
    }

    final prefs = await SharedPreferences.getInstance();
    try {
      await clearLocalUserData();
    } catch (error) {
      debugPrint('Logout: failed to clear local sync data: $error');
    } finally {
      await prefs.clear();
      syncStatus.value = SyncSnapshot.initial();
    }
  }

  static Future<SyncSnapshot> syncAllOfflineData({
    bool manual = false,
    bool auto = false,
  }) async {
    if (_isSyncing) {
      print("Sync already in progress - skipping");
      return syncStatus.value;
    }

    if (!(await _hasActiveSession())) {
      final snapshot = SyncSnapshot.initial();
      syncStatus.value = snapshot;
      return snapshot;
    }

    if (!(await hasInternetConnection())) {
      final snapshot = await _buildSnapshot(
        state: 'offline',
        message: 'No internet connection. Sync skipped.',
      );
      syncStatus.value = snapshot;
      return snapshot;
    }

    _isSyncing = true;
    _cancelRequested = false;
    final pendingBefore = await _pendingOfflineItemCount();
    syncStatus.value = await _buildSnapshot(
      state: 'syncing',
      isSyncing: true,
      message: 'Downloading latest accessible jobs...',
    );

    try {
      final downloadedJobs = await syncAccessibleSurveyJobsToLocal();
      if (_cancelRequested) {
        throw Exception('Sync cancelled.');
      }

      syncStatus.value = syncStatus.value.copyWith(
        downloadedJobCount: downloadedJobs,
        message: 'Uploading pending offline changes...',
      );

      await syncSurveyJobQueueToServer();
      if (_cancelRequested) throw Exception('Sync cancelled.');
      await syncTowageCertificatesToServer();
      if (_cancelRequested) throw Exception('Sync cancelled.');
      await syncSeaFasteningCertificatesToServer();
      if (_cancelRequested) throw Exception('Sync cancelled.');
      await syncLoadoutCertificatesToServer();
      if (_cancelRequested) throw Exception('Sync cancelled.');
      await IhmOfflineService.syncPendingIhmData();
      if (_cancelRequested) throw Exception('Sync cancelled.');
      await ExSurveyOfflineService.syncPendingExData();
      if (_cancelRequested) throw Exception('Sync cancelled.');
      await syncFromServerToLocal();

      final pendingAfter = await _pendingOfflineItemCount();
      final failedAfter = await _failedOfflineItemCount();
      final now = DateTime.now();
      await _saveSyncMetadata(
        lastSyncedAt: now,
        downloadedJobCount: downloadedJobs,
      );

      final snapshot = SyncSnapshot(
        state: failedAfter > 0 ? 'failed' : 'synced',
        isSyncing: false,
        pendingCount: pendingAfter,
        failedCount: failedAfter,
        downloadedJobCount: downloadedJobs,
        uploadedItemCount: pendingBefore > pendingAfter
            ? pendingBefore - pendingAfter
            : 0,
        lastSyncedAt: now,
        message: failedAfter > 0
            ? '$failedAfter item(s) need retry.'
            : 'Sync completed successfully.',
      );
      syncStatus.value = snapshot;
      return snapshot;
    } catch (e) {
      final snapshot = await _buildSnapshot(
        state: 'failed',
        downloadedJobCount: syncStatus.value.downloadedJobCount,
        message: e.toString().replaceFirst('Exception: ', ''),
      );
      syncStatus.value = snapshot;
      return snapshot;
    } finally {
      _isSyncing = false;
      _cancelRequested = false;
    }
  }

  static void requestCancel() {
    _cancelRequested = true;
  }

  static Future<void> refreshSyncStatus() async {
    syncStatus.value = await _buildSnapshot(state: syncStatus.value.state);
  }

  static Future<int> syncAccessibleSurveyJobsToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('userId') ?? 0;
    final role = (prefs.getString('userRole') ?? '').toLowerCase();
    final isAdmin = role == 'admin' ||
        role == 'global admin' ||
        role == 'globaladmin' ||
        role == 'administrator' ||
        role == 'manager';
    final downloaded = <int, SurveyJob>{};
    var fetchFailures = 0;

    Future<void> fetchAndCache({
      required String surveyType,
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
        await SurveyJobOfflineService.cacheSurveyJobs(
          surveyType: surveyType,
          isAdmin: isAdmin,
          userId: userId,
          jobs: jobs,
          ihmCompletionFilter: ihmCompletionFilter,
          jobCompletionFilter: jobCompletionFilter,
        );
        for (final job in jobs) {
          if (job.id > 0) downloaded[job.id] = job;
        }
      } catch (_) {
        fetchFailures++;
      }
    }

    await fetchAndCache(surveyType: 'IHM Survey');
    await fetchAndCache(
      surveyType: 'IHM Survey',
      ihmCompletionFilter: 'live',
    );
    await fetchAndCache(surveyType: 'Ex-Survey');
    await fetchAndCache(
      surveyType: 'Ex-Survey',
      jobCompletionFilter: 'live',
    );

    var cachedJobs = 0;
    for (final job in downloaded.values) {
      if (_isIhmJob(job)) {
        try {
          cachedJobs += await IhmOfflineService.cacheJobForOffline(job);
        } catch (_) {}
      } else {
        try {
          await ExSurveyOfflineService.fetchEquipment(job.id);
          await ExSurveyOfflineService.fetchDefects(job.id);
          await ExSurveyOfflineService.fetchPhotos(job.id);
          await ExSurveyOfflineService.fetchDocuments(job.id);
          cachedJobs++;
        } catch (_) {}
      }
      if (_cancelRequested) break;
    }

    if (downloaded.isEmpty && fetchFailures > 0) {
      throw Exception('Unable to download accessible jobs.');
    }

    return cachedJobs;
  }
  // 🔁 SYNC ALL CERTIFICATES

  static Future<void> syncAllCertificatesToServer() async {
    if (_isSyncing) {
      print("⚠ Sync already in progress — skipping");
      return;
    }
    _isSyncing = true;

    try {
      await syncTowageCertificatesToServer();
      await syncSeaFasteningCertificatesToServer();
      await syncLoadoutCertificatesToServer();
    } finally {
      _isSyncing = false;
    }
  }

  static Future<void> clearLocalUserData() async {
    await IhmOfflineService.clearLocalUserData();
    final db = await DatabaseHelper.instance.database;
    for (final table in [
      'ex_equipment',
      'ex_checklist_questions',
      'ex_answers',
      'ex_defects',
      'ex_evidence',
      'ex_sync_queue',
      'survey_job_sync_queue',
    ]) {
      try {
        await db.delete(table);
      } catch (_) {}
    }
    await clearExLocalFiles();
    syncStatus.value = SyncSnapshot.initial();
  }

  static Future<void> syncSurveyJobQueueToServer() async {
    final db = await DatabaseHelper.instance.database;
    final queue = await db.query(
      'survey_job_sync_queue',
      where: 'status IN (0, 2)',
      orderBy: 'id ASC',
    );

    for (final item in queue) {
      final queueId = int.tryParse(item['id']?.toString() ?? '') ?? 0;
      try {
        await db.update(
          'survey_job_sync_queue',
          {'status': -1, 'updatedAt': DateTime.now().toIso8601String()},
          where: 'id = ?',
          whereArgs: [queueId],
        );

        final payload = jsonDecode(item['payloadJson']?.toString() ?? '{}');
        if (item['entityType']?.toString() == 'surveyDate') {
          final jobId =
              int.tryParse(payload['surveyJobId']?.toString() ?? '') ?? 0;
          final surveyDate = DateTime.parse(
            payload['surveyDate']?.toString() ?? '',
          );
          await ApiService.updateSurveyDate(
            surveyJobId: jobId,
            surveyDate: surveyDate,
          );
        }

        await db.update(
          'survey_job_sync_queue',
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
          'survey_job_sync_queue',
          {
            'status': 2,
            'lastError': error.toString(),
            'retryCount':
                (int.tryParse(item['retryCount']?.toString() ?? '') ?? 0) + 1,
            'updatedAt': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [queueId],
        );
      }
    }
  }

  // 🔽 SYNC FROM SERVER TO LOCAL
  static Future<void> syncFromServerToLocal() async {
    final db = await DatabaseHelper.instance.database;

    try {
      // 🟦 1. TOWAGE
      final towageList = await ApiService.fetchTowageCertificatesFromServer();
      for (final certMap in towageList) {
        final id = certMap['id'] as int;
        final exists = await db.query(
          'towage_certificates',
          where: 'id = ?',
          whereArgs: [id],
        );
        if (exists.isEmpty) {
          await db.insert('towage_certificates', certMap..['synced'] = 1);
          print("✅ Inserted Towage cert from server: $id");
        }
      }

      // 🟩 2. LOADOUT
      final loadoutList = await ApiService.fetchAllLoadoutCertificates();
      for (final certMap in loadoutList) {
        final id = certMap['id'] as int;
        final exists = await db.query(
          'loadout_certificates',
          where: 'id = ?',
          whereArgs: [id],
        );
        if (exists.isEmpty) {
          await db.insert('loadout_certificates', certMap..['synced'] = 1);
          print("✅ Inserted Loadout cert from server: $id");
        }
      }

      // 🟨 3. SEAFASTENING
      final seaList = await ApiService.fetchAllSeafasteningCertificates();
      for (final cert in seaList) {
        final exists = await db.query(
          'seafastening_certificates',
          where: 'id = ?',
          whereArgs: [cert.id],
        );
        if (exists.isEmpty) {
          await db.insert(
            'seafastening_certificates',
            cert.toMap()..['synced'] = 1,
          );
          print("✅ Inserted SeaFastening cert from server: ${cert.id}");
        }
      }
    } catch (e) {
      // print("❌ Error syncing from server to local: $e");
    }
  }

  // 🔼 SYNC TOWAGE
  static Future<void> syncTowageCertificatesToServer() async {
    final dbHelper = DatabaseHelper.instance;
    final db = await dbHelper.database;

    final unsynced = await db.query(
      'towage_certificates',
      where: 'synced = ?',
      whereArgs: [0],
    );

    for (var map in unsynced) {
      try {
        // Mark as syncing first
        await db.update(
          'towage_certificates',
          {'synced': -1},
          where: 'id = ?',
          whereArgs: [map['id']],
        );

        final cert = TowageCertificate.fromMap(map);
        cert.defaultRecommendations = await dbHelper.getRecommendations(
          cert.id!,
        );
        cert.cargoDetails = await dbHelper.getCargoDetails(cert.id!);

        final response = await http.post(
          Uri.parse('${AppConfig.baseUrl}Certificate/create'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(cert.toJson(forSync: true)),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          await db.update(
            'towage_certificates',
            {'synced': 1},
            where: 'id = ?',
            whereArgs: [cert.id],
          );
          print('✅ Synced Towage Certificate: ${cert.id}');
        } else {
          await db.update(
            'towage_certificates',
            {'synced': 0}, // revert if failed
            where: 'id = ?',
            whereArgs: [cert.id],
          );
          print('❌ Towage sync failed: ${response.body}');
        }
      } catch (e) {
        await db.update(
          'towage_certificates',
          {'synced': 0}, // revert if error
          where: 'id = ?',
          whereArgs: [map['id']],
        );
        print('🔥 Error syncing towage: $e');
      }
    }
  }

  // 🔼 SYNC SEAFASTENING
  static Future<void> syncSeaFasteningCertificatesToServer() async {
    final dbHelper = DatabaseHelper.instance;
    final db = await dbHelper.database;

    final unsynced = await db.query(
      'seafastening_certificates',
      where: 'synced = ?',
      whereArgs: [0],
    );

    for (var map in unsynced) {
      try {
        await db.update(
          'seafastening_certificates',
          {'synced': -1},
          where: 'id = ?',
          whereArgs: [map['id']],
        );

        final cert = SeaFasteningCertificate.fromMap(map);
        cert.recommendations ??= await dbHelper.getSeafasteningRecommendations(
          cert.id!,
        );
        cert.cargoDetails ??= await dbHelper.getCargoDetails(cert.id!);

        final response = await http.post(
          Uri.parse('${AppConfig.baseUrl}SeaFastening/create-seafastening'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(cert.toJson(forSync: true)),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          await db.update(
            'seafastening_certificates',
            {'synced': 1},
            where: 'id = ?',
            whereArgs: [cert.id],
          );
          print('✅ Synced Seafastening Certificate: ${cert.id}');
        } else {
          await db.update(
            'seafastening_certificates',
            {'synced': 0},
            where: 'id = ?',
            whereArgs: [cert.id],
          );
          print('❌ Seafastening sync failed: ${response.body}');
        }
      } catch (e) {
        await db.update(
          'seafastening_certificates',
          {'synced': 0},
          where: 'id = ?',
          whereArgs: [map['id']],
        );
        print('🔥 Error syncing Seafastening: $e');
      }
    }
  }

  // 🔼 SYNC LOADOUT
  static Future<void> syncLoadoutCertificatesToServer() async {
    final dbHelper = DatabaseHelper.instance;
    final db = await dbHelper.database;

    final unsynced = await db.query(
      'loadout_certificates',
      where: 'synced = ?',
      whereArgs: [0],
    );

    for (var map in unsynced) {
      try {
        await db.update(
          'loadout_certificates',
          {'synced': -1},
          where: 'id = ?',
          whereArgs: [map['id']],
        );

        final cert = LoadoutCertificate.fromMap(map);
        cert.cargoDetails ??= await dbHelper.getCargoDetails(cert.id!);

        final response = await http.post(
          Uri.parse('${AppConfig.baseUrl}LoadOut/create-Loadout'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(cert.toJson(forSync: true)),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          await db.update(
            'loadout_certificates',
            {'synced': 1},
            where: 'id = ?',
            whereArgs: [cert.id],
          );
          print('✅ Synced Loadout Certificate: ${cert.id}');
        } else {
          await db.update(
            'loadout_certificates',
            {'synced': 0},
            where: 'id = ?',
            whereArgs: [cert.id],
          );
          print('❌ Loadout sync failed: ${response.body}');
        }
      } catch (e) {
        await db.update(
          'loadout_certificates',
          {'synced': 0},
          where: 'id = ?',
          whereArgs: [map['id']],
        );
        print('🔥 Error syncing Loadout: $e');
      }
    }
  }

  static bool _isIhmJob(SurveyJob job) {
    return job.moduleType.toLowerCase().contains('ihm');
  }

  static Future<SyncSnapshot> _buildSnapshot({
    required String state,
    bool isSyncing = false,
    int? downloadedJobCount,
    int? uploadedItemCount,
    String? message,
  }) async {
    final metadata = await _readSyncMetadata();
    return SyncSnapshot(
      state: state,
      isSyncing: isSyncing,
      pendingCount: await _pendingOfflineItemCount(),
      failedCount: await _failedOfflineItemCount(),
      downloadedJobCount:
          downloadedJobCount ?? metadata.downloadedJobCount,
      uploadedItemCount: uploadedItemCount ?? 0,
      lastSyncedAt: metadata.lastSyncedAt,
      message: message,
    );
  }

  static Future<int> _pendingOfflineItemCount() async {
    final db = await DatabaseHelper.instance.database;
    var count = 0;
    count += await _tableCount(
      db,
      'towage_certificates',
      where: 'synced IN (0, -1)',
    );
    count += await _tableCount(
      db,
      'seafastening_certificates',
      where: 'synced IN (0, -1)',
    );
    count += await _tableCount(
      db,
      'loadout_certificates',
      where: 'synced IN (0, -1)',
    );
    count += await _tableCount(
      db,
      'ihm_sync_queue',
      where: 'status IN (0, 2, -1)',
    );
    count += await _tableCount(
      db,
      'survey_job_sync_queue',
      where: 'status IN (0, 2, -1)',
    );
    count += await _tableCount(
      db,
      'ex_sync_queue',
      where: 'status IN (0, 2, -1)',
    );
    return count;
  }

  static Future<int> _failedOfflineItemCount() async {
    final db = await DatabaseHelper.instance.database;
    var count = 0;
    count += await _tableCount(
      db,
      'survey_job_sync_queue',
      where: 'status = 2',
    );
    count += await _tableCount(db, 'ihm_sync_queue', where: 'status = 2');
    count += await _tableCount(db, 'ex_sync_queue', where: 'status = 2');
    return count;
  }

  static Future<int> _tableCount(
    dynamic db,
    String table, {
    String? where,
  }) async {
    try {
      final result = await db.rawQuery(
        'SELECT COUNT(*) AS count FROM $table${where == null ? '' : ' WHERE $where'}',
      );
      return int.tryParse(result.first['count']?.toString() ?? '') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> _saveSyncMetadata({
    required DateTime lastSyncedAt,
    required int downloadedJobCount,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();
    await db.insert(
      'sync_metadata',
      {
        'key': 'lastSyncedAt',
        'value': lastSyncedAt.toIso8601String(),
        'updatedAt': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await db.insert(
      'sync_metadata',
      {
        'key': 'downloadedJobCount',
        'value': downloadedJobCount.toString(),
        'updatedAt': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<_SyncMetadata> _readSyncMetadata() async {
    final db = await DatabaseHelper.instance.database;
    try {
      final rows = await db.query('sync_metadata');
      final values = {
        for (final row in rows) row['key']?.toString() ?? '': row['value'],
      };
      return _SyncMetadata(
        lastSyncedAt: DateTime.tryParse(
          values['lastSyncedAt']?.toString() ?? '',
        ),
        downloadedJobCount:
            int.tryParse(values['downloadedJobCount']?.toString() ?? '') ?? 0,
      );
    } catch (_) {
      return const _SyncMetadata();
    }
  }
}

class _SyncMetadata {
  final DateTime? lastSyncedAt;
  final int downloadedJobCount;

  const _SyncMetadata({this.lastSyncedAt, this.downloadedJobCount = 0});
}
