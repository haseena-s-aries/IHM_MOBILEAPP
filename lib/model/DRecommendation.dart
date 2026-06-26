class DefaultRecommendation {
  int? id;
  String? recommendationText;

  DefaultRecommendation({this.id, this.recommendationText});

  factory DefaultRecommendation.fromJson(Map<String, dynamic> json) {
    return DefaultRecommendation(
      id: json['id'],
      recommendationText: json['recommendationText'],
    );
  }

  // ✅ Updated method
  Map<String, dynamic> toJson({bool forSync = false}) {
    final map = {'recommendationText': recommendationText};

    // Only include `id` if not syncing to API
    if (!forSync && id != null) {
      map['id'] = id.toString(); // <-- fix if required to be string
    }
    return map;
  }

  factory DefaultRecommendation.fromMap(Map<String, dynamic> map) {
    return DefaultRecommendation(
      id: map['id'],
      recommendationText: map['recommendationText'],
    );
  }
}
