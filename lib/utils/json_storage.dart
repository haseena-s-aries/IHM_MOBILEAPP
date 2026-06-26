import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:Auras/model/towage.dart';
import 'package:Auras/model/seafastening.dart';
import 'package:Auras/model/loadout.dart'; // 👈 Add this line

/// ----------------------
/// TOWAGE CERTIFICATE
/// ----------------------

Future<TowageCertificate?> saveTowageJsonLocally(
  TowageCertificate certificate,
) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/towage_certificate.json');
  final jsonData = jsonEncode(certificate.toJson());
  await file.writeAsString(jsonData);
  if (await file.exists()) {
    final content = await file.readAsString();
    final json = jsonDecode(content);
    return TowageCertificate.fromJson(json);
  }
  return null;
}

Future<TowageCertificate?> loadTowageJsonFromLocal() async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/towage_certificate.json');
  if (await file.exists()) {
    final content = await file.readAsString();
    final json = jsonDecode(content);
    return TowageCertificate.fromJson(json);
  }
  return null;
}

/// ----------------------
/// SEAFASTENING CERTIFICATE
/// ----------------------

Future<SeaFasteningCertificate?> saveSeafasteningJsonLocally(
  SeaFasteningCertificate certificate,
) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/seafastening_certificate.json');
  final jsonData = jsonEncode(certificate.toJson());
  await file.writeAsString(jsonData);
  if (await file.exists()) {
    final content = await file.readAsString();
    final json = jsonDecode(content);
    return SeaFasteningCertificate.fromJson(json);
  }
  return null;
}

Future<SeaFasteningCertificate?> loadSeafasteningJsonFromLocal() async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/seafastening_certificate.json');
  if (await file.exists()) {
    final content = await file.readAsString();
    final json = jsonDecode(content);
    return SeaFasteningCertificate.fromJson(json);
  }
  return null;
}

/// ----------------------
/// LOADOUT CERTIFICATE
/// ----------------------

Future<LoadoutCertificate?> saveLoadoutJsonLocally(
  LoadoutCertificate certificate,
) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/loadout_certificate.json');
  final jsonData = jsonEncode(certificate.toJson());
  await file.writeAsString(jsonData);
  if (await file.exists()) {
    final content = await file.readAsString();
    final json = jsonDecode(content);
    return LoadoutCertificate.fromJson(json);
  }
  return null;
}

Future<LoadoutCertificate?> loadLoadoutJsonFromLocal() async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/loadout_certificate.json');
  if (await file.exists()) {
    final content = await file.readAsString();
    final json = jsonDecode(content);
    return LoadoutCertificate.fromJson(json);
  }
  return null;
}
