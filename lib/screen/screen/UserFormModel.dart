import 'package:Auras/service/api_service.dart';
import 'package:Auras/utils/app_dialog.dart';
import 'package:flutter/material.dart';

class UserFormModal extends StatefulWidget {
  final Map<String, dynamic>? user;
  final VoidCallback onSaved;
  const UserFormModal({super.key, this.user, required this.onSaved});

  @override
  State<UserFormModal> createState() => _UserFormModalState();
}

class _UserFormModalState extends State<UserFormModal> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  String _role = "User";
  bool isNew = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      isNew = false;
      _name.text = widget.user!['fullName'];
      _email.text = widget.user!['email'];
      _role = widget.user!['role'];
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _showPopup(String title, String message) {
    AppDialog.error(context, title: title, message: message);
  }

  void _saveUser() async {
    if (!_formKey.currentState!.validate()) return;

    if (isNew && _password.text != _confirmPassword.text) {
      _showPopup("Error", "Passwords do not match");
      return;
    }

    final userData = {
      "id": widget.user?['id'] ?? widget.user?['Id'] ?? 0,
      "fullName": _name.text.trim(),
      "email": _email.text.trim(),
      "role": _role,
      if (isNew) "password": _password.text.trim(),
    };

    final saved = await AppDialog.execute<bool>(
      context,
      loadingMessage: isNew ? 'Creating user...' : 'Updating user...',
      action: () async {
        await ApiService.saveUser(userData);
        return true;
      },
      successTitle: isNew ? 'User created' : 'User updated',
      successMessage: isNew
          ? '${_name.text.trim()} can now access the application.'
          : '${_name.text.trim()} was updated successfully.',
      errorTitle: 'Unable to save user',
    );
    if (saved == true && mounted) {
      Navigator.pop(context);
      widget.onSaved();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Wrap(
            children: [
              Text(
                isNew ? "Add User" : "Edit User",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: "Full Name"),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(labelText: "Email"),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return "Email is required";
                  final valid = RegExp(
                    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
                  ).hasMatch(value);
                  return valid ? null : "Enter a valid email address";
                },
              ),
              DropdownButtonFormField<String>(
                value: _role,
                decoration: const InputDecoration(labelText: "Role"),
                items: const ["User", "Surveyor", "Manager", "Admin"]
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (val) => setState(() => _role = val!),
              ),
              if (isNew) ...[
                TextFormField(
                  controller: _password,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: "Password",
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () => setState(
                        () => _obscurePassword = !_obscurePassword,
                      ),
                    ),
                  ),
                  validator: (v) =>
                      (v ?? '').length < 6 ? "Min 6 characters" : null,
                ),
                TextFormField(
                  controller: _confirmPassword,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: "Confirm Password",
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () => setState(
                        () => _obscureConfirmPassword =
                            !_obscureConfirmPassword,
                      ),
                    ),
                  ),
                  validator: (v) =>
                      v != _password.text ? "Passwords do not match" : null,
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _saveUser,
                icon: const Icon(Icons.save),
                label: const Text("Save User"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
