import 'dart:typed_data';

Future<String> writeIhmLocalPhoto(Uint8List bytes, String fileName) {
  throw UnsupportedError('Offline photo storage is not available on this platform.');
}

Future<String> writeIhmLocalFile(
  Uint8List bytes,
  String fileName, {
  String folderName = 'ihm_sampling_photos',
}) {
  throw UnsupportedError('Offline file storage is not available on this platform.');
}

Future<Uint8List> readIhmLocalPhoto(String path) {
  throw UnsupportedError('Offline photo storage is not available on this platform.');
}

Future<void> clearIhmLocalFiles() async {}

Future<bool> ihmLocalFileHasContent(String path) async => false;
