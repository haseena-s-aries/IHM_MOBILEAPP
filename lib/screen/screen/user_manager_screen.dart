import 'package:Auras/screen/screen/UserFormModel.dart';
import 'package:Auras/service/api_service.dart';
import 'package:Auras/utils/app_dialog.dart';
import 'package:flutter/material.dart';

class UserManagerScreen extends StatefulWidget {
  const UserManagerScreen({super.key});

  @override
  State<UserManagerScreen> createState() => _UserManagerScreenState();
}

class _UserManagerScreenState extends State<UserManagerScreen> {
  List<dynamic> users = [];
  List<dynamic> _allUsers = [];
  bool isLoading = true;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  void _loadUsers() async {
    try {
      final result = await ApiService.getAllUsers(); // implement this method
      setState(() {
        _allUsers = List<dynamic>.from(result);
        users = List<dynamic>.from(result);
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to load users")));
    }
  }

  void _searchUsers(String query) {
    final filtered = _allUsers
        .where(
          (user) =>
              user['fullName'].toLowerCase().contains(query.toLowerCase()) ||
              user['email'].toLowerCase().contains(query.toLowerCase()),
        )
        .toList();

    setState(() => users = filtered);
  }

  void _showEditModal(Map<String, dynamic>? user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => UserFormModal(user: user, onSaved: _loadUsers),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("User Manager")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: _searchUsers,
                    decoration: const InputDecoration(
                      labelText: "Search Users...",
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        return Card(
                          child: ListTile(
                            title: Text(user['fullName']),
                            subtitle: Text(
                              "${user['email']} - ${user['role']}",
                            ),
                            trailing: Wrap(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.orange,
                                  ),
                                  onPressed: () => _showEditModal(user),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () async {
                                    final confirmed = await AppDialog.confirm(
                                      context,
                                      title: 'Delete user?',
                                      message:
                                          "Delete ${user['fullName']} permanently? This cannot be undone.",
                                      confirmLabel: 'Delete user',
                                      destructive: true,
                                    );
                                    if (!confirmed) return;
                                    final deleted =
                                        await AppDialog.execute<bool>(
                                      context,
                                      loadingMessage: 'Deleting user...',
                                      action: () async {
                                        await ApiService.deleteUser(user['id']);
                                        return true;
                                      },
                                      successTitle: 'User deleted',
                                      successMessage:
                                          "${user['fullName']} was deleted successfully.",
                                      errorTitle: 'Unable to delete user',
                                    );
                                    if (deleted == true && mounted) {
                                      _loadUsers();
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditModal(null),
        child: const Icon(Icons.add),
      ),
    );
  }
}
