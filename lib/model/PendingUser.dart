class PendingUser {
  final int id;
  final String fullName;
  final String email;
  final String requestedRole;

  PendingUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.requestedRole,
  });

  factory PendingUser.fromJson(Map<String, dynamic> json) {
    return PendingUser(
      id: json['id'],
      fullName: json['fullName'],
      email: json['email'],
      requestedRole: json['requestedRole'],
    );
  }
}
