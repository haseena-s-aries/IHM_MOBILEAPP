import 'dart:async';
import 'package:Auras/model/CarogDetails_model.dart';
import 'package:Auras/model/Recommendation.dart';
import 'package:Auras/model/loadout.dart';
import 'package:Auras/model/towage.dart';
import 'package:Auras/model/seafastening.dart';
import 'package:Auras/screen/screen/Seafastening_certificate_screen.dart';
import 'package:Auras/service/api_service.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:Auras/model/DRecommendation.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  factory DatabaseHelper() => instance;
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await initDB();
    return _database!;
  }

  Future<Database> initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'auras.db');

    return await openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE towage_certificates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        headerImagePath TEXT,
        certificateType TEXT,
        jobNumber TEXT,
        projectTitle TEXT,
        certificateNumber TEXT,
        clientName TEXT,
        cargo TEXT,
        departurePort TEXT,
        arrivalPort TEXT,
        issuedDate TEXT,
        noDateCheckbox INTEGER,
        surveyedBy TEXT,
        reviewedBy TEXT,
        towName TEXT,
        tugName TEXT,
        stampPath TEXT,
        signaturePath TEXT,
        signatureClient TEXT,
        isCargoDetailsNA INTEGER,
        includeAnnexure2 INTEGER,
        includeCargoDetails INTEGER,
        synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE seafastening_certificates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId TEXT,
        headerImagePath TEXT,
        certificateTitle TEXT,
        issuedBy TEXT,
        client TEXT,
        transportUnit TEXT,
        projectTitle TEXT,
        fromPort TEXT,
        toPort TEXT,
        jobNumber TEXT,
        certificateNumber TEXT,
        issuedDate TEXT,
        slNo INTEGER,
        stampPath TEXT,
        signaturePath TEXT,
        signatureClient TEXT,
        isCargoDetailsNA INTEGER,
        includeCargoDetails INTEGER,
        cargo TEXT,
        serialNo INTEGER,
        location TEXT,
        idMarkings TEXT,
        weight TEXT,
        dimensions TEXT,
        remarks TEXT,
        includeAnnexure2 INTEGER,
        synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE default_recommendations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        certificateId INTEGER,
        recommendationText TEXT,
        FOREIGN KEY (certificateId) REFERENCES towage_certificates(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE recommendations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        certificateId INTEGER,
        recommendationText TEXT,
        FOREIGN KEY (certificateId) REFERENCES seafastening_certificates(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE cargo_details (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        certificateId INTEGER,
        serialNo INTEGER,
        location TEXT,
        cargos TEXT,
        idMarkings TEXT,
        weight TEXT,
        dimensions TEXT,
        remarks TEXT,
        FOREIGN KEY (certificateId) REFERENCES towage_certificates(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE loadout_certificates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        headerImagePath TEXT,
        certificateTitle TEXT,
        operationType TEXT,
        jobNumber TEXT,
        projectTitle TEXT,
        certificateNumber TEXT,
        client TEXT,
        cargo TEXT,
        modeOfOperation TEXT,
        bargeVessel TEXT,
        issuedBy TEXT,
        location TEXT,
        issuedDate TEXT,
        noDateCheckbox INTEGER,
        stampPath TEXT,
        signaturePath TEXT,
        signatureClient TEXT,
        includeCargoDetails INTEGER,
        isCargoDetailsNA INTEGER,
        synced INTEGER DEFAULT 0
      )
    ''');

    await _createIhmOfflineTables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE towage_certificates ADD COLUMN synced INTEGER DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE seafastening_certificates ADD COLUMN synced INTEGER DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE loadout_certificates ADD COLUMN synced INTEGER DEFAULT 0',
      );
    }

    if (oldVersion < 4) {
      await _createIhmOfflineTables(db);
    }
  }

  Future<void> _createIhmOfflineTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ihm_areas (
        id INTEGER PRIMARY KEY,
        surveyJobId INTEGER NOT NULL,
        areaName TEXT,
        description TEXT,
        sortOrder INTEGER DEFAULT 0,
        synced INTEGER DEFAULT 1,
        updatedAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ihm_checkpoints (
        id INTEGER PRIMARY KEY,
        surveyJobId INTEGER NOT NULL,
        ihmAreaId INTEGER NOT NULL,
        sampleNo TEXT,
        description TEXT,
        tableType TEXT,
        location TEXT,
        equipmentName TEXT,
        component TEXT,
        tableAB TEXT,
        hazardousMaterial TEXT,
        quantityUnitKg TEXT,
        quantityNo TEXT,
        quantityTotalKg TEXT,
        manufacturerBrandName TEXT,
        documentAnalysisResult TEXT,
        samplingCheck TEXT,
        visualCheck TEXT,
        checkResult TEXT,
        result TEXT,
        remarks TEXT,
        isPchm INTEGER DEFAULT 0,
        locationRemarks TEXT,
        sourceRowNumber INTEGER,
        synced INTEGER DEFAULT 1,
        updatedAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ihm_markers (
        id INTEGER PRIMARY KEY,
        serverId INTEGER,
        surveyJobId INTEGER NOT NULL,
        ihmAreaId INTEGER,
        ihmCheckpointId INTEGER,
        imagePath TEXT,
        xPercent REAL,
        yPercent REAL,
        markerLabel TEXT,
        notes TEXT,
        deleted INTEGER DEFAULT 0,
        synced INTEGER DEFAULT 1,
        updatedAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ihm_sampling_photos (
        id INTEGER PRIMARY KEY,
        serverId INTEGER,
        surveyJobId INTEGER NOT NULL,
        ihmAreaId INTEGER,
        ihmCheckpointId INTEGER NOT NULL,
        filePath TEXT,
        localFilePath TEXT,
        caption TEXT,
        deleted INTEGER DEFAULT 0,
        synced INTEGER DEFAULT 1,
        updatedAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ihm_sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entityType TEXT NOT NULL,
        entityLocalId INTEGER NOT NULL,
        operation TEXT NOT NULL,
        payloadJson TEXT NOT NULL,
        status INTEGER DEFAULT 0,
        retryCount INTEGER DEFAULT 0,
        lastError TEXT,
        createdAt TEXT,
        updatedAt TEXT
      )
    ''');
  }

  //synced all certficate
  Future<void> syncAllCertificates() async {
    final db = DatabaseHelper.instance;
    final isOnline = await isConnected();

    if (!isOnline) {
      print("📴 Offline – Sync postponed.");
      return;
    }

    try {
      // ✅ 1. Towage Certificates
      final unsyncedTowage = await db.getUnsyncedTowageCertificates();
      for (final cert in unsyncedTowage) {
        final certJson = cert.toJson()
          ..['model'] = 'Towage'
          ..remove('id'); // Remove local ID

        final response = await ApiService.submitTowageCertificate(certJson);
        print("✅ Synced Towage: $response");
        await db.markTowageCertificateAsSynced(cert.id!);
      }

      // ✅ 2. Seafastening Certificates
      final unsyncedSeafastening = await db
          .getUnsyncedSeaFasteningCertificates();
      for (final cert in unsyncedSeafastening) {
        final certJson = cert.toJson()
          ..['model'] = 'Seafastening'
          ..remove('id');

        // Fix nested list items if needed
        if (certJson['cargoDetails'] != null &&
            certJson['cargoDetails'] is List) {
          certJson['cargoDetails'] = (certJson['cargoDetails'] as List).map((
            item,
          ) {
            final fixed = Map<String, dynamic>.from(item);
            fixed.remove('id');
            return fixed;
          }).toList();
        }

        final response = await ApiService.submitSeafasteningCertificate(
          certJson,
        );
        print("✅ Synced Seafastening: $response");
        await db.markSeaFasteningCertificateAsSynced(cert.id!);
      }

      // ✅ 3. Loadout Certificates
      final unsyncedLoadout = await db.getUnsyncedLoadoutCertificates();
      for (final cert in unsyncedLoadout) {
        final certJson = cert.toJson()
          ..['model'] = 'Loadout'
          ..remove('id');

        if (certJson['cargoDetails'] != null &&
            certJson['cargoDetails'] is List) {
          certJson['cargoDetails'] = (certJson['cargoDetails'] as List).map((
            item,
          ) {
            final fixed = Map<String, dynamic>.from(item);
            fixed.remove('id');
            return fixed;
          }).toList();
        }

        final response = await ApiService.submitLoadoutCertificate(certJson);
        print("✅ Synced Loadout: $response");
        await db.markLoadoutCertificateAsSynced(cert.id!);
      }

      print("🟢 All offline certificates synced successfully.");
    } catch (e) {
      print("❌ Sync failed: $e");
    }
  }

  ///UNSYNCED METHODS

  Future<List<TowageCertificate>> getUnsyncedTowageCertificates() async {
    final db = await database;
    final maps = await db.query('towage_certificates', where: 'synced = 0');
    return maps.map((map) => TowageCertificate.fromMap(map)).toList();
  }

  Future<List<SeaFasteningCertificate>>
  getUnsyncedSeaFasteningCertificates() async {
    final db = await database;
    final maps = await db.query(
      'seafastening_certificates',
      where: 'synced = 0',
    );
    return maps.map((map) => SeaFasteningCertificate.fromMap(map)).toList();
  }

  Future<List<LoadoutCertificate>> getUnsyncedLoadoutCertificates() async {
    final db = await database;
    final maps = await db.query('loadout_certificates', where: 'synced = 0');
    return maps.map((map) => LoadoutCertificate.fromMap(map)).toList();
  }

  ///End unsynced method

  ///
  ///SYNCED METHOD
  Future<void> markTowageCertificateAsSynced(int id) async {
    final db = await database;
    await db.update(
      'towage_certificates',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markSeaFasteningCertificateAsSynced(int id) async {
    final db = await database;
    await db.update(
      'seafastening_certificates',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markLoadoutCertificateAsSynced(int id) async {
    final db = await database;
    await db.update(
      'loadout_certificates',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  ///END SYNCED METHOD

  /// TOWAGE OPERATIONS
  Future<int> insertCertificate(TowageCertificate cert) async {
    final db = await database;
    return await db.insert('towage_certificates', cert.toMap());
  }

  Future<List<TowageCertificate>> getAllCertificates() async {
    final db = await database;
    final maps = await db.query('towage_certificates');

    List<TowageCertificate> list = [];

    for (final map in maps) {
      final cert = TowageCertificate.fromMap(map);
      cert.defaultRecommendations = await getRecommendations(cert.id!);
      cert.cargoDetails = await getCargoDetails(cert.id!);
      list.add(cert);
    }

    return list;
  }

  Future<void> upsertTowageCertificate(Map<String, dynamic> certData) async {
    final db = await database;
    final id = certData['id'];

    final existing = await db.query(
      'towage_certificates',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (existing.isEmpty) {
      // Insert if not present
      certData['synced'] = 1;
      await db.insert('towage_certificates', certData);
    }
  }

  Future<TowageCertificate?> getTowageCertificateById(int id) async {
    final db = await database;
    final maps = await db.query(
      'towage_certificates',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return TowageCertificate.fromMap(maps.first);
    }
    return null;
  }

  Future<void> deleteCertificate(int id) async {
    final db = await database;
    await db.delete('towage_certificates', where: 'id = ?', whereArgs: [id]);
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  /// SEAFASTENING OPERATIONS
  Future<int> insertSeaFastening(SeaFasteningCertificate cert) async {
    final db = await database;
    return await db.insert(
      'seafastening_certificates',
      cert.toMap(forInsert: true),
    );
  }

  Future<List<SeaFasteningCertificate>>
  getAllUnsyncedSeaFasteningCertificates() async {
    final db = await database;

    final maps = await db.query(
      'seafastening_certificates',
      where: 'synced = ?',
      whereArgs: [0],
    );
    List<SeaFasteningCertificate> list = [];

    for (final map in maps) {
      final cert = SeaFasteningCertificate.fromMap(map);
      cert.recommendations = await getSeafasteningRecommendations(cert.id!);
      cert.cargoDetails = await getCargoDetails(cert.id!);
      list.add(cert);
    }

    return list;
  }

  Future<SeaFasteningCertificate?> getSeafasteningCertificateById(
    int id,
  ) async {
    final db = await database;
    final maps = await db.query(
      'seafastening_certificates',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return SeaFasteningCertificate.fromMap(maps.first);
    }
    return null;
  }

  Future<void> deleteSeaFastening(int id) async {
    final db = await database;
    await db.delete(
      'seafastening_certificates',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// COMMON CHILD TABLES
  Future<void> insertRecommendations(
    List<DefaultRecommendation> recommendations,
    int certificateId,
  ) async {
    final db = await database;
    for (final recommendation in recommendations) {
      await db.insert('default_recommendations', {
        'certificateId': certificateId,
        'recommendationText': recommendation.recommendationText,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> insertSeafasteningRecommendations(
    List<Recommendation> recommendations,
    int certificateId,
  ) async {
    final db = await database;
    for (final r in recommendations) {
      await db.insert('recommendations', {
        'certificateId': certificateId,
        'recommendationText': r.recommendationText,
      });
    }
  }

  Future<List<DefaultRecommendation>> getRecommendations(
    int certificateId,
  ) async {
    final db = await database;
    final maps = await db.query(
      'default_recommendations',
      where: 'certificateId = ?',
      whereArgs: [certificateId],
    );
    return List.generate(
      maps.length,
      (i) => DefaultRecommendation.fromJson(maps[i]),
    );
  }

  Future<List<Recommendation>> getSeafasteningRecommendations(
    int certificateId,
  ) async {
    final db = await database;
    final maps = await db.query(
      'recommendations',
      where: 'certificateId = ?',
      whereArgs: [certificateId],
    );
    return List.generate(maps.length, (i) => Recommendation.fromMap(maps[i]));
  }

  Future<List<String>> fetchSeafasteningRecommendationTexts(
    int certificateId,
  ) async {
    final db = await database;
    final maps = await db.query(
      'recommendations',
      where: 'certificateId = ?',
      whereArgs: [certificateId],
    );
    return List<String>.from(
      maps.map((row) => row['recommendationText'] as String),
    );
  }

  Future<void> insertCargoDetails(List<CargoDetail> list) async {
    final db = await database;
    for (var item in list) {
      await db.insert('cargo_details', item.toJson(forInsert: true));
    }
  }

  Future<List<CargoDetail>> getCargoDetails(int certificateId) async {
    final db = await database;
    final maps = await db.query(
      'cargo_details',
      where: 'certificateId = ?',
      whereArgs: [certificateId],
    );

    return List.generate(maps.length, (i) => CargoDetail.fromJson(maps[i]));
  }

  /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  /// LOADOUT OPERATIONS
  Future<int> insertLoadoutCertificate(LoadoutCertificate cert) async {
    final db = await database;
    return await db.insert('loadout_certificates', cert.toMap());
  }

  Future<List<LoadoutCertificate>> getAllLoadoutCertificates() async {
    final db = await database;
    final maps = await db.query('loadout_certificates');
    return List.generate(
      maps.length,
      (i) => LoadoutCertificate.fromMap(maps[i]),
    );
  }

  Future<LoadoutCertificate?> getLoadoutCertificateById(int id) async {
    final db = await database;
    final result = await db.query(
      'loadout_certificates',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isNotEmpty) {
      return LoadoutCertificate.fromMap(result.first);
    }
    return null;
  }

  Future<void> deleteLoadoutCertificate(int id) async {
    final db = await database;
    await db.delete('loadout_certificates', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> logTableSchema(String table) async {
    final db = await database;
    final result = await db.rawQuery('PRAGMA table_info($table)');
    print('🧩 Table schema for $table:');
    for (final row in result) {
      print(row);
    }
  }
}
