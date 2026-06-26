import 'dart:convert';
import 'package:Auras/Db/database_helper.dart';
import 'package:Auras/app_config.dart';
import 'package:Auras/model/loadout.dart';
import 'package:Auras/model/seafastening.dart';
import 'package:Auras/model/towage.dart';
import 'package:Auras/service/api_service.dart';
import 'package:http/http.dart' as http;

class SyncService {
  static bool _isSyncing = false;
  // 🔁 SYNC ALL CERTIFICATES

  static Future<void> syncAllCertificatesToServer() async {
    if (_isSyncing) {
      print("⚠ Sync already in progress — skipping");
      return;
    }
    _isSyncing = true;

    try {
      await syncTowageCertificatesToServer();
      await syncSeaFasteningCertificatesToServer();
      await syncLoadoutCertificatesToServer();
    } finally {
      _isSyncing = false;
    }
  }

  // 🔽 SYNC FROM SERVER TO LOCAL
  static Future<void> syncFromServerToLocal() async {
    final db = await DatabaseHelper.instance.database;

    try {
      // 🟦 1. TOWAGE
      final towageList = await ApiService.fetchTowageCertificatesFromServer();
      for (final certMap in towageList) {
        final id = certMap['id'] as int;
        final exists = await db.query(
          'towage_certificates',
          where: 'id = ?',
          whereArgs: [id],
        );
        if (exists.isEmpty) {
          await db.insert('towage_certificates', certMap..['synced'] = 1);
          print("✅ Inserted Towage cert from server: $id");
        }
      }

      // 🟩 2. LOADOUT
      final loadoutList = await ApiService.fetchAllLoadoutCertificates();
      for (final certMap in loadoutList) {
        final id = certMap['id'] as int;
        final exists = await db.query(
          'loadout_certificates',
          where: 'id = ?',
          whereArgs: [id],
        );
        if (exists.isEmpty) {
          await db.insert('loadout_certificates', certMap..['synced'] = 1);
          print("✅ Inserted Loadout cert from server: $id");
        }
      }

      // 🟨 3. SEAFASTENING
      final seaList = await ApiService.fetchAllSeafasteningCertificates();
      for (final cert in seaList) {
        final exists = await db.query(
          'seafastening_certificates',
          where: 'id = ?',
          whereArgs: [cert.id],
        );
        if (exists.isEmpty) {
          await db.insert(
            'seafastening_certificates',
            cert.toMap()..['synced'] = 1,
          );
          print("✅ Inserted SeaFastening cert from server: ${cert.id}");
        }
      }
    } catch (e) {
      // print("❌ Error syncing from server to local: $e");
    }
  }

  // 🔼 SYNC TOWAGE
  static Future<void> syncTowageCertificatesToServer() async {
    final dbHelper = DatabaseHelper.instance;
    final db = await dbHelper.database;

    final unsynced = await db.query(
      'towage_certificates',
      where: 'synced = ?',
      whereArgs: [0],
    );

    for (var map in unsynced) {
      try {
        // Mark as syncing first
        await db.update(
          'towage_certificates',
          {'synced': -1},
          where: 'id = ?',
          whereArgs: [map['id']],
        );

        final cert = TowageCertificate.fromMap(map);
        cert.defaultRecommendations = await dbHelper.getRecommendations(
          cert.id!,
        );
        cert.cargoDetails = await dbHelper.getCargoDetails(cert.id!);

        final response = await http.post(
          Uri.parse('${AppConfig.baseUrl}Certificate/create'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(cert.toJson(forSync: true)),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          await db.update(
            'towage_certificates',
            {'synced': 1},
            where: 'id = ?',
            whereArgs: [cert.id],
          );
          print('✅ Synced Towage Certificate: ${cert.id}');
        } else {
          await db.update(
            'towage_certificates',
            {'synced': 0}, // revert if failed
            where: 'id = ?',
            whereArgs: [cert.id],
          );
          print('❌ Towage sync failed: ${response.body}');
        }
      } catch (e) {
        await db.update(
          'towage_certificates',
          {'synced': 0}, // revert if error
          where: 'id = ?',
          whereArgs: [map['id']],
        );
        print('🔥 Error syncing towage: $e');
      }
    }
  }

  // 🔼 SYNC SEAFASTENING
  static Future<void> syncSeaFasteningCertificatesToServer() async {
    final dbHelper = DatabaseHelper.instance;
    final db = await dbHelper.database;

    final unsynced = await db.query(
      'seafastening_certificates',
      where: 'synced = ?',
      whereArgs: [0],
    );

    for (var map in unsynced) {
      try {
        await db.update(
          'seafastening_certificates',
          {'synced': -1},
          where: 'id = ?',
          whereArgs: [map['id']],
        );

        final cert = SeaFasteningCertificate.fromMap(map);
        cert.recommendations ??= await dbHelper.getSeafasteningRecommendations(
          cert.id!,
        );
        cert.cargoDetails ??= await dbHelper.getCargoDetails(cert.id!);

        final response = await http.post(
          Uri.parse('${AppConfig.baseUrl}SeaFastening/create-seafastening'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(cert.toJson(forSync: true)),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          await db.update(
            'seafastening_certificates',
            {'synced': 1},
            where: 'id = ?',
            whereArgs: [cert.id],
          );
          print('✅ Synced Seafastening Certificate: ${cert.id}');
        } else {
          await db.update(
            'seafastening_certificates',
            {'synced': 0},
            where: 'id = ?',
            whereArgs: [cert.id],
          );
          print('❌ Seafastening sync failed: ${response.body}');
        }
      } catch (e) {
        await db.update(
          'seafastening_certificates',
          {'synced': 0},
          where: 'id = ?',
          whereArgs: [map['id']],
        );
        print('🔥 Error syncing Seafastening: $e');
      }
    }
  }

  // 🔼 SYNC LOADOUT
  static Future<void> syncLoadoutCertificatesToServer() async {
    final dbHelper = DatabaseHelper.instance;
    final db = await dbHelper.database;

    final unsynced = await db.query(
      'loadout_certificates',
      where: 'synced = ?',
      whereArgs: [0],
    );

    for (var map in unsynced) {
      try {
        await db.update(
          'loadout_certificates',
          {'synced': -1},
          where: 'id = ?',
          whereArgs: [map['id']],
        );

        final cert = LoadoutCertificate.fromMap(map);
        cert.cargoDetails ??= await dbHelper.getCargoDetails(cert.id!);

        final response = await http.post(
          Uri.parse('${AppConfig.baseUrl}LoadOut/create-Loadout'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(cert.toJson(forSync: true)),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          await db.update(
            'loadout_certificates',
            {'synced': 1},
            where: 'id = ?',
            whereArgs: [cert.id],
          );
          print('✅ Synced Loadout Certificate: ${cert.id}');
        } else {
          await db.update(
            'loadout_certificates',
            {'synced': 0},
            where: 'id = ?',
            whereArgs: [cert.id],
          );
          print('❌ Loadout sync failed: ${response.body}');
        }
      } catch (e) {
        await db.update(
          'loadout_certificates',
          {'synced': 0},
          where: 'id = ?',
          whereArgs: [map['id']],
        );
        print('🔥 Error syncing Loadout: $e');
      }
    }
  }
}
