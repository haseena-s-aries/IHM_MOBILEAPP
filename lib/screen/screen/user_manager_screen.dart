import 'package:Auras/model/PendingUser.dart';
import 'package:Auras/service/api_service.dart';
import 'package:Auras/utils/app_dialog.dart';
import 'package:flutter/material.dart';

class UserManagerScreen extends StatefulWidget {
  final Map<String, dynamic>? currentUser;
  final bool embedded;

  const UserManagerScreen({super.key, this.currentUser, this.embedded = false});

  @override
  State<UserManagerScreen> createState() => _UserManagerScreenState();
}

class _UserManagerScreenState extends State<UserManagerScreen> {
  static const _pageSize = 20;

  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  List<Map<String, dynamic>> _users = [];
  List<ProjectOption> _projects = [];
  bool _isLoading = true;
  String? _error;
  String _query = '';
  String _roleFilter = 'All';
  String _statusFilter = 'All';
  String _projectFilter = 'All';
  int _visibleCount = _pageSize;

  bool get _isAdmin =>
      (widget.currentUser?['role'] ?? widget.currentUser?['Role'] ?? '')
          .toString()
          .toLowerCase() ==
      'admin';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreIfNeeded);
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        ApiService.getAllUsers(),
        ApiService.fetchPendingUsers(),
        ApiService.fetchManageableProjects(),
      ]);

      final allUsers = (results[0] as List<dynamic>)
          .whereType<Map>()
          .map((x) => Map<String, dynamic>.from(x))
          .toList();
      final pendingUsers = results[1] as List<PendingUser>;
      final projects = results[2] as List<ProjectOption>;

      final byId = <int, Map<String, dynamic>>{};
      for (final user in allUsers) {
        final id = _readInt(user, ['id', 'Id']);
        if (id > 0) byId[id] = user;
      }

      for (final pending in pendingUsers) {
        byId[pending.id] = {
          ...?byId[pending.id],
          'id': pending.id,
          'fullName': pending.fullName,
          'email': pending.email,
          'role': pending.requestedRole,
          'requestedRole': pending.requestedRole,
          'projectId': pending.projectId,
          'projectName': pending.projectName,
          'roleId': pending.roleId,
          'roleName': pending.roleName,
          'isApproved': false,
          'isRejected': false,
        };
      }

      final mergedUsers = byId.values.toList()
        ..sort((a, b) => _displayName(a).compareTo(_displayName(b)));

      if (!mounted) return;
      setState(() {
        _users = mergedUsers;
        _projects = projects;
        _visibleCount = _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _loadMoreIfNeeded() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 240) return;
    final total = _filteredUsers.length;
    if (_visibleCount >= total) return;
    setState(() {
      _visibleCount = (_visibleCount + _pageSize).clamp(0, total);
    });
  }

  List<Map<String, dynamic>> get _filteredUsers {
    final search = _query.trim().toLowerCase();
    return _users.where((user) {
      final status = _status(user);
      final role = _role(user);
      final project = _projectName(user);
      final haystack = [
        _displayName(user),
        _employeeCode(user),
        _email(user),
        role,
        project,
        status,
      ].join(' ').toLowerCase();

      if (search.isNotEmpty && !haystack.contains(search)) return false;
      if (_roleFilter != 'All' &&
          role.toLowerCase() != _roleFilter.toLowerCase()) {
        return false;
      }
      if (_statusFilter != 'All' &&
          status.toLowerCase() != _statusFilter.toLowerCase()) {
        return false;
      }
      if (_projectFilter != 'All' &&
          !project.toLowerCase().contains(_projectFilter.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
  }

  List<String> get _roles {
    final values = <String>{'All'};
    for (final user in _users) {
      final role = _role(user);
      if (role.isNotEmpty) values.add(role);
    }
    return values.toList();
  }

  List<String> get _projectsForFilter {
    final values = <String>{'All'};
    for (final project in _availableProjects) {
      if (project.name.trim().isNotEmpty) values.add(project.name.trim());
    }
    for (final user in _users) {
      final project = _projectName(user);
      if (project.isNotEmpty && project != '-') values.add(project);
    }
    return values.toList();
  }

  List<ProjectOption> get _availableProjects {
    return _projects;
  }

  Future<void> _approveUser(Map<String, dynamic> user) async {
    final id = _id(user);
    final selectedProjectId = _readInt(user, ['projectId', 'ProjectId']);
    final projectId = await _selectProjectForApproval(
      initialProjectId: selectedProjectId > 0 ? selectedProjectId : null,
      title: 'Approve ${_displayName(user)}',
    );
    if (projectId == null || projectId <= 0) return;

    final approved = await AppDialog.execute<bool>(
      context,
      loadingMessage: 'Approving user...',
      action: () async {
        await ApiService.approveUser(id, projectId: projectId);
        return true;
      },
      successTitle: 'User approved',
      successMessage: '${_displayName(user)} can now access the app.',
      errorTitle: 'Unable to approve user',
    );
    if (approved == true && mounted) await _loadData();
  }

  Future<void> _rejectUser(Map<String, dynamic> user) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Reject user?',
      message: 'Reject ${_displayName(user)} registration request?',
      confirmLabel: 'Reject',
      destructive: true,
    );
    if (!confirmed) return;

    final rejected = await AppDialog.execute<bool>(
      context,
      loadingMessage: 'Rejecting user...',
      action: () async {
        await ApiService.rejectUser(_id(user));
        return true;
      },
      successTitle: 'User rejected',
      successMessage: '${_displayName(user)} was rejected.',
      errorTitle: 'Unable to reject user',
    );
    if (rejected == true && mounted) await _loadData();
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Deactivate user?',
      message:
          'This uses the same web delete action and removes ${_displayName(user)} access. Continue?',
      confirmLabel: 'Deactivate',
      destructive: true,
    );
    if (!confirmed) return;

    final deleted = await AppDialog.execute<bool>(
      context,
      loadingMessage: 'Updating user access...',
      action: () async {
        await ApiService.deleteUser(_id(user));
        return true;
      },
      successTitle: 'User access removed',
      successMessage: '${_displayName(user)} was removed successfully.',
      errorTitle: 'Unable to update user access',
    );
    if (deleted == true && mounted) await _loadData();
  }

  Future<int?> _selectProjectForApproval({
    required int? initialProjectId,
    required String title,
  }) {
    int? selectedProjectId = initialProjectId;
    if (selectedProjectId == null && _projects.length == 1) {
      selectedProjectId = _projects.first.id;
    }

    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                18,
                18,
                MediaQuery.of(context).viewInsets.bottom + 18,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    value: selectedProjectId,
                    decoration: const InputDecoration(
                      labelText: 'Approve Project',
                      border: OutlineInputBorder(),
                    ),
                    items: _availableProjects
                        .map(
                          (project) => DropdownMenuItem<int>(
                            value: project.id,
                            child: Text(project.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setSheetState(() => selectedProjectId = value),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: selectedProjectId == null
                          ? null
                          : () => Navigator.pop(context, selectedProjectId),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Continue'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openEditSheet(Map<String, dynamic>? user) async {
    final isNew = user == null;
    final nameController = TextEditingController(
      text: user == null ? '' : _displayName(user),
    );
    final emailController = TextEditingController(
      text: user == null ? '' : _email(user),
    );
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final availableProjects = _availableProjects;
    final projectAccessDraft = isNew
        ? <Map<String, dynamic>>[]
        : _editableProjectAccesses(user!, availableProjects);
    int? selectedProjectId = isNew
        ? null
        : (projectAccessDraft.isNotEmpty
              ? _readInt(projectAccessDraft.first, ['projectId', 'ProjectId'])
                    .takeIfPositive()
              : _readInt(user!, ['projectId', 'ProjectId']).takeIfPositive());
    if (selectedProjectId != null &&
        !availableProjects.any((project) => project.id == selectedProjectId)) {
      selectedProjectId = null;
    }
    String selectedRole = isNew ? 'User' : _role(user!);
    int? selectedRoleId =
        isNew ? null : _readInt(user!, ['roleId', 'RoleId']).takeIfPositive();
    List<RoleOption> roles = [];
    bool loadingRoles = false;
    bool obscurePassword = true;

    void addOrUpdateProjectAccess(StateSetter setSheetState) {
      if ((selectedRole).toLowerCase() == 'admin') return;
      final projectId = selectedProjectId;
      if (projectId == null || projectId <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a project.')),
        );
        return;
      }
      if (selectedRole.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a role.')),
        );
        return;
      }

      ProjectOption? project;
      for (final item in availableProjects) {
        if (item.id == projectId) {
          project = item;
          break;
        }
      }
      final existingIndex = projectAccessDraft.indexWhere(
        (x) => _readInt(x, ['projectId', 'ProjectId']) == projectId,
      );
      final existing = existingIndex >= 0 ? projectAccessDraft[existingIndex] : null;
      final next = <String, dynamic>{
        'id': existing == null ? 0 : _readInt(existing, ['id', 'Id']),
        'userId': isNew ? 0 : _id(user!),
        'projectId': projectId,
        'projectName': project?.name ?? '',
        'projectCode': project?.code,
        'roleId': selectedRoleId,
        'roleName': selectedRole,
        'isActive': true,
        'isApproved': true,
        'isRejected': false,
      };

      setSheetState(() {
        if (existingIndex >= 0) {
          projectAccessDraft[existingIndex] = next;
        } else {
          projectAccessDraft.add(next);
        }
      });
    }

    void removeProjectAccess(StateSetter setSheetState, int projectId) {
      setSheetState(() {
        projectAccessDraft.removeWhere(
          (x) => _readInt(x, ['projectId', 'ProjectId']) == projectId,
        );
      });
    }

    Future<void> loadRoles(StateSetter setSheetState) async {
      if (selectedRole.toLowerCase() == 'admin') {
        setSheetState(() => roles = const []);
        return;
      }
      final projectId = selectedProjectId;
      if (projectId == null || projectId <= 0) {
        setSheetState(() => roles = const []);
        return;
      }
      setSheetState(() => loadingRoles = true);
      try {
        final loaded = await ApiService.fetchManagedProjectRoles(projectId);
        setSheetState(() {
          roles = loaded;
          loadingRoles = false;
          if (roles.isNotEmpty &&
              !roles.any((role) => role.roleName == selectedRole)) {
            selectedRole = roles.first.roleName;
            selectedRoleId = roles.first.id;
          }
        });
      } catch (_) {
        setSheetState(() => loadingRoles = false);
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            if (roles.isEmpty && !loadingRoles && selectedProjectId != null) {
              Future.microtask(() => loadRoles(setSheetState));
            }
            final roleItems = <String>{
              if (_isAdmin) 'Admin',
              ...roles.map((role) => role.roleName),
              'Manager',
              'Surveyor',
              'User',
              'Client',
            }.where((role) => _isAdmin || role.toLowerCase() != 'admin').toList();

            if (!roleItems.contains(selectedRole)) {
              selectedRole = roleItems.isEmpty ? 'User' : roleItems.first;
            }

            final isAdminRole = selectedRole.toLowerCase() == 'admin';

            return Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                18,
                18,
                MediaQuery.of(context).viewInsets.bottom + 18,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isNew ? 'Add User' : 'Edit User',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Full name is required'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final email = (value ?? '').trim();
                          if (email.isEmpty) return 'Email is required';
                          final valid = RegExp(
                            r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
                          ).hasMatch(email);
                          return valid ? null : 'Enter a valid email address';
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedRole,
                        decoration: const InputDecoration(
                          labelText: 'Role',
                          border: OutlineInputBorder(),
                        ),
                        items: roleItems
                            .map(
                              (role) => DropdownMenuItem<String>(
                                value: role,
                                child: Text(role),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setSheetState(() {
                            selectedRole = value;
                            final matched = roles
                                .where((role) => role.roleName == value)
                                .toList();
                            selectedRoleId =
                                matched.isEmpty ? null : matched.first.id;
                            if (value.toLowerCase() == 'admin') {
                              selectedProjectId = null;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: isAdminRole ? null : selectedProjectId,
                        decoration: const InputDecoration(
                          labelText: 'Project',
                          border: OutlineInputBorder(),
                        ),
                        items: availableProjects
                            .map(
                              (project) => DropdownMenuItem<int>(
                                value: project.id,
                                child: Text(project.name),
                              ),
                            )
                            .toList(),
                        onChanged: isAdminRole
                            ? null
                            : (value) {
                                setSheetState(() {
                                  selectedProjectId = value;
                                  selectedRoleId = null;
                                  roles = const [];
                                });
                                loadRoles(setSheetState);
                              },
                        validator: (_) {
                          if (isAdminRole) return null;
                          return selectedProjectId == null
                              ? 'Project is required'
                              : null;
                        },
                      ),
                      if (loadingRoles)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: LinearProgressIndicator(),
                        ),
                      if (!isAdminRole) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Project access',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'Add, change, or remove each project role.',
                                          style: TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        addOrUpdateProjectAccess(setSheetState),
                                    icon: const Icon(Icons.add_circle_outline),
                                    label: const Text('Add'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (projectAccessDraft.isEmpty)
                                const Text(
                                  'No project access added yet.',
                                  style: TextStyle(color: Color(0xFF64748B)),
                                )
                              else
                                ...projectAccessDraft.map((access) {
                                  final projectId = _readInt(
                                    access,
                                    ['projectId', 'ProjectId'],
                                  );
                                  final projectName = _readString(
                                    access,
                                    ['projectName', 'ProjectName'],
                                  );
                                  final roleName = _readString(
                                    access,
                                    ['roleName', 'RoleName'],
                                  );
                                  return Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                projectName.isEmpty
                                                    ? 'Project'
                                                    : projectName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                              Text(
                                                roleName.isEmpty
                                                    ? 'Role not selected'
                                                    : roleName,
                                                style: const TextStyle(
                                                  color: Color(0xFF64748B),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Remove project access',
                                          onPressed: () => removeProjectAccess(
                                            setSheetState,
                                            projectId,
                                          ),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Color(0xFFDC2626),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                            ],
                          ),
                        ),
                      ],
                      if (isNew) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: passwordController,
                          obscureText: obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () => setSheetState(
                                () => obscurePassword = !obscurePassword,
                              ),
                            ),
                          ),
                          validator: (value) =>
                              (value ?? '').length < 6
                                  ? 'Password must be at least 6 characters'
                                  : null,
                        ),
                      ],
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            if (!isAdminRole && projectAccessDraft.isEmpty) {
                              addOrUpdateProjectAccess(setSheetState);
                            }
                            if (!isAdminRole && projectAccessDraft.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Please add at least one project access.'),
                                ),
                              );
                              return;
                            }
                            final firstAccess = projectAccessDraft.isEmpty
                                ? null
                                : projectAccessDraft.first;
                            final primaryAccess =
                                firstAccess ?? <String, dynamic>{};
                            final saved = await AppDialog.execute<bool>(
                              context,
                              loadingMessage:
                                  isNew ? 'Creating user...' : 'Saving user...',
                              action: () async {
                                await ApiService.saveUser({
                                  'id': isNew ? 0 : _id(user!),
                                  'fullName': nameController.text.trim(),
                                  'email': emailController.text.trim(),
                                  'role': isAdminRole
                                      ? selectedRole
                                      : _readString(
                                          primaryAccess,
                                          ['roleName', 'RoleName'],
                                        ),
                                  'roleName': isAdminRole
                                      ? selectedRole
                                      : _readString(
                                          primaryAccess,
                                          ['roleName', 'RoleName'],
                                        ),
                                  'roleId': isAdminRole
                                      ? selectedRoleId
                                      : _readInt(
                                          primaryAccess,
                                          ['roleId', 'RoleId'],
                                        )
                                          .takeIfPositive(),
                                  'projectId': isAdminRole
                                      ? null
                                      : _readInt(
                                          primaryAccess,
                                          ['projectId', 'ProjectId'],
                                        ),
                                  'projectName': isAdminRole
                                      ? 'All Projects'
                                      : _readString(
                                          primaryAccess,
                                          ['projectName', 'ProjectName'],
                                        ),
                                  'replaceProjectAccesses': true,
                                  'projectAccesses':
                                      isAdminRole ? [] : projectAccessDraft,
                                  if (isNew)
                                    'password': passwordController.text.trim(),
                                });
                                return true;
                              },
                              successTitle:
                                  isNew ? 'User created' : 'User updated',
                              successMessage:
                                  '${nameController.text.trim()} saved successfully.',
                              errorTitle: 'Unable to save user',
                            );
                            if (saved == true && mounted) {
                              Navigator.pop(context);
                              await _loadData();
                            }
                          },
                          icon: const Icon(Icons.save_outlined),
                          label: Text(isNew ? 'Create User' : 'Save Changes'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
  }

  void _showUserDetails(Map<String, dynamic> user) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _avatar(user, radius: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _displayName(user),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(_email(user)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _detailRow('Employee Code', _employeeCode(user)),
              _detailRow('Role', _role(user)),
              _detailRow('Requested Role', _requestedRole(user)),
              _detailRow('Project', _projectName(user)),
              _detailRow('Status', _status(user)),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent();
    if (widget.embedded) return content;

    return Scaffold(
      appBar: AppBar(title: const Text('User Management')),
      body: content,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditSheet(null),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add User'),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _stateView(
        icon: Icons.error_outline,
        title: 'Unable to load users',
        message: _error!,
        actionLabel: 'Retry',
        onAction: _loadData,
      );
    }

    final filtered = _filteredUsers;
    final visible = filtered.take(_visibleCount).toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            sliver: SliverToBoxAdapter(child: _header(filtered.length)),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(child: _filters()),
          ),
          if (visible.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _stateView(
                icon: Icons.people_outline,
                title: 'No users found',
                message: 'Try changing search or filters.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              sliver: SliverList.separated(
                itemCount: visible.length + (_visibleCount < filtered.length ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index >= visible.length) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  return _userCard(visible[index]);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _header(int count) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF2563EB)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.manage_accounts, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'User Management',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '$count users visible',
                  style: const TextStyle(
                    color: Color(0xFFE0F2FE),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: () => _openEditSheet(null),
            icon: const Icon(Icons.person_add_alt_1),
          ),
        ],
      ),
    );
  }

  Widget _filters() {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() {
              _query = value;
              _visibleCount = _pageSize;
            });
          },
          decoration: InputDecoration(
            hintText: 'Search name, employee code, email...',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterChip(
                label: 'Role',
                value: _roleFilter,
                values: _roles,
                onChanged: (value) => setState(() {
                  _roleFilter = value;
                  _visibleCount = _pageSize;
                }),
              ),
              const SizedBox(width: 8),
              _filterChip(
                label: 'Status',
                value: _statusFilter,
                values: const ['All', 'Approved', 'Pending', 'Rejected', 'Inactive'],
                onChanged: (value) => setState(() {
                  _statusFilter = value;
                  _visibleCount = _pageSize;
                }),
              ),
              const SizedBox(width: 8),
              _filterChip(
                label: 'Project',
                value: _projectFilter,
                values: _projectsForFilter,
                onChanged: (value) => setState(() {
                  _projectFilter = value;
                  _visibleCount = _pageSize;
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filterChip({
    required String label,
    required String value,
    required List<String> values,
    required ValueChanged<String> onChanged,
  }) {
    return PopupMenuButton<String>(
      onSelected: onChanged,
      itemBuilder: (context) => values
          .map((item) => PopupMenuItem<String>(value: item, child: Text(item)))
          .toList(),
      child: Chip(
        label: Text('$label: $value'),
        avatar: const Icon(Icons.tune, size: 18),
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
    );
  }

  Widget _userCard(Map<String, dynamic> user) {
    final status = _status(user);
    final statusColor = _statusColor(status);
    final isPending = status == 'Pending';

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _avatar(user),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _displayName(user),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _email(user),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (action) {
                    switch (action) {
                      case 'view':
                        _showUserDetails(user);
                        break;
                      case 'edit':
                        _openEditSheet(user);
                        break;
                      case 'approve':
                        _approveUser(user);
                        break;
                      case 'reject':
                        _rejectUser(user);
                        break;
                      case 'delete':
                        _deleteUser(user);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'view', child: Text('View details')),
                    const PopupMenuItem(value: 'edit', child: Text('Edit role/project')),
                    if (isPending)
                      const PopupMenuItem(value: 'approve', child: Text('Approve')),
                    if (isPending)
                      const PopupMenuItem(value: 'reject', child: Text('Reject')),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Deactivate / Remove'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _pill(Icons.badge_outlined, _employeeCode(user)),
                _pill(Icons.security_outlined, _role(user)),
                _pill(Icons.apps_outlined, _projectName(user)),
                _statusPill(status, statusColor),
              ],
            ),
            if (isPending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rejectUser(user),
                      icon: const Icon(Icons.close),
                      label: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _approveUser(user),
                      icon: const Icon(Icons.check),
                      label: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _avatar(Map<String, dynamic> user, {double radius = 21}) {
    final name = _displayName(user);
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFE0F2FE),
      child: Text(
        initial,
        style: const TextStyle(
          color: Color(0xFF2563EB),
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _pill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF64748B)),
          const SizedBox(width: 5),
          Text(
            text.isEmpty ? '-' : text,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _stateView({
    required IconData icon,
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: const Color(0xFF64748B)),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              FilledButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ],
        ),
      ),
    );
  }

  int _id(Map<String, dynamic> user) => _readInt(user, ['id', 'Id']);

  String _displayName(Map<String, dynamic> user) =>
      _readString(user, ['fullName', 'FullName', 'name', 'Name']);

  String _email(Map<String, dynamic> user) =>
      _readString(user, ['email', 'Email']);

  String _role(Map<String, dynamic> user) {
    final requested = _requestedRole(user);
    final role = _readString(user, ['roleName', 'RoleName', 'role', 'Role']);
    return requested.isNotEmpty && _status(user) == 'Pending' ? requested : role;
  }

  String _requestedRole(Map<String, dynamic> user) =>
      _readString(user, ['requestedRole', 'RequestedRole']);

  String _projectName(Map<String, dynamic> user) {
    final accessNames = _projectAccesses(user)
        .where((access) =>
            _readBool(access, ['isActive', 'IsActive']) &&
            !_readBool(access, ['isRejected', 'IsRejected']))
        .map((access) =>
            _readString(access, ['projectName', 'ProjectName', 'projectCode', 'ProjectCode']))
        .where((name) => name.trim().isNotEmpty)
        .toSet()
        .toList();
    if (accessNames.isNotEmpty) return accessNames.join(', ');

    final project = _readString(user, ['projectName', 'ProjectName']);
    return project.trim().isEmpty ? '-' : project;
  }

  List<Map<String, dynamic>> _projectAccesses(Map<String, dynamic> user) {
    final raw = user['projectAccesses'] ?? user['ProjectAccesses'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return const [];
  }

  List<Map<String, dynamic>> _editableProjectAccesses(
    Map<String, dynamic> user,
    List<ProjectOption> availableProjects,
  ) {
    return _projectAccesses(user)
        .where(
          (access) =>
              _readInt(access, ['projectId', 'ProjectId']) > 0 &&
              _readBool(access, ['isActive', 'IsActive']) &&
              !_readBool(access, ['isRejected', 'IsRejected']),
        )
        .map((access) {
          final projectId = _readInt(access, ['projectId', 'ProjectId']);
          ProjectOption? project;
          for (final item in availableProjects) {
            if (item.id == projectId) {
              project = item;
              break;
            }
          }
          return <String, dynamic>{
            'id': _readInt(access, ['id', 'Id']),
            'userId': _readInt(access, ['userId', 'UserId']),
            'projectId': projectId,
            'projectName': _readString(
                  access,
                  ['projectName', 'ProjectName'],
                ).isNotEmpty
                ? _readString(access, ['projectName', 'ProjectName'])
                : project?.name,
            'projectCode': _readString(access, ['projectCode', 'ProjectCode'])
                    .isNotEmpty
                ? _readString(access, ['projectCode', 'ProjectCode'])
                : project?.code,
            'roleId': _readInt(access, ['roleId', 'RoleId']).takeIfPositive(),
            'roleName': _readString(access, ['roleName', 'RoleName']),
            'isActive': true,
            'isApproved': _readBool(access, ['isApproved', 'IsApproved']),
            'isRejected': false,
          };
        })
        .toList();
  }

  String _employeeCode(Map<String, dynamic> user) {
    final employee = _readString(
      user,
      ['employeeId', 'EmployeeId', 'employeeCode', 'EmployeeCode', 'fieldName', 'FieldName'],
    );
    return employee.trim().isEmpty ? '-' : employee;
  }

  String _status(Map<String, dynamic> user) {
    final rejected = _readBool(user, ['isRejected', 'IsRejected']);
    final approved = _readBool(user, ['isApproved', 'IsApproved']);
    final requested = _requestedRole(user);
    if (rejected) return 'Rejected';
    if (!approved && requested.isNotEmpty) return 'Pending';
    if (!approved) return 'Inactive';
    return 'Approved';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Approved':
        return const Color(0xFF16A34A);
      case 'Pending':
        return const Color(0xFFF59E0B);
      case 'Rejected':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _readString(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return '';
  }

  int _readInt(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value is int) return value;
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return 0;
  }

  bool _readBool(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value is bool) return value;
      final text = value?.toString().toLowerCase();
      if (text == 'true') return true;
      if (text == 'false') return false;
    }
    return false;
  }
}

extension on int {
  int? takeIfPositive() => this > 0 ? this : null;
}
