class ProfileDto {
  final int userId;
  final String fullName;
  final String email;
  final String role;

  ProfileDto({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.role,
  });

  factory ProfileDto.fromJson(Map<String, dynamic> json) {
    return ProfileDto(
      userId: json['userId'],
      fullName: json['fullName'],
      email: json['email'],
      role: json['role'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'fullName': fullName,
      'email': email,
      'role': role,
    };
  }
}
