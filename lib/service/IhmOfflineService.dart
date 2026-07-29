import 'dart:convert';
import 'dart:typed_data';

import 'package:Auras/Db/database_helper.dart';
import 'package:Auras/ihm_area.dart';
import 'package:Auras/model/survey_job.dart';
import 'package:Auras/service/api_service.dart';
import 'package:Auras/service/survey_job_offline_service.dart';
import 'package:Auras/service/ihm_photo_storage_stub.dart'
    if (dart.library.io) 'package:Auras/service/ihm_photo_storage_io.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

class IhmOfflineService {
  static bool _syncing = false;

  static Future<bool> get isOnline async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  static Future<List<IhmArea>> getAreasForJob(int jobId) async {
    if (kIsWeb) {
      return ApiService.fetchIhmAreasWithCheckpoints(jobId);
    }

    if (await isOnline) {
      try {
        final areas = await ApiService.fetchIhmAreasWithCheckpoints(jobId);
        await cacheAreas(jobId, areas);
        await syncPendingIhmData();
        return getLocalAreas(jobId);
      } catch (_) {
        return getLocalAreas(jobId);
      }
    }

    return getLocalAreas(jobId);
  }

  static Future<void> cacheAreas(int jobId, List<IhmArea> areas) async {
    if (kIsWeb) return;

    final db = await DatabaseHelper.instance.database;
    final latestAreaIds = areas.map((area) => area.id).toSet();
    final latestCheckpointIds = areas
        .expand((area) => area.checkpoints)
        .map((checkpoint) => checkpoint.id)
        .toSet();

    await db.transaction((txn) async {
      await _deleteStaleImportedJobData(
        txn,
        jobId: jobId,
        latestAreaIds: latestAreaIds,
        latestCheckpointIds: latestCheckpointIds,
      );

      for (final area in areas) {
        await txn.insert(
          'ihm_areas',
          area.toLocalMap(jobId),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        for (final checkpoint in area.checkpoints) {
          final existing = await txn.query(
            'ihm_checkpoints',
            columns: ['synced'],
            where: 'id = ?',
            whereArgs: [checkpoint.id],
            limit: 1,
          );

          if (existing.isNotEmpty && existing.first['synced'] == 0) {
            continue;
          }

          await txn.insert(
            'ihm_checkpoints',
            checkpoint.toLocalMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  static Future<void> _deleteStaleImportedJobData(
    Transaction txn, {
    required int jobId,
    required Set<int> latestAreaIds,
    required Set<int> latestCheckpointIds,
  }) async {
    final areaPlaceholders = latestAreaIds.map((_) => '?').join(',');
    final checkpointPlaceholders = latestCheckpointIds.map((_) => '?').join(',');

    if (latestCheckpointIds.isEmpty) {
      await txn.delete(
        'ihm_checkpoints',
        where: 'surveyJobId = ?',
        whereArgs: [jobId],
      );
      await txn.delete(
        'ihm_markers',
        where: 'surveyJobId = ?',
        whereArgs: [jobId],
      );
      await txn.delete(
        'ihm_sampling_photos',
        where: 'surveyJobId = ?',
        whereArgs: [jobId],
      );
    } else {
      await txn.delete(
        'ihm_checkpoints',
        where: 'surveyJobId = ? AND id NOT IN ($checkpointPlaceholders)',
        whereArgs: [jobId, ...latestCheckpointIds],
      );
      await txn.delete(
        'ihm_markers',
        where:
            'surveyJobId = ? AND ihmCheckpointId IS NOT NULL AND ihmCheckpointId NOT IN ($checkpointPlaceholders)',
        whereArgs: [jobId, ...latestCheckpointIds],
      );
      await txn.delete(
        'ihm_sampling_photos',
        where:
            'surveyJobId = ? AND ihmCheckpointId IS NOT NULL AND ihmCheckpointId NOT IN ($checkpointPlaceholders)',
        whereArgs: [jobId, ...latestCheckpointIds],
      );
    }

    if (latestAreaIds.isEmpty) {
      await txn.delete(
        'ihm_areas',
        where: 'surveyJobId = ?',
        whereArgs: [jobId],
      );
      await txn.delete(
        'ihm_layout_images',
        where: 'surveyJobId = ? AND isCommon = 0',
        whereArgs: [jobId],
      );
    } else {
      await txn.delete(
        'ihm_areas',
        where: 'surveyJobId = ? AND id NOT IN ($areaPlaceholders)',
        whereArgs: [jobId, ...latestAreaIds],
      );
      await txn.delete(
        'ihm_layout_images',
        where:
            'surveyJobId = ? AND isCommon = 0 AND ihmAreaId IS NOT NULL AND ihmAreaId NOT IN ($areaPlaceholders)',
        whereArgs: [jobId, ...latestAreaIds],
      );
      await txn.delete(
        'ihm_markers',
        where:
            'surveyJobId = ? AND ihmAreaId IS NOT NULL AND ihmAreaId NOT IN ($areaPlaceholders)',
        whereArgs: [jobId, ...latestAreaIds],
      );
      await txn.delete(
        'ihm_sampling_photos',
        where:
            'surveyJobId = ? AND ihmAreaId IS NOT NULL AND ihmAreaId NOT IN ($areaPlaceholders)',
        whereArgs: [jobId, ...latestAreaIds],
      );
    }
  }

  static Future<List<IhmArea>> getLocalAreas(int jobId) async {
    final db = await DatabaseHelper.instance.database;
    final areaRows = await db.query(
      'ihm_areas',
      where: 'surveyJobId = ?',
      whereArgs: [jobId],
      orderBy: 'sortOrder ASC, id ASC',
    );

    final result = <IhmArea>[];
    for (final area in areaRows) {
      final checkpointRows = await db.query(
        'ihm_checkpoints',
        where: 'ihmAreaId = ?',
        whereArgs: [area['id']],
        orderBy: 'sampleNo ASC',
      );

      result.add(
        IhmArea(
          id: _int(area['id']),
          areaName: area['areaName']?.toString() ?? '',
          checkpoints: checkpointRows.map(_checkpointFromLocal).toList(),
        ),
      );
    }

    return result;
  }

  static Future<IhmCheckpoint> saveCheckpointDetails({
    required IhmCheckpoint checkpoint,
    required bool isPchm,
    required String auditStatus,
    required String remarks,
    required String locationRemarks,
  }) async {
    final updatedCheckpoint = checkpoint.copyWith(
      isPchm: isPchm,
      auditStatus: auditStatus,
      remarks: remarks,
      locationRemarks: locationRemarks,
    );

    debugPrint(
      '[IHM] local save request checkpoint ${checkpoint.id}: '
      'auditStatus=$auditStatus, isPchm=$isPchm',
    );

    if (kIsWeb) {
      return ApiService.updateIhmCheckpointDetails(
        checkpoint: updatedCheckpoint,
      );
    }

    if (await isOnline) {
      try {
        final saved = await ApiService.updateIhmCheckpointDetails(
          checkpoint: updatedCheckpoint,
        );
        final db = await DatabaseHelper.instance.database;
        await _replaceLocalCheckpoint(db, saved, synced: 1);
        await SurveyJobOfflineService.refreshCachedIhmDisplayStatus(
          saved.surveyJobId,
        );
        debugPrint(
          '[IHM] checkpoint ${checkpoint.id} saved online and cached: '
          'auditStatus=${saved.auditStatus}',
        );
        return saved;
      } catch (error) {
        debugPrint(
          '[IHM] online checkpoint save failed; queued offline update: $error',
        );
      }
    }

    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();

    await _upsertCheckpointBase(db, checkpoint);
    await db.update(
      'ihm_checkpoints',
      {
        'isPchm': isPchm ? 1 : 0,
        'auditStatus': auditStatus,
        'remarks': remarks,
        'locationRemarks': locationRemarks,
        'synced': 0,
        'updatedAt': now,
      },
      where: 'id = ?',
      whereArgs: [checkpoint.id],
    );
    await SurveyJobOfflineService.refreshCachedIhmDisplayStatus(
      checkpoint.surveyJobId,
    );

    await _enqueue(
      entityType: 'checkpointDetails',
      entityLocalId: checkpoint.id,
      operation: 'update',
      payload: {
        'checkpointId': checkpoint.id,
        'isPchm': isPchm,
        'auditStatus': auditStatus,
        'remarks': remarks,
        'locationRemarks': locationRemarks,
      },
    );

    await syncPendingIhmData();
    return _getLocalCheckpoint(checkpoint.id);
  }

  static Future<IhmCheckpoint> saveFullCheckpoint(
    IhmCheckpoint checkpoint,
  ) async {
    if (kIsWeb) {
      return ApiService.updateIhmCheckpointDetails(checkpoint: checkpoint);
    }

    if (await isOnline) {
      try {
        final saved = await ApiService.updateIhmCheckpointDetails(
          checkpoint: checkpoint,
        );
        final db = await DatabaseHelper.instance.database;
        await _replaceLocalCheckpoint(db, saved, synced: 1);
        await SurveyJobOfflineService.refreshCachedIhmDisplayStatus(
          saved.surveyJobId,
        );
        debugPrint(
          '[IHM] full checkpoint ${checkpoint.id} saved online and cached: '
          'auditStatus=${saved.auditStatus}',
        );
        return saved;
      } catch (error) {
        debugPrint(
          '[IHM] online full checkpoint save failed; queued offline update: $error',
        );
      }
    }

    final db = await DatabaseHelper.instance.database;
    final values = checkpoint.toLocalMap()
      ..['synced'] = 0
      ..['updatedAt'] = DateTime.now().toIso8601String();
    await _upsertCheckpointBase(db, checkpoint);
    await db.update(
      'ihm_checkpoints',
      values,
      where: 'id = ?',
      whereArgs: [checkpoint.id],
    );
    await SurveyJobOfflineService.refreshCachedIhmDisplayStatus(
      checkpoint.surveyJobId,
    );
    await _enqueue(
      entityType: 'checkpointDetails',
      entityLocalId: checkpoint.id,
      operation: 'update',
      payload: {'checkpointId': checkpoint.id},
    );
    await syncPendingIhmData();
    return _getLocalCheckpoint(checkpoint.id);
  }

  static Future<IhmCheckpoint> saveCheckpointProcedure({
    required IhmCheckpoint checkpoint,
    required String procedureType,
  }) async {
    if (kIsWeb) {
      return ApiService.updateIhmCheckpointProcedure(
        checkpointId: checkpoint.id,
        procedureType: procedureType,
      );
    }

    final db = await DatabaseHelper.instance.database;
    final isVisual = procedureType.toLowerCase() == 'visual';

    await _upsertCheckpointBase(db, checkpoint);
    await db.update(
      'ihm_checkpoints',
      {
        'visualCheck': isVisual ? 'V' : '-',
        'samplingCheck': isVisual ? '-' : 'S',
        'synced': 0,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [checkpoint.id],
    );

    await _enqueue(
      entityType: 'checkpointProcedure',
      entityLocalId: checkpoint.id,
      operation: 'update',
      payload: {'checkpointId': checkpoint.id, 'procedureType': procedureType},
    );

    await syncPendingIhmData();
    return _getLocalCheckpoint(checkpoint.id);
  }

  static Future<List<IhmMarker>> getMarkers(int jobId, int areaId) async {
    if (kIsWeb) {
      return ApiService.fetchIhmMarkers(jobId);
    }

    if (await isOnline) {
      try {
        final markers = await ApiService.fetchIhmMarkers(jobId);
        await _cacheMarkers(jobId, markers);
        await syncPendingIhmData();
      } catch (_) {}
    }

    return getLocalMarkers(jobId);
  }

  static Future<List<IhmLayoutImage>> getLayouts(int jobId, int areaId) async {
    if (kIsWeb) {
      return ApiService.fetchIhmLayouts(jobId: jobId, areaId: areaId);
    }

    if (await isOnline) {
      try {
        final layouts = await ApiService.fetchIhmLayouts(
          jobId: jobId,
          areaId: areaId,
        );
        await _cacheLayouts(jobId, areaId, layouts);
      } catch (_) {}
    }

    return getLocalLayouts(jobId, areaId);
  }

  static Future<List<IhmLayoutImage>> getLocalLayouts(
    int jobId,
    int areaId,
  ) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'ihm_layout_images',
      where: 'surveyJobId = ? AND (ihmAreaId = ? OR isCommon = 1)',
      whereArgs: [jobId, areaId],
      orderBy: 'isCommon DESC, id ASC',
    );

    return rows.map(_layoutFromLocal).toList();
  }

  static Future<List<IhmMarker>> getLocalMarkers(int jobId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'ihm_markers',
      where: 'surveyJobId = ? AND deleted = 0',
      whereArgs: [jobId],
      orderBy: 'id ASC',
    );

    return rows.map(_markerFromLocal).toList();
  }

  static Future<IhmMarker> saveMarker({
    required IhmCheckpoint checkpoint,
    required String imagePath,
    required double xPercent,
    required double yPercent,
  }) async {
    if (kIsWeb) {
      return ApiService.saveIhmMarker(
        checkpoint: checkpoint,
        imagePath: imagePath,
        xPercent: xPercent,
        yPercent: yPercent,
      );
    }

    final db = await DatabaseHelper.instance.database;
    final markerLabel = _stableLocalMarkerLabel(checkpoint);
    final values = {
      'xPercent': xPercent,
      'yPercent': yPercent,
      'markerLabel': markerLabel,
      'deleted': 0,
      'synced': 0,
      'updatedAt': DateTime.now().toIso8601String(),
    };

    final existingRows = await db.query(
  'ihm_markers',
  columns: ['id', 'imagePath'],
  where:
      'surveyJobId = ? AND ihmAreaId = ? AND ihmCheckpointId = ? AND deleted = 0',
  whereArgs: [
    checkpoint.surveyJobId,
    checkpoint.ihmAreaId,
    checkpoint.id,
  ],
);

String norm(String? path) {
  final value = (path ?? '').trim();
  final parsed = Uri.tryParse(value);
  if (parsed != null && parsed.hasScheme) {
    return parsed.path.replaceFirst(RegExp(r'^/+'), '').toLowerCase();
  }
  return value
      .replaceFirst(RegExp(r'^https?://[^/]+', caseSensitive: false), '')
      .replaceFirst(RegExp(r'^/+'), '')
      .toLowerCase();
}

final existing = existingRows
    .where((row) => norm(row['imagePath']?.toString()) == norm(imagePath))
    .toList();

    final int localId;
    if (existing.isNotEmpty) {
      localId = _int(existing.first['id']);
      await db.update(
        'ihm_markers',
        values,
        where: 'id = ?',
        whereArgs: [localId],
      );
    } else {
      localId = await db.insert('ihm_markers', {
        'surveyJobId': checkpoint.surveyJobId,
        'ihmAreaId': checkpoint.ihmAreaId,
        'ihmCheckpointId': checkpoint.id,
        'imagePath': imagePath,
        ...values,
      });
    }

    await _enqueue(
      entityType: 'marker',
      entityLocalId: localId,
      operation: 'create',
      payload: {'localId': localId},
    );

    await syncPendingIhmData();
    final rows = await db.query(
      'ihm_markers',
      where: 'id = ?',
      whereArgs: [localId],
    );
    return _markerFromLocal(rows.first);
  }

  static String _stableLocalMarkerLabel(IhmCheckpoint checkpoint) {
    final code = checkpoint.sampleNo.trim();
    if (checkpoint.isSample && code.isNotEmpty) return code;
    if (checkpoint.isVisual &&
        code.toUpperCase().startsWith('V') &&
        code.length > 1) {
      return code;
    }
    if (checkpoint.isVisual) return 'V${checkpoint.id}';
    return code;
  }

  static Future<void> deleteMarker(IhmMarker marker) async {
    if (kIsWeb) {
      await ApiService.deleteIhmMarker(marker.id);
      return;
    }

    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'ihm_markers',
      columns: ['serverId'],
      where: 'id = ?',
      whereArgs: [marker.id],
      limit: 1,
    );
    final serverId = rows.isEmpty ? marker.id : _int(rows.first['serverId']);

    await db.update(
      'ihm_markers',
      {
        'deleted': 1,
        'synced': 0,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [marker.id],
    );

    await _enqueue(
      entityType: 'marker',
      entityLocalId: marker.id,
      operation: 'delete',
      payload: {'localId': marker.id, 'serverId': serverId},
    );

    await syncPendingIhmData();
  }

static Future<List<IhmSamplingPhoto>> getCheckpointPhotos(
  IhmCheckpoint checkpoint,
) async {
  if (kIsWeb) {
    return ApiService.fetchCheckpointPhotos(checkpoint.id);
  }

  if (await isOnline) {
    try {
      final photos = await ApiService.fetchCheckpointPhotos(checkpoint.id);

      try {
        await _cachePhotos(checkpoint, photos);
      } catch (_) {
        // Cache failure should not hide server images from mobile UI.
      }

      return photos;
    } catch (_) {
      // Offline/fetch failed: fall back to local cache.
    }
  }

  return getLocalCheckpointPhotos(checkpoint.id);
}

  static Future<List<IhmSamplingPhoto>> getLocalCheckpointPhotos(
    int checkpointId,
  ) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'ihm_sampling_photos',
      where: 'ihmCheckpointId = ? AND deleted = 0',
      whereArgs: [checkpointId],
      orderBy: 'id DESC',
    );

    return rows.map(_photoFromLocal).toList();
  }

  static Future<IhmSamplingPhoto> saveCheckpointPhoto({
    required IhmCheckpoint checkpoint,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    if (kIsWeb) {
      return ApiService.uploadCheckpointPhoto(
        checkpoint: checkpoint,
        fileBytes: fileBytes,
        fileName: fileName,
      );
    }

    if (await isOnline) {
      try {
        final uploaded = await ApiService.uploadCheckpointPhoto(
          checkpoint: checkpoint,
          fileBytes: fileBytes,
          fileName: fileName,
        );
        try {
          await _cachePhotos(checkpoint, [uploaded]);
        } catch (_) {}

        return uploaded;
      } catch (_) {
        // Keep the photo locally if the device has a network but the API call fails.
      }
    }

    final localPath = await _writeLocalPhoto(fileBytes, fileName);
    final db = await DatabaseHelper.instance.database;

    final localId = await db.insert('ihm_sampling_photos', {
      'surveyJobId': checkpoint.surveyJobId,
      'ihmAreaId': checkpoint.ihmAreaId,
      'ihmCheckpointId': checkpoint.id,
      'filePath': localPath,
      'localFilePath': localPath,
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


    final rows = await db.query(
      'ihm_sampling_photos',
      where: 'id = ?',
      whereArgs: [localId],
    );
    return _photoFromLocal(rows.first);
  }

  static Future<void> deleteCheckpointPhoto(IhmSamplingPhoto photo) async {
    if (kIsWeb) {
      await ApiService.deleteCheckpointPhoto(photo.id);
      return;
    }

    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'ihm_sampling_photos',
      columns: ['serverId'],
      where: 'id = ?',
      whereArgs: [photo.id],
      limit: 1,
    );
    final serverId = rows.isEmpty ? photo.id : _int(rows.first['serverId']);

    await db.update(
      'ihm_sampling_photos',
      {
        'deleted': 1,
        'synced': 0,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [photo.id],
    );

    await _enqueue(
      entityType: 'photo',
      entityLocalId: photo.id,
      operation: 'delete',
      payload: {'localId': photo.id, 'serverId': serverId},
    );

    await syncPendingIhmData();
  }

  static Future<void> syncPendingIhmData() async {
    if (kIsWeb) return;
    if (_syncing || !(await isOnline)) return;

    _syncing = true;
    final db = await DatabaseHelper.instance.database;

    try {
      final queue = await db.query(
        'ihm_sync_queue',
        where: 'status IN (0, 2)',
        orderBy: "CASE WHEN entityType = 'photo' THEN 1 ELSE 0 END, id ASC",
      );

      for (final item in queue) {
        final queueId = _int(item['id']);
        try {
          await db.update(
            'ihm_sync_queue',
            {'status': -1, 'updatedAt': DateTime.now().toIso8601String()},
            where: 'id = ?',
            whereArgs: [queueId],
          );

          await _syncQueueItem(db, item);

          await db.update(
            'ihm_sync_queue',
            {
              'status': 1,
              'lastError': null,
              'updatedAt': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [queueId],
          );
        } catch (e) {
          await db.update(
            'ihm_sync_queue',
            {
              'status': 2,
              'lastError': e.toString(),
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
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM ihm_sync_queue WHERE status IN (0, 2, -1)',
    );

    return _int(result.first['count']);
  }

  static Future<int> failedSyncCount() async {
    if (kIsWeb) return 0;

    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM ihm_sync_queue WHERE status = 2',
    );

    return _int(result.first['count']);
  }

  static Future<int> cacheJobForOffline(SurveyJob job) async {
    if (kIsWeb || job.id <= 0 || !(await isOnline)) return 0;

    var cachedJobs = 0;
    final hasVscpChecklist =
        (job.vscpChecklistFilePath ?? '').trim().isNotEmpty;

    if (hasVscpChecklist) {
      await cacheVscpChecklist(
        jobId: job.id,
        fileName: job.vscpChecklistFileName,
        serverPath: job.vscpChecklistFilePath,
      );
    }

    final areas = await ApiService.fetchIhmAreasWithCheckpoints(job.id);
    await cacheAreas(job.id, areas);

    try {
      final markers = await ApiService.fetchIhmMarkers(job.id);
      await _cacheMarkers(job.id, markers);
    } catch (_) {}

    for (final area in areas) {
      try {
        final layouts = await ApiService.fetchIhmLayouts(
          jobId: job.id,
          areaId: area.id,
        );
        await _cacheLayouts(job.id, area.id, layouts);
      } catch (_) {}

      for (final checkpoint in area.checkpoints) {
        try {
          final photos = await ApiService.fetchCheckpointPhotos(checkpoint.id);
          await _cachePhotos(checkpoint, photos);
        } catch (_) {}
      }
    }

    cachedJobs++;
    return cachedJobs;
  }

  static Future<void> cacheVscpChecklist({
    required int jobId,
    required String? fileName,
    required String? serverPath,
  }) async {
    if (kIsWeb || !(await isOnline)) return;

    final pathKey = (serverPath ?? '/ihm-survey/jobs/$jobId/vscp-checklist')
        .trim();
    if (pathKey.isEmpty) return;

    final db = await DatabaseHelper.instance.database;
    final existing = await db.query(
      'ihm_cached_files',
      columns: ['localPath'],
      where: 'surveyJobId = ? AND fileType = ? AND serverPath = ?',
      whereArgs: [jobId, 'vscpChecklist', pathKey],
      limit: 1,
    );
    final existingLocalPath = existing.isEmpty
        ? null
        : existing.first['localPath']?.toString();

    if (existingLocalPath != null &&
        existingLocalPath.isNotEmpty &&
        await _canReadLocalFile(existingLocalPath)) {
      return;
    }

    try {
      final bytes = await ApiService.downloadVscpChecklist(jobId);
      if (bytes.isEmpty) return;

      final localPath = await writeIhmLocalFile(
        bytes,
        _safeFileName(
          (fileName ?? '').trim().isEmpty
              ? 'vscp-checklist-$jobId.xlsx'
              : fileName!.trim(),
        ),
        folderName: 'ihm_vscp_checklists',
      );
      final now = DateTime.now().toIso8601String();

      await db.insert(
        'ihm_cached_files',
        {
          'surveyJobId': jobId,
          'fileType': 'vscpChecklist',
          'serverPath': pathKey,
          'localPath': localPath,
          'fileName': fileName,
          'updatedAt': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  static Future<String?> getCachedVscpChecklistLocalPath(int jobId) async {
    if (kIsWeb) return null;

    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'ihm_cached_files',
      columns: ['localPath'],
      where: 'surveyJobId = ? AND fileType = ?',
      whereArgs: [jobId, 'vscpChecklist'],
      orderBy: 'updatedAt DESC',
      limit: 1,
    );

    if (rows.isEmpty) return null;
    final localPath = rows.first['localPath']?.toString();
    if (localPath == null ||
        localPath.isEmpty ||
        !(await _canReadLocalFile(localPath))) {
      return null;
    }
    return localPath;
  }

  static Future<void> clearLocalUserData() async {
    if (kIsWeb) return;

    final db = await DatabaseHelper.instance.database;
    for (final table in [
      'survey_jobs_cache',
      'ihm_areas',
      'ihm_checkpoints',
      'ihm_markers',
      'ihm_sampling_photos',
      'ihm_layout_images',
      'ihm_sync_queue',
      'ihm_cached_files',
      'sync_metadata',
    ]) {
      try {
        await db.delete(table);
      } catch (error) {
        debugPrint('Logout: failed to clear $table: $error');
      }
    }

    try {
      await clearIhmLocalFiles();
    } catch (error) {
      debugPrint('Logout: failed to clear IHM local files: $error');
    }
  }

  static Future<void> _syncQueueItem(
    Database db,
    Map<String, Object?> item,
  ) async {
    final entityType = item['entityType']?.toString();
    final operation = item['operation']?.toString();
    final payload = jsonDecode(item['payloadJson']?.toString() ?? '{}');

    if (entityType == 'checkpointDetails') {
      final checkpoint = await _getLocalCheckpoint(
        _int(payload['checkpointId']),
      );
      final saved = await ApiService.updateIhmCheckpointDetails(
        checkpoint: checkpoint,
      );
      await _replaceLocalCheckpoint(db, saved, synced: 1);
      await _markCheckpointSynced(db, _int(payload['checkpointId']));
      return;
    }

    if (entityType == 'checkpointProcedure') {
      await ApiService.updateIhmCheckpointProcedure(
        checkpointId: _int(payload['checkpointId']),
        procedureType: payload['procedureType']?.toString() ?? 'Visual',
      );
      await _markCheckpointSynced(db, _int(payload['checkpointId']));
      return;
    }

    if (entityType == 'marker') {
      final localId = _int(payload['localId']);
      if (operation == 'delete') {
        final serverId = _int(payload['serverId']);
        if (serverId > 0) await ApiService.deleteIhmMarker(serverId);
        await db.delete('ihm_markers', where: 'id = ?', whereArgs: [localId]);
        return;
      }

      final rows = await db.query(
        'ihm_markers',
        where: 'id = ?',
        whereArgs: [localId],
      );
      if (rows.isEmpty) return;

      final marker = _markerFromLocal(rows.first);
      final synced = await ApiService.saveIhmMarker(
        checkpoint: _checkpointForRelatedUpload(
          surveyJobId: marker.surveyJobId,
          ihmAreaId: marker.ihmAreaId ?? 0,
          checkpointId: marker.ihmCheckpointId ?? 0,
          sampleNo: marker.markerLabel ?? '',
        ),
        imagePath: marker.imagePath,
        xPercent: marker.xPercent,
        yPercent: marker.yPercent,
      );

      await db.update(
        'ihm_markers',
        {
          'serverId': synced.id,
          'synced': 1,
          'updatedAt': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [localId],
      );
      return;
    }

    if (entityType == 'photo') {
      final localId = _int(payload['localId']);
      if (operation == 'delete') {
        final serverId = _int(payload['serverId']);
        if (serverId > 0) await ApiService.deleteCheckpointPhoto(serverId);
        await db.delete(
          'ihm_sampling_photos',
          where: 'id = ?',
          whereArgs: [localId],
        );
        return;
      }

      final rows = await db.query(
        'ihm_sampling_photos',
        where: 'id = ? AND deleted = 0',
        whereArgs: [localId],
        limit: 1,
      );
      if (rows.isEmpty) return;

      final photo = _photoFromLocal(rows.first);
      final checkpointId = _int(rows.first['ihmCheckpointId']);
      final checkpoint = await _getLocalCheckpoint(checkpointId);
      final localPath = photo.localFilePath ?? photo.filePath;
      final uploaded = await ApiService.uploadCheckpointPhoto(
        checkpoint: checkpoint,
        fileBytes: await readIhmLocalPhoto(localPath),
        fileName: localPath.split(RegExp(r'[\\/]')).last,
      );

   await db.delete(
  'ihm_sampling_photos',
  where: '(serverId = ? OR id = ?) AND id != ?',
  whereArgs: [uploaded.id, uploaded.id, localId],
);

await db.update(
  'ihm_sampling_photos',
  uploaded.toLocalMap(
    surveyJobId: checkpoint.surveyJobId,
    checkpointId: checkpoint.id,
    areaId: checkpoint.ihmAreaId,
    localId: localId,
    localFilePath: localPath,
    synced: 1,
  ),
  where: 'id = ?',
  whereArgs: [localId],
);
return;
    }
  }

  static Future<void> _cacheMarkers(int jobId, List<IhmMarker> markers) async {
    final db = await DatabaseHelper.instance.database;
    for (final marker in markers) {
      final existing = await db.query(
        'ihm_markers',
        where: 'id = ? AND synced = 0',
        whereArgs: [marker.id],
      );
      if (existing.isNotEmpty) continue;

      await db.insert(
        'ihm_markers',
        marker.toLocalMap(localId: marker.id),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  static Future<void> _cachePhotos(
    IhmCheckpoint checkpoint,
    List<IhmSamplingPhoto> photos,
  ) async {
    final db = await DatabaseHelper.instance.database;
    for (final photo in photos) {
      final existing = await db.query(
        'ihm_sampling_photos',
        columns: ['filePath', 'localFilePath'],
        where: 'id = ?',
        whereArgs: [photo.id],
        limit: 1,
      );
      final existingFilePath = existing.isEmpty
          ? null
          : existing.first['filePath']?.toString();
      final existingLocalPath =
          existingFilePath == photo.filePath && existing.isNotEmpty
          ? existing.first['localFilePath']?.toString()
          : null;
      final localPath = await _ensureCachedRemoteFile(
        remotePath: photo.filePath,
        existingLocalPath: existingLocalPath,
        fallbackFileName: 'checkpoint_photo_${photo.id}.jpg',
        folderName: 'ihm_sampling_photos',
      );

      await db.insert(
        'ihm_sampling_photos',
        photo.toLocalMap(
          surveyJobId: checkpoint.surveyJobId,
          checkpointId: checkpoint.id,
          areaId: checkpoint.ihmAreaId,
          localId: photo.id,
          localFilePath: localPath,
        ),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  static Future<void> _cacheLayouts(
    int jobId,
    int areaId,
    List<IhmLayoutImage> layouts,
  ) async {
    final db = await DatabaseHelper.instance.database;
    final layoutIds = layouts.map((layout) => layout.id).toSet();
    if (layoutIds.isEmpty) {
      await db.delete(
        'ihm_layout_images',
        where: 'surveyJobId = ? AND (ihmAreaId = ? OR isCommon = 1)',
        whereArgs: [jobId, areaId],
      );
    } else {
      final placeholders = layoutIds.map((_) => '?').join(',');
      await db.delete(
        'ihm_layout_images',
        where:
            'surveyJobId = ? AND (ihmAreaId = ? OR isCommon = 1) AND id NOT IN ($placeholders)',
        whereArgs: [jobId, areaId, ...layoutIds],
      );
    }

    for (final layout in layouts) {
      final existing = await db.query(
        'ihm_layout_images',
        columns: ['filePath', 'localFilePath'],
        where: 'id = ?',
        whereArgs: [layout.id],
        limit: 1,
      );
      final existingFilePath = existing.isEmpty
          ? null
          : existing.first['filePath']?.toString();
      final existingLocalPath =
          existingFilePath == layout.filePath && existing.isNotEmpty
          ? existing.first['localFilePath']?.toString()
          : null;
      final localPath = await _ensureCachedRemoteFile(
        remotePath: layout.filePath,
        existingLocalPath: existingLocalPath,
        fallbackFileName: layout.originalFileName.isEmpty
            ? 'layout_${layout.id}.jpg'
            : layout.originalFileName,
        folderName: 'ihm_layout_images',
      );

      await db.insert(
        'ihm_layout_images',
        {
          'id': layout.id,
          'surveyJobId': jobId,
          'ihmAreaId': layout.ihmAreaId,
          'filePath': layout.filePath,
          'localFilePath': localPath,
          'originalFileName': layout.originalFileName,
          'contentType': layout.contentType,
          'isCommon': layout.isCommon ? 1 : 0,
          'synced': 1,
          'updatedAt': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  static Future<void> _upsertCheckpointBase(
    Database db,
    IhmCheckpoint checkpoint,
  ) async {
    await db.insert(
      'ihm_checkpoints',
      checkpoint.toLocalMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  static Future<void> _replaceLocalCheckpoint(
    Database db,
    IhmCheckpoint checkpoint, {
    required int synced,
  }) async {
    final values = checkpoint.toLocalMap()
      ..['synced'] = synced
      ..['updatedAt'] = DateTime.now().toIso8601String();

    await db.insert(
      'ihm_checkpoints',
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<IhmCheckpoint> _getLocalCheckpoint(int checkpointId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'ihm_checkpoints',
      where: 'id = ?',
      whereArgs: [checkpointId],
      limit: 1,
    );

    if (rows.isEmpty) throw Exception('Checkpoint not found locally.');
    return _checkpointFromLocal(rows.first);
  }

  static Future<void> _markCheckpointSynced(
    Database db,
    int checkpointId,
  ) async {
    await db.update(
      'ihm_checkpoints',
      {'synced': 1, 'updatedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [checkpointId],
    );
  }

  static Future<void> _enqueue({
    required String entityType,
    required int entityLocalId,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();

    await db.insert('ihm_sync_queue', {
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

  static Future<String> _writeLocalPhoto(
    Uint8List bytes,
    String fileName,
  ) async {
    return writeIhmLocalPhoto(bytes, fileName);
  }

  static IhmCheckpoint _checkpointFromLocal(Map<String, Object?> row) {
    return IhmCheckpoint.fromJson({
      'id': row['id'],
      'sampleNo': row['sampleNo'],
      'description': row['description'],
      'tableType': row['tableType'],
      'table_A_B': row['tableAB'],
      'location': row['location'],
      'equipmentName': row['equipmentName'],
      'component': row['component'],
      'hazardousMaterial': row['hazardousMaterial'],
      'samplingCheck': row['samplingCheck'],
      'visualCheck': row['visualCheck'],
      'checkResult': row['checkResult'],
      'result': row['result'],
      'auditStatus': row['auditStatus'],
      'remarks': row['remarks'],
      'documentAnalysisResult': row['documentAnalysisResult'],
      'quantityUnitKg': row['quantityUnitKg'],
      'quantityNo': row['quantityNo'],
      'quantityTotalKg': row['quantityTotalKg'],
      'manufacturerBrandName': row['manufacturerBrandName'],
      'surveyJobId': row['surveyJobId'],
      'ihmAreaId': row['ihmAreaId'],
      'isPchm': row['isPchm'],
      'locationRemarks': row['locationRemarks'],
    });
  }

  static IhmMarker _markerFromLocal(Map<String, Object?> row) {
    return IhmMarker(
      id: _int(row['id']),
      surveyJobId: _int(row['surveyJobId']),
      ihmAreaId: row['ihmAreaId'] == null ? null : _int(row['ihmAreaId']),
      ihmCheckpointId: row['ihmCheckpointId'] == null
          ? null
          : _int(row['ihmCheckpointId']),
      imagePath: row['imagePath']?.toString() ?? '',
      xPercent: _double(row['xPercent']),
      yPercent: _double(row['yPercent']),
      markerLabel: row['markerLabel']?.toString(),
    );
  }

  static IhmLayoutImage _layoutFromLocal(Map<String, Object?> row) {
    return IhmLayoutImage(
      id: _int(row['id']),
      ihmAreaId: row['ihmAreaId'] == null ? null : _int(row['ihmAreaId']),
      filePath: row['filePath']?.toString() ?? '',
      originalFileName: row['originalFileName']?.toString() ?? 'Layout',
      contentType: row['contentType']?.toString(),
      isCommon: _int(row['isCommon']) == 1,
      localFilePath: row['localFilePath']?.toString(),
    );
  }

 static IhmSamplingPhoto _photoFromLocal(Map<String, Object?> row) {
  return IhmSamplingPhoto(
    id: _int(row['serverId']) > 0 ? _int(row['serverId']) : _int(row['id']),
    filePath: row['filePath']?.toString() ?? '',
    localFilePath: row['localFilePath']?.toString(),
    caption: row['caption']?.toString(),
    showInAppendixThree: _int(row['showInAppendixThree']) == 1,
    appendixThreeSortOrder: _int(row['appendixThreeSortOrder']),
    appendixThreeEditedFilePath: row['appendixThreeEditedFilePath']?.toString(),
    appendixThreeWidth: row['appendixThreeWidth'] == null
        ? null
        : _int(row['appendixThreeWidth']),
    appendixThreeHeight: row['appendixThreeHeight'] == null
        ? null
        : _int(row['appendixThreeHeight']),
  );
}

  static IhmCheckpoint _checkpointForRelatedUpload({
    required int surveyJobId,
    required int ihmAreaId,
    required int checkpointId,
    required String sampleNo,
  }) {
    return IhmCheckpoint(
      id: checkpointId,
      sampleNo: sampleNo,
      surveyJobId: surveyJobId,
      ihmAreaId: ihmAreaId,
    );
  }

  static int _int(Object? value) => int.tryParse(value?.toString() ?? '') ?? 0;

  static double _double(Object? value) =>
      double.tryParse(value?.toString() ?? '') ?? 0;

  static Future<String?> _ensureCachedRemoteFile({
    required String remotePath,
    required String? existingLocalPath,
    required String fallbackFileName,
    required String folderName,
  }) async {
    if (remotePath.trim().isEmpty || remotePath.toLowerCase().endsWith('.pdf')) {
      return existingLocalPath;
    }

    if (existingLocalPath != null &&
        existingLocalPath.isNotEmpty &&
        await _canReadLocalFile(existingLocalPath)) {
      return existingLocalPath;
    }

    try {
      final response = await http.get(Uri.parse(ApiService.fileUrl(remotePath)));
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          response.bodyBytes.isEmpty) {
        return existingLocalPath;
      }

      return writeIhmLocalFile(
        response.bodyBytes,
        _remoteFileName(remotePath, fallbackFileName),
        folderName: folderName,
      );
    } catch (_) {
      return existingLocalPath;
    }
  }

  static Future<bool> _canReadLocalFile(String path) async {
    try {
      final bytes = await readIhmLocalPhoto(path);
      return bytes.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static String _remoteFileName(String remotePath, String fallbackFileName) {
    final parsed = Uri.tryParse(remotePath);
    final name = parsed == null || parsed.pathSegments.isEmpty
        ? ''
        : parsed.pathSegments.last;
    return name.trim().isEmpty ? fallbackFileName : name;
  }

  static String _safeFileName(String fileName) {
    return fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }
}
