import 'package:Auras/ThemeNotifier.dart';
import 'package:Auras/model/TotalCertificateCountDto.dart';
import 'package:Auras/screen/screen/Loadout_certificate_screen.dart';
import 'package:Auras/screen/screen/PendingApprovalsScreen.dart';
import 'package:Auras/screen/screen/Seafastening_certificate_screen.dart';
import 'package:Auras/screen/screen/TaskManager_screen.dart';
import 'package:Auras/screen/screen/Towage_certificate_screen.dart';
import 'package:Auras/screen/screen/changepassword_screen.dart'
    show ChangePasswordScreen;
import 'package:Auras/screen/screen/pdf_viewer_screen.dart';
import 'package:Auras/screen/screen/profile_screen.dart';
import 'package:Auras/screen/screen/survey_job_list_screen.dart';
import 'package:Auras/screen/screen/user_manager_screen.dart';
import 'package:Auras/screen/screen/vessel_master_screen.dart';

import 'package:Auras/service/api_service.dart';
import 'package:Auras/service/sync_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SurveyDashboardStats {
  final int totalSurveyJobs;
  final int ihmSurveyJobs;
  final int exSurveyJobs;
  final int submittedJobs;
  final int approvedJobs;
  final int closedJobs;

  const SurveyDashboardStats({
    this.totalSurveyJobs = 0,
    this.ihmSurveyJobs = 0,
    this.exSurveyJobs = 0,
    this.submittedJobs = 0,
    this.approvedJobs = 0,
    this.closedJobs = 0,
  });
}

class AdminDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const AdminDashboardScreen({required this.user, super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  SurveyDashboardStats surveyStats = const SurveyDashboardStats();

  String get _role => widget.user['role']?.toString().toLowerCase() ?? '';

  bool get isSurveyor => _role == 'surveyor';

  bool get isAdminOrManager => _role == 'admin' || _role == 'manager';

  String get _displayName {
    final candidates = [
      widget.user['fullName'],
      widget.user['name'],
      widget.user['username'],
      widget.user['email'],
    ];
    for (final value in candidates) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return isSurveyor ? 'Surveyor' : 'Administrator';
  }

  int _currentIndex = 0;
  List<Widget>? _pages;

  CertificateReport? report;
  bool isLoading = true;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchCertificateReport();
    _fetchPendingCount();
  }

  Future<void> _fetchPendingCount() async {
    try {
      final users = await ApiService.fetchPendingUsers();
      if (!mounted) return;
      setState(() {
        _pendingCount = users.length;
      });
    } catch (e) {
      print("❌ Failed to fetch pending users: $e");
    }
  }

  Future<void> _fetchCertificateReport() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      final userId = int.tryParse(widget.user['userId'].toString()) ?? 0;
      final result = isSurveyor
          ? CertificateReport(
              totalCertificates: 0,
              towageCount: 0,
              seaFasteningCount: 0,
              loadoutCount: 0,
            )
          : await ApiService.fetchCertificateReport();

      final ihmJobs = await ApiService.fetchSurveyJobsByType(
        surveyType: 'IHM Survey',
        isAdmin: !isSurveyor,
        userId: userId,
      );

      final exJobs = await ApiService.fetchSurveyJobsByType(
        surveyType: 'Ex-Survey',
        isAdmin: !isSurveyor,
        userId: userId,
      );

      final allSurveyJobs = [...ihmJobs, ...exJobs];

      if (!isSurveyor) {
        await prefs.setInt('totalCertificates', result.totalCertificates);
        await prefs.setInt('towageCount', result.towageCount);
        await prefs.setInt('seaFasteningCount', result.seaFasteningCount);
        await prefs.setInt('loadoutCount', result.loadoutCount);
      }

      if (!mounted) return;
      setState(() {
        report = result;
        surveyStats = SurveyDashboardStats(
          totalSurveyJobs: allSurveyJobs.length,
          ihmSurveyJobs: ihmJobs.length,
          exSurveyJobs: exJobs.length,
          submittedJobs: allSurveyJobs
              .where((x) => x.status == 'Submitted')
              .length,
          approvedJobs: allSurveyJobs
              .where((x) => x.status == 'Approved')
              .length,
          closedJobs: allSurveyJobs.where((x) => x.status == 'Closed').length,
        );
        isLoading = false;
        _pages = const [];
      });
    } catch (e) {
      final total = isSurveyor ? 0 : prefs.getInt('totalCertificates') ?? 0;
      final towage = isSurveyor ? 0 : prefs.getInt('towageCount') ?? 0;
      final seaFastening = isSurveyor
          ? 0
          : prefs.getInt('seaFasteningCount') ?? 0;
      final loadout = isSurveyor ? 0 : prefs.getInt('loadoutCount') ?? 0;

      if (!mounted) return;
      setState(() {
        report = CertificateReport(
          totalCertificates: total,
          towageCount: towage,
          seaFasteningCount: seaFastening,
          loadoutCount: loadout,
        );
        surveyStats = const SurveyDashboardStats();
        isLoading = false;
        _pages = const [];
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Offline: last saved data")));
    }
  }

  Widget _buildCurrentPage() {
    if (_currentIndex == 0) return _buildHomePage();
    return _buildProfileSection();
  }

  Widget _buildHomePage() {
    final themeNotifier = context.watch<ThemeNotifier>();
    final colors = themeNotifier.colors;

    if (isLoading) return const Center(child: CircularProgressIndicator());
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
        await SyncService.syncAllOfflineData();
        await SyncService.syncFromServerToLocal();
        await _fetchCertificateReport();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCommandHeader(themeNotifier.isDarkMode),
            const SizedBox(height: 24),
            // ─── 3 HORIZONTAL QUICK-ACTION CARDS ───────────────────────────
            Row(
              children: [
                // Card 1: Certificates (Loadout / Towage / Seafastening)
                if (!isSurveyor)
                  _buildTopActionCard(
                    icon: Icons.verified_rounded,
                    label: 'Certificates',
                    sublabel: 'Loadout · Towage\n· Seafastening',
                    gradient: themeNotifier.isDarkMode
                        ? const [Color(0xFF0D3024), Color(0xFF071A13)]
                        : const [Color(0xFF11998E), Color(0xFF2ECC71)],
                    iconColor: const Color(0xFF6FFFD4),
                    onTap: () => _showCertificateDialog(context),
                    isLast: false,
                  ),
                // Card 2: IHM Survey
                _buildTopActionCard(
                  icon: Icons.inventory_2_rounded,
                  label: 'IHM Survey',
                  sublabel: 'Inventory of\nHazardous Materials',
                  gradient: themeNotifier.isDarkMode
                      ? const [Color(0xFF0D1E3A), Color(0xFF071228)]
                      : const [Color(0xFF4158D0), Color(0xFF2575FC)],
                  iconColor: const Color(0xFF79B8FF),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const SurveyJobListScreen(surveyType: 'IHM Survey'),
                    ),
                  ),
                  isLast: false,
                ),
                // Card 3: Ex-Survey
                _buildTopActionCard(
                  icon: Icons.electrical_services_rounded,
                  label: 'Ex-Survey',
                  sublabel: 'Explosion-proof\nEquipment Survey',
                  gradient: themeNotifier.isDarkMode
                      ? const [Color(0xFF3A0D0D), Color(0xFF220707)]
                      : const [Color(0xFFFF416C), Color(0xFFFF6B35)],
                  iconColor: const Color(0xFFFFB3B3),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const SurveyJobListScreen(surveyType: 'Ex-Survey'),
                    ),
                  ),
                  isLast: true,
                ),
              ],
            ),

            // ───────────────────────────────────────────────────────────────
            if (!isSurveyor) ...[
              const SizedBox(height: 22),
              Text(
                'Certificate Summary',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildStatCard(
                    "Certificates",
                    report!.totalCertificates,
                    Icons.verified,
                    Colors.orange,
                  ),
                  _buildStatCard(
                    "Towage",
                    report!.towageCount,
                    Icons.directions_boat,
                    Colors.blue,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildStatCard(
                    "Sea Fastening",
                    report!.seaFasteningCount,
                    Icons.anchor,
                    Colors.green,
                  ),
                  _buildStatCard(
                    "Loadout",
                    report!.loadoutCount,
                    Icons.local_shipping,
                    Colors.purple,
                  ),
                ],
              ),
            ],

            const SizedBox(height: 22),

            Text(
              'Survey Summary',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                _buildStatCard(
                  "Survey Jobs",
                  surveyStats.totalSurveyJobs,
                  Icons.assignment_turned_in,
                  Colors.teal,
                ),
                _buildStatCard(
                  "IHM Survey",
                  surveyStats.ihmSurveyJobs,
                  Icons.inventory_2,
                  Colors.indigo,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStatCard(
                  "Ex-Survey",
                  surveyStats.exSurveyJobs,
                  Icons.electrical_services,
                  Colors.deepOrange,
                ),
                _buildStatCard(
                  "Submitted",
                  surveyStats.submittedJobs,
                  Icons.cloud_done,
                  Colors.cyan,
                ),
              ],
            ),

            const SizedBox(height: 24),

            Text(
              'Quick Actions',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),

            _buildActionTile(
              icon: Icons.inventory_2,
              title: 'IHM Survey Jobs',
              subtitle: 'Open all IHM survey jobs',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const SurveyJobListScreen(surveyType: 'IHM Survey'),
                  ),
                );
              },
            ),

            _buildActionTile(
              icon: Icons.electrical_services,
              title: 'Ex-Survey Jobs',
              subtitle: 'Open all Ex-Survey jobs',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const SurveyJobListScreen(surveyType: 'Ex-Survey'),
                  ),
                );
              },
            ),
            if (!isSurveyor) ...[
              _buildActionTile(
                icon: Icons.directions_boat,
                title: 'Vessel Master',
                subtitle: 'Create and manage vessel information',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const VesselMasterScreen(),
                    ),
                  );
                },
              ),

              _buildActionTile(
                icon: Icons.fact_check,
                title: 'Task Manager',
                subtitle: 'Manage tasks and assignments',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TaskManagerScreen(),
                    ),
                  );
                },
              ),

              _buildActionTile(
                icon: Icons.group,
                title: 'User Manager',
                subtitle: 'Manage users and approvals',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const UserManagerScreen(),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── NEW: Top 3-card horizontal section ──────────────────────────────────

  Widget _buildCommandHeader(bool isDark) {
    final userName = _displayName;

    return Container(
      constraints: const BoxConstraints(minHeight: 178),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF15385E), Color(0xFF09182D)]
              : const [Color(0xFF174B82), Color(0xFF2875BA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF174B82).withOpacity(0.35),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(right: -48, top: -58, child: _buildDepthCircle(180)),
            Positioned(right: 95, bottom: -76, child: _buildDepthCircle(135)),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'MARINE OPERATIONS',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.65),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.8,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          'Welcome, $userName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Text(
                        //   'Everything is organized and ready for review.',
                        //   style: TextStyle(
                        //     color: Colors.white.withOpacity(0.76),
                        //     fontSize: 12.5,
                        //   ),
                        // ),
                        const SizedBox(height: 17),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.11),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.16),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.circle,
                                color: Color(0xFF55E6A5),
                                size: 8,
                              ),
                              SizedBox(width: 7),
                              Text(
                                'SYSTEM ONLINE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.7,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.13),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.23)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 18,
                          offset: const Offset(0, 9),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      color: Colors.white,
                      size: 35,
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

  Widget _buildDepthCircle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.045),
        border: Border.all(color: Colors.white.withOpacity(0.06), width: 18),
      ),
    );
  }

  Widget _buildTopActionCard({
    required IconData icon,
    required String label,
    required String sublabel,
    required List<Color> gradient,
    required Color iconColor,
    required VoidCallback onTap,
    required bool isLast,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: EdgeInsets.only(right: isLast ? 0 : 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
            boxShadow: [
              BoxShadow(
                color: gradient.first.withOpacity(0.38),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.12),
                blurRadius: 1,
                offset: const Offset(0, -1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                sublabel,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.60),
                  fontSize: 10,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    'Open',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white.withOpacity(0.85),
                    size: 12,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Certificate dialog (formerly part of _showCreateDialog) ─────────────

  void _showCertificateDialog(BuildContext context) {
    String selectedCertificateType = '-- select certification type --';
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2F2F2F),
          title: const Text(
            'Select Certificate Type',
            style: TextStyle(color: Colors.white),
          ),
          content: StatefulBuilder(
            builder: (context, setState) {
              return DropdownButtonFormField<String>(
                value: selectedCertificateType,
                items:
                    [
                      '-- select certification type --',
                      'Towage',
                      'Seafastening',
                      'Loadout',
                    ].map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(
                          type,
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }).toList(),
                onChanged: (value) =>
                    setState(() => selectedCertificateType = value!),
                dropdownColor: Colors.grey[850],
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: Colors.white24,
                  border: OutlineInputBorder(),
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
                if (selectedCertificateType ==
                    '-- select certification type --') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Please select certificate type"),
                    ),
                  );
                  return;
                }
                Navigator.pop(context);
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
                }
              },
              child: const Text('Proceed'),
            ),
          ],
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────

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

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = context.watch<ThemeNotifier>();
    final colors = theme.colors;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: colors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(theme.isDarkMode ? 0.16 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: colors.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: colors.primary, size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(subtitle, style: TextStyle(color: colors.textSecond)),
        trailing: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: colors.bgCardAlt,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.chevron_right, color: colors.textSecond, size: 20),
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildCertificatePage() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton.icon(
            onPressed: () => _showCertificateDialog(context),
            icon: const Icon(Icons.add),
            label: const Text("Create Certificate/Survey"),
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

  // kept for backward compat (called from nowhere now, but safe to keep)
  void _showCreateDialog(BuildContext context) =>
      _showCertificateDialog(context);

  Widget _buildProfileSection() {
    final colors = context.watch<ThemeNotifier>().colors;
    final userName =
        widget.user['username']?.toString() ??
        widget.user['name']?.toString() ??
        'AURAS User';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colors.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.person_rounded, color: colors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _role.isEmpty ? 'Signed in user' : _role.toUpperCase(),
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
        const SizedBox(height: 18),
        _buildActionTile(
          icon: Icons.badge_rounded,
          title: "View Profile",
          subtitle: "Open account and user information",
          onTap: () {
            final userId = int.tryParse(widget.user['userId'].toString()) ?? 0;
            if (userId == 0) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text("User ID missing")));
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId)),
            );
          },
        ),
        _buildActionTile(
          icon: Icons.lock_rounded,
          title: "Change Password",
          subtitle: "Update your login password",
          onTap: () {
            final userId = int.tryParse(widget.user['userId'].toString()) ?? 0;
            if (userId == 0) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text("User ID missing")));
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChangePasswordScreen(userId: userId),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = context.watch<ThemeNotifier>();
    final colors = themeNotifier.colors;
    final mainColor = colors.primary;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        toolbarHeight: 68,
        title: Text(
          isSurveyor ? "Survey Dashboard" : "Admin Dashboard",
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                mainColor,
                Color.lerp(mainColor, const Color(0xFF12345B), 0.55)!,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: mainColor.withOpacity(0.25),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: themeNotifier.isDarkMode ? 'Light mode' : 'Dark mode',
            icon: Icon(
              themeNotifier.isDarkMode
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
            ),
            onPressed: themeNotifier.toggleTheme,
          ),
          if (!isSurveyor)
            SizedBox(
              width: 48,
              child: Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PendingApprovalsScreen(),
                        ),
                      );
                      if (mounted) _fetchPendingCount();
                    },
                  ),
                  if (_pendingCount > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          '$_pendingCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
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
        elevation: 18,
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        selectedItemColor: mainColor,
        unselectedItemColor: colors.textSecond,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        onTap: (index) => setState(() => _currentIndex = index),
        items: isSurveyor
            ? const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard),
                  label: "Survey",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: "Profile",
                ),
              ]
            : const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard),
                  label: "Dashboard",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: "Profile",
                ),
              ],
      ),
    );
  }
}
