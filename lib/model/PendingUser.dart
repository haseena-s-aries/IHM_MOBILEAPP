class PendingUser {
  final int id;
  final String fullName;
  final String email;
  final String requestedRole;
  final int? projectId;
  final String? projectName;
  final int? roleId;
  final String? roleName;

  PendingUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.requestedRole,
    this.projectId,
    this.projectName,
    this.roleId,
    this.roleName,
  });

  factory PendingUser.fromJson(Map<String, dynamic> json) {
    return PendingUser(
      id: json['id'],
      fullName: json['fullName'],
      email: json['email'],
      requestedRole: json['requestedRole'],
      projectId: int.tryParse(json['projectId']?.toString() ?? ''),
      projectName: json['projectName']?.toString(),
      roleId: int.tryParse(json['roleId']?.toString() ?? ''),
      roleName: json['roleName']?.toString(),
    );
  }
}

class ProjectOption {
  final int id;
  final String name;
  final String? code;

  const ProjectOption({required this.id, required this.name, this.code});

  factory ProjectOption.fromJson(Map<String, dynamic> json) {
    return ProjectOption(
      id: int.tryParse((json['id'] ?? json['Id'])?.toString() ?? '') ?? 0,
      name:
          (json['name'] ??
                  json['Name'] ??
                  json['projectName'] ??
                  json['ProjectName'])
              ?.toString() ??
          '',
      code: (json['code'] ?? json['Code'])?.toString(),
    );
  }
}

class RoleOption {
  final int id;
  final String roleName;

  const RoleOption({required this.id, required this.roleName});

  factory RoleOption.fromJson(Map<String, dynamic> json) {
    return RoleOption(
      id: int.tryParse((json['id'] ?? json['Id'])?.toString() ?? '') ?? 0,
      roleName:
          (json['roleName'] ?? json['RoleName'] ?? json['name'] ?? json['Name'])
              ?.toString() ??
          '',
    );
  }
}
