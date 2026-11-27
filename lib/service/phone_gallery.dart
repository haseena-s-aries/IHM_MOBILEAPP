import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Saves a copy of a checkpoint camera photo to the phone's storage, in
/// Pictures/IHM/<yyyy-MM-dd>/, so it is visible in the Gallery and File
/// Manager. Works offline. The app keeps its own copy for sync as before.
class PhoneGallery {
  static const MethodChannel _channel = MethodChannel('auras/phone_gallery');

  /// Returns where the photo was saved, or null if it could not be saved.
  static Future<String?> saveCheckpointPhoto({
    required Uint8List bytes,
    required String sampleNo,
    DateTime? takenAt,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;

    final now = takenAt ?? DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final date = '${now.year}-${two(now.month)}-${two(now.day)}';
    final time = '${two(now.hour)}${two(now.minute)}${two(now.second)}';
    final code = sampleNo.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    final fileName =
        'IHM_${code.isEmpty ? 'photo' : code}_${date.replaceAll('-', '')}_'
        '${time}_${now.millisecond}.jpg';

    try {
      return await _channel.invokeMethod<String>('saveImage', {
        'bytes': bytes,
        'fileName': fileName,
        'folder': 'IHM/$date',
      });
    } catch (error) {
      debugPrint('[Phone gallery] could not save photo: $error');
      return null;
    }
  }
}
