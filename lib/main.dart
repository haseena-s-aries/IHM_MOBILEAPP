import 'package:Auras/ThemeNotifier.dart';
import 'package:Auras/Db/database_factory_initializer.dart';
import 'package:Auras/network/http_override_initilalizer.dart';
import 'package:Auras/screen/screen/admin_dashboard_screen.dart';
import 'package:Auras/screen/screen/assigned_reports_screen.dart';
import 'package:Auras/screen/screen/dashboard_screen.dart';
import 'package:Auras/screen/screen/landing_screen.dart';
import 'package:Auras/screen/screen/login_screen.dart';
import 'package:Auras/screen/screen/register_screen.dart';
import 'package:Auras/service/sync_service.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Function to check internet
Future<bool> checkInternetConnection() => hasInternetConnection();

Future<void> syncCertificates(BuildContext context) async {
  // 🔍 Check internet connection
  final connectivityResult = await Connectivity().checkConnectivity();
  if (connectivityResult != ConnectivityResult.none) {
    // Internet is ON → Do Sync
    await performSync();

    // Show popup/snackbar after sync starts
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("🔄 Syncing certificates to server..."),
        duration: Duration(seconds: 3),
        backgroundColor: Colors.blue,
      ),
    );
  } else {
    // Internet is OFF → Show warning
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("⚠️ No internet connection. Sync skipped."),
        duration: Duration(seconds: 3),
        backgroundColor: Colors.red,
      ),
    );
  }
}

Future<void> performSync() async {
  // Your sync logic here
  await Future.delayed(Duration(seconds: 2)); // Simulate sync time
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initializeHttpOverrides();
  await initializeDatabaseFactory();
  SyncService.startAutoSync();

  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  final userRole = prefs.getString('userRole');
  final userId = prefs.getInt('userId');
  final fullName = prefs.getString('fullName');
  final isDarkMode = await ThemeNotifier.loadSavedTheme();

  // Simulate user object
  final user = {'userId': userId, 'role': userRole, 'fullName': fullName};

  // Add this in a suitable place like in your main() or initState of a central widget

  Widget initialScreen;

  if (isLoggedIn && userRole != null && userId != null) {
    final normalizedRole = userRole.toLowerCase();
    if (normalizedRole == 'admin' ||
        normalizedRole == 'manager' ||
        normalizedRole == 'surveyor') {
      initialScreen = AdminDashboardScreen(user: user);
    } else if (normalizedRole == 'client') {
      initialScreen = AssignedReportsScreen(user: user);
    } else if (normalizedRole == 'user') {
      initialScreen = DashboardScreen(user: user);
    } else {
      initialScreen = const LoginScreen();
    }
  } else {
    initialScreen = const LoginScreen();
  }

  runApp(MyApp(startScreen: initialScreen, isDarkMode: isDarkMode));
}

class MyApp extends StatelessWidget {
  final Widget startScreen;
  final bool isDarkMode;

  const MyApp({super.key, required this.startScreen, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeNotifier(isDarkMode: isDarkMode),
      child: Consumer<ThemeNotifier>(
        builder: (context, themeNotifier, _) {
          return MaterialApp(
            title: 'AURAS',
            debugShowCheckedModeBanner: false,
            themeMode: themeNotifier.themeMode,
            theme: ThemeData(
              brightness: Brightness.light,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF6A5ACD),
                brightness: Brightness.light,
              ),
              scaffoldBackgroundColor: const Color(0xFFF0F4FA),
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF4BA3F5),
                brightness: Brightness.dark,
              ),
              scaffoldBackgroundColor: const Color(0xFF0D1B2A),
              useMaterial3: true,
            ),
            home: startScreen,
            routes: {
              '/login': (context) => const LoginScreen(),
              '/register': (context) => const RegisterScreen(),
              '/landing': (context) => LandingScreen(),
            },
          );
        },
      ),
    );
  }
}
