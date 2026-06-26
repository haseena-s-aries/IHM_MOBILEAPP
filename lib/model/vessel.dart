class Vessel {
  final int id;
  final String vesselName;
  final String? imoNumber;
  final String? officialNumber;
  final String? vesselType;
  final String? flag;
  final String? portOfRegistry;
  final String? classSociety;
  final String? callSign;
  final String? builder;
  final String? dateOfBuild;

  final double? grossTonnage;
  final double? netTonnage;
  final double? deadweight;
  final double? lengthOverall;
  final double? lengthBetweenPerpendiculars;
  final double? breadth;
  final double? depth;
  final double? draughtMoulded;

  final int? yearBuilt;
  final String? ownerName;
  final String? managerName;
  final String? clientName;
  final String status;

  Vessel({
    required this.id,
    required this.vesselName,
    this.imoNumber,
    this.officialNumber,
    this.vesselType,
    this.flag,
    this.portOfRegistry,
    this.classSociety,
    this.callSign,
    this.builder,
    this.dateOfBuild,
    this.grossTonnage,
    this.netTonnage,
    this.deadweight,
    this.lengthOverall,
    this.lengthBetweenPerpendiculars,
    this.breadth,
    this.depth,
    this.draughtMoulded,
    this.yearBuilt,
    this.ownerName,
    this.managerName,
    this.clientName,
    required this.status,
  });

  factory Vessel.fromJson(Map<String, dynamic> json) {
    return Vessel(
      id: _toInt(json['id']) ?? 0,
      vesselName: json['vesselName']?.toString() ?? '',
      imoNumber: json['imoNumber']?.toString(),
      officialNumber: json['officialNumber']?.toString(),
      vesselType: json['vesselType']?.toString(),
      flag: json['flag']?.toString(),
      portOfRegistry: json['portOfRegistry']?.toString(),
      classSociety: json['classSociety']?.toString(),
      callSign: json['callSign']?.toString(),
      builder: json['builder']?.toString(),
      dateOfBuild: json['dateOfBuild']?.toString(),
      grossTonnage: _toDouble(json['grossTonnage']),
      netTonnage: _toDouble(json['netTonnage']),
      deadweight: _toDouble(json['deadweight']),
      lengthOverall: _toDouble(json['lengthOverall']),
      lengthBetweenPerpendiculars: _toDouble(
        json['lengthBetweenPerpendiculars'],
      ),
      breadth: _toDouble(json['breadth']),
      depth: _toDouble(json['depth']),
      draughtMoulded: _toDouble(json['draughtMoulded']),
      yearBuilt: _toInt(json['yearBuilt']),
      ownerName: json['ownerName']?.toString(),
      managerName: json['managerName']?.toString(),
      clientName: json['clientName']?.toString(),
      status: json['status']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'vesselName': vesselName,
      'imoNumber': imoNumber,
      'officialNumber': officialNumber,
      'vesselType': vesselType,
      'flag': flag,
      'portOfRegistry': portOfRegistry,
      'classSociety': classSociety,
      'callSign': callSign,
      'builder': builder,
      'dateOfBuild': dateOfBuild,
      'grossTonnage': grossTonnage,
      'netTonnage': netTonnage,
      'deadweight': deadweight,
      'lengthOverall': lengthOverall,
      'lengthBetweenPerpendiculars': lengthBetweenPerpendiculars,
      'breadth': breadth,
      'depth': depth,
      'draughtMoulded': draughtMoulded,
      'yearBuilt': yearBuilt,
      'ownerName': ownerName,
      'managerName': managerName,
      'clientName': clientName,
    };
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    return double.tryParse(value.toString());
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    return int.tryParse(value.toString());
  }
}
