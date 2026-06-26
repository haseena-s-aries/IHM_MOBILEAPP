class Recommendation {
  int? id;
  String? recommendationText;

  Recommendation({this.id, this.recommendationText});

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      id: json['id'],
      recommendationText: json['recommendationText'],
    );
  }

  Map<String, dynamic> toJson({bool forSync = false}) {
    final map = <String, dynamic>{'recommendationText': recommendationText};
    if (!forSync && id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory Recommendation.fromMap(Map<String, dynamic> map) {
    return Recommendation(
      id: map['id'],
      recommendationText: map['recommendationText'],
    );
  }
}
