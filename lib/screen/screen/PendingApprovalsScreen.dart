import 'package:Auras/model/PendingUser.dart';
import 'package:Auras/service/api_service.dart';
import 'package:Auras/utils/app_dialog.dart';
import 'package:flutter/material.dart';

class PendingApprovalsScreen extends StatefulWidget {
  const PendingApprovalsScreen({super.key});

  @override
  State<PendingApprovalsScreen> createState() => _PendingApprovalsScreenState();
}

class _PendingApprovalsScreenState extends State<PendingApprovalsScreen> {
  late Future<List<PendingUser>> _pendingUsersFuture;
  final Set<int> _processing = {};
  final Map<int, int?> _selectedProjectIds = {};
  List<ProjectOption> _projects = [];

  @override
  void initState() {
    super.initState();
    _pendingUsersFuture = _loadPendingUsers();
  }

  Future<List<PendingUser>> _loadPendingUsers() async {
    final usersFuture = ApiService.fetchPendingUsers();
    final projectsFuture = ApiService.fetchProjects();
    final users = await usersFuture;
    _projects = await projectsFuture;
    for (final user in users) {
      _selectedProjectIds[user.id] ??= user.projectId;
    }
    return users;
  }

  void _showPopup(String title, String message) {
    if (title.toLowerCase().contains('fail')) {
      AppDialog.error(context, title: title, message: message);
    } else {
      AppDialog.success(context, title: title, message: message);
    }
  }

  void _refreshList() {
    setState(() {
      _pendingUsersFuture = _loadPendingUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pending User Approvals"),
        backgroundColor: Colors.deepPurple,
      ),
      body: FutureBuilder<List<PendingUser>>(
        future: _pendingUsersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final users = snapshot.data!;
          if (users.isEmpty) {
            return const Center(child: Text("No pending users to approve."));
          }

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text(user.fullName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Email: ${user.email}"),
                      Text("Requested Role: ${user.requestedRole}"),
                      Text(
                        "Requested Project: ${user.projectName?.trim().isNotEmpty == true ? user.projectName : '-'}",
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        value: _selectedProjectIds[user.id],
                        decoration: const InputDecoration(
                          labelText: 'Approve Project',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        items: _projects
                            .map(
                              (project) => DropdownMenuItem<int>(
                                value: project.id,
                                child: Text(project.name),
                              ),
                            )
                            .toList(),
                        onChanged: _processing.contains(user.id)
                            ? null
                            : (value) {
                                setState(() {
                                  _selectedProjectIds[user.id] = value;
                                });
                              },
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                        ),
                        onPressed: () async {
                          if (_processing.contains(user.id)) return;
                          final projectId = _selectedProjectIds[user.id];
                          if (projectId == null || projectId <= 0) {
                            _showPopup(
                              "Approval failed",
                              "Please select project before approving user.",
                            );
                            return;
                          }
                          final confirmed = await AppDialog.confirm(
                            context,
                            title: 'Approve user?',
                            message:
                                'Approve ${user.fullName} as ${user.requestedRole}?',
                            confirmLabel: 'Approve',
                          );
                          if (!confirmed) return;
                          setState(() => _processing.add(user.id));
                          try {
                            await ApiService.approveUser(
                              user.id,
                              projectId: projectId,
                            );
                            if (!mounted) return;
                            _showPopup("Success", "User approved successfully.");
                            _refreshList();
                          } catch (e) {
                            if (!mounted) return;
                            _showPopup("Approval failed", e.toString());
                          } finally {
                            if (mounted) {
                              setState(() => _processing.remove(user.id));
                            }
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        onPressed: () async {
                          if (_processing.contains(user.id)) return;
                          final confirmed = await AppDialog.confirm(
                            context,
                            title: 'Remove pending user?',
                            message:
                                'Reject and remove ${user.fullName} from pending approvals?',
                            confirmLabel: 'Reject user',
                            destructive: true,
                          );
                          if (!confirmed) return;
                          setState(() => _processing.add(user.id));
                          try {
                            await ApiService.rejectUser(user.id);
                            if (!mounted) return;
                            _showPopup("Deleted", "Pending user removed.");
                            _refreshList();
                          } catch (e) {
                            if (!mounted) return;
                            _showPopup("Delete failed", e.toString());
                          } finally {
                            if (mounted) {
                              setState(() => _processing.remove(user.id));
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
