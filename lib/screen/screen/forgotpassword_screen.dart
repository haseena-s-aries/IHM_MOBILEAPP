import 'package:Auras/screen/screen/OtpVerification_screen.dart';
import 'package:Auras/service/api_service.dart';
import 'package:flutter/material.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();

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

  void _sendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showPopup("Error", "Please enter a valid email.");
      return;
    }

    try {
      final response = await ApiService.sendForgotPasswordOtp(email);
      final msg = response['message'] ?? 'Unexpected error';

      if (msg.toLowerCase().contains("otp sent")) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(email: email),
          ),
        );
      } else {
        _showPopup("Error", msg); // clean message like "User not found"
      }
    } catch (e) {
      // Show simple message for format or parsing error
      _showPopup("Error", "User not found");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Forgot Password")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              "Enter your email to receive an OTP for password reset.",
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _sendOtp, child: const Text("Send OTP")),
          ],
        ),
      ),
    );
  }
}
