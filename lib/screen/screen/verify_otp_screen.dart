import 'package:Auras/service/api_service.dart';
import 'package:flutter/material.dart';

import 'login_screen.dart';

class VerifyOtpScreen extends StatefulWidget {
  final String fullName;
  final String email;
  final String password;
  final String role;

  const VerifyOtpScreen({
    required this.fullName,
    required this.email,
    required this.password,
    required this.role,
    super.key,
  });

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  final _otpController = TextEditingController();

  void _verifyOtpAndRegister() async {
    try {
      print(
        "Verifying OTP for: ${widget.email}, OTP: ${_otpController.text.trim()}",
      );

      // ✅ Attempt Registration
      final response = await ApiService.Register(
        widget.fullName,
        widget.email,
        widget.password,
        widget.password, // Confirm password same here
        widget.role,
        projectId: 0,
        roleId: 0,
      );

      final status = response['status'];
      final message = response['message'];

      print("🔵 Registration Status: $status");
      print("🟡 Registration Message: $message");

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));

      if (status == 200 && message.toLowerCase().contains("account created")) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      print("❌ Exception in registration: $e");

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _resendOtp() async {
    try {
      final msg = await ApiService.sendOtp(widget.email);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to resend OTP: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF4FB),
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Enter OTP",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text("Sent to: ${widget.email}"),
              const SizedBox(height: 20),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "OTP",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _verifyOtpAndRegister,
                  child: const Text("Verify & Register"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
