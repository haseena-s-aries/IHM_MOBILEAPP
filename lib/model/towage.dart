import 'package:Auras/model/CarogDetails_model.dart';
import 'package:Auras/model/DRecommendation.dart';

class TowageCertificate {
  int? synced;
  int? id;
  String? headerImagePath;
  String? certificateType;
  String? jobNumber;
  String? projectTitle;
  String? certificateNumber;
  String? clientName;
  String? cargo;
  String? departurePort;
  String? arrivalPort;
  String? issuedDate;
  bool? noDateCheckbox;
  String? surveyedBy;
  String? reviewedBy;
  String? towName;
  String? tugName;
  String? stampPath;
  String? signaturePath;
  String? signatureClient;
  bool? isCargoDetailsNA;
  bool? includeAnnexure2;
  bool? includeCargoDetails;
  List<DefaultRecommendation>? defaultRecommendations;
  List<CargoDetail>? cargoDetails;

  TowageCertificate({
    this.id,
    this.headerImagePath,
    this.certificateType,
    this.jobNumber,
    this.projectTitle,
    this.certificateNumber,
    this.clientName,
    this.cargo,
    this.departurePort,
    this.arrivalPort,
    this.issuedDate,
    this.noDateCheckbox,
    this.surveyedBy,
    this.reviewedBy,
    this.towName,
    this.tugName,
    this.synced, // ✅ Add this
    this.stampPath,
    this.signaturePath,
    this.signatureClient,
    this.isCargoDetailsNA,
    this.includeAnnexure2,
    this.includeCargoDetails,
    this.defaultRecommendations,
    this.cargoDetails,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'headerImagePath': headerImagePath,
      'certificateType': certificateType,
      'jobNumber': jobNumber,
      'projectTitle': projectTitle,
      'certificateNumber': certificateNumber,
      'clientName': clientName,
      'cargo': cargo,
      'departurePort': departurePort,
      'arrivalPort': arrivalPort,
      'issuedDate': issuedDate,
      'noDateCheckbox': noDateCheckbox == true ? 1 : 0,
      'surveyedBy': surveyedBy,
      'synced': synced ?? 0, // ✅ Add this
      'reviewedBy': reviewedBy,
      'towName': towName,
      'tugName': tugName,
      'stampPath': stampPath,
      'signaturePath': signaturePath,
      'signatureClient': signatureClient,
      'isCargoDetailsNA': isCargoDetailsNA == true ? 1 : 0,
      'includeAnnexure2': includeAnnexure2 == true ? 1 : 0,
      'includeCargoDetails': includeCargoDetails == true ? 1 : 0,
    };
  }

  factory TowageCertificate.fromMap(Map<String, dynamic> map) {
    return TowageCertificate(
      id: map['id'],
      headerImagePath: map['headerImagePath'],
      certificateType: map['certificateType'],
      jobNumber: map['jobNumber'],
      projectTitle: map['projectTitle'],
      certificateNumber: map['certificateNumber'],
      clientName: map['clientName'],
      cargo: map['cargo'],
      departurePort: map['departurePort'],
      arrivalPort: map['arrivalPort'],
      issuedDate: map['issuedDate'],
      noDateCheckbox: map['noDateCheckbox'] == 1,
      surveyedBy: map['surveyedBy'],
      reviewedBy: map['reviewedBy'],
      towName: map['towName'],
      synced: map['synced'] ?? 0, // ✅ Add this
      tugName: map['tugName'],
      stampPath: map['stampPath'],
      signaturePath: map['signaturePath'],
      signatureClient: map['signatureClient'],
      isCargoDetailsNA: map['isCargoDetailsNA'] == 1,
      includeAnnexure2: map['includeAnnexure2'] == 1,
      includeCargoDetails: map['includeCargoDetails'] == 1,
    );
  }

  Map<String, dynamic> toJson({bool forSync = false}) {
    final map = <String, dynamic>{
      'certificateType': certificateType,
      'jobNumber': jobNumber,
      'projectTitle': projectTitle,
      'certificateNumber': certificateNumber,
      'clientName': clientName,
      'towName': towName,
      'tugName': tugName,
      'cargo': cargo,
      'departurePort': departurePort,
      'arrivalPort': arrivalPort,
      'surveyedBy': surveyedBy,
      'reviewedBy': reviewedBy,
      'issuedDate': issuedDate != null && issuedDate!.isNotEmpty
          ? issuedDate
          : null,
      'NoDateCheckbox': noDateCheckbox == true,
      'isCargoDetailsNA': isCargoDetailsNA == true,
      'includeCargoDetails': includeCargoDetails == true,
      'includeAnnexure2': includeAnnexure2 == true,
      'synced': synced ?? 0,
      'stampPath': stampPath,
      'signaturePath': signaturePath,
      'signatureClient': signatureClient,
      'headerImagePath': headerImagePath,
      'defaultRecommendations': defaultRecommendations
          ?.map((r) => r.toJson(forSync: forSync))
          .toList(),
      'cargoDetails': cargoDetails
          ?.map((c) => c.toJson(forSync: forSync))
          .toList(),
    };

    // Only include model field when syncing
    if (forSync) {
      map['model'] = 'Towage';
    }

    // Only include local ID when not syncing
    if (!forSync && id != null) {
      map['certificateId'] = id;
    }

    return map;
  }

  factory TowageCertificate.fromJson(Map<String, dynamic> json) {
    return TowageCertificate(
      id: json['id'],
      headerImagePath: json['headerImagePath'],
      certificateType: json['certificateType'],
      jobNumber: json['jobNumber'],
      projectTitle: json['projectTitle'],
      certificateNumber: json['certificateNumber'],
      clientName: json['clientName'],
      cargo: json['cargo'],
      departurePort: json['departurePort'],
      arrivalPort: json['arrivalPort'],
      issuedDate: json['issuedDate'],
      noDateCheckbox: json['noDateCheckbox'],
      surveyedBy: json['surveyedBy'],
      reviewedBy: json['reviewedBy'],
      synced: json['synced'] ?? 0, // ✅ Include this
      towName: json['towName'],
      tugName: json['tugName'],
      stampPath: json['stampPath'],
      signaturePath: json['signaturePath'],
      signatureClient: json['signatureClient'],
      isCargoDetailsNA: json['isCargoDetailsNA'],
      includeAnnexure2: json['includeAnnexure2'],
      includeCargoDetails: json['includeCargoDetails'],
      defaultRecommendations: (json['defaultRecommendations'] as List<dynamic>?)
          ?.map((e) => DefaultRecommendation.fromJson(e))
          .toList(),
      cargoDetails: (json['cargoDetails'] as List<dynamic>?)
          ?.map((e) => CargoDetail.fromJson(e))
          .toList(),
    );
  }
  bool get isSynced => synced == 1;

  TowageCertificate copyWith({
    int? synced, // ✅ ADD THIS
    int? certificateId,
    String? headerImagePath,
    String? certificateType,
    String? jobNumber,
    String? projectTitle,
    String? certificateNumber,
    String? clientName,
    String? cargo,
    String? departurePort,
    String? arrivalPort,
    String? issuedDate,
    bool? noDateCheckbox,
    String? surveyedBy,
    String? reviewedBy,
    String? towName,
    String? tugName,
    String? stampPath,
    String? signaturePath,
    String? signatureClient,
    bool? isCargoDetailsNA,
    bool? includeAnnexure2,
    bool? includeCargoDetails,
    List<DefaultRecommendation>? defaultRecommendations,
    List<CargoDetail>? cargoDetails,
  }) {
    return TowageCertificate(
      id: certificateId ?? id,
      headerImagePath: headerImagePath ?? this.headerImagePath,
      certificateType: certificateType ?? this.certificateType,
      jobNumber: jobNumber ?? this.jobNumber,
      projectTitle: projectTitle ?? this.projectTitle,
      certificateNumber: certificateNumber ?? this.certificateNumber,
      clientName: clientName ?? this.clientName,
      cargo: cargo ?? this.cargo,
      departurePort: departurePort ?? this.departurePort,
      arrivalPort: arrivalPort ?? this.arrivalPort,
      issuedDate: issuedDate ?? this.issuedDate,
      noDateCheckbox: noDateCheckbox ?? this.noDateCheckbox,
      surveyedBy: surveyedBy ?? this.surveyedBy,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      towName: towName ?? this.towName,
      tugName: tugName ?? this.tugName,
      stampPath: stampPath ?? this.stampPath,
      signaturePath: signaturePath ?? this.signaturePath,
      signatureClient: signatureClient ?? this.signatureClient,
      isCargoDetailsNA: isCargoDetailsNA ?? this.isCargoDetailsNA,
      includeAnnexure2: includeAnnexure2 ?? this.includeAnnexure2,
      includeCargoDetails: includeCargoDetails ?? this.includeCargoDetails,
      defaultRecommendations:
          defaultRecommendations ?? this.defaultRecommendations,
      cargoDetails: cargoDetails ?? this.cargoDetails,
      synced: synced ?? this.synced, // ✅ ADD THIS LINE
    );
  }
}
