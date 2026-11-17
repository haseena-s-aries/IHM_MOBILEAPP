import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<String> writeIhmLocalFile(
  Uint8List bytes,
  String fileName, {
  String folderName = 'ihm_sampling_photos',
}) async {
  final directory = await getApplicationDocumentsDirectory();
  final photosDirectory = Directory(p.join(directory.path, folderName));

  if (!await photosDirectory.exists()) {
    await photosDirectory.create(recursive: true);
  }

  final extension = p.extension(fileName).isEmpty ? '.jpg' : p.extension(fileName);
  final baseName = p
      .basenameWithoutExtension(fileName)
      .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
      .replaceAll(RegExp(r'_+'), '_');
  final safeBaseName = baseName.isEmpty ? 'photo' : baseName;
  final savedName =
      '${safeBaseName}_${DateTime.now().millisecondsSinceEpoch}$extension';
  final savedFile = File(p.join(photosDirectory.path, savedName));

  await savedFile.writeAsBytes(bytes, flush: true);
  return savedFile.path;
}

Future<String> writeIhmLocalPhoto(Uint8List bytes, String fileName) async {
  return writeIhmLocalFile(bytes, fileName);
}

Future<Uint8List> readIhmLocalPhoto(String path) async {
  return File(path).readAsBytes();
}

Future<void> clearIhmLocalFiles() async {
  final directory = await getApplicationDocumentsDirectory();
  for (final folderName in [
    'ihm_sampling_photos',
    'ihm_layout_images',
    'ihm_vscp_checklists',
  ]) {
    final target = Directory(p.join(directory.path, folderName));
    if (await target.exists()) {
      await target.delete(recursive: true);
    }
  }
}

Future<bool> ihmLocalFileHasContent(String path) async {
  final file = File(path);
  if (!await file.exists()) return false;
  return await file.length() > 0;
}
