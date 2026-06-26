class CargoDetail {
  int? id;
  int? certificateId;
  int? serialNo;
  String? location;
  String? cargos;
  String? idMarkings;
  String? weight;
  String? dimensions;
  String? remarks;

  CargoDetail({
    this.id,
    this.certificateId,
    this.serialNo,
    this.location,
    this.cargos,
    this.idMarkings,
    this.weight,
    this.dimensions,
    this.remarks,
  });

  factory CargoDetail.fromJson(Map<String, dynamic> json) {
    return CargoDetail(
      id: json['id'],
      certificateId: json['certificateId'],
      serialNo: json['serialNo'],
      location: json['location'],
      cargos: json['cargos'],
      idMarkings: json['idMarkings'],
      weight: json['weight'],
      dimensions: json['dimensions'],
      remarks: json['remarks'],
    );
  }

  Map<String, dynamic> toJson({bool forInsert = false, bool forSync = false}) {
    final map = {
      'certificateId': certificateId,
      'serialNo': serialNo,
      'location': location,
      'cargos': cargos,
      'idMarkings': idMarkings,
      'weight': weight,
      'dimensions': dimensions,
      'remarks': remarks,
    };

    // Include `id` only when not syncing or inserting
    if (!forInsert && !forSync && id != null) {
      map['id'] = id;
    }

    return map;
  }
}
