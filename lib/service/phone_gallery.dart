import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Saves a copy of a checkpoint camera photo to the phone's storage, in
/// `Pictures/IHM/<yyyy-MM-dd>/`, so it is visible in the Gallery and File
/// Manager. Works offline. The app keeps its own copy for sync as before.
///
/// 1. Native MediaStore save (MainActivity.kt, channel auras/phone_gallery).
/// 2. If that is unavailable or fails, write the file directly to the
///    phone's Pictures folder. On Android 11+ files written there are
///    indexed by the Gallery automatically.
class PhoneGallery {
  static const MethodChannel _channel = MethodChannel('auras/phone_gallery');

  /// Short reason for the last failure, shown to the user.
  static String? lastError;

  /// Returns where the photo was saved, or null if it could not be saved
  /// (see [lastError]).
  static Future<String?> saveCheckpointPhoto({
    required Uint8List bytes,
    required String sampleNo,
    DateTime? takenAt,
  }) async {
    lastError = null;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;

    final now = takenAt ?? DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final date = '${now.year}-${two(now.month)}-${two(now.day)}';
    final time = '${two(now.hour)}${two(now.minute)}${two(now.second)}';
    final code = sampleNo.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    final fileName =
        'IHM_${code.isEmpty ? 'photo' : code}_${date.replaceAll('-', '')}_'
        '${time}_${now.millisecond}.jpg';
    final folder = 'IHM/$date';

    String? nativeError;
    try {
      final saved = await _channel.invokeMethod<String>('saveImage', {
        'bytes': bytes,
        'fileName': fileName,
        'folder': folder,
      });
      if (saved != null && saved.isNotEmpty) return saved;
      nativeError = 'native save returned nothing';
    } on MissingPluginException {
      // MainActivity.kt in the APK does not have the save function: the
      // android/ folder was not updated before building.
      nativeError = 'Android part missing (update android folder and rebuild)';
    } on PlatformException catch (error) {
      nativeError = error.message ?? error.code;
    } catch (error) {
      nativeError = error.toString();
    }
    debugPrint('[Phone gallery] native save failed: $nativeError');

    // Fallback: write straight into the phone's Pictures folder.
    try {
      final picturesDir = await _publicPicturesDirectory();
      if (picturesDir == null) {
        lastError = nativeError;
        return null;
      }
      final directory = Directory(p.join(picturesDir, 'IHM', date));
      await directory.create(recursive: true);
      final file = File(p.join(directory.path, fileName));
      await file.writeAsBytes(bytes, flush: true);
      debugPrint('[Phone gallery] saved with direct write: ${file.path}');
      return file.path;
    } catch (error) {
      debugPrint('[Phone gallery] direct write failed: $error');
      lastError = '$nativeError; direct write: $error';
      return null;
    }
  }

  /// /storage/emulated/0/Pictures (derived from the app's external folder,
  /// which is `/storage/emulated/0/Android/data/<package>/files`).
  static Future<String?> _publicPicturesDirectory() async {
    final appExternal = await getExternalStorageDirectory();
    if (appExternal == null) return null;
    final path = appExternal.path;
    final index = path.indexOf('${Platform.pathSeparator}Android${Platform.pathSeparator}');
    if (index <= 0) return null;
    return p.join(path.substring(0, index), 'Pictures');
  }
}
