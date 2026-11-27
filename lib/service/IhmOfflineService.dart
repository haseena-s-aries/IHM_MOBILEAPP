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

  // Reused for file downloads so connections (TLS handshakes) are kept alive
  // instead of opening a new connection for every image.
  static final http.Client _downloadClient = http.Client();

  static const int _parallelFetchLimit = 10;

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
            // Unsynced local edits win, but still take the Excel row order.
            await txn.update(
              'ihm_checkpoints',
              {'sourceRowNumber': checkpoint.sourceRowNumber},
              where: 'id = ?',
              whereArgs: [checkpoint.id],
            );
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
    final checkpointPlaceholders = latestCheckpointIds
        .map((_) => '?')
        .join(',');

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
      await txn.delete(
        'ihm_area_layouts',
        where: 'surveyJobId = ?',
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
        'ihm_area_layouts',
        where: 'surveyJobId = ? AND ihmAreaId NOT IN ($areaPlaceholders)',
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
        // Same order as the uploaded Excel sheet (and the server). Sorting by
        // sampleNo put every S above every V and made a card jump when it
        // was changed between S and V.
        orderBy:
            'CASE WHEN sourceRowNumber IS NULL THEN 1 ELSE 0 END, '
            'sourceRowNumber ASC, id ASC',
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
    // Sample / visual numbers (S01, V01, ...) are entered by the surveyor and
    // saved exactly as typed. They are no longer generated automatically.
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
    // Never clear the Excel row order with a copy that lacks it.
    if (values['sourceRowNumber'] == null) values.remove('sourceRowNumber');
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

  /// Saves a sample / visual number typed by the surveyor (e.g. S01, V01).
  /// Works offline: the change is queued and sent on the next sync.
  static Future<IhmCheckpoint> saveSampleNumber({
    required IhmCheckpoint checkpoint,
    required String sampleNo,
  }) {
    return saveFullCheckpoint(
      checkpoint.copyWith(sampleNo: sampleNo.trim().toUpperCase()),
    );
  }

  /// Whether another checkpoint of the same job already uses [sampleNo]
  /// (checked against the data on this phone).
  static Future<bool> isSampleNumberUsed({
    required int jobId,
    required String sampleNo,
    required int excludeCheckpointId,
  }) async {
    if (kIsWeb) return false;
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'ihm_checkpoints',
      columns: ['id'],
      where: 'surveyJobId = ? AND id != ? AND UPPER(TRIM(sampleNo)) = ?',
      whereArgs: [jobId, excludeCheckpointId, sampleNo.trim().toUpperCase()],
      limit: 1,
    );
    return rows.isNotEmpty;
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
    final currentCode = checkpoint.sampleNo.trim();
    final procedureCode = isVisual ? 'V' : 'S';
    final updatedCode = RegExp(r'^[SV](\d+)$', caseSensitive: false).hasMatch(currentCode)
        ? '$procedureCode${currentCode.substring(1)}'
        : (currentCode.toUpperCase() == 'S' || currentCode.toUpperCase() == 'V'
            ? procedureCode
            : currentCode);

    await _upsertCheckpointBase(db, checkpoint);
    await db.update(
      'ihm_checkpoints',
      {
        'sampleNo': updatedCode,
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
    final saved = await _getLocalCheckpoint(checkpoint.id);
    // Return the changed procedure fields as well as the locally persisted
    // record so the card immediately changes from S↔V while offline.
    return saved.copyWith(
      sampleNo: updatedCode,
      samplingCheck: isVisual ? '-' : 'S',
      visualCheck: isVisual ? 'V' : '-',
    );
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

    // Preferred: the exact per-area assignment captured from the server's
    // /areas/{areaId}/layouts response (handles machinery layouts that have
    // no ihmAreaId and are not flagged as common).
    final mappedRows = await db.rawQuery(
      '''
      SELECT l.* FROM ihm_area_layouts m
      INNER JOIN ihm_layout_images l ON l.id = m.layoutId
      WHERE m.surveyJobId = ? AND m.ihmAreaId = ?
      ORDER BY m.sortOrder ASC, l.id ASC
      ''',
      [jobId, areaId],
    );
    if (mappedRows.isNotEmpty) {
      return mappedRows.map(_layoutFromLocal).toList();
    }

    // Legacy cache (synced before the mapping table existed): mirror the
    // server priority - the area's own layout first, then the common layout.
    final areaRows = await db.query(
      'ihm_layout_images',
      where: 'surveyJobId = ? AND ihmAreaId = ?',
      whereArgs: [jobId, areaId],
      orderBy: 'id DESC',
    );
    if (areaRows.isNotEmpty) {
      return areaRows.map(_layoutFromLocal).toList();
    }

    final commonRows = await db.query(
      'ihm_layout_images',
      where: 'surveyJobId = ? AND isCommon = 1',
      whereArgs: [jobId],
      orderBy: 'id DESC',
    );
    return commonRows.map(_layoutFromLocal).toList();
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
      whereArgs: [checkpoint.surveyJobId, checkpoint.ihmAreaId, checkpoint.id],
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
      List<IhmSamplingPhoto> photos;
      final fetchedAt = DateTime.now();
      try {
        photos = await ApiService.fetchCheckpointPhotos(checkpoint.id);
      } catch (_) {
        // Fetch failed: fall back to local cache.
        return getLocalCheckpointPhotos(checkpoint.id);
      }

      try {
        await _cachePhotos(
          checkpoint,
          photos,
          isCompleteList: true,
          listFetchedAt: fetchedAt,
        );
      } catch (_) {
        // Cache failure must not hide images: show server photos plus any
        // photos still waiting to upload from this device.
        final pending = (await getLocalCheckpointPhotos(
          checkpoint.id,
        )).where((photo) => photo.id < 0).toList();
        return [...pending, ...photos];
      }
    }

    // The local table holds both server photos and photos taken offline that
    // are still waiting to upload, so the full set is always shown.
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
      // Pending offline photos (negative ids, newest = most negative) first,
      // then server photos newest first.
      orderBy: 'CASE WHEN id < 0 THEN 0 ELSE 1 END, '
          'CASE WHEN id < 0 THEN id ELSE -id END',
    );

    // Older app versions could store the same server photo twice (once under
    // the local id used while offline and once under the server id).
    final seenServerIds = <int>{};
    final photos = <IhmSamplingPhoto>[];
    for (final row in rows) {
      final serverId = _int(row['serverId']);
      if (serverId > 0 && !seenServerIds.add(serverId)) continue;
      photos.add(_photoFromLocal(row));
    }
    return photos;
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

    // Negative ids keep offline photos out of the server id range, so caching
    // server photos can never overwrite a photo that has not uploaded yet.
    final localId = await _nextLocalPhotoId(db);
    await db.insert('ihm_sampling_photos', {
      'id': localId,
      'serverId': null,
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

    // Photo taken offline and never uploaded: drop the pending upload, there
    // is nothing to delete on the server.
    if (rows.isNotEmpty && serverId <= 0) {
      final pendingUploads = await db.query(
        'ihm_sync_queue',
        columns: ['id'],
        where:
            "entityType = 'photo' AND operation = 'upload' AND entityLocalId = ? "
            'AND status IN (0, 2)',
        whereArgs: [photo.id],
      );
      if (pendingUploads.isNotEmpty) {
        await db.delete(
          'ihm_sync_queue',
          where:
              "entityType = 'photo' AND operation = 'upload' AND entityLocalId = ? "
              'AND status IN (0, 2)',
          whereArgs: [photo.id],
        );
        await db.delete(
          'ihm_sampling_photos',
          where: 'id = ?',
          whereArgs: [photo.id],
        );
        return;
      }
    }

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

  static Future<void>? _pendingSyncRun;

  /// Uploads queued offline changes. When a run is already in progress, screens
  /// return immediately, while the main sync passes [waitIfRunning] so it does
  /// not report "done" while photos are still uploading.
  static Future<void> syncPendingIhmData({
    void Function(int processed, int total)? onProgress,
    bool waitIfRunning = false,
  }) async {
    if (kIsWeb) return;
    final running = _pendingSyncRun;
    if (running != null) {
      if (waitIfRunning) await running;
      return;
    }
    if (!(await isOnline)) return;
    final startedMeanwhile = _pendingSyncRun;
    if (startedMeanwhile != null) {
      if (waitIfRunning) await startedMeanwhile;
      return;
    }

    final run = _runPendingIhmSync(onProgress: onProgress);
    _pendingSyncRun = run;
    try {
      await run;
    } finally {
      if (identical(_pendingSyncRun, run)) _pendingSyncRun = null;
    }
  }

  static Future<void> _runPendingIhmSync({
    void Function(int processed, int total)? onProgress,
  }) async {
    final db = await DatabaseHelper.instance.database;

    try {
      final queue = await db.query(
        'ihm_sync_queue',
        where: 'status IN (0, 2)',
        orderBy: "CASE WHEN entityType = 'photo' THEN 1 ELSE 0 END, id ASC",
      );
      final total = queue.length;
      var processed = 0;
      onProgress?.call(processed, total);

      // Keep checkpoint/marker updates ordered, but upload photos in small
      // parallel batches. This avoids the very slow one-photo-at-a-time path
      // while limiting server and device pressure.
      for (var start = 0; start < queue.length;) {
        final isPhoto = queue[start]['entityType']?.toString() == 'photo';
        if (!isPhoto) {
          await _syncQueueItemWithRetry(db, queue[start]);
          processed++;
          onProgress?.call(processed, total);
          start++;
          continue;
        }

        final batch = <Map<String, Object?>>[];
        while (start < queue.length &&
            queue[start]['entityType']?.toString() == 'photo' &&
            batch.length < 6) {
          batch.add(queue[start]);
          start++;
        }

        await Future.wait(
          batch.map((item) async {
            await _syncQueueItemWithRetry(db, item);
            processed++;
            onProgress?.call(processed, total);
          }),
        );
      }
    } finally {
      // Run bookkeeping is handled by syncPendingIhmData.
    }
  }

  static Future<bool> _syncQueueItemWithRetry(
    Database db,
    Map<String, Object?> item,
  ) async {
    final queueId = _int(item['id']);
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
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
        return true;
      } catch (error) {
        lastError = error;
        debugPrint(
          '[IHM sync] queueId=$queueId entity=${item['entityType']} '
          'attempt=${attempt + 1}/3 failed: $error',
        );
        if (attempt < 2 && await isOnline) {
          await Future<void>.delayed(
            Duration(milliseconds: 300 * (attempt + 1)),
          );
        }
      }
    }

    await db.update(
      'ihm_sync_queue',
      {
        'status': 2,
        'lastError': lastError?.toString() ?? 'Sync failed',
        'retryCount': _int(item['retryCount']) + 1,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [queueId],
    );
    debugPrint(
      '[IHM sync] permanently failed queueId=$queueId '
      'entity=${item['entityType']} error=$lastError',
    );
    return false;
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
    final failures = <String>[];
    final hasVscpChecklist = (job.vscpChecklistFilePath ?? '')
        .trim()
        .isNotEmpty;

    if (hasVscpChecklist) {
      try {
        await cacheVscpChecklist(
          jobId: job.id,
          fileName: job.vscpChecklistFileName,
          serverPath: job.vscpChecklistFilePath,
        );
      } catch (error) {
        failures.add('VSCP Checklist: $error');
      }
    }

    final areas = await ApiService.fetchIhmAreasWithCheckpoints(job.id);
    await cacheAreas(job.id, areas);

    final markerTask = () async {
      try {
        final markers = await ApiService.fetchIhmMarkers(job.id);
        await _cacheMarkers(job.id, markers);
      } catch (error) {
        failures.add('Markers: $error');
      }
    }();

    // Prefer the bulk endpoints (one request per job). Older servers return
    // 404 for them, in which case fall back to one request per area /
    // checkpoint.
    Map<int, List<IhmLayoutImage>>? bulkLayouts;
    try {
      bulkLayouts = await ApiService.fetchIhmAreaLayouts(job.id);
    } catch (error) {
      debugPrint('[IHM sync] bulk layouts failed for job ${job.id}: $error');
    }

    Map<int, List<IhmSamplingPhoto>>? bulkPhotos;
    final photosFetchedAt = DateTime.now();
    try {
      bulkPhotos = await ApiService.fetchJobCheckpointPhotos(job.id);
    } catch (error) {
      debugPrint('[IHM sync] bulk photos failed for job ${job.id}: $error');
    }

    final layoutTasks = areas.map<Future<void> Function()>((area) => () async {
      try {
        final layouts =
            bulkLayouts?[area.id] ??
            (bulkLayouts != null
                ? const <IhmLayoutImage>[]
                : await ApiService.fetchIhmLayouts(
                    jobId: job.id,
                    areaId: area.id,
                  ));
        await _cacheLayouts(job.id, area.id, layouts, failures: failures);
      } catch (error) {
        failures.add('Layout ${area.areaName}: $error');
      }
    }).toList();

    final photoTasks = areas
        .expand((area) => area.checkpoints)
        .map<Future<void> Function()>((checkpoint) => () async {
      try {
        final photos =
            bulkPhotos?[checkpoint.id] ??
            (bulkPhotos != null
                ? const <IhmSamplingPhoto>[]
                : await ApiService.fetchCheckpointPhotos(checkpoint.id));
        await _cachePhotos(
          checkpoint,
          photos,
          failures: failures,
          isCompleteList: true,
          listFetchedAt: photosFetchedAt,
        );
      } catch (error) {
        failures.add('Photos ${checkpoint.sampleNo}: $error');
      }
    }).toList();

    await markerTask;
    await _runInBatches(layoutTasks, _parallelFetchLimit);
    await _runInBatches(photoTasks, _parallelFetchLimit);

    cachedJobs++;
    await SurveyJobOfflineService.refreshCachedIhmDisplayStatus(job.id);

    if (failures.isNotEmpty) {
      throw IhmOfflineCacheException(job.id, failures);
    }

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

    final bytes = await ApiService.downloadVscpChecklist(jobId);
    if (bytes.isEmpty) {
      throw Exception('Downloaded checklist was empty.');
    }

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

    await db.insert('ihm_cached_files', {
      'surveyJobId': jobId,
      'fileType': 'vscpChecklist',
      'serverPath': pathKey,
      'localPath': localPath,
      'fileName': fileName,
      'updatedAt': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
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
      'ihm_area_layouts',
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
        var serverId = _int(payload['serverId']);
        if (serverId <= 0) {
          // The photo may have been uploaded after the delete was queued.
          final current = await db.query(
            'ihm_sampling_photos',
            columns: ['serverId'],
            where: 'id = ?',
            whereArgs: [localId],
            limit: 1,
          );
          if (current.isNotEmpty) serverId = _int(current.first['serverId']);
        }
        if (serverId > 0) await ApiService.deleteCheckpointPhoto(serverId);
        await db.delete(
          'ihm_sampling_photos',
          where: 'id = ? OR (serverId = ? AND serverId > 0)',
          whereArgs: [localId, serverId],
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

      await _storeUploadedPhoto(
        db,
        localId: localId,
        uploaded: uploaded,
        checkpoint: checkpoint,
        localPath: localPath,
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

  /// Next id for a photo taken offline. Always negative, so it never clashes
  /// with a server photo id.
  static Future<int> _nextLocalPhotoId(DatabaseExecutor db) async {
    final result = await db.rawQuery(
      'SELECT MIN(id) AS minId FROM ihm_sampling_photos',
    );
    final minId = _int(result.first['minId']);
    return (minId < 0 ? minId : 0) - 1;
  }

  /// After an offline photo uploads, store it under its server id so later
  /// downloads update this same row (keeping the local file, no re-download
  /// and no duplicate).
  static Future<void> _storeUploadedPhoto(
    Database db, {
    required int localId,
    required IhmSamplingPhoto uploaded,
    required IhmCheckpoint checkpoint,
    required String localPath,
  }) async {
    await db.transaction((txn) async {
      final serverId = uploaded.id;
      var targetId = localId;

      if (serverId > 0) {
        final clash = await txn.query(
          'ihm_sampling_photos',
          columns: ['id', 'serverId', 'synced'],
          where: 'id = ?',
          whereArgs: [serverId],
          limit: 1,
        );
        final clashIsCopy =
            clash.isNotEmpty &&
            _int(clash.first['serverId']) == serverId &&
            _int(clash.first['synced']) == 1;
        if (clash.isEmpty || clashIsCopy) {
          if (clashIsCopy && serverId != localId) {
            await txn.delete(
              'ihm_sampling_photos',
              where: 'id = ?',
              whereArgs: [serverId],
            );
          }
          targetId = serverId;
        }
        // Remove any other copy of the same server photo.
        await txn.delete(
          'ihm_sampling_photos',
          where: 'serverId = ? AND id != ? AND id != ?',
          whereArgs: [serverId, localId, targetId],
        );
      }

      await txn.update(
        'ihm_sampling_photos',
        uploaded.toLocalMap(
          surveyJobId: checkpoint.surveyJobId,
          checkpointId: checkpoint.id,
          areaId: checkpoint.ihmAreaId,
          localId: targetId,
          localFilePath: localPath,
          synced: 1,
        ),
        where: 'id = ?',
        whereArgs: [localId],
      );

      if (targetId != localId) {
        // Keep later queue entries (e.g. a delete) pointing at this photo.
        final queueRows = await txn.query(
          'ihm_sync_queue',
          columns: ['id', 'payloadJson'],
          where: "entityType = 'photo' AND entityLocalId = ? AND status != 1",
          whereArgs: [localId],
        );
        for (final row in queueRows) {
          Map<String, dynamic> payload;
          try {
            payload = Map<String, dynamic>.from(
              jsonDecode(row['payloadJson']?.toString() ?? '{}') as Map,
            );
          } catch (_) {
            payload = {};
          }
          payload['localId'] = targetId;
          payload['serverId'] = serverId;
          await txn.update(
            'ihm_sync_queue',
            {'entityLocalId': targetId, 'payloadJson': jsonEncode(payload)},
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        }
      }
    });
  }

  /// Stores server photos locally (downloading files that are not on the
  /// device yet). Rows are matched by server id, so a photo uploaded from this
  /// device reuses its local file instead of being downloaded again.
  ///
  /// When [isCompleteList] is true, [photos] is the full server list for the
  /// checkpoint and synced local rows that are no longer on the server are
  /// removed. Photos still waiting to upload are never touched.
  static Future<void> _cachePhotos(
    IhmCheckpoint checkpoint,
    List<IhmSamplingPhoto> photos, {
    List<String>? failures,
    bool isCompleteList = false,
    DateTime? listFetchedAt,
  }) async {
    final db = await DatabaseHelper.instance.database;

    if (isCompleteList) {
      final serverIds = photos
          .map((photo) => photo.id)
          .where((id) => id > 0)
          .toList();
      final placeholders = serverIds.map((_) => '?').join(',');
      // Rows changed after the list was fetched (e.g. a photo that finished
      // uploading meanwhile) are kept.
      final cutoff = (listFetchedAt ?? DateTime.now()).toIso8601String();
      await db.delete(
        'ihm_sampling_photos',
        where:
            'ihmCheckpointId = ? AND synced = 1 AND deleted = 0 AND serverId > 0 '
            'AND (updatedAt IS NULL OR updatedAt < ?)'
            '${serverIds.isEmpty ? '' : ' AND serverId NOT IN ($placeholders)'}',
        whereArgs: [checkpoint.id, cutoff, ...serverIds],
      );
    }

    for (final photo in photos) {
      if (photo.id <= 0) continue;

      final matches = await db.query(
        'ihm_sampling_photos',
        where: 'serverId = ?',
        whereArgs: [photo.id],
        orderBy: 'CASE WHEN id = ${photo.id} THEN 0 ELSE 1 END',
      );

      // A pending local delete or edit of this photo wins over the server copy.
      if (matches.any((row) => _int(row['synced']) == 0)) continue;

      final existing = matches.isEmpty ? null : matches.first;
      final existingFilePath = existing?['filePath']?.toString();
      String? existingLocalPath = existing?['localFilePath']?.toString();
      if (existingFilePath != null &&
          existingFilePath != photo.filePath &&
          existingFilePath != existingLocalPath) {
        // Server file changed: download again.
        existingLocalPath = null;
      }

      final localPath = await _ensureCachedRemoteFile(
        remotePath: photo.filePath,
        existingLocalPath: existingLocalPath,
        fallbackFileName: 'checkpoint_photo_${photo.id}.jpg',
        folderName: 'ihm_sampling_photos',
        requiredForOffline: true,
        failures: failures,
        label: 'Checkpoint ${checkpoint.sampleNo} photo ${photo.id}',
      );
      final editedPath = photo.appendixThreeEditedFilePath;
      final String? existingEditedFilePath = existing == null
          ? null
          : existing['appendixThreeEditedFilePath']?.toString();
      final String? existingEditedLocalPathRaw = existing == null
          ? null
          : existing['appendixThreeEditedLocalFilePath']?.toString();
      final existingEditedLocalPath = existingEditedFilePath == editedPath
          ? existingEditedLocalPathRaw
          : null;
      final editedLocalPath = editedPath != null && editedPath.trim().isNotEmpty
          ? await _ensureCachedRemoteFile(
              remotePath: editedPath,
              existingLocalPath: existingEditedLocalPath,
              fallbackFileName: 'checkpoint_photo_${photo.id}_edited.jpg',
              folderName: 'ihm_sampling_photos',
              requiredForOffline: true,
              failures: failures,
              label:
                  'Checkpoint ${checkpoint.sampleNo} edited photo ${photo.id}',
            )
          : existingEditedLocalPath;

      final rowId = existing == null ? photo.id : _int(existing['id']);
      final values = photo.toLocalMap(
        surveyJobId: checkpoint.surveyJobId,
        checkpointId: checkpoint.id,
        areaId: checkpoint.ihmAreaId,
        localId: rowId,
        localFilePath: localPath,
        appendixThreeEditedLocalFilePath: editedLocalPath,
      );

      await db.transaction((txn) async {
        if (existing == null) {
          final clash = await txn.query(
            'ihm_sampling_photos',
            columns: ['id'],
            where: 'id = ?',
            whereArgs: [photo.id],
            limit: 1,
          );
          if (clash.isNotEmpty) {
            // Legacy row using this number as a local id: keep it and store
            // the server photo under a new local id.
            values['id'] = await _nextLocalPhotoId(txn);
          }
          await txn.insert('ihm_sampling_photos', values);
        } else {
          await txn.update(
            'ihm_sampling_photos',
            values,
            where: 'id = ?',
            whereArgs: [rowId],
          );
          // Drop duplicate copies left by older app versions.
          final extraIds = matches
              .skip(1)
              .map((row) => _int(row['id']))
              .where((id) => id != rowId)
              .toList();
          if (extraIds.isNotEmpty) {
            await txn.delete(
              'ihm_sampling_photos',
              where: 'id IN (${extraIds.map((_) => '?').join(',')})',
              whereArgs: extraIds,
            );
          }
        }
      });
    }
  }

  // Shared layouts (machinery / GA) are returned for many areas of the same
  // job. Areas are cached in parallel, so dedupe concurrent downloads of the
  // same layout id to avoid writing the same file several times.
  static final Map<int, Future<String?>> _layoutDownloadsInFlight = {};

  static Future<void> _cacheLayouts(
    int jobId,
    int areaId,
    List<IhmLayoutImage> layouts, {
    List<String>? failures,
  }) async {
    final db = await DatabaseHelper.instance.database;

    // Remove this area's own (non-shared) layouts that the server no longer
    // returns.
    final areaLayoutIds = layouts
        .where((layout) => !layout.isCommon && layout.ihmAreaId == areaId)
        .map((layout) => layout.id)
        .toSet();
    final placeholders = areaLayoutIds.map((_) => '?').join(',');
    await db.delete(
      'ihm_layout_images',
      where: areaLayoutIds.isEmpty
          ? 'surveyJobId = ? AND ihmAreaId = ? AND isCommon = 0'
          : 'surveyJobId = ? AND ihmAreaId = ? AND isCommon = 0 AND id NOT IN ($placeholders)',
      whereArgs: [jobId, areaId, ...areaLayoutIds],
    );

    for (final layout in layouts) {
      final pending = _layoutDownloadsInFlight[layout.id];
      final download =
          pending ??
          _downloadLayout(jobId, areaId, layout, failures: failures);
      if (pending == null) {
        _layoutDownloadsInFlight[layout.id] = download;
      }
      try {
        await download;
      } finally {
        if (pending == null) {
          _layoutDownloadsInFlight.remove(layout.id);
        }
      }
    }

    // Record exactly which layouts apply to this area, in server order, so the
    // offline lookup returns the same layout the online API would.
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.delete(
        'ihm_area_layouts',
        where: 'surveyJobId = ? AND ihmAreaId = ?',
        whereArgs: [jobId, areaId],
      );
      for (var i = 0; i < layouts.length; i++) {
        await txn.insert('ihm_area_layouts', {
          'surveyJobId': jobId,
          'ihmAreaId': areaId,
          'layoutId': layouts[i].id,
          'sortOrder': i,
          'updatedAt': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  static Future<String?> _downloadLayout(
    int jobId,
    int areaId,
    IhmLayoutImage layout, {
    List<String>? failures,
  }) async {
    final db = await DatabaseHelper.instance.database;
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
      requiredForOffline: true,
      failures: failures,
      label: layout.isCommon ? 'Common layout' : 'Area $areaId layout',
    );

    await db.insert('ihm_layout_images', {
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
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    return localPath;
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

    // Keep the Excel row number if this copy of the checkpoint lacks it, so
    // the card does not move.
    if (values['sourceRowNumber'] == null) {
      final existing = await db.query(
        'ihm_checkpoints',
        columns: ['sourceRowNumber'],
        where: 'id = ?',
        whereArgs: [checkpoint.id],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        values['sourceRowNumber'] = existing.first['sourceRowNumber'];
      }
    }

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
      'sourceRowNumber': row['sourceRowNumber'],
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
      id: _int(row['id']),
      filePath: row['filePath']?.toString() ?? '',
      localFilePath: row['localFilePath']?.toString(),
      caption: row['caption']?.toString(),
      showInAppendixThree: _int(row['showInAppendixThree']) == 1,
      appendixThreeSortOrder: _int(row['appendixThreeSortOrder']),
      appendixThreeEditedFilePath: row['appendixThreeEditedFilePath']
          ?.toString(),
      appendixThreeEditedLocalFilePath: row['appendixThreeEditedLocalFilePath']
          ?.toString(),
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
    bool requiredForOffline = false,
    List<String>? failures,
    String? label,
  }) async {
    if (remotePath.trim().isEmpty) {
      if (requiredForOffline) {
        failures?.add('${label ?? 'File'}: missing server path.');
      }
      debugPrint(
        '[IHM offline image] ${label ?? 'File'} skipped: missing remote path.',
      );
      return existingLocalPath;
    }

    if (existingLocalPath != null &&
        existingLocalPath.isNotEmpty &&
        await _canReadLocalFile(existingLocalPath)) {
      debugPrint(
        '[IHM offline image] ${label ?? remotePath} reused. '
        'remote=${ApiService.fileUrl(remotePath)} local=$existingLocalPath exists=true',
      );
      return existingLocalPath;
    }

    try {
      final remoteUrl = ApiService.fileUrl(remotePath);
      debugPrint(
        '[IHM offline image] ${label ?? remotePath} downloading. '
        'remote=$remoteUrl existingLocal=$existingLocalPath',
      );
      final response = await _downloadClient.get(Uri.parse(remoteUrl));
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          response.bodyBytes.isEmpty) {
        if (requiredForOffline) {
          final reason = response.statusCode == 404
              ? 'server file missing (404); offline placeholder will be used'
              : 'download failed (${response.statusCode})';
          failures?.add('${label ?? remotePath}: $reason.');
        }
        debugPrint(
          '[IHM offline image] ${label ?? remotePath} download failed. '
          'status=${response.statusCode} bytes=${response.bodyBytes.length}',
        );
        return existingLocalPath;
      }

      final localPath = await writeIhmLocalFile(
        response.bodyBytes,
        _remoteFileName(remotePath, fallbackFileName),
        folderName: folderName,
      );
      final exists = await _canReadLocalFile(localPath);
      debugPrint(
        '[IHM offline image] ${label ?? remotePath} downloaded. '
        'remote=$remoteUrl local=$localPath exists=$exists bytes=${response.bodyBytes.length}',
      );
      return localPath;
    } catch (error) {
      if (requiredForOffline) {
        failures?.add('${label ?? remotePath}: $error');
      }
      debugPrint(
        '[IHM offline image] ${label ?? remotePath} download error. '
        'remote=${ApiService.fileUrl(remotePath)} local=$existingLocalPath error=$error',
      );
      return existingLocalPath;
    }
  }

  // Tasks are passed as factories so that only [batchSize] downloads are in
  // flight at once (a list of already-created futures would all start
  // immediately and defeat the batching).
  static Future<void> _runInBatches(
    List<Future<void> Function()> tasks,
    int batchSize,
  ) async {
    for (var start = 0; start < tasks.length; start += batchSize) {
      final end = (start + batchSize) > tasks.length
          ? tasks.length
          : start + batchSize;
      await Future.wait(tasks.sublist(start, end).map((task) => task()));
    }
  }

  // Only checks that the file exists and is not empty. Reading every cached
  // image in full on each sync made sync very slow on jobs with many photos.
  static Future<bool> _canReadLocalFile(String path) async {
    try {
      return await ihmLocalFileHasContent(path);
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

class IhmOfflineCacheException implements Exception {
  final int jobId;
  final List<String> failures;

  IhmOfflineCacheException(this.jobId, this.failures);

  @override
  String toString() {
    final shown = failures.take(3).join('; ');
    final extra = failures.length > 3 ? ' (+${failures.length - 3} more)' : '';
    return 'Job $jobId partial offline cache: $shown$extra';
  }
}
