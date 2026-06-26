import 'package:Auras/app_config.dart';
import 'package:Auras/model/ProfileDto.dart';
import 'package:Auras/utils/app_dialog.dart';

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ViewProfileScreen extends StatefulWidget {
  final int userId;

  const ViewProfileScreen({super.key, required this.userId});

  @override
  State<ViewProfileScreen> createState() => _ViewProfileScreenState();
}

class _ViewProfileScreenState extends State<ViewProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _roleController;
  bool _isLoading = true;

  Future<void> fetchProfile() async {
    final url = Uri.parse(
      "${AppConfig.baseUrl}User/GetProfile/${widget.userId}",
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final profile = ProfileDto.fromJson(data);

      _nameController.text = profile.fullName;
      _emailController.text = profile.email;
      _roleController.text = profile.role;
    } else {
      await AppDialog.error(
        context,
        title: 'Unable to load profile',
        message: 'The profile request returned ${response.statusCode}.',
      );
    }

    setState(() => _isLoading = false);
  }

  Future<void> updateProfile() async {
    await AppDialog.execute<bool>(
      context,
      loadingMessage: 'Updating profile...',
      action: () async {
        final url = Uri.parse("${AppConfig.baseUrl}User/UpdateProfile");
        final model = ProfileDto(
          userId: widget.userId,
          fullName: _nameController.text.trim(),
          email: _emailController.text.trim(),
          role: _roleController.text.trim(),
        );
        final response = await http.post(
          url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(model.toJson()),
        );
        if (response.statusCode != 200) {
          throw Exception(
            'Profile update failed with status ${response.statusCode}.',
          );
        }
        return true;
      },
      successTitle: 'Profile updated',
      successMessage: 'Your profile changes were saved successfully.',
      errorTitle: 'Unable to update profile',
    );
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _roleController = TextEditingController();
    fetchProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("View Profile")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: "Full Name"),
                  ),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: "Email"),
                  ),
                  TextField(
                    controller: _roleController,
                    decoration: const InputDecoration(labelText: "Role"),
                    readOnly: true,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: updateProfile,
                    child: const Text("Update Profile"),
                  ),
                ],
              ),
            ),
    );
  }
}
