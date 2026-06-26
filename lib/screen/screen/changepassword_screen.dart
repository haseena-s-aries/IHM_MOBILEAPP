import 'package:Auras/service/api_service.dart';

import 'package:flutter/material.dart';

class ChangePasswordScreen extends StatefulWidget {
  final int userId;

  const ChangePasswordScreen({super.key, required this.userId});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPassController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();

  bool _isLoading = false;

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

  void _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final message = await ApiService.changePassword(
        UserId: widget.userId,
        currentPassword: _currentPassController.text.trim(),
        newPassword: _newPassController.text.trim(),
        confirmPassword: _confirmPassController.text.trim(),
      );

      _showPopup("Success", message);

      // Clear inputs
      _currentPassController.clear();
      _newPassController.clear();
      _confirmPassController.clear();
    } catch (e) {
      _showPopup("Error", "Failed to change password");
    }

    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _currentPassController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _currentPassController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Enter current password' : null,
              ),
              TextFormField(
                controller: _newPassController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New Password'),
                validator: (value) =>
                    value!.length < 6 ? 'Min 6 characters required' : null,
              ),
              TextFormField(
                controller: _confirmPassController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                ),
                validator: (value) => value != _newPassController.text
                    ? 'Passwords do not match'
                    : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _changePassword,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Change Password'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
