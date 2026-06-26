import 'package:Auras/model/CarogDetails_model.dart';
import 'package:Auras/model/Recommendation.dart';
import 'package:intl/intl.dart';

class SeaFasteningCertificate {
  int? synced; // ✅ Add to class
  int? id;
  String? userId;
  String? headerImagePath;
  String? certificateTitle;
  String? issuedBy;
  String? client;
  String? transportUnit;
  String? cargoType;
  String? projectTitle;
  String? fromPort;
  String? toPort;
  String? jobNumber;
  String? certificateNumber;
  String? issuedDate;
  int? slNo;
  List<Recommendation>? recommendations;

  String? stampPath;
  String? signaturePath;
  String? signatureClient;
  List<CargoDetail>? cargoDetails;
  bool? isCargoDetailsNA;
  bool? includeCargoDetails;
  String? cargo;
  int? serialNo;
  String? location;
  String? idMarkings;
  String? weight;
  String? dimensions;
  String? remarks;
  bool? includeAnnexure2;

  SeaFasteningCertificate({
    this.id,
    this.synced,
    this.userId,
    this.headerImagePath,
    this.certificateTitle,
    this.issuedBy,
    this.client,
    this.transportUnit,
    this.projectTitle,
    this.fromPort,
    this.cargoType,
    this.toPort,
    this.jobNumber,
    this.certificateNumber,
    this.issuedDate,
    this.slNo,
    this.recommendations = const [],
    this.stampPath,
    this.signaturePath,
    this.signatureClient,
    this.cargoDetails = const [],
    this.isCargoDetailsNA,
    this.includeCargoDetails,
    this.cargo,
    this.serialNo,
    this.location,
    this.idMarkings,
    this.weight,
    this.dimensions,
    this.remarks,
    this.includeAnnexure2,
  });

  Map<String, dynamic> toMap({bool forInsert = false}) {
    final map = {
      'userId': userId,
      'synced': synced ?? 0,
      'headerImagePath': headerImagePath,
      'certificateTitle': certificateTitle,
      'issuedBy': issuedBy,
      'client': client,
      'transportUnit': transportUnit,
      'projectTitle': projectTitle,
      'fromPort': fromPort,
      'toPort': toPort,
      'cargoType': cargoType,
      'jobNumber': jobNumber,
      'certificateNumber': certificateNumber,
      'issuedDate': issuedDate,
      'SlNo': slNo ?? 0,
      'stampPath': stampPath,
      'signaturePath': signaturePath,
      'signatureClient': signatureClient,
      'isCargoDetailsNA': isCargoDetailsNA == true ? 1 : 0,
      'includeCargoDetails': includeCargoDetails == true ? 1 : 0,
      'cargo': cargo,
      'includeAnnexure2': includeAnnexure2 == true ? 1 : 0,
    };

    if (!forInsert && id != null) {
      map['id'] = id;
    }

    return map;
  }

  factory SeaFasteningCertificate.fromMap(Map<String, dynamic> map) {
    return SeaFasteningCertificate(
      id: map['id'],
      userId: map['userId'],
      synced: map['synced'] ?? 0, // ✅ Add this
      headerImagePath: map['headerImagePath'],
      certificateTitle: map['certificateTitle'],
      issuedBy: map['issuedBy'],
      client: map['client'],
      transportUnit: map['transportUnit'],
      projectTitle: map['projectTitle'],
      fromPort: map['fromPort'],
      toPort: map['toPort'],
      jobNumber: map['jobNumber'],
      certificateNumber: map['certificateNumber'],
      issuedDate: map['issuedDate'],
      slNo: map['slNo'],
      cargoType: map['cargoType'],
      stampPath: map['stampPath'],
      signaturePath: map['signaturePath'],
      signatureClient: map['signatureClient'],
      isCargoDetailsNA: map['isCargoDetailsNA'] == 1,
      includeCargoDetails: map['includeCargoDetails'] == 1,
      cargo: map['cargo'],
      serialNo: map['serialNo'],
      location: map['location'],
      idMarkings: map['idMarkings'],
      weight: map['weight'],
      dimensions: map['dimensions'],
      remarks: map['remarks'],
      includeAnnexure2: map['includeAnnexure2'] == 1,
    );
  }
  Map<String, dynamic> toJson({bool forSync = false}) {
    final map = <String, dynamic>{
      'UserId': userId,
      'Synced': synced ?? 0,
      'HeaderImagePath': headerImagePath,
      'CertificateTitle': certificateTitle,
      'IssuedBy': issuedBy,
      'CargoType': cargoType,
      'Client': client,
      'TransportUnit': transportUnit,
      'ProjectTitle': projectTitle,
      'FromPort': fromPort,
      'ToPort': toPort,
      'JobNumber': jobNumber,
      'CertificateNumber': certificateNumber,
      'IssuedDate': issuedDate?.isNotEmpty == true
          ? DateFormat('yyyy-MMM-dd').format(DateTime.parse(issuedDate!))
          : null,
      'SlNo': slNo ?? 0,
      'StampPath': stampPath,
      'SignaturePath': signaturePath,
      'SignatureClient': signatureClient,
      'IsCargoDetailsNA': isCargoDetailsNA,
      'IncludeCargoDetails': includeCargoDetails,
      'Cargo': cargo,
      'SerialNo': serialNo ?? 0,
      'Location': location,
      'IDMarkings': idMarkings,
      'Weight': weight,
      'Dimensions': dimensions,
      'Remarks': remarks,
      'IncludeAnnexure2': includeAnnexure2,
      'Recommendations': (recommendations ?? [])
          .map((e) => e.toJson(forSync: forSync))
          .toList(),
      'CargoDetails': (cargoDetails ?? [])
          .map((e) => e.toJson(forSync: forSync))
          .toList(),
    };

    // ❌ Do not include `id` when syncing
    if (!forSync && id != null) {
      map['Id'] = id;
    }

    return map;
  }

  factory SeaFasteningCertificate.fromJson(Map<String, dynamic> json) {
    return SeaFasteningCertificate(
      id: json['id'],
      userId: json['userId'],
      synced: json['synced'] ?? json['Synced'] ?? 0, // ✅ Add this
      headerImagePath: json['headerImagePath'],
      certificateTitle: json['certificateTitle'],
      issuedBy: json['issuedBy'],
      client: json['client'],
      transportUnit: json['transportUnit'],
      projectTitle: json['projectTitle'],
      fromPort: json['fromPort'],
      toPort: json['toPort'],
      jobNumber: json['jobNumber'],
      certificateNumber: json['certificateNumber'],
      cargoType: json['CargoType'],
      issuedDate: json['issuedDate'],
      slNo: json['slNo'],
      stampPath: json['stampPath'],
      signaturePath: json['signaturePath'],
      signatureClient: json['signatureClient'],
      isCargoDetailsNA: json['isCargoDetailsNA'],
      includeCargoDetails: json['includeCargoDetails'],
      cargo: json['cargo'],
      serialNo: json['serialNo'],
      location: json['location'],
      idMarkings: json['idMarkings'],
      weight: json['weight'],
      dimensions: json['dimensions'],
      remarks: json['remarks'],
      includeAnnexure2: json['includeAnnexure2'],
      recommendations: (json['recommendations'] != null)
          ? List<Recommendation>.from(
              (json['recommendations'] as List).map(
                (x) => Recommendation.fromJson(x),
              ),
            )
          : [],
      cargoDetails: (json['cargoDetails'] != null)
          ? List<CargoDetail>.from(
              (json['cargoDetails'] as List).map(
                (x) => CargoDetail.fromJson(x),
              ),
            )
          : [],
    );
  }
  bool get isSynced => synced == 1;

  SeaFasteningCertificate copyWith({
    int? id,
    String? userId,
    int? synced, // ✅ Add this
    String? headerImagePath,
    String? certificateTitle,
    String? issuedBy,
    String? client,
    String? transportUnit,
    String? projectTitle,
    String? fromPort,
    String? toPort,
    String? jobNumber,
    String? certificateNumber,
    String? issuedDate,
    int? slNo,
    List<Recommendation>? recommendations,
    String? stampPath,
    String? signaturePath,
    String? signatureClient,
    List<CargoDetail>? cargoDetails,
    bool? isCargoDetailsNA,
    bool? includeCargoDetails,
    String? cargo,
    int? serialNo,
    String? location,
    String? idMarkings,
    String? weight,
    String? dimensions,
    String? remarks,
    bool? includeAnnexure2,
  }) {
    return SeaFasteningCertificate(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      headerImagePath: headerImagePath ?? this.headerImagePath,
      certificateTitle: certificateTitle ?? this.certificateTitle,
      issuedBy: issuedBy ?? this.issuedBy,
      client: client ?? this.client,
      transportUnit: transportUnit ?? this.transportUnit,
      projectTitle: projectTitle ?? this.projectTitle,
      fromPort: fromPort ?? this.fromPort,
      toPort: toPort ?? this.toPort,
      jobNumber: jobNumber ?? this.jobNumber,
      certificateNumber: certificateNumber ?? this.certificateNumber,
      issuedDate: issuedDate ?? this.issuedDate,
      slNo: slNo ?? this.slNo,
      recommendations: recommendations ?? this.recommendations,
      stampPath: stampPath ?? this.stampPath,
      signaturePath: signaturePath ?? this.signaturePath,
      signatureClient: signatureClient ?? this.signatureClient,
      cargoDetails: cargoDetails ?? this.cargoDetails,
      isCargoDetailsNA: isCargoDetailsNA ?? this.isCargoDetailsNA,
      includeCargoDetails: includeCargoDetails ?? this.includeCargoDetails,
      cargo: cargo ?? this.cargo,
      serialNo: serialNo ?? this.serialNo,
      location: location ?? this.location,
      idMarkings: idMarkings ?? this.idMarkings,
      weight: weight ?? this.weight,
      dimensions: dimensions ?? this.dimensions,
      remarks: remarks ?? this.remarks,
      includeAnnexure2: includeAnnexure2 ?? this.includeAnnexure2,
      synced: synced ?? this.synced, // ✅ Add this
    );
  }
}
