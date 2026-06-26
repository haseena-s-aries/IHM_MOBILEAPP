import 'package:Auras/model/CarogDetails_model.dart';
import 'dart:typed_data';
import 'package:intl/intl.dart';

class LoadoutCertificate {
  int? synced;
  int? id;
  String? headerImagePath;
  String? certificateTitle;
  String? operationType;
  String? jobNumber;
  String? projectTitle;
  String? certificateNumber;
  String? client;
  String? cargo;
  String? modeOfOperation;
  String? bargeVessel;
  String? issuedBy;
  String? location;
  String? issuedDate;
  bool? noDateCheckbox;
  String? stampPath;
  String? signaturePath;
  String? signatureClient;
  bool? includeCargoDetails;
  bool? isCargoDetailsNA;
  List<CargoDetail>? cargoDetails;

  LoadoutCertificate({
    this.id,
    this.synced, // ✅
    this.headerImagePath,
    this.certificateTitle,
    this.operationType,
    this.jobNumber,
    this.projectTitle,
    this.certificateNumber,
    this.client,
    this.cargo,
    this.modeOfOperation,
    this.bargeVessel,
    this.issuedBy,
    this.location,
    this.issuedDate,
    this.noDateCheckbox,
    this.stampPath,
    this.signaturePath,
    this.signatureClient,
    this.includeCargoDetails,
    this.isCargoDetailsNA,
    this.cargoDetails,
  });

  Map<String, dynamic> toMap({bool forInsert = false}) {
    final map = {
      'headerImagePath': headerImagePath,
      'certificateTitle': certificateTitle,
      'synced': synced ?? 0, // ✅
      'operationType': operationType,
      'jobNumber': jobNumber,
      'projectTitle': projectTitle,
      'certificateNumber': certificateNumber,
      'client': client,
      'cargo': cargo,
      'modeOfOperation': modeOfOperation,
      'bargeVessel': bargeVessel,
      'issuedBy': issuedBy,
      'location': location,
      'issuedDate': issuedDate,
      'NoDateCheckbox': noDateCheckbox == true ? 1 : 0,
      'stampPath': stampPath,
      'signaturePath': signaturePath,
      'signatureClient': signatureClient,
      'includeCargoDetails': includeCargoDetails == true ? 1 : 0,
      'isCargoDetailsNA': isCargoDetailsNA == true ? 1 : 0,
    };

    if (!forInsert && id != null) {
      map['id'] = id;
    }

    return map;
  }

  factory LoadoutCertificate.fromMap(Map<String, dynamic> map) {
    return LoadoutCertificate(
      synced: map['synced'] ?? 0, // ✅
      id: map['id'],
      headerImagePath: map['headerImagePath'],
      certificateTitle: map['certificateTitle'],
      operationType: map['operationType'],
      jobNumber: map['jobNumber'],
      projectTitle: map['projectTitle'],
      certificateNumber: map['certificateNumber'],
      client: map['client'],
      cargo: map['cargo'],
      modeOfOperation: map['modeOfOperation'],
      bargeVessel: map['bargeVessel'],
      issuedBy: map['issuedBy'],
      location: map['location'],
      issuedDate: map['issuedDate'],
      noDateCheckbox: map['noDateCheckbox'] == 1,
      stampPath: map['stampPath'],
      signaturePath: map['signaturePath'],
      signatureClient: map['signatureClient'],
      includeCargoDetails: map['includeCargoDetails'] == 1,
      isCargoDetailsNA: map['isCargoDetailsNA'] == 1,
    );
  }

  Map<String, dynamic> toJson({bool forSync = false}) {
    final map = <String, dynamic>{
      'synced': synced ?? 0,
      'headerImagePath': headerImagePath,
      'certificateTitle': certificateTitle,
      'operationType': operationType,
      'jobNumber': jobNumber,
      'projectTitle': projectTitle,
      'certificateNumber': certificateNumber,
      'client': client,
      'cargo': cargo,
      'modeOfOperation': modeOfOperation,
      'bargeVessel': bargeVessel,
      'issuedBy': issuedBy,
      'location': location,
      'issuedDate': issuedDate?.isNotEmpty == true
          ? DateFormat('yyyy/MMM/dd').format(DateTime.parse(issuedDate!))
          : null,
      'NoDateCheckbox': noDateCheckbox,
      'stampPath': stampPath,
      'signaturePath': signaturePath,
      'signatureClient': signatureClient,
      'includeCargoDetails': includeCargoDetails,
      'isCargoDetailsNA': isCargoDetailsNA,
      'cargoDetails': cargoDetails
          ?.map((e) => e.toJson(forSync: forSync))
          .toList(),
    };

    // ❌ Don't send `id` to API if syncing
    if (!forSync && id != null) {
      map['id'] = id;
    }

    return map;
  }

  factory LoadoutCertificate.fromJson(Map<String, dynamic> json) {
    return LoadoutCertificate(
      id: json['id'],
      synced: json['synced'] ?? 0, // ✅
      headerImagePath: json['headerImagePath'],
      certificateTitle: json['certificateTitle'],
      operationType: json['operationType'],
      jobNumber: json['jobNumber'],
      projectTitle: json['projectTitle'],
      certificateNumber: json['certificateNumber'],
      client: json['client'],
      cargo: json['cargo'],
      modeOfOperation: json['modeOfOperation'],
      bargeVessel: json['bargeVessel'],
      issuedBy: json['issuedBy'],
      location: json['location'],
      issuedDate: json['issuedDate'],
      noDateCheckbox: json['noDateCheckbox'],
      stampPath: json['stampPath'],
      signaturePath: json['signaturePath'],
      signatureClient: json['signatureClient'],
      includeCargoDetails: json['includeCargoDetails'],
      isCargoDetailsNA: json['isCargoDetailsNA'],
      cargoDetails: (json['cargoDetails'] as List<dynamic>?)
          ?.map((e) => CargoDetail.fromJson(e))
          .toList(),
    );
  }

  bool get isSynced => synced == 1;

  LoadoutCertificate copyWith({
    int? id,
    int? synced, // ✅
    String? headerImagePath,
    String? certificateTitle,
    String? operationType,
    String? jobNumber,
    String? projectTitle,
    String? certificateNumber,
    String? client,
    String? cargo,
    String? modeOfOperation,
    String? bargeVessel,
    String? issuedBy,
    String? location,
    String? issuedDate,
    bool? noDateCheckbox,
    String? stampPath,
    String? signaturePath,
    String? signatureClient,
    bool? includeCargoDetails,
    bool? isCargoDetailsNA,
    List<CargoDetail>? cargoDetails,
  }) {
    return LoadoutCertificate(
      id: id ?? this.id,
      headerImagePath: headerImagePath ?? this.headerImagePath,
      certificateTitle: certificateTitle ?? this.certificateTitle,
      operationType: operationType ?? this.operationType,
      jobNumber: jobNumber ?? this.jobNumber,
      projectTitle: projectTitle ?? this.projectTitle,
      certificateNumber: certificateNumber ?? this.certificateNumber,
      client: client ?? this.client,
      cargo: cargo ?? this.cargo,
      modeOfOperation: modeOfOperation ?? this.modeOfOperation,
      bargeVessel: bargeVessel ?? this.bargeVessel,
      issuedBy: issuedBy ?? this.issuedBy,
      location: location ?? this.location,
      issuedDate: issuedDate ?? this.issuedDate,
      noDateCheckbox: noDateCheckbox ?? this.noDateCheckbox,
      stampPath: stampPath ?? this.stampPath,
      signaturePath: signaturePath ?? this.signaturePath,
      signatureClient: signatureClient ?? this.signatureClient,
      includeCargoDetails: includeCargoDetails ?? this.includeCargoDetails,
      isCargoDetailsNA: isCargoDetailsNA ?? this.isCargoDetailsNA,
      cargoDetails: cargoDetails ?? this.cargoDetails,
      synced: synced ?? this.synced, // ✅
    );
  }
}
