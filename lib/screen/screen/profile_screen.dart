import 'package:Auras/service/api_service.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  final int userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  bool _isEditing = false;

  Map<String, dynamic>? _userData;
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  void _showPopup(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchProfile() async {
    try {
      final user = await ApiService.getProfile(widget.userId);
      setState(() {
        _userData = user;
        _nameController.text = user['fullName'] ?? '';
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showPopup("Error", "Failed to load profile");
    }
  }

  Future<void> _updateProfile() async {
    try {
      final response = await ApiService.updateProfile({
        'userId': widget.userId,
        'fullName': _nameController.text.trim(),
        'email': _userData!['email'],
        'role': _userData!['role'],
      });

      setState(() {
        _userData!['fullName'] = _nameController.text.trim();
        _isEditing = false;
      });

      _showPopup("Success", response['message'] ?? "Profile updated");
    } catch (e) {
      _showPopup("Error", "Failed to update profile");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Profile")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userData == null
          ? const Center(child: Text("User data not found"))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Profile Details",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Name Field
                      TextField(
                        controller: _nameController,
                        enabled: _isEditing,
                        decoration: const InputDecoration(
                          labelText: "Full Name",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Email (read-only)
                      TextFormField(
                        initialValue: _userData!['email'],
                        enabled: false,
                        decoration: const InputDecoration(
                          labelText: "Email",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Role (read-only)
                      TextFormField(
                        initialValue: _userData!['role'],
                        enabled: false,
                        decoration: const InputDecoration(
                          labelText: "Role",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Buttons
                      _isEditing
                          ? Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _updateProfile,
                                    child: const Text("Save"),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      _nameController.text =
                                          _userData!['fullName'];
                                      setState(() => _isEditing = false);
                                    },
                                    child: const Text("Cancel"),
                                  ),
                                ),
                              ],
                            )
                          : SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.edit),
                                label: const Text("Edit Profile"),
                                onPressed: () =>
                                    setState(() => _isEditing = true),
                              ),
                            ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
