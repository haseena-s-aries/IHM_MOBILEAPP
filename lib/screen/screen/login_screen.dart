import 'package:Auras/screen/screen/admin_dashboard_screen.dart';
import 'package:Auras/screen/screen/assigned_reports_screen.dart';
import 'package:Auras/screen/screen/forgotpassword_screen.dart';
import 'package:Auras/screen/screen/register_screen.dart';
import 'package:Auras/service/api_service.dart';
import 'package:Auras/service/sync_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  static final RegExp _emailRegex = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Please enter Email';
    if (!_emailRegex.hasMatch(email)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Please enter Password';
    return null;
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate() || _isLoading) return;

    setState(() => _isLoading = true);
    try {
      final result = await ApiService.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      final token = result['token']?.toString() ?? '';
      final Map<String, dynamic> user = Map<String, dynamic>.from(
        result['user'],
      );
      final userId =
          int.tryParse((user['userId'] ?? user['id'] ?? 0).toString()) ?? 0;

      final role = (user['role'] ??
              user['Role'] ??
              user['roleName'] ??
              user['RoleName'] ??
              '')
          .toString()
          .trim()
          .toLowerCase();
      final userWithId = {...user, 'userId': userId, 'role': role};
      final fullName =
          userWithId['fullName']?.toString() ??
          userWithId['name']?.toString() ??
          userWithId['username']?.toString() ??
          '';
      final email = userWithId['email']?.toString() ?? '';
      final projectName =
          (userWithId['projectName'] ?? userWithId['ProjectName'] ?? '')
              .toString();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userRole', role);
      await prefs.setInt('userId', userId);
      await prefs.setString('fullName', fullName);
      await prefs.setString('email', email);
      await prefs.setString('projectName', projectName);
      await prefs.setString('token', token);
      SyncService.startAutoSync();

      if (!mounted) return;
      final isGlobalAdminRole = role == 'admin' ||
          role == 'global admin' ||
          role == 'globaladmin' ||
          role == 'administrator';

      if (isGlobalAdminRole || role == 'manager' || role == 'surveyor') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AdminDashboardScreen(user: userWithId),
          ),
        );
      } else if (role == 'client') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AssignedReportsScreen(user: userWithId),
          ),
        );
      } else if (role == 'user') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => DashboardScreen(user: userWithId)),
        );
      } else {
        throw Exception('Unknown role: $role');
      }
    } catch (e) {
      if (!mounted) return;
      var errorMessage = e.toString();
      errorMessage = errorMessage
          .replaceFirst('Exception: Login error: Exception: Login failed: ', '')
          .replaceFirst('Exception: Login error: ', '')
          .replaceFirst('Exception: ', '');

      final lower = errorMessage.toLowerCase();
      if (errorMessage.contains('Invalid Password') ||
          errorMessage.contains('Invalid Email')) {
        errorMessage = 'Invalid email or password.';
      } else if (lower.contains('failed host lookup') ||
          lower.contains('socketexception') ||
          lower.contains('socketfailed') ||
          lower.contains('network is unreachable') ||
          lower.contains('connection refused') ||
          lower.contains('connection timed out') ||
          lower.contains('clientexception')) {
        // The phone could not reach the server (no internet, or DNS blocked).
        // This is not an account problem: the same email can be signed in
        // on more than one phone.
        errorMessage =
            'Cannot connect to the server.\n\n'
            'Please check this phone\'s internet connection (mobile data or '
            'Wi-Fi) and try again. If you have internet, turn off '
            '"Private DNS" or any VPN / ad blocker in phone settings.';
      } else if (errorMessage.trim().isEmpty) {
        errorMessage = 'Login failed. Please try again.';
      }

      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Login Failed'),
          content: Text(errorMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF081A31), Color(0xFF174EA6), Color(0xFF6A5ACD)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: _loginCard(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _loginCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.20),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF4FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.lock_rounded, color: Color(0xFF2563EB)),
            ),
            const SizedBox(height: 20),
            const Text(
              'Welcome Back',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Color(0xFF10233F),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Sign in to continue your survey workflow.',
              style: TextStyle(color: Color(0xFF6B7890), fontSize: 14),
            ),
            const SizedBox(height: 26),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: _validateEmail,
              decoration: _inputDecoration(
                label: 'Email address',
                icon: Icons.alternate_email_rounded,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              validator: _validatePassword,
              onFieldSubmitted: (_) => _login(),
              decoration: _inputDecoration(
                label: 'Password',
                icon: Icons.password_rounded,
                suffix: IconButton(
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ForgotPasswordScreen(),
                          ),
                        );
                      },
                child: const Text('Forgot Password?'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _isLoading ? null : _login,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.login_rounded),
                label: Text(_isLoading ? 'Signing in...' : 'Login'),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Don't have an account? ",
                  style: TextStyle(color: Color(0xFF6B7890)),
                ),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RegisterScreen(),
                            ),
                          );
                        },
                  child: const Text('Register Here'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF5F7FB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFD7DFEA)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFD7DFEA)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE11D48)),
      ),
    );
  }
}
