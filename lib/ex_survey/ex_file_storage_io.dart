import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<String> writeExLocalFile(
  Uint8List bytes,
  String fileName, {
  String folder = 'ex_survey_files',
}) async {
  final directory = await getApplicationDocumentsDirectory();
  final targetDirectory = Directory(p.join(directory.path, folder));
  await targetDirectory.create(recursive: true);

  final extension = p.extension(fileName).isEmpty ? '.bin' : p.extension(fileName);
  final baseName = p
      .basenameWithoutExtension(fileName)
      .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
      .replaceAll(RegExp(r'_+'), '_');
  final safeBaseName = baseName.isEmpty ? 'file' : baseName;
  final savedName =
      '${safeBaseName}_${DateTime.now().millisecondsSinceEpoch}$extension';
  final savedFile = File(p.join(targetDirectory.path, savedName));

  await savedFile.writeAsBytes(bytes, flush: true);
  return savedFile.path;
}

Future<Uint8List> readExLocalFile(String path) async {
  return File(path).readAsBytes();
}

Future<void> clearExLocalFiles() async {
  final directory = await getApplicationDocumentsDirectory();
  for (final folderName in ['ex_survey_files']) {
    final target = Directory(p.join(directory.path, folderName));
    if (await target.exists()) {
      await target.delete(recursive: true);
    }
  }
}
