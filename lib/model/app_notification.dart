class AppNotification {
  final int id;
  final int userId;
  final String type;
  final String title;
  final String message;
  final int? surveyJobId;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    required this.surveyJobId,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: int.tryParse(json['id'].toString()) ?? 0,
      userId: int.tryParse(json['userId'].toString()) ?? 0,
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Notification',
      message: json['message']?.toString() ?? '',
      surveyJobId: json['surveyJobId'] == null
          ? null
          : int.tryParse(json['surveyJobId'].toString()),
      isRead: json['isRead'] == true || json['isRead'] == 1,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  AppNotification copyWith({
    int? id,
    int? userId,
    String? type,
    String? title,
    String? message,
    int? surveyJobId,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      surveyJobId: surveyJobId ?? this.surveyJobId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
