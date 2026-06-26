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

  @override
  void initState() {
    super.initState();
    _pendingUsersFuture = ApiService.fetchPendingUsers();
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
      _pendingUsersFuture = ApiService.fetchPendingUsers();
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
                            await ApiService.approveUser(user.id);
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
