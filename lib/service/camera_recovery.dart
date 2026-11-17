import 'dart:convert';

import 'package:Auras/ihm_area.dart';
import 'package:Auras/service/IhmOfflineService.dart';
import 'package:Auras/service/auth_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Recovers checkpoint photos taken with the camera when Android closed the
/// app in the background.
///
/// While the camera app is open, Android may kill this app to free memory
/// (common on the first camera launch, when the camera app starts cold).
/// When the user presses OK, the app restarts from the dashboard and the
/// photo result is lost unless it is fetched with
/// [ImagePicker.retrieveLostData]. Before opening the camera, the target
/// checkpoint is saved here, so the photo can still be stored for it after the
/// restart.
class CameraRecovery {
  static const String _prefsKey = 'pendingCameraCheckpoint';

  /// Call right before opening the camera for [checkpoint].
  static Future<void> rememberCheckpoint(IhmCheckpoint checkpoint) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode({
          'id': checkpoint.id,
          'surveyJobId': checkpoint.surveyJobId,
          'ihmAreaId': checkpoint.ihmAreaId,
          'sampleNo': checkpoint.sampleNo,
        }),
      );
    } catch (error) {
      debugPrint('[Camera recovery] could not save checkpoint: $error');
    }
  }

  /// Call when the camera returned normally (photo taken or cancelled).
  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (_) {}
  }

  /// Call once at app start. Saves any photo that was lost because the app
  /// was closed while the camera was open.
  static Future<void> recoverLostPhotos() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    try {
      final response = await ImagePicker().retrieveLostData();
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);

      if (response.isEmpty) {
        // Nothing to recover. Drop a stale marker from a camera session that
        // ended normally but was not cleared.
        if (saved != null) await prefs.remove(_prefsKey);
        return;
      }

      final files = <XFile>[
        ...?response.files,
        if (response.files == null && response.file != null) response.file!,
      ];

      if (files.isEmpty || saved == null) {
        if (response.exception != null) {
          debugPrint(
            '[Camera recovery] camera error: ${response.exception?.message}',
          );
        }
        await prefs.remove(_prefsKey);
        return;
      }

      final data = jsonDecode(saved) as Map<String, dynamic>;
      final checkpoint = IhmCheckpoint(
        id: int.tryParse(data['id'].toString()) ?? 0,
        sampleNo: data['sampleNo']?.toString() ?? '',
        surveyJobId: int.tryParse(data['surveyJobId'].toString()) ?? 0,
        ihmAreaId: int.tryParse(data['ihmAreaId'].toString()) ?? 0,
      );
      if (checkpoint.id <= 0 || checkpoint.surveyJobId <= 0) {
        await prefs.remove(_prefsKey);
        return;
      }

      var savedCount = 0;
      for (final file in files) {
        try {
          final bytes = await file.readAsBytes();
          if (bytes.isEmpty) continue;
          await IhmOfflineService.saveCheckpointPhoto(
            checkpoint: checkpoint,
            fileBytes: bytes,
            fileName: file.name,
          );
          savedCount++;
        } catch (error) {
          debugPrint('[Camera recovery] could not save photo: $error');
        }
      }

      await prefs.remove(_prefsKey);

      if (savedCount > 0) {
        final label = checkpoint.sampleNo.isEmpty
            ? 'the checkpoint'
            : 'checkpoint ${checkpoint.sampleNo}';
        _showMessage(
          savedCount == 1
              ? 'Camera photo saved to $label.'
              : '$savedCount camera photos saved to $label.',
        );
      }
    } catch (error) {
      debugPrint('[Camera recovery] failed: $error');
    }
  }

  static void _showMessage(String text) {
    // The first screen may still be building; retry briefly.
    Future<void> attempt(int remaining) async {
      final context = appNavigatorKey.currentContext;
      final messenger = context == null
          ? null
          : ScaffoldMessenger.maybeOf(context);
      if (messenger != null) {
        messenger.showSnackBar(
          SnackBar(content: Text(text), duration: const Duration(seconds: 5)),
        );
        return;
      }
      if (remaining <= 0) return;
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await attempt(remaining - 1);
    }

    attempt(10);
  }
}
