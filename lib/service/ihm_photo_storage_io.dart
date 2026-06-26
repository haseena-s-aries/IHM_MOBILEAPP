import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<String> writeIhmLocalPhoto(Uint8List bytes, String fileName) async {
  final directory = await getApplicationDocumentsDirectory();
  final photosDirectory = Directory(p.join(directory.path, 'ihm_sampling_photos'));

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
