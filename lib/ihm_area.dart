import 'package:flutter/material.dart';

class IhmArea {
  final int id;
  final String areaName;
  final List<IhmCheckpoint> checkpoints;
  final bool isPchm;
  final String? locationRemarks;

  IhmArea({
    required this.id,
    required this.areaName,
    required this.checkpoints,
    this.isPchm = false,
    this.locationRemarks,
  });

  factory IhmArea.fromJson(Map<String, dynamic> json) => IhmArea(
    id: json['id'] ?? 0,
    areaName: json['areaName'] ?? '',
    checkpoints: (json['checkpoints'] as List? ?? [])
        .map((e) => IhmCheckpoint.fromJson(e))
        .toList(),
    isPchm: json['isPchm'] == true || json['isPchm'] == 1,
    locationRemarks: json['locationRemarks']?.toString(),
  );

  Map<String, dynamic> toLocalMap(int surveyJobId) => {
    'id': id,
    'surveyJobId': surveyJobId,
    'areaName': areaName,
    'synced': 1,
    'updatedAt': DateTime.now().toIso8601String(),
  };

  int get total => checkpoints.length;
  int get visual => checkpoints.where((x) => x.isVisual).length;
  int get sample => checkpoints.where((x) => x.isSample).length;
  int get audited => checkpoints.where((x) => x.isAudited).length;
  int get pending => total - audited;
}

class IhmCheckpoint {
  final int id;
  final String sampleNo;
  final String? location;
  final String? equipmentName;
  final String? component;
  final String? hazardousMaterial;
  final String? samplingCheck;
  final String? visualCheck;
  final String? checkResult;
  final String result;
  final String auditStatus;
  final String? remarks;
  final String? documentAnalysisResult;
  final String? description;
  final String? tableType;
  final String? materialCategory;
  final String? quantityUnitKg;
  final String? quantityNo;
  final String? quantityTotalKg;
  final String? manufacturerBrandName;

  final int surveyJobId;
  final int ihmAreaId;
  final bool isPchm;
  final String? locationRemarks;

  IhmCheckpoint({
    required this.id,
    required this.sampleNo,
    this.location,
    this.equipmentName,
    this.component,
    this.hazardousMaterial,
    this.samplingCheck,
    this.visualCheck,
    this.checkResult,
    this.result = 'Pending',
    this.auditStatus = 'Pending',
    this.remarks,
    this.description,
    this.tableType,
    this.materialCategory,
    this.quantityUnitKg,
    this.quantityNo,
    this.quantityTotalKg,
    this.manufacturerBrandName,

    required this.surveyJobId,
    required this.ihmAreaId,
    this.isPchm = false,
    this.locationRemarks,
    this.documentAnalysisResult,
  });

  factory IhmCheckpoint.fromJson(Map<String, dynamic> json) {
    return IhmCheckpoint(
      id: int.tryParse(json['id'].toString()) ?? 0,
      sampleNo:
          json['sampleNo']?.toString() ??
          json['sample_No']?.toString() ??
          json['sample_NO']?.toString() ??
          '',
      location: json['location']?.toString(),
      equipmentName: json['equipmentName']?.toString(),
      component: json['component']?.toString(),
      hazardousMaterial: json['hazardousMaterial']?.toString(),
      samplingCheck: json['samplingCheck']?.toString(),
      visualCheck: json['visualCheck']?.toString(),
      checkResult:
          json['checkResult']?.toString() ?? json['result']?.toString(),
      result: json['result']?.toString() ?? 'Pending',
      auditStatus:
          json['auditStatus']?.toString() ??
          json['AuditStatus']?.toString() ??
          'Pending',
      remarks: json['remarks']?.toString(),
      documentAnalysisResult: json['documentAnalysisResult']?.toString(),
      description: json['description']?.toString(),
      tableType: json['tableType']?.toString(),
      materialCategory:
          json['materialCategory']?.toString() ?? json['table_A_B']?.toString(),
      quantityUnitKg: json['quantityUnitKg']?.toString(),
      quantityNo: json['quantityNo']?.toString(),
      quantityTotalKg: json['quantityTotalKg']?.toString(),
      manufacturerBrandName: json['manufacturerBrandName']?.toString(),
      surveyJobId: int.tryParse(json['surveyJobId'].toString()) ?? 0,
      ihmAreaId: int.tryParse(json['ihmAreaId'].toString()) ?? 0,
      isPchm: json['isPchm'] == true || json['isPchm'] == 1,
      locationRemarks: json['locationRemarks']?.toString(),
    );
  }

  Map<String, dynamic> toLocalMap() => {
    'id': id,
    'surveyJobId': surveyJobId,
    'ihmAreaId': ihmAreaId,
    'sampleNo': sampleNo,
    'description': description,
    'tableType': tableType,
    'tableAB': materialCategory,
    'quantityUnitKg': quantityUnitKg,
    'quantityNo': quantityNo,
    'quantityTotalKg': quantityTotalKg,
    'manufacturerBrandName': manufacturerBrandName,
    'location': location,
    'equipmentName': equipmentName,
    'component': component,
    'hazardousMaterial': hazardousMaterial,
    'samplingCheck': samplingCheck,
    'visualCheck': visualCheck,
    'checkResult': checkResult,
    'result': result,
    'auditStatus': auditStatus,
    'remarks': remarks,
    'documentAnalysisResult': documentAnalysisResult,
    'isPchm': isPchm ? 1 : 0,
    'locationRemarks': locationRemarks,
    'synced': 1,
    'updatedAt': DateTime.now().toIso8601String(),
  };

  bool get isSample {
    final value = samplingCheck?.trim().toUpperCase() ?? '';
    return value == 'S';
  }

  bool get isVisual {
    final value = visualCheck?.trim().toUpperCase() ?? '';
    return value == 'V';
  }

  bool get isAudited {
    final value = auditStatus.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
    return value == 'done' || value == '3' || value == 'completed';
  }

  String get procedureType {
    if (isSample) return 'Sample';
    if (isVisual) return 'Visual';
    return 'Pending';
  }

  IconData get procedureIcon {
    if (isSample) return Icons.science;
    if (isVisual) return Icons.camera_alt;
    return Icons.help_outline;
  }

  IhmCheckpoint copyWith({
    String? sampleNo,
    String? location,
    String? equipmentName,
    String? component,
    String? hazardousMaterial,
    String? samplingCheck,
    String? visualCheck,
    String? checkResult,
    String? result,
    String? auditStatus,
    String? remarks,
    String? documentAnalysisResult,
    String? description,
    String? tableType,
    String? materialCategory,
    String? quantityUnitKg,
    String? quantityNo,
    String? quantityTotalKg,
    String? manufacturerBrandName,
    bool? isPchm,
    String? locationRemarks,
  }) => IhmCheckpoint(
    id: id,
    sampleNo: sampleNo ?? this.sampleNo,
    location: location ?? this.location,
    equipmentName: equipmentName ?? this.equipmentName,
    component: component ?? this.component,
    hazardousMaterial: hazardousMaterial ?? this.hazardousMaterial,
    samplingCheck: samplingCheck ?? this.samplingCheck,
    visualCheck: visualCheck ?? this.visualCheck,
    checkResult: checkResult ?? this.checkResult,
    result: result ?? this.result,
    auditStatus: auditStatus ?? this.auditStatus,
    remarks: remarks ?? this.remarks,
    documentAnalysisResult:
        documentAnalysisResult ?? this.documentAnalysisResult,
    description: description ?? this.description,
    tableType: tableType ?? this.tableType,
    materialCategory: materialCategory ?? this.materialCategory,
    quantityUnitKg: quantityUnitKg ?? this.quantityUnitKg,
    quantityNo: quantityNo ?? this.quantityNo,
    quantityTotalKg: quantityTotalKg ?? this.quantityTotalKg,
    manufacturerBrandName: manufacturerBrandName ?? this.manufacturerBrandName,
    surveyJobId: surveyJobId,
    ihmAreaId: ihmAreaId,
    isPchm: isPchm ?? this.isPchm,
    locationRemarks: locationRemarks ?? this.locationRemarks,
  );
}

class IhmMarker {
  final int id;
  final int surveyJobId;
  final int? ihmAreaId;
  final int? ihmCheckpointId;
  final String imagePath;
  final double xPercent;
  final double yPercent;
  final String? markerLabel;

  IhmMarker({
    required this.id,
    required this.surveyJobId,
    this.ihmAreaId,
    this.ihmCheckpointId,
    required this.imagePath,
    required this.xPercent,
    required this.yPercent,
    this.markerLabel,
  });

  factory IhmMarker.fromJson(Map<String, dynamic> json) {
    return IhmMarker(
      id: int.tryParse(json['id'].toString()) ?? 0,
      surveyJobId: int.tryParse(json['surveyJobId'].toString()) ?? 0,
      ihmAreaId: json['ihmAreaId'] == null
          ? null
          : int.tryParse(json['ihmAreaId'].toString()),
      ihmCheckpointId: json['ihmCheckpointId'] == null
          ? null
          : int.tryParse(json['ihmCheckpointId'].toString()),
      imagePath: json['imagePath']?.toString() ?? '',
      xPercent: double.tryParse(json['xPercent'].toString()) ?? 0,
      yPercent: double.tryParse(json['yPercent'].toString()) ?? 0,
      markerLabel: json['markerLabel']?.toString(),
    );
  }
  Map<String, dynamic> toLocalMap({int? localId, int synced = 1}) => {
    'id': localId ?? id,
    'serverId': id > 0 ? id : null,
    'surveyJobId': surveyJobId,
    'ihmAreaId': ihmAreaId,
    'ihmCheckpointId': ihmCheckpointId,
    'imagePath': imagePath,
    'xPercent': xPercent,
    'yPercent': yPercent,
    'markerLabel': markerLabel,
    'deleted': 0,
    'synced': synced,
    'updatedAt': DateTime.now().toIso8601String(),
  };
}

class IhmLayoutImage {
  final int id;
  final int? ihmAreaId;
  final String filePath;
  final String? localFilePath;
  final String originalFileName;
  final String? contentType;
  final bool isCommon;

  IhmLayoutImage({
    required this.id,
    this.ihmAreaId,
    required this.filePath,
    this.localFilePath,
    required this.originalFileName,
    this.contentType,
    required this.isCommon,
  });

  factory IhmLayoutImage.fromJson(Map<String, dynamic> json) => IhmLayoutImage(
    id: int.tryParse(json['id'].toString()) ?? 0,
    ihmAreaId: json['ihmAreaId'] == null
        ? null
        : int.tryParse(json['ihmAreaId'].toString()),
    filePath: json['filePath']?.toString() ?? '',
    localFilePath: json['localFilePath']?.toString(),
    originalFileName: json['originalFileName']?.toString() ?? 'Layout',
    contentType: json['contentType']?.toString(),
    isCommon: json['isCommon'] == true,
  );
}

class IhmSamplingPhoto {
  final int id;
  final String filePath;
  final String? localFilePath;
  final String? caption;
  final bool showInAppendixThree;
  final int appendixThreeSortOrder;
  final String? appendixThreeEditedFilePath;
  final String? appendixThreeEditedLocalFilePath;
  final int? appendixThreeWidth;
  final int? appendixThreeHeight;

  IhmSamplingPhoto({
    required this.id,
    required this.filePath,
    this.localFilePath,
    this.caption,
    this.showInAppendixThree = false,
    this.appendixThreeSortOrder = 0,
    this.appendixThreeEditedFilePath,
    this.appendixThreeEditedLocalFilePath,
    this.appendixThreeWidth,
    this.appendixThreeHeight,
  });

  factory IhmSamplingPhoto.fromJson(Map<String, dynamic> json) {
    return IhmSamplingPhoto(
      id: int.tryParse(json['id'].toString()) ?? 0,
      filePath: json['filePath']?.toString() ?? '',
      localFilePath: json['localFilePath']?.toString(),
      caption: json['caption']?.toString(),
      showInAppendixThree:
          json['showInAppendixThree'] == true ||
          json['ShowInAppendixThree'] == true,
      appendixThreeSortOrder:
          int.tryParse(
            (json['appendixThreeSortOrder'] ??
                    json['AppendixThreeSortOrder'] ??
                    0)
                .toString(),
          ) ??
          0,
      appendixThreeEditedFilePath:
          (json['appendixThreeEditedFilePath'] ??
                  json['AppendixThreeEditedFilePath'])
              ?.toString(),
      appendixThreeEditedLocalFilePath:
          (json['appendixThreeEditedLocalFilePath'] ??
                  json['AppendixThreeEditedLocalFilePath'])
              ?.toString(),
      appendixThreeWidth: int.tryParse(
        (json['appendixThreeWidth'] ?? json['AppendixThreeWidth'] ?? '')
            .toString(),
      ),
      appendixThreeHeight: int.tryParse(
        (json['appendixThreeHeight'] ?? json['AppendixThreeHeight'] ?? '')
            .toString(),
      ),
    );
  }
  Map<String, dynamic> toLocalMap({
    required int surveyJobId,
    required int checkpointId,
    int? areaId,
    int? localId,
    String? localFilePath,
    String? appendixThreeEditedLocalFilePath,
    int synced = 1,
  }) => {
    'id': localId ?? id,
    'serverId': id > 0 ? id : null,
    'surveyJobId': surveyJobId,
    'ihmAreaId': areaId,
    'ihmCheckpointId': checkpointId,
    'filePath': filePath,
    'localFilePath': localFilePath,
    'caption': caption,
    'showInAppendixThree': showInAppendixThree ? 1 : 0,
    'appendixThreeSortOrder': appendixThreeSortOrder,
    'appendixThreeEditedFilePath': appendixThreeEditedFilePath,
    'appendixThreeEditedLocalFilePath': appendixThreeEditedLocalFilePath,
    'appendixThreeWidth': appendixThreeWidth,
    'appendixThreeHeight': appendixThreeHeight,
    'deleted': 0,
    'synced': synced,
    'updatedAt': DateTime.now().toIso8601String(),
  };
}
