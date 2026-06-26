import 'package:Auras/service/api_service.dart';
import 'package:flutter/material.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  String _selectedRole = 'User';
  bool _otpSent = false;
  bool _otpVerified = false;
  bool _sendingOtp = false;
  bool _verifyingOtp = false;
  bool _registering = false;
  String? _otpVerificationToken;

  Future<void> _showPopup(String title, String message) {
    return showDialog(
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

  Future<void> _showApprovalAndRedirect(String message) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Registration"),
        content: Text(message),
      ),
    );

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    _nameController.clear();
    _emailController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
    _otpController.clear();
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  void _sendOtp() async {
    if (_sendingOtp) return;
    final fullName = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (fullName.isEmpty) {
      _showPopup("Invalid Name", "Enter a valid name");
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      _showPopup("Invalid Email", "Enter a valid email address");
      return;
    }
    final passwordMessage = _passwordValidationMessage(
      password,
      confirmPassword,
    );
    if (passwordMessage != null) {
      _showPopup("Invalid Password", passwordMessage);
      return;
    }
    if (password != confirmPassword) {
      _showPopup(
        "Password Mismatch",
        "Password and Confirm Password must match",
      );
      return;
    }

    setState(() {
      _sendingOtp = true;
      _otpVerified = false;
      _otpVerificationToken = null;
      _otpController.clear();
    });

    try {
      final response = await ApiService.SendOtp(email);
      final msg = response['message']?.toString() ?? 'Failed to send OTP';
      await _showPopup("OTP", msg);

      if ((response['status'] == 200 ||
              msg.toLowerCase().contains("otp sent")) &&
          mounted) {
        setState(() => _otpSent = true);
      }
    } finally {
      if (mounted) setState(() => _sendingOtp = false);
    }
  }

  void _verifyOtp() async {
    if (_verifyingOtp) return;
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();

    if (otp.isEmpty) {
      _showPopup("Missing OTP", "Please enter OTP first");
      return;
    }

    setState(() => _verifyingOtp = true);
    try {
      final response = await ApiService.VerifyOtp(email, otp);
      final msg = response['message']?.toString() ?? 'OTP verification failed';
      await _showPopup("OTP Verification", msg);

      if (response['status'] == 200 && mounted) {
        setState(() {
          _otpVerified = true;
          _otpVerificationToken = null;
        });
      }
    } finally {
      if (mounted) setState(() => _verifyingOtp = false);
    }
  }

  void _register() async {
    if (_registering) return;
    if (!_otpVerified) {
      _showPopup("Error", "Please verify OTP first");
      return;
    }

    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final passwordMessage = _passwordValidationMessage(
      password,
      confirmPassword,
    );
    if (passwordMessage != null) {
      _showPopup("Invalid Password", passwordMessage);
      return;
    }

    if (password != confirmPassword) {
      _showPopup("Error", "Password and Confirm Password must match");
      return;
    }

    setState(() => _registering = true);
    final response = await ApiService.Register(
      _nameController.text.trim(),
      _emailController.text.trim(),
      password,
      confirmPassword,
      _selectedRole,
      _otpVerificationToken,
    );
    if (mounted) setState(() => _registering = false);

    final msg = response['message']?.toString() ?? 'Unexpected error';
    final status = response['status'];
    final success =
        status == 200 && msg.toLowerCase().contains("account created");
    if (success) {
      final message = _selectedRole == 'User'
          ? 'Account created successfully'
          : 'Waiting for Admin Approval';
      await _showApprovalAndRedirect(message);
      return;
    }

    await _showPopup("Registration", msg);
  }

  String? _passwordValidationMessage(String password, String confirmPassword) {
    if (password.isEmpty && confirmPassword.isEmpty) {
      return 'Please enter Password and Confirm Password';
    }
    if (password.isEmpty) return 'Please enter Password';
    if (confirmPassword.isEmpty) return 'Please enter Confirm Password';
    if (password.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Full Name"),
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: "Email"),
              ),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: "Password"),
                obscureText: true,
              ),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(
                  labelText: "Confirm Password",
                ),
                obscureText: true,
              ),
              DropdownButtonFormField(
                value: _selectedRole,
                items: ['User', 'Surveyor', 'Manager', 'Admin']
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedRole = val!),
                decoration: const InputDecoration(labelText: "Role"),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _sendingOtp ? null : _sendOtp,
                child: Text(
                  _sendingOtp
                      ? "Sending..."
                      : (_otpSent ? "Resend OTP" : "Send OTP"),
                ),
              ),
              if (_otpSent)
                Column(
                  children: [
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _otpController,
                      decoration: const InputDecoration(labelText: "Enter OTP"),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _verifyingOtp ? null : _verifyOtp,
                      child: Text(
                        _verifyingOtp ? "Verifying..." : "Verify OTP",
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _otpVerified && !_registering ? _register : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _otpVerified ? Colors.blue : Colors.grey,
                ),
                child: Text(_registering ? "Registering..." : "Register"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
