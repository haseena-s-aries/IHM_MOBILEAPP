import 'dart:async';
import 'dart:convert';

import 'package:Auras/app_config.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Global navigator so the session can send the user back to login from
/// service code when the server definitively rejects the stored session.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Keeps the stored JWT usable across app restarts.
///
/// The backend issues 1-hour access tokens, while the app keeps the user
/// signed in indefinitely (needed for offline field work). Without renewal,
/// reopening the app after an hour sends an expired token: authorized
/// endpoints fail and the job list endpoint silently returns an empty list,
/// so the dashboard shows only cached counts and no jobs until the user logs
/// out and in again. This class transparently refreshes the token when it is
/// expired or about to expire.
class AuthSession {
  static const Duration _refreshBeforeExpiry = Duration(minutes: 5);
  static Future<String>? _refreshInFlight;
  static bool _redirectingToLogin = false;

  static String get _baseUrl =>
      AppConfig.baseUrl.replaceAll(RegExp(r'/$'), '');

  /// Returns a token that is valid (refreshing it first when needed). When
  /// offline or the server is unreachable, the stored token is returned
  /// unchanged so offline features keep working.
  static Future<String> validToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    if (token.isEmpty) return token;

    final expiry = tokenExpiry(token);
    if (expiry == null ||
        expiry.isAfter(DateTime.now().toUtc().add(_refreshBeforeExpiry))) {
      return token;
    }

    return _refreshInFlight ??= _refresh(token).whenComplete(() {
      _refreshInFlight = null;
    });
  }

  /// Call at app start (and on resume) to renew the session proactively.
  static Future<void> ensureFreshSession() async {
    try {
      await validToken();
    } catch (error) {
      debugPrint('[Auth] session refresh skipped: $error');
    }
  }

  static DateTime? tokenExpiry(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final data = jsonDecode(payload);
      if (data is! Map) return null;
      final exp = int.tryParse(data['exp']?.toString() ?? '');
      if (exp == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
    } catch (_) {
      return null;
    }
  }

  static Future<String> _refresh(String currentToken) async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) return currentToken;

    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$_baseUrl/User/refresh-token'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'token': currentToken}),
          )
          .timeout(const Duration(seconds: 15));
    } catch (error) {
      // Network problem: keep working with what we have.
      debugPrint('[Auth] refresh failed (network): $error');
      return currentToken;
    }

    if (response.statusCode == 200) {
      try {
        final decoded = jsonDecode(response.body);
        final newToken = decoded is Map ? decoded['token']?.toString() : null;
        if (newToken == null || newToken.isEmpty) return currentToken;

        final prefs = await SharedPreferences.getInstance();
        // Only store it if the user did not log out meanwhile.
        if ((prefs.getString('token') ?? '') == currentToken) {
          await prefs.setString('token', newToken);
          final user = decoded['user'];
          if (user is Map) {
            final projectName = user['projectName']?.toString();
            if (projectName != null) {
              await prefs.setString('projectName', projectName);
            }
          }
        }
        return newToken;
      } catch (error) {
        debugPrint('[Auth] refresh response invalid: $error');
        return currentToken;
      }
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      await _sessionRejected();
      return '';
    }

    // 404 (older backend without the endpoint), 5xx, etc.
    debugPrint('[Auth] refresh failed: HTTP ${response.statusCode}');
    return currentToken;
  }

  /// The server says this session can no longer be renewed (account
  /// disabled, or signed out for longer than the grace period). Ask the user
  /// to sign in again. Offline data (including unsynced changes) is kept.
  static Future<void> _sessionRejected() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.setBool('isLoggedIn', false);

    if (_redirectingToLogin) return;
    _redirectingToLogin = true;
    try {
      final navigator = appNavigatorKey.currentState;
      if (navigator == null) return;
      navigator.pushNamedAndRemoveUntil('/login', (_) => false);
      final context = appNavigatorKey.currentContext;
      if (context != null) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Your session has expired. Please login again.'),
          ),
        );
      }
    } finally {
      _redirectingToLogin = false;
    }
  }
}
