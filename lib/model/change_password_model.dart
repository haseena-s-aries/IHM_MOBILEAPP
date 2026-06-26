class ChangePasswordModel {
  final int UserId;
  final String currentPassword;
  final String newPassword;
  final String confirmaPassword;

  ChangePasswordModel({
    required this.UserId,
    required this.currentPassword,
    required this.newPassword,
    required this.confirmaPassword,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': UserId,
      'currentPassword': currentPassword,
      'newPassword': newPassword,
      'confirmPassword': confirmaPassword,
    };
  }
}
