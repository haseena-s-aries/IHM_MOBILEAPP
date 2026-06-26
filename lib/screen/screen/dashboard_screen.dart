import 'dart:async';

import 'package:Auras/ThemeNotifier.dart';
import 'package:Auras/Db/database_helper.dart';
import 'package:Auras/main.dart';
import 'package:Auras/model/TotalCertificateCountDto.dart';
import 'package:Auras/model/app_notification.dart';
import 'package:Auras/screen/screen/Loadout_certificate_screen.dart';
import 'package:Auras/screen/screen/Seafastening_certificate_screen.dart';
import 'package:Auras/screen/screen/Towage_certificate_screen.dart';
import 'package:Auras/screen/screen/changepassword_screen.dart';
import 'package:Auras/screen/screen/pdf_viewer_screen.dart';
import 'package:Auras/screen/screen/profile_screen.dart';
import 'package:Auras/service/api_service.dart';
import 'package:Auras/service/sync_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const DashboardScreen({required this.user, super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0; // Set 'Certificates' as default active tab

  List<Widget>? _pages;

  CertificateReport? report;
  bool isLoading = true;
  List<AppNotification> _notifications = const [];
  Timer? _notificationTimer;
  bool _notificationsLoaded = false;

  @override
  void initState() {
    super.initState();

    // Load initial data
    _fetchCertificateReport();
    _loadNotifications();
    _notificationTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadNotifications(showNewAlert: true),
    );

    // 🔁 Auto-sync when online, then refresh dashboard
    Connectivity().onConnectivityChanged.listen((result) async {
      if (result != ConnectivityResult.none) {
        await SyncService.syncAllCertificatesToServer();
        await SyncService.syncFromServerToLocal();

        // ✅ Refresh dashboard data after sync
        _fetchCertificateReport();
      }
    });
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  int get _unreadNotificationCount =>
      _notifications.where((item) => !item.isRead).length;

  Future<int> _currentUserId() async {
    final fromWidget =
        int.tryParse(
          (widget.user['userId'] ?? widget.user['id'] ?? '').toString(),
        ) ??
        0;
    if (fromWidget > 0) return fromWidget;

    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('userId') ?? 0;
  }

  Future<void> _loadNotifications({bool showNewAlert = false}) async {
    try {
      final userId = await _currentUserId();
      if (userId <= 0) return;

      final previousUnread = _unreadNotificationCount;
      final notifications = await ApiService.fetchUserNotifications(userId);
      if (!mounted) return;
      setState(() {
        _notifications = notifications;
        _notificationsLoaded = true;
      });

      final currentUnread = notifications.where((item) => !item.isRead).length;
      if (showNewAlert &&
          _notificationsLoaded &&
          currentUnread > previousUnread &&
          mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have a new survey assignment')),
        );
      }
    } catch (_) {
      // Dashboard remains usable when notification polling is unavailable.
    }
  }

  Future<void> _showNotifications() async {
    await _loadNotifications();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.72,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 12, 10),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Notifications',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (_unreadNotificationCount > 0)
                            TextButton(
                              onPressed: () async {
                                final userId = await _currentUserId();
                                await ApiService.markAllNotificationsRead(
                                  userId,
                                );
                                await _loadNotifications();
                                if (sheetContext.mounted) setSheetState(() {});
                              },
                              child: const Text('Mark all read'),
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: _notifications.isEmpty
                          ? const Center(
                              child: Text('No notifications yet'),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: _notifications.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (_, index) {
                                final item = _notifications[index];
                                return Material(
                                  color: item.isRead
                                      ? Theme.of(context).cardColor
                                      : Theme.of(
                                          context,
                                        ).colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                  child: ListTile(
                                    leading: Icon(
                                      Icons.assignment_turned_in_outlined,
                                      color: item.isRead
                                          ? Colors.grey
                                          : Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                    ),
                                    title: Text(
                                      item.title,
                                      style: TextStyle(
                                        fontWeight: item.isRead
                                            ? FontWeight.w600
                                            : FontWeight.w800,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Text(item.message),
                                        const SizedBox(height: 5),
                                        Text(
                                          _notificationTime(item.createdAt),
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                    onTap: () async {
                                      if (!item.isRead) {
                                        await ApiService.markNotificationRead(
                                          item.id,
                                        );
                                        await _loadNotifications();
                                        if (sheetContext.mounted) {
                                          setSheetState(() {});
                                        }
                                      }
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _notificationTime(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} $hour:$minute';
  }

  Widget _buildHomePage() {
    final colors = context.watch<ThemeNotifier>().colors;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (report == null) {
      return Center(
        child: Text(
          "No data available",
          style: TextStyle(color: colors.textSecond),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await SyncService.syncAllCertificatesToServer();
        await SyncService.syncFromServerToLocal();
        await _fetchCertificateReport();
        await _loadNotifications();
      },
      child: SingleChildScrollView(
        // Needed for RefreshIndicator to work
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: context.watch<ThemeNotifier>().isDarkMode
                        ? const [Color(0xFF102A43), Color(0xFF1E3A5F)]
                        : const [Color(0xFF00A8A8), Color(0xFF1E88E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.16),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'SURVEYOR WORKSPACE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Survey Dashboard',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Create certificates, sync field data and review recent counts.',
                      style: TextStyle(color: Colors.white70, height: 1.35),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () => _showCreateDialog(context),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Create Certificate'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: colors.primary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _syncAllCertificates() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ No internet connection")),
      );
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("🔁 Syncing...")));

    await SyncService.syncAllCertificatesToServer(); // 🔁 Call full sync

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("✅ Sync completed")));
  }

  Widget _buildStatCard(String title, int count, IconData icon, Color color) {
    final theme = context.watch<ThemeNotifier>();
    final colors = theme.colors;

    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        constraints: const BoxConstraints(minHeight: 96),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(theme.isDarkMode ? 0.18 : 0.06),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 23),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textSecond,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchCertificateReport() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      final result = await ApiService.fetchCertificateReport();

      // Save the latest values in SharedPreferences for offline use
      await prefs.setInt('totalCertificates', result.totalCertificates);
      await prefs.setInt('towageCount', result.towageCount);
      await prefs.setInt('seaFasteningCount', result.seaFasteningCount);
      await prefs.setInt('loadoutCount', result.loadoutCount);

      setState(() {
        report = result;
        isLoading = false;
        _pages = const [];
      });
    } catch (e) {
      // Load offline cached data
      final total = prefs.getInt('totalCertificates') ?? 0;
      final towage = prefs.getInt('towageCount') ?? 0;
      final seafastening = prefs.getInt('seaFasteningCount') ?? 0;
      final loadout = prefs.getInt('loadoutCount') ?? 0;

      setState(() {
        report = CertificateReport(
          totalCertificates: total,
          towageCount: towage,
          seaFasteningCount: seafastening,
          loadoutCount: loadout,
        );
        isLoading = false;
        _pages = const [];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Offline: showing cached data")),
      );
    }
  }

  Future<void> syncFromServerToLocal() async {
    final isOnline = await isConnected();
    if (!isOnline) return;

    try {
      final serverCerts = await ApiService.fetchTowageCertificatesFromServer();
      final db = DatabaseHelper();

      for (final cert in serverCerts) {
        await db.upsertTowageCertificate(cert);
      }

      print("📥 Synced ${serverCerts.length} certificates from server.");
    } catch (e) {
      print("❌ Sync from server failed: $e");
    }
  }

  Future<void> syncTowageCertificatesToServer() async {
    final dbHelper = DatabaseHelper();
    final unsynced = await dbHelper.getUnsyncedTowageCertificates();

    for (final cert in unsynced) {
      try {
        final result = await ApiService.submitTowageCertificate(cert.toMap());
        print('✅ Synced Towage ID: ${cert.id}');

        // ✅ MARK AS SYNCED IN LOCAL DB
        await DatabaseHelper.instance.markTowageCertificateAsSynced(cert.id!);
      } catch (e) {
        print('❌ Sync failed for ID ${cert.id}: $e');
      }
    }
  }

  Widget _buildCertificatePage() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton.icon(
            onPressed: () => _showCreateDialog(context),
            icon: const Icon(Icons.add),
            label: const Text("Create Certificate"),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _showViewCertificateOptions(context),

            icon: const Icon(Icons.visibility),
            label: const Text("View Demo Certificates"),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ],
      ),
    );
  }

  void _showViewCertificateOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text("Towage Certificate"),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        PDFViewerScreen(assetPath: 'assets/TOWAGE.pdf'),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text("Seafastening Certificate"),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        PDFViewerScreen(assetPath: 'assets/SEAFASTENING.pdf'),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text("Loadout Certificate"),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        PDFViewerScreen(assetPath: 'assets/LOADOUT.pdf'),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Widget _buildCurrentPage() {
    switch (_currentIndex) {
      case 0:
        return _buildHomePage();
      case 1:
        return _buildCertificatePage();
      default:
        return _buildProfileSection();
    }
  }

  void _showCreateDialog(BuildContext context) {
    String selectedDocument = '-- Select Document Type --';
    String? selectedCertificateType;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2F2F2F),
          title: const Text(
            'Create Certificate',
            style: TextStyle(color: Colors.white),
          ),
          content: StatefulBuilder(
            builder: (context, setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Select Document Type:',
                      style: TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedDocument,
                      items:
                          [
                            '-- Select Document Type --',
                            'Certificate',
                            'QHSE Form',
                            'Survey Divison Form',
                            'Reports',
                          ].map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(
                                type,
                                style: const TextStyle(color: Colors.white),
                              ),
                            );
                          }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedDocument = value!;
                          selectedCertificateType = null;
                        });
                      },
                      dropdownColor: Colors.grey[850],
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Colors.white24,
                        border: OutlineInputBorder(),
                      ),
                    ),

                    if (selectedDocument == 'Certificate') ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Select Certificate Type:',
                        style: TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedCertificateType,
                        items: ['Towage', 'Seafastening', 'Loadout'].map((
                          type,
                        ) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(
                              type,
                              style: const TextStyle(color: Colors.white),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => selectedCertificateType = value);
                        },
                        dropdownColor: Colors.grey[850],
                        decoration: const InputDecoration(
                          filled: true,
                          fillColor: Colors.white24,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedDocument == 'Certificate') {
                  if (selectedCertificateType == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Please select certificate type"),
                      ),
                    );
                    return;
                  }

                  Navigator.pop(context); // Close the dialog

                  if (selectedCertificateType == 'Towage') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TowageCertificateScreen(),
                      ),
                    );
                  } else if (selectedCertificateType == 'Seafastening') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SeafasteningCertificateScreen(),
                      ),
                    );
                  } else if (selectedCertificateType == 'Loadout') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LoadoutCertificateScreen(),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "Form for $selectedCertificateType is not implemented yet.",
                        ),
                      ),
                    );
                  }
                } else if (selectedDocument != '-- Select Document Type --') {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Selected Document: $selectedDocument"),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Please select a document type"),
                    ),
                  );
                }
              },
              child: const Text('Proceed'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileSection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.person),
              label: const Text("View Profile"),
              onPressed: () {
                final userId =
                    int.tryParse(widget.user['userId'].toString()) ?? 0;
                print("🔍 UserId = $userId");

                if (userId == 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("User ID is missing")),
                  );
                  return;
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen(userId: userId),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.lock),
              label: const Text("Change Password"),
              onPressed: () {
                final userId =
                    int.tryParse(widget.user['userId'].toString()) ?? 0;

                print("📍 Navigating with userId = $userId");

                if (userId == 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("User ID is missing")),
                  );
                  return;
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChangePasswordScreen(userId: userId),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = context.watch<ThemeNotifier>();
    final colors = themeNotifier.colors;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        title: const Text(
          'Survey Dashboard',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                tooltip: 'Notifications',
                icon: const Icon(Icons.notifications_outlined),
                onPressed: _showNotifications,
              ),
              if (_unreadNotificationCount > 0)
                Positioned(
                  right: 5,
                  top: 5,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 17),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _unreadNotificationCount > 99
                          ? '99+'
                          : '$_unreadNotificationCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            tooltip: themeNotifier.isDarkMode ? 'Light mode' : 'Dark mode',
            icon: Icon(
              themeNotifier.isDarkMode
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
            ),
            onPressed: themeNotifier.toggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.cloud_download),
            tooltip: 'Sync from Server',
            onPressed: () async {
              // Check internet before syncing
              final hasInternet = await checkInternetConnection();
              if (hasInternet) {
                await syncCertificates(context); // Your existing sync logic
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Data synced successfully ✅"),
                    duration: Duration(seconds: 2),
                  ),
                );
              } else {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("No internet connection ❌"),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            },
          ),
        ],
      ),

      body: _pages == null
          ? const Center(child: CircularProgressIndicator())
          : _buildCurrentPage(),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: colors.bgCard,
        elevation: 12,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: colors.primary,
        unselectedItemColor: colors.textSecond,
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Certificates',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
