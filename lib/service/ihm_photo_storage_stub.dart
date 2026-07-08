import 'dart:typed_data';

Future<String> writeIhmLocalPhoto(Uint8List bytes, String fileName) {
  throw UnsupportedError('Offline photo storage is not available on this platform.');
}

Future<Uint8List> readIhmLocalPhoto(String path) {
  throw UnsupportedError('Offline photo storage is not available on this platform.');
}
