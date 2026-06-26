import 'package:Auras/service/api_service.dart';
import 'package:flutter/material.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  const OtpVerificationScreen({required this.email, super.key});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();

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

  void _verifyAndReset() async {
    final otp = _otpController.text.trim();
    final newPassword = _newPasswordController.text.trim();

    if (otp.isEmpty || newPassword.isEmpty) {
      _showPopup("Error", "All fields are required");
      return;
    }

    if (newPassword.length < 6) {
      _showPopup("Error", "Password must be at least 6 characters");
      return;
    }

    try {
      final response = await ApiService.verifyForgotPasswordOtp(
        widget.email,
        otp,
        newPassword,
      );

      final msg = response['message'] ?? 'Unexpected error';

      if (msg.toLowerCase().contains("success")) {
        _showPopup("Success", msg);
        Future.delayed(const Duration(seconds: 2), () {
          Navigator.popUntil(
            context,
            (route) => route.isFirst,
          ); // back to login
        });
      } else {
        _showPopup("Error", msg);
      }
    } catch (e) {
      _showPopup("Error", "Something went wrong. Please try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Reset Password")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text("OTP sent to: ${widget.email}"),
            const SizedBox(height: 16),
            TextField(
              controller: _otpController,
              decoration: const InputDecoration(labelText: "Enter OTP"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "New Password"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _verifyAndReset,
              child: const Text("Reset Password"),
            ),
          ],
        ),
      ),
    );
  }
}
