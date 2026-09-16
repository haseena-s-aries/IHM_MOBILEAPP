import 'dart:async';

import 'package:Auras/model/PendingUser.dart';
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

  String _selectedRole = '';
  int? _selectedProjectId;
  int? _selectedRoleId;
  List<ProjectOption> _projects = [];
  List<RoleOption> _roles = [];
  bool _loadingProjects = true;
  bool _loadingRoles = false;
  bool _otpSent = false;
  bool _otpVerified = false;
  bool _sendingOtp = false;
  bool _verifyingOtp = false;
  bool _registering = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _otpVerificationToken;
  String? _projectLoadError;
  String? _roleLoadError;
  Timer? _resendTimer;
  int _resendSeconds = 0;

  static final RegExp _emailRegex = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_resetOtpWhenIdentityChanges);
    _passwordController.addListener(_resetOtpWhenIdentityChanges);
    _confirmPasswordController.addListener(_resetOtpWhenIdentityChanges);
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    if (!mounted) return;
    setState(() {
      _loadingProjects = true;
      _projectLoadError = null;
      _roleLoadError = null;
      _roles = [];
      _selectedRoleId = null;
      _selectedRole = '';
    });

    try {
      final projects = await ApiService.fetchProjects();
      if (!mounted) return;
      setState(() {
        _projects = projects;
        _selectedProjectId = projects.isNotEmpty ? projects.first.id : null;
        _loadingProjects = false;
      });
      if (_selectedProjectId != null) {
        await _loadRoles(_selectedProjectId!);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _projects = [];
          _selectedProjectId = null;
          _loadingProjects = false;
          _projectLoadError = error.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _loadRoles(int projectId) async {
    if (!mounted) return;
    setState(() {
      _loadingRoles = true;
      _roleLoadError = null;
      _roles = [];
      _selectedRoleId = null;
      _selectedRole = '';
    });

    try {
      final roles = await ApiService.fetchPublicRoles(projectId);
      if (!mounted) return;
      setState(() {
        _roles = roles;
        _selectedRoleId = roles.isNotEmpty ? roles.first.id : null;
        _selectedRole = roles.isNotEmpty ? roles.first.roleName : '';
        _loadingRoles = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _roles = [];
        _selectedRoleId = null;
        _selectedRole = '';
        _loadingRoles = false;
        _roleLoadError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _resetOtpWhenIdentityChanges() {
    if (!_otpSent && !_otpVerified) return;
    setState(() {
      _otpSent = false;
      _otpVerified = false;
      _otpVerificationToken = null;
      _otpController.clear();
      _resendTimer?.cancel();
      _resendSeconds = 0;
    });
  }

  Future<void> _showPopup(String title, String message) {
    return showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Registration'),
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

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 45);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  Future<void> _sendOtp() async {
    FocusScope.of(context).unfocus();
    if (_sendingOtp || _resendSeconds > 0) return;

    final nameError = _validateName(_nameController.text);
    final emailError = _validateEmail(_emailController.text);
    if (nameError != null || emailError != null) {
      await _showPopup(
        'Required Details',
        nameError ?? emailError ?? 'Please enter your name and email.',
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
      final response = await ApiService.SendOtp(_emailController.text.trim());
      final msg = response['message']?.toString() ?? 'Failed to send OTP';
      await _showPopup('OTP', msg);

      if ((response['status'] == 200 ||
              msg.toLowerCase().contains('otp sent')) &&
          mounted) {
        setState(() => _otpSent = true);
        _startResendTimer();
      }
    } finally {
      if (mounted) setState(() => _sendingOtp = false);
    }
  }

  Future<void> _verifyOtp() async {
    FocusScope.of(context).unfocus();
    if (_verifyingOtp) return;
    final otp = _otpController.text.trim();

    if (otp.isEmpty) {
      await _showPopup('Missing OTP', 'Please enter OTP first');
      return;
    }

    setState(() => _verifyingOtp = true);
    try {
      final response = await ApiService.VerifyOtp(
        _emailController.text.trim(),
        otp,
      );
      final msg = response['message']?.toString() ?? 'OTP verification failed';
      await _showPopup('OTP Verification', msg);

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

  Future<void> _register() async {
    FocusScope.of(context).unfocus();
    if (_registering) return;
    if (!_formKey.currentState!.validate()) return;
    if (!_otpVerified) {
      await _showPopup('OTP Required', 'Please verify OTP before registering.');
      return;
    }
    if (_selectedProjectId == null || _selectedRoleId == null) {
      await _showPopup(
        'Project Required',
        'Please select project and role before registering.',
      );
      return;
    }

    setState(() => _registering = true);
    final response = await ApiService.Register(
      _nameController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text.trim(),
      _confirmPasswordController.text.trim(),
      _selectedRole,
      projectId: _selectedProjectId!,
      roleId: _selectedRoleId!,
      otpVerificationToken: _otpVerificationToken,
    );
    if (mounted) setState(() => _registering = false);

    final msg = response['message']?.toString() ?? 'Unexpected error';
    final status = response['status'];
    final success =
        status == 200 &&
        (msg.toLowerCase().contains('account created') ||
            msg.toLowerCase().contains('registration successful'));
    if (success) {
      await _showApprovalAndRedirect('Waiting for Admin Approval');
      return;
    }

    if (mounted) await _showPopup('Registration', msg);
  }

  String? _validateName(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Please enter Full Name';
    return null;
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
    final password = value?.trim() ?? '';
    final confirmPassword = _confirmPasswordController.text.trim();
    final message = _passwordValidationMessage(password, confirmPassword);
    if (message == 'Please enter Confirm Password') return null;
    return message;
  }

  String? _validateConfirmPassword(String? value) {
    final password = _passwordController.text.trim();
    final confirmPassword = value?.trim() ?? '';
    final message = _passwordValidationMessage(password, confirmPassword);
    if (message == 'Please enter Password') return null;
    if (message != null) return message;
    if (password != confirmPassword) {
      return 'Password and Confirm Password must match';
    }
    return null;
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

  bool get _canRegister =>
      !_registering &&
      _otpVerified &&
      _nameController.text.trim().isNotEmpty &&
      _emailController.text.trim().isNotEmpty &&
      _passwordController.text.trim().isNotEmpty &&
      _confirmPasswordController.text.trim().isNotEmpty &&
      _selectedProjectId != null &&
      _selectedRoleId != null;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 720;
    final selectedProjectValue =
        _projects.any((project) => project.id == _selectedProjectId)
        ? _selectedProjectId
        : null;
    final selectedRoleValue = _roles.any((role) => role.id == _selectedRoleId)
        ? _selectedRoleId
        : null;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF4F7FB), Color(0xFFEAF0FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isWide ? 620 : 440),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF174EA6).withOpacity(0.12),
                        blurRadius: 30,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Create Account',
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF10233F),
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Register and verify your email to continue.',
                                    style: TextStyle(
                                      color: Color(0xFF6B7890),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _nameController,
                          textInputAction: TextInputAction.next,
                          validator: _validateName,
                          decoration: _inputDecoration(
                            label: 'Full Name',
                            icon: Icons.person_rounded,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: _validateEmail,
                          decoration: _inputDecoration(
                            label: 'Email Address',
                            icon: Icons.alternate_email_rounded,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.next,
                          validator: _validatePassword,
                          decoration: _inputDecoration(
                            label: 'Password',
                            icon: Icons.lock_rounded,
                            suffix: IconButton(
                              tooltip: _obscurePassword
                                  ? 'Show password'
                                  : 'Hide password',
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          validator: _validateConfirmPassword,
                          decoration: _inputDecoration(
                            label: 'Confirm Password',
                            icon: Icons.verified_user_rounded,
                            suffix: IconButton(
                              tooltip: _obscureConfirmPassword
                                  ? 'Show password'
                                  : 'Hide password',
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                              ),
                              onPressed: () => setState(
                                () => _obscureConfirmPassword =
                                    !_obscureConfirmPassword,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<int>(
                          value: selectedProjectValue,
                          decoration: _inputDecoration(
                            label: _loadingProjects
                                ? 'Loading projects...'
                                : 'Requested Project / Module',
                            icon: Icons.apps_rounded,
                          ),
                          isExpanded: true,
                          hint: Text(
                            _loadingProjects
                                ? 'Loading projects...'
                                : 'Select Project',
                          ),
                          items: _projects
                              .map(
                                (project) => DropdownMenuItem<int>(
                                  value: project.id,
                                  child: Text(
                                    project.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          validator: (value) =>
                              value == null ? 'Please select Project' : null,
                          onChanged: _loadingProjects || _projects.isEmpty
                              ? null
                              : (value) async {
                                  if (value == null) return;
                                  setState(() {
                                    _selectedProjectId = value;
                                    _roles = [];
                                    _selectedRoleId = null;
                                    _selectedRole = '';
                                  });
                                  await _loadRoles(value);
                                },
                        ),
                        if (_loadingProjects)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: LinearProgressIndicator(minHeight: 3),
                          ),
                        if (_projectLoadError != null)
                          _inlineError(
                            _projectLoadError!,
                            actionLabel: 'Retry',
                            onPressed: _loadProjects,
                          ),
                        if (!_loadingProjects &&
                            _projects.isEmpty &&
                            _projectLoadError == null)
                          _inlineError(
                            'No active projects are available for registration.',
                            actionLabel: 'Retry',
                            onPressed: _loadProjects,
                          ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<int>(
                          value: selectedRoleValue,
                          decoration: _inputDecoration(
                            label: _loadingRoles
                                ? 'Loading roles...'
                                : 'Requested Role',
                            icon: Icons.badge_rounded,
                          ),
                          isExpanded: true,
                          hint: Text(
                            _loadingRoles ? 'Loading roles...' : 'Select Role',
                          ),
                          items: _roles
                              .map(
                                (role) => DropdownMenuItem<int>(
                                  value: role.id,
                                  child: Text(
                                    role.roleName,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          validator: (value) =>
                              value == null ? 'Please select Role' : null,
                          onChanged: _loadingRoles || _roles.isEmpty
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  final role = _roles.firstWhere(
                                    (item) => item.id == value,
                                    orElse: () =>
                                        RoleOption(id: value, roleName: ''),
                                  );
                                  setState(() {
                                    _selectedRoleId = value;
                                    _selectedRole = role.roleName;
                                  });
                                },
                        ),
                        if (_loadingRoles)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: LinearProgressIndicator(minHeight: 3),
                          ),
                        if (_roleLoadError != null)
                          _inlineError(
                            _roleLoadError!,
                            actionLabel: _selectedProjectId == null
                                ? null
                                : 'Retry',
                            onPressed: _selectedProjectId == null
                                ? null
                                : () => _loadRoles(_selectedProjectId!),
                          ),
                        if (!_loadingRoles &&
                            _selectedProjectId != null &&
                            _roles.isEmpty &&
                            _roleLoadError == null)
                          _inlineError(
                            'No public roles are available for this project.',
                            actionLabel: 'Retry',
                            onPressed: () => _loadRoles(_selectedProjectId!),
                          ),
                        const SizedBox(height: 20),
                        _otpPanel(),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: _canRegister
                                  ? const Color(0xFF2563EB)
                                  : const Color(0xFF9AA7BA),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: _canRegister ? _register : null,
                            icon: _registering
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.how_to_reg_rounded),
                            label: Text(
                              _registering ? 'Registering...' : 'Register',
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Center(
                          child: TextButton(
                            onPressed: _registering
                                ? null
                                : () => Navigator.pushNamedAndRemoveUntil(
                                      context,
                                      '/login',
                                      (route) => false,
                                    ),
                            child: const Text('Already registered? Login'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _otpPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _otpVerified ? const Color(0xFF16A34A) : const Color(0xFFD7DFEA),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _otpVerified
                    ? Icons.check_circle_rounded
                    : Icons.mark_email_read_rounded,
                color: _otpVerified
                    ? const Color(0xFF16A34A)
                    : const Color(0xFF2563EB),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _otpVerified ? 'Email verified' : 'Email OTP Verification',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF10233F),
                  ),
                ),
              ),
              TextButton(
                onPressed: (_sendingOtp || _resendSeconds > 0)
                    ? null
                    : _sendOtp,
                child: Text(
                  _sendingOtp
                      ? 'Sending...'
                      : _otpSent
                          ? (_resendSeconds > 0
                              ? 'Resend in ${_resendSeconds}s'
                              : 'Resend OTP')
                          : 'Send OTP',
                ),
              ),
            ],
          ),
          if (_otpSent && !_otpVerified) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration(
                label: 'Enter OTP',
                icon: Icons.pin_rounded,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _verifyingOtp ? null : _verifyOtp,
                icon: _verifyingOtp
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.verified_rounded),
                label: Text(_verifyingOtp ? 'Verifying...' : 'Verify OTP'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _inlineError(
    String message, {
    String? actionLabel,
    VoidCallback? onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFDA4AF)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFE11D48),
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Color(0xFF9F1239),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (actionLabel != null && onPressed != null)
              TextButton(
                onPressed: onPressed,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(actionLabel),
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
      fillColor: Colors.white,
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
