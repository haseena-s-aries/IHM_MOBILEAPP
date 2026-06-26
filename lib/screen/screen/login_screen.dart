import 'package:Auras/screen/screen/admin_dashboard_screen.dart';
import 'package:Auras/screen/screen/forgotpassword_screen.dart';
import 'package:Auras/screen/screen/register_screen.dart';
import 'package:Auras/service/api_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  void _login() async {
    try {
      final result = await ApiService.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      final token = result['token']?.toString() ?? '';
      final Map<String, dynamic> user = Map<String, dynamic>.from(
        result['user'],
      );
      final userId = user['userId'] ?? user['id'] ?? 0;
      print("🟢 Final userId = $userId");

      final userWithId = {...user, 'userId': userId};
      final role = userWithId['role']?.toLowerCase();
      final fullName =
          userWithId['fullName']?.toString() ??
          userWithId['name']?.toString() ??
          userWithId['username']?.toString() ??
          '';

      print("✅ Logging in with userId = ${userWithId['userId']}");

      // ✅ Save login state locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userRole', role ?? '');
      await prefs.setInt('userId', userId);
      await prefs.setString('fullName', fullName);
      await prefs.setString('token', token);

      if (role == 'admin' || role == 'manager' || role == 'surveyor') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AdminDashboardScreen(user: userWithId),
          ),
        );
      } else if (role == 'user') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => DashboardScreen(user: userWithId)),
        );
      } else {
        throw Exception("Unknown role: $role");
      }
    } catch (e) {
      var errorMessage = e.toString();
      errorMessage = errorMessage
          .replaceFirst('Exception: Login error: Exception: Login failed: ', '')
          .replaceFirst('Exception: Login error: ', '')
          .replaceFirst('Exception: ', '');

      if (errorMessage.contains('Invalid Password') ||
          errorMessage.contains('Invalid Email')) {
        errorMessage = 'Invalid email or password.';
      } else if (errorMessage.trim().isEmpty) {
        errorMessage = 'Login failed. Please try again.';
      }

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Login Failed"),
          content: Text(errorMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF5B3FD4), // Purple background
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Login",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: "Email",
                  filled: true,
                  fillColor: Color(0xFFF0F4FF),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Password",
                  filled: true,
                  fillColor: Color(0xFFF0F4FF),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF316CFF),
                    padding: EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _login,
                  child: const Text(
                    "Login",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ForgotPasswordScreen()),
                  );
                },
                child: const Text("Forgot Password?"),
              ),

              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account? "),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => RegisterScreen()),
                      );
                    },
                    child: const Text(
                      "Register Here",
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
