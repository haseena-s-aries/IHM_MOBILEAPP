class ExSurveySummary {
  final String status;
  final int areaCount;
  final int equipmentCount;
  final int answeredEquipmentCount;
  final int answerCount;
  final int failedAnswerCount;
  final int openDefectCount;
  final int photoCount;

  const ExSurveySummary({
    required this.status,
    required this.areaCount,
    required this.equipmentCount,
    required this.answeredEquipmentCount,
    required this.answerCount,
    required this.failedAnswerCount,
    required this.openDefectCount,
    required this.photoCount,
  });

  factory ExSurveySummary.fromJson(Map<String, dynamic> json) {
    return ExSurveySummary(
      status: json['status']?.toString() ?? 'Draft',
      areaCount: _int(json['areaCount']),
      equipmentCount: _int(json['equipmentCount']),
      answeredEquipmentCount: _int(json['answeredEquipmentCount']),
      answerCount: _int(json['answerCount']),
      failedAnswerCount: _int(json['failedAnswerCount']),
      openDefectCount: _int(json['openDefectCount']),
      photoCount: _int(json['photoCount']),
    );
  }
}

class ExEquipment {
  final int id;
  final int surveyJobId;
  final String equipmentId;
  final String? rfidTag;
  final String area;
  final String? location;
  final String? equipmentType;
  final String? description;
  final String? manufacturer;
  final String? model;
  final String? serialNumber;
  final bool isActive;

  const ExEquipment({
    required this.id,
    required this.surveyJobId,
    required this.equipmentId,
    required this.area,
    required this.isActive,
    this.rfidTag,
    this.location,
    this.equipmentType,
    this.description,
    this.manufacturer,
    this.model,
    this.serialNumber,
  });

  factory ExEquipment.fromJson(Map<String, dynamic> json) {
    return ExEquipment(
      id: _int(json['id']),
      surveyJobId: _int(json['surveyJobId']),
      equipmentId: json['equipmentId']?.toString() ?? '',
      rfidTag: _text(json['rfidTag']),
      area: _text(json['area']) ?? 'Unassigned',
      location: _text(json['location']),
      equipmentType: _text(json['equipmentType']),
      description: _text(json['description']),
      manufacturer: _text(json['manufacturer']),
      model: _text(json['model']),
      serialNumber: _text(json['serialNumber']),
      isActive: json['isActive'] != false,
    );
  }
}

class ExChecklistQuestion {
  final int id;
  final String questionCode;
  final String inspectionType;
  final String questionText;
  final int sortOrder;

  const ExChecklistQuestion({
    required this.id,
    required this.questionCode,
    required this.inspectionType,
    required this.questionText,
    required this.sortOrder,
  });

  factory ExChecklistQuestion.fromJson(Map<String, dynamic> json) {
    return ExChecklistQuestion(
      id: _int(json['id']),
      questionCode: json['questionCode']?.toString() ?? '',
      inspectionType: json['inspectionType']?.toString() ?? 'Visual',
      questionText: json['questionText']?.toString() ?? '',
      sortOrder: _int(json['sortOrder']),
    );
  }
}

class ExChecklistAnswer {
  final int id;
  final int questionId;
  final String result;
  final String? comment;

  const ExChecklistAnswer({
    required this.id,
    required this.questionId,
    required this.result,
    this.comment,
  });

  factory ExChecklistAnswer.fromJson(Map<String, dynamic> json) {
    return ExChecklistAnswer(
      id: _int(json['id']),
      questionId: _int(json['exChecklistQuestionId']),
      result: json['result']?.toString() ?? '',
      comment: _text(json['comment']),
    );
  }
}

class ExDefect {
  final int id;
  final int equipmentId;
  final String? equipmentCode;
  final String? defectNumber;
  final String description;
  final String? severity;
  final String? recommendation;
  final String status;

  const ExDefect({
    required this.id,
    required this.equipmentId,
    required this.description,
    required this.status,
    this.equipmentCode,
    this.defectNumber,
    this.severity,
    this.recommendation,
  });

  factory ExDefect.fromJson(Map<String, dynamic> json) {
    return ExDefect(
      id: _int(json['id']),
      equipmentId: _int(json['exEquipmentId']),
      equipmentCode: _text(json['equipmentId']),
      defectNumber: _text(json['defectNumber']),
      description: json['description']?.toString() ?? '',
      severity: _text(json['severity']),
      recommendation: _text(json['recommendation']),
      status: json['status']?.toString() ?? 'Open',
    );
  }
}

class ExSurveyPhoto {
  final int id;
  final int? equipmentId;
  final String originalFileName;
  final String filePath;
  final String? localFilePath;
  final DateTime? uploadedAt;

  const ExSurveyPhoto({
    required this.id,
    required this.originalFileName,
    required this.filePath,
    this.localFilePath,
    this.equipmentId,
    this.uploadedAt,
  });

  factory ExSurveyPhoto.fromJson(Map<String, dynamic> json) {
    return ExSurveyPhoto(
      id: _int(json['id']),
      equipmentId: json['equipmentId'] == null
          ? null
          : _int(json['equipmentId']),
      originalFileName: json['originalFileName']?.toString() ?? 'Photo',
      filePath: json['filePath']?.toString() ?? '',
      localFilePath: _text(json['localFilePath']),
      uploadedAt: DateTime.tryParse(json['uploadedAt']?.toString() ?? ''),
    );
  }
}

class ExSurveyDocument {
  final int id;
  final String documentType;
  final String originalFileName;
  final String filePath;
  final String? localFilePath;
  final int sizeBytes;

  const ExSurveyDocument({
    required this.id,
    required this.documentType,
    required this.originalFileName,
    required this.filePath,
    this.localFilePath,
    required this.sizeBytes,
  });

  factory ExSurveyDocument.fromJson(Map<String, dynamic> json) {
    return ExSurveyDocument(
      id: _int(json['id']),
      documentType: json['documentType']?.toString() ?? 'Document',
      originalFileName: json['originalFileName']?.toString() ?? 'Document',
      filePath: json['filePath']?.toString() ?? '',
      localFilePath: _text(json['localFilePath']),
      sizeBytes: _int(json['sizeBytes']),
    );
  }
}

int _int(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

String? _text(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
