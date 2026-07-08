import 'dart:typed_data';

Future<String> writeExLocalFile(
  Uint8List bytes,
  String fileName, {
  String folder = 'ex_survey_files',
}) {
  throw UnsupportedError('Offline file storage is not available on this platform.');
}

Future<Uint8List> readExLocalFile(String path) {
  throw UnsupportedError('Offline file storage is not available on this platform.');
}
