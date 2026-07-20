import 'package:Auras/ThemeNotifier.dart';
import 'package:Auras/model/PendingUser.dart';
import 'package:Auras/model/TotalCertificateCountDto.dart';
import 'package:Auras/model/survey_job.dart';
import 'package:Auras/model/vessel.dart';
import 'package:Auras/screen/screen/Loadout_certificate_screen.dart';
import 'package:Auras/screen/screen/PendingApprovalsScreen.dart';
import 'package:Auras/screen/screen/Seafastening_certificate_screen.dart';
import 'package:Auras/screen/screen/TaskManager_screen.dart';
import 'package:Auras/screen/screen/Towage_certificate_screen.dart';
import 'package:Auras/screen/screen/assigned_reports_screen.dart';
import 'package:Auras/screen/screen/changepassword_screen.dart'
    show ChangePasswordScreen;
import 'package:Auras/screen/screen/ihm_reports_screen.dart';
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
  final int approvedJobs;
  final int closedJobs;
  final int liveJobs;
  final int completedJobs;
  final int dueTodayJobs;
  final int ihmLiveJobs;
  final int exSurveyLiveJobs;
  final int exSurveyReports;

  const SurveyDashboardStats({
    this.totalSurveyJobs = 0,
    this.ihmSurveyJobs = 0,
    this.exSurveyJobs = 0,
    this.approvedJobs = 0,
    this.closedJobs = 0,
    this.liveJobs = 0,
    this.completedJobs = 0,
    this.dueTodayJobs = 0,
    this.ihmLiveJobs = 0,
    this.exSurveyLiveJobs = 0,
    this.exSurveyReports = 0,
  });
}

enum _AurasTone { green, greenDark, blue, violet, amber, coral, soon }

class AdminDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const AdminDashboardScreen({required this.user, super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  SurveyDashboardStats surveyStats = const SurveyDashboardStats();

  String get _role => widget.user['role']?.toString().toLowerCase() ?? '';

  String get _projectName =>
      widget.user['projectName']?.toString().trim().toLowerCase() ?? '';

  bool get _isAdmin =>
      _role == 'admin' ||
      _role == 'global admin' ||
      _role == 'globaladmin' ||
      _role == 'administrator';

  bool get _isManager => _role == 'manager';

  bool get _hasAllProjectAccess =>
      _isAdmin || _projectName.contains('all');

  bool get _hasAurasAccess =>
      _hasAllProjectAccess || _projectName.contains('auras') || _hasManagedProject('auras');

  bool get _hasIhmAccess =>
      _hasAllProjectAccess || _projectName.contains('ihm') || _hasManagedProject('ihm');

  bool get _hasExSurveyAccess =>
      _hasAllProjectAccess || _projectName.contains('ex') || _hasManagedProject('ex');

  bool get isSurveyor => _role == 'surveyor';

  bool get isAdminOrManager => _isAdmin || _isManager;

  bool _hasManagedProject(String needle) {
    return _manageableProjects.any((project) {
      final text = '${project.name} ${project.code ?? ''}'.toLowerCase();
      return text.contains(needle);
    });
  }

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
    if (isSurveyor) return 'Surveyor';
    if (_isManager) return 'Manager';
    return 'Administrator';
  }

  String get _dashboardTitle {
    if (isSurveyor) return 'Survey Dashboard';
    return _isAdmin ? 'Admin Dashboard' : 'Manager Dashboard';
  }

  String get _profileTitle {
    if (isSurveyor) return 'Surveyor';
    return _isAdmin ? 'Administrator' : 'Manager';
  }

  bool _isIhmUser(dynamic user) {
    final text = _userScopeText(user);
    return text.contains('ihm');
  }

  bool _isExSurveyUser(dynamic user) {
    final text = _userScopeText(user);
    return text.contains('ex');
  }

  String _userScopeText(dynamic user) {
    if (user is Map) {
      return [
        user['projectName'],
        user['ProjectName'],
        user['role'],
        user['Role'],
        user['roleName'],
        user['RoleName'],
      ].whereType<Object>().map((x) => x.toString().toLowerCase()).join(' ');
    }
    return user.toString().toLowerCase();
  }

  int _currentIndex = 0;
  List<Widget>? _pages;

  CertificateReport? report;
  bool isLoading = true;
  bool _isRefreshingDashboard = false;
  int _pendingCount = 0;
  int _totalUsers = 0;
  int _ihmUsersCount = 0;
  int _exSurveyUsersCount = 0;
  int _ihmReportsCount = 0;
  int _exSurveyReportsCount = 0;
  List<ProjectOption> _manageableProjects = [];
  List<Vessel> _dashboardVessels = [];
  List<PendingUser> _pendingUsers = [];

  @override
  void initState() {
    super.initState();
    _fetchCertificateReport();
    _fetchPendingCount();
  }

  Future<void> _refreshDashboard({bool syncOfflineData = false}) async {
    if (_isRefreshingDashboard) return;
    _isRefreshingDashboard = true;
    try {
      if (syncOfflineData) {
        await SyncService.syncAllOfflineData();
        await SyncService.syncFromServerToLocal();
      }
      await _fetchPendingCount();
      await _fetchCertificateReport();
    } finally {
      _isRefreshingDashboard = false;
    }
  }

  Future<void> _runManualSync() async {
    final snapshot = await SyncService.syncAllOfflineData(manual: true);
    if (!mounted) return;

    if (snapshot.state == 'synced' || snapshot.state == 'failed') {
      await _refreshDashboard();
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(snapshot.message ?? snapshot.label),
        action: snapshot.failedCount > 0
            ? SnackBarAction(
                label: 'Retry',
                onPressed: () => _runManualSync(),
              )
            : null,
      ),
    );
  }

  Future<void> _openDashboardPage(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) {
      await _refreshDashboard();
    }
  }

  Future<void> _fetchPendingCount() async {
    try {
      final users = await ApiService.fetchPendingUsers();
      if (!mounted) return;
      setState(() {
        _pendingUsers = users;
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

      var stats = const SurveyDashboardStats();

      if (isSurveyor) {
        final summary = await ApiService.fetchSurveyorDashboardSummary();
        var dueTodayJobs = summary['dueTodayJobs'] ?? 0;
        try {
          final assignedIhmJobs = await ApiService.fetchSurveyJobsByType(
            surveyType: 'IHM Survey',
            isAdmin: false,
            userId: userId,
          );
          dueTodayJobs = _countDueTodayJobs(assignedIhmJobs, userId);
        } catch (_) {
          dueTodayJobs = prefs.getInt('surveyorDashboardDueTodayJobs') ?? 0;
        }
        stats = SurveyDashboardStats(
          liveJobs: summary['liveJobs'] ?? 0,
          completedJobs: summary['completedJobs'] ?? 0,
          dueTodayJobs: dueTodayJobs,
          ihmLiveJobs: summary['liveJobs'] ?? 0,
        );
        await prefs.setInt('surveyorDashboardLiveJobs', stats.liveJobs);
        await prefs.setInt(
          'surveyorDashboardCompletedJobs',
          stats.completedJobs,
        );
        await prefs.setInt(
          'surveyorDashboardDueTodayJobs',
          stats.dueTodayJobs,
        );
      } else {
        try {
          _manageableProjects = await ApiService.fetchManageableProjects();
          await prefs.setString(
            'dashboardManageableProjects',
            _manageableProjects.map((project) => project.name).join('|'),
          );
        } catch (_) {
          final cachedProjects =
              prefs.getString('dashboardManageableProjects') ?? '';
          _manageableProjects = cachedProjects
              .split('|')
              .where((name) => name.trim().isNotEmpty)
              .map((name) => ProjectOption(id: 0, name: name.trim()))
              .toList();
        }

        final summary = await ApiService.fetchSurveySummary();
        final ihmJobs = await ApiService.fetchSurveyJobsByType(
          surveyType: 'IHM Survey',
          isAdmin: true,
          userId: userId,
        );

        final exJobs = await ApiService.fetchSurveyJobsByType(
          surveyType: 'Ex-Survey',
          isAdmin: true,
          userId: userId,
        );

        final allSurveyJobs = [...ihmJobs, ...exJobs];

        stats = SurveyDashboardStats(
          totalSurveyJobs: summary['totalSurveyJobs'] ?? allSurveyJobs.length,
          ihmSurveyJobs: summary['ihmSurveyJobs'] ?? ihmJobs.length,
          exSurveyJobs: summary['exSurveyJobs'] ?? exJobs.length,
          approvedJobs: summary['approvedJobs'] ?? 0,
          closedJobs: summary['closedJobs'] ?? 0,
          liveJobs: summary['liveJobs'] ?? 0,
          completedJobs: summary['completedJobs'] ?? 0,
          ihmLiveJobs: summary['ihmLiveJobs'] ?? summary['liveJobs'] ?? 0,
          exSurveyLiveJobs: summary['exSurveyLiveJobs'] ?? 0,
          exSurveyReports: summary['exSurveyReports'] ?? 0,
        );

        try {
          final vessels = await ApiService.fetchVessels();
          final uniqueVessels = <int, Vessel>{};
          for (final vessel in vessels) {
            uniqueVessels[vessel.id] = vessel;
          }
          _dashboardVessels = uniqueVessels.values.toList();
          await prefs.setInt('dashboardVesselsCount', _dashboardVessels.length);
        } catch (_) {
          _dashboardVessels = [];
        }

        try {
          final savedReports = await ApiService.fetchSavedReports();
          final ihmReportIds = <int>{};
          for (final report in savedReports) {
            final type = (report['reportType'] ?? report['ReportType'] ?? '')
                .toString()
                .toLowerCase();
            final id = int.tryParse(
              (report['id'] ?? report['Id'] ?? '').toString(),
            );
            if (type == 'ihm' && id != null && id > 0) {
              ihmReportIds.add(id);
            }
          }
          _ihmReportsCount = ihmReportIds.length;
          final exReportIds = <int>{};
          for (final report in savedReports) {
            final type = (report['reportType'] ?? report['ReportType'] ?? '')
                .toString()
                .toLowerCase();
            final id = int.tryParse(
              (report['id'] ?? report['Id'] ?? '').toString(),
            );
            if (type == 'exsurvey' && id != null && id > 0) {
              exReportIds.add(id);
            }
          }
          _exSurveyReportsCount = exReportIds.length;
          await prefs.setInt('dashboardIhmReportsCount', _ihmReportsCount);
          await prefs.setInt(
            'dashboardExSurveyReportsCount',
            _exSurveyReportsCount,
          );
        } catch (_) {
          _ihmReportsCount =
              prefs.getInt('dashboardIhmReportsCount') ?? _ihmReportsCount;
          _exSurveyReportsCount =
              prefs.getInt('dashboardExSurveyReportsCount') ??
              _exSurveyReportsCount;
        }

        try {
          final users = await ApiService.getAllUsers();
          _totalUsers = users.length;
          _ihmUsersCount = users.where(_isIhmUser).length;
          _exSurveyUsersCount = users.where(_isExSurveyUser).length;
          await prefs.setInt('dashboardTotalUsers', _totalUsers);
          await prefs.setInt('dashboardIhmUsers', _ihmUsersCount);
          await prefs.setInt('dashboardExUsers', _exSurveyUsersCount);
        } catch (_) {
          _totalUsers = prefs.getInt('dashboardTotalUsers') ?? _totalUsers;
          _ihmUsersCount = prefs.getInt('dashboardIhmUsers') ?? _ihmUsersCount;
          _exSurveyUsersCount =
              prefs.getInt('dashboardExUsers') ?? _exSurveyUsersCount;
        }
      }

      if (!isSurveyor) {
        await prefs.setInt('totalCertificates', result.totalCertificates);
        await prefs.setInt('towageCount', result.towageCount);
        await prefs.setInt('seaFasteningCount', result.seaFasteningCount);
        await prefs.setInt('loadoutCount', result.loadoutCount);
      }

      if (!mounted) return;
      setState(() {
        report = result;
        surveyStats = stats;
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
      final liveJobs = prefs.getInt('surveyorDashboardLiveJobs') ?? 0;
      final completedJobs =
          prefs.getInt('surveyorDashboardCompletedJobs') ?? 0;
      final dueTodayJobs =
          prefs.getInt('surveyorDashboardDueTodayJobs') ?? 0;
      final cachedVessels = prefs.getInt('dashboardVesselsCount') ?? 0;
      final cachedIhmReports = prefs.getInt('dashboardIhmReportsCount') ?? 0;
      final cachedExReports =
          prefs.getInt('dashboardExSurveyReportsCount') ?? 0;
      final cachedUsers = prefs.getInt('dashboardTotalUsers') ?? 0;
      final cachedIhmUsers = prefs.getInt('dashboardIhmUsers') ?? 0;
      final cachedExUsers = prefs.getInt('dashboardExUsers') ?? 0;

      if (!mounted) return;
      setState(() {
        report = CertificateReport(
          totalCertificates: total,
          towageCount: towage,
          seaFasteningCount: seaFastening,
          loadoutCount: loadout,
        );
        surveyStats = isSurveyor
            ? SurveyDashboardStats(
                liveJobs: liveJobs,
                completedJobs: completedJobs,
                dueTodayJobs: dueTodayJobs,
              )
            : const SurveyDashboardStats();
        if (!isSurveyor) {
          _totalUsers = cachedUsers;
          _ihmUsersCount = cachedIhmUsers;
          _exSurveyUsersCount = cachedExUsers;
          _ihmReportsCount = cachedIhmReports;
          _exSurveyReportsCount = cachedExReports;
          if (_dashboardVessels.isEmpty && cachedVessels > 0) {
            _dashboardVessels = List.generate(
              cachedVessels,
              (index) => Vessel(
                id: 0,
                vesselName: 'Cached vessel ${index + 1}',
                status: 'Available',
              ),
            );
          }
        }
        isLoading = false;
        _pages = const [];
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Offline: last saved data")));
    }
  }

  void _openLiveSurveyJobs() {
    _openDashboardPage(
      const SurveyJobListScreen(
        surveyType: 'IHM Survey',
        titleOverride: 'Live Jobs',
        ihmCompletionFilter: 'live',
      ),
    );
  }

  void _openCompletedSurveyJobs() {
    _openDashboardPage(
      const SurveyJobListScreen(
        surveyType: 'IHM Survey',
        titleOverride: 'Completed Survey Jobs',
        ihmCompletionFilter: 'completed',
      ),
    );
  }

  int _countDueTodayJobs(List<SurveyJob> jobs, int userId) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return jobs.where((job) {
      final endDate = job.endDate?.toLocal();
      if (endDate == null) return false;

      final dueDate = DateTime(endDate.year, endDate.month, endDate.day);
      if (dueDate != today) return false;

      final hasActiveAssignment = job.activeAssignments.any(
        (assignment) => assignment.surveyorUserId == userId,
      );
      if (!hasActiveAssignment) return false;

      return !_isSurveyJobFinished(job);
    }).length;
  }

  bool _isSurveyJobFinished(SurveyJob job) {
    final statusText = '${job.status} ${job.displayStatus}'.toLowerCase();
    return statusText.contains('completed') ||
        statusText.contains('closed') ||
        statusText.contains('reportgenerated') ||
        statusText.contains('report generated');
  }

  Widget _buildCurrentPage() {
    if (_currentIndex == 0) return _buildHomePage();
    if (isAdminOrManager && _currentIndex == 1) {
      return UserManagerScreen(currentUser: widget.user, embedded: true);
    }
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

    if (isSurveyor) {
      return _buildSurveyorDashboard(themeNotifier.isDarkMode);
    }

    return _buildAdminManagerDashboard();

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
            if (!isSurveyor)
              Row(
              children: [
                // Card 1: Certificates (Loadout / Towage / Seafastening)
                if (!isSurveyor && _hasAurasAccess)
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
                if (_hasIhmAccess)
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
                        builder: (_) => const SurveyJobListScreen(
                          surveyType: 'IHM Survey',
                        ),
                      ),
                    ),
                    isLast: false,
                  ),
                // Card 3: Ex-Survey
                if (_hasExSurveyAccess)
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
                        builder: (_) => const SurveyJobListScreen(
                          surveyType: 'Ex-Survey',
                        ),
                      ),
                    ),
                    isLast: true,
                  ),
              ],
            ),

            // ───────────────────────────────────────────────────────────────
            if (!isSurveyor && _hasAurasAccess) ...[
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

            if (isSurveyor) ...[
              Row(
                children: [
                  _buildStatCard(
                    "Live Jobs",
                    surveyStats.liveJobs,
                    Icons.work_history,
                    Colors.teal,
                    onTap: _openLiveSurveyJobs,
                  ),
                  _buildStatCard(
                    "Completed Survey Jobs",
                    surveyStats.completedJobs,
                    Icons.verified,
                    Colors.green,
                    onTap: _openCompletedSurveyJobs,
                  ),
                ],
              ),
            ] else ...[
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

              if (_hasIhmAccess)
                _buildActionTile(
                  icon: Icons.inventory_2,
                  title: 'IHM Survey Jobs',
                  subtitle: 'Open all IHM survey jobs',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SurveyJobListScreen(
                          surveyType: 'IHM Survey',
                        ),
                      ),
                    );
                  },
                ),

              if (_hasExSurveyAccess)
                _buildActionTile(
                  icon: Icons.electrical_services,
                  title: 'Ex-Survey Jobs',
                  subtitle: 'Open all Ex-Survey jobs',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SurveyJobListScreen(
                          surveyType: 'Ex-Survey',
                        ),
                      ),
                    );
                  },
                ),
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

              if (_hasAurasAccess) ...[
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
          ],
        ),
      ),
    );
  }

  // ─── NEW: Top 3-card horizontal section ──────────────────────────────────

  Widget _buildAdminManagerDashboard() {
    const bg = Color(0xFFF3F4F0);
    final canSeeIhm = _hasIhmAccess;
    final canSeeEx = _hasExSurveyAccess;
    final canSeeAuras = _hasAurasAccess;
    final canSeeUsers = _role != 'client';
    const canSeeVessels = true;
    final ihmJobs = canSeeIhm ? surveyStats.ihmSurveyJobs : 0;
    final liveIhmJobs = canSeeIhm ? surveyStats.ihmLiveJobs : 0;
    final exJobs = canSeeEx ? surveyStats.exSurveyJobs : 0;
    final liveExJobs = canSeeEx ? surveyStats.exSurveyLiveJobs : 0;
    final exReportsCount = canSeeEx
        ? (_exSurveyReportsCount > 0
              ? _exSurveyReportsCount
              : surveyStats.exSurveyReports)
        : 0;
    final attentionJobs = liveIhmJobs;
    final vesselCount = _dashboardVessels.length;

    return RefreshIndicator(
      onRefresh: () async {
        await _refreshDashboard(syncOfflineData: true);
      },
      child: Container(
        color: bg,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAurasTopProfile(),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final crossAxisCount = width >= 1120
                      ? 4
                      : width >= 700
                      ? 2
                      : 1;
                  final cards = <Widget>[
                    if (canSeeIhm)
                      _adminMetricCard(
                        tone: _AurasTone.blue,
                        icon: Icons.assignment_turned_in_rounded,
                        title: 'IHM Survey Jobs',
                        value: ihmJobs,
                        subtitle: 'IHM survey jobs',
                      ),
                    if (canSeeAuras)
                      _adminMetricCard(
                        tone: _AurasTone.green,
                        icon: Icons.verified_rounded,
                        title: 'Auras Certificates',
                        value: report?.totalCertificates ?? 0,
                        subtitle: '${report?.towageCount ?? 0} towage',
                      ),
                    if (canSeeUsers)
                      _adminMetricCard(
                        tone: _AurasTone.violet,
                        icon: Icons.groups_rounded,
                        title: 'Active Users',
                        value: _totalUsers,
                        subtitle:
                            '${_projectName.isEmpty ? 'All Projects' : _projectName} roles',
                      ),
                    if (canSeeUsers)
                      _adminMetricCard(
                        tone: _AurasTone.amber,
                        icon: Icons.warning_amber_rounded,
                        title: 'Attention',
                        value: attentionJobs,
                        subtitle: 'Assigned, not started',
                      ),
                    if (canSeeVessels)
                      _adminMetricCard(
                        tone: _AurasTone.green,
                        icon: Icons.directions_boat_filled_rounded,
                        title: 'Vessels',
                        value: vesselCount,
                        subtitle: 'Created vessels',
                      ),
                    if (canSeeEx)
                      _adminMetricCard(
                        tone: _AurasTone.blue,
                        icon: Icons.assignment_rounded,
                        title: 'EX-Survey Jobs',
                        value: exJobs,
                        subtitle: 'EX-Survey jobs',
                      ),
                    if (_isAdmin)
                      _adminMetricCard(
                        tone: _AurasTone.violet,
                        icon: Icons.groups_rounded,
                        title: 'IHM Users',
                        value: _ihmUsersCount,
                        subtitle: 'IHM roles',
                      ),
                    if (_isAdmin)
                      _adminMetricCard(
                        tone: _AurasTone.green,
                        icon: Icons.group_add_rounded,
                        title: 'EX-Survey Users',
                        value: _exSurveyUsersCount,
                        subtitle: 'EX-Survey roles',
                      ),
                  ];

                  return GridView.count(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: width >= 700 ? 2.25 : 2.7,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: cards,
                  );
                },
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final crossAxisCount = width >= 980
                      ? 3
                      : width >= 660
                      ? 2
                      : 1;
                  final appCards = <Widget>[
                    if (canSeeAuras)
                      _adminAppCard(
                        primary: true,
                        icon: Icons.shield_rounded,
                        iconTone: _AurasTone.greenDark,
                        badge: 'Active',
                        badgeTone: _AurasTone.green,
                        title: 'Auras SurveyApp',
                        description:
                            'Certificates Creation For Towage,Seafastening,and Loadout',
                        meta: [
                          '${report?.totalCertificates ?? 0} certificates',
                          '$_totalUsers users',
                        ],
                        actionLabel: 'Open workspace',
                        actionDark: true,
                        onTap: () => _showCertificateDialog(context),
                      ),
                    if (canSeeIhm)
                      _adminAppCard(
                        icon: Icons.work_rounded,
                        iconTone: _AurasTone.blue,
                        badge: 'Beta',
                        badgeTone: _AurasTone.violet,
                        title: 'IHM All Jobs',
                        description:
                            'View all IHM survey jobs and job details.',
                        meta: [
                          '$ihmJobs job${ihmJobs == 1 ? '' : 's'}',
                        ],
                        actionLabel: 'Open jobs',
                        onTap: () => _openDashboardPage(
                          const SurveyJobListScreen(
                            surveyType: 'IHM Survey',
                          ),
                        ),
                      ),
                    if (canSeeIhm)
                      _adminAppCard(
                        icon: Icons.description_rounded,
                        iconTone: _AurasTone.greenDark,
                        badge: 'Reports',
                        badgeTone: _AurasTone.green,
                        title: 'IHM Reports',
                        description: 'View saved IHM survey reports.',
                        meta: [
                          '$_ihmReportsCount report${_ihmReportsCount == 1 ? '' : 's'}',
                        ],
                        actionLabel: 'Open reports',
                        onTap: () => _openDashboardPage(
                          const IhmReportsScreen(),
                        ),
                      ),
                    if (canSeeIhm && !_isAdmin)
                      _adminAppCard(
                        icon: Icons.sync_rounded,
                        iconTone: _AurasTone.coral,
                        badge: 'Live',
                        badgeTone: _AurasTone.soon,
                        title: 'IHM Live Jobs',
                        description: 'Ongoing IHM jobs currently in progress.',
                        meta: [
                          '$liveIhmJobs ongoing job${liveIhmJobs == 1 ? '' : 's'}',
                        ],
                        actionLabel: 'Open live jobs',
                        onTap: () => _openDashboardPage(
                          const SurveyJobListScreen(
                            surveyType: 'IHM Survey',
                            titleOverride: 'Live Jobs',
                            ihmCompletionFilter: 'live',
                          ),
                        ),
                      ),
                    if (_isAdmin && (canSeeIhm || canSeeEx))
                      _adminLiveJobsCard(
                        ihmLiveJobs: liveIhmJobs,
                        exSurveyLiveJobs: liveExJobs,
                        canOpenIhm: canSeeIhm,
                        canOpenExSurvey: canSeeEx,
                      ),
                    if (canSeeEx)
                      _adminAppCard(
                        icon: Icons.assignment_rounded,
                        iconTone: _AurasTone.blue,
                        badge: 'EX-Survey',
                        badgeTone: _AurasTone.violet,
                        title: 'EX-Survey All Jobs',
                        description:
                            'View all accessible EX-Survey jobs and job details.',
                        meta: [
                          '$exJobs job${exJobs == 1 ? '' : 's'}',
                        ],
                        actionLabel: 'Open jobs',
                        onTap: () => _openDashboardPage(
                          const SurveyJobListScreen(
                            surveyType: 'Ex-Survey',
                          ),
                        ),
                      ),
                    if (canSeeEx)
                      _adminAppCard(
                        icon: Icons.description_rounded,
                        iconTone: _AurasTone.greenDark,
                        badge: 'Reports',
                        badgeTone: _AurasTone.green,
                        title: 'EX-Survey Reports',
                        description: 'View saved EX-Survey report documents.',
                        meta: [
                          '$exReportsCount report${exReportsCount == 1 ? '' : 's'}',
                        ],
                        actionLabel: 'Open reports',
                        onTap: () => _openDashboardPage(
                          const IhmReportsScreen(initialCategory: 'exsurvey'),
                        ),
                      ),
                    if (canSeeEx && !_isAdmin)
                      _adminAppCard(
                        icon: Icons.sync_rounded,
                        iconTone: _AurasTone.coral,
                        badge: 'Live',
                        badgeTone: _AurasTone.soon,
                        title: 'EX-Survey Live Jobs',
                        description:
                            'Ongoing EX-Survey jobs currently in progress.',
                        meta: [
                          '$liveExJobs ongoing job${liveExJobs == 1 ? '' : 's'}',
                        ],
                        actionLabel: 'Open live jobs',
                        onTap: () => _openDashboardPage(
                          const SurveyJobListScreen(
                            surveyType: 'Ex-Survey',
                            titleOverride: 'EX-Survey Live Jobs',
                            jobCompletionFilter: 'live',
                          ),
                        ),
                      ),
                  ];

                  return GridView.count(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: width >= 980
                        ? 1.55
                        : width >= 660
                        ? 1.45
                        : 1.32,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: appCards,
                  );
                },
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stack = constraints.maxWidth < 860;
                  if (stack) {
                    return Column(
                      children: [
                        if (canSeeVessels) _vesselPanel(),
                        if (canSeeVessels) const SizedBox(height: 16),
                        _recentActivityPanel(),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (canSeeVessels) Expanded(flex: 6, child: _vesselPanel()),
                      if (canSeeVessels) const SizedBox(width: 16),
                      Expanded(flex: 5, child: _recentActivityPanel()),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _toneColor(_AurasTone tone) {
    switch (tone) {
      case _AurasTone.green:
        return const Color(0xFF007F67);
      case _AurasTone.greenDark:
        return const Color(0xFF06231D);
      case _AurasTone.blue:
        return const Color(0xFF3B7BD6);
      case _AurasTone.violet:
        return const Color(0xFF4D4FB2);
      case _AurasTone.amber:
        return const Color(0xFFD88C21);
      case _AurasTone.coral:
        return const Color(0xFFE36D4E);
      case _AurasTone.soon:
        return const Color(0xFF5D625F);
    }
  }

  Color _toneSoft(_AurasTone tone) {
    switch (tone) {
      case _AurasTone.green:
      case _AurasTone.greenDark:
        return const Color(0xFFD8F1E9);
      case _AurasTone.blue:
        return const Color(0xFFE8F0FF);
      case _AurasTone.violet:
        return const Color(0xFFE9E9FB);
      case _AurasTone.amber:
        return const Color(0xFFFFF0D7);
      case _AurasTone.coral:
        return const Color(0xFFFFE8DF);
      case _AurasTone.soon:
        return const Color(0xFFEEEEEA);
    }
  }

  Widget _buildAurasTopProfile() {
    final email = widget.user['email']?.toString() ?? '';
    final initial = (_displayName.isNotEmpty ? _displayName[0] : 'A')
        .toUpperCase();

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF007F67),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.shield_rounded, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AURAS',
                style: TextStyle(
                  color: Color(0xFF06120F),
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              Text(
                _dashboardTitle,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF6F7C77),
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDEDFD8)),
          ),
          child: const Icon(Icons.notifications_none, size: 19),
        ),
        const SizedBox(width: 10),
        CircleAvatar(
          backgroundColor: const Color(0xFF007F67),
          child: Text(
            initial,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _profileTitle,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF06120F),
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
              Text(
                email,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF6F7C77),
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _adminMetricCard({
    required _AurasTone tone,
    required IconData icon,
    required String title,
    required int value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _aurasCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _toneSoft(tone),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: _toneColor(tone), size: 18),
          ),
          const Spacer(),
          Text(
            title.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF6F7C77),
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: .7,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '$value',
            style: const TextStyle(
              color: Color(0xFF06120F),
              fontSize: 29,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF6F7C77),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _adminAppCard({
    required IconData icon,
    required _AurasTone iconTone,
    required String badge,
    required _AurasTone badgeTone,
    required String title,
    required String description,
    required List<String> meta,
    required String actionLabel,
    VoidCallback? onTap,
    bool primary = false,
    bool muted = false,
    bool actionDark = false,
  }) {
    final actionEnabled = onTap != null;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _aurasCardDecoration(
        borderColor: primary ? const Color(0xFF007F67) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconTone == _AurasTone.greenDark
                      ? const Color(0xFF007F67)
                      : _toneSoft(iconTone),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  color: iconTone == _AurasTone.greenDark
                      ? Colors.white
                      : _toneColor(iconTone),
                  size: 21,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _toneSoft(badgeTone),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge.toUpperCase(),
                  style: TextStyle(
                    color: _toneColor(badgeTone),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF050F0D),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description.isEmpty ? ' ' : description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF233632),
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 14),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFDEDFD8))),
            ),
            child: Wrap(
              spacing: 18,
              runSpacing: 6,
              children: meta
                  .map(
                    (item) => Text(
                      item,
                      style: const TextStyle(
                        color: Color(0xFF6F7C77),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: ElevatedButton(
              onPressed: actionEnabled ? onTap : null,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: actionDark
                    ? const Color(0xFF06231D)
                    : const Color(0xFFE9E9FB),
                disabledBackgroundColor: const Color(0xFFEEEEEA),
                foregroundColor: actionDark
                    ? Colors.white
                    : const Color(0xFF4D4FB2),
                disabledForegroundColor: const Color(0xFF777D79),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    actionLabel,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  if (actionEnabled) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 17),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _adminLiveJobsCard({
    required int ihmLiveJobs,
    required int exSurveyLiveJobs,
    required bool canOpenIhm,
    required bool canOpenExSurvey,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _aurasCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _toneSoft(_AurasTone.coral),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Icons.sync_rounded,
                  color: _toneColor(_AurasTone.coral),
                  size: 21,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _toneSoft(_AurasTone.soon),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'LIVE',
                  style: TextStyle(
                    color: _toneColor(_AurasTone.soon),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Live Jobs',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Color(0xFF050F0D),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ongoing jobs currently in progress across active survey projects.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Color(0xFF233632),
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 14),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFDEDFD8))),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stack = constraints.maxWidth < 250;
                final summaries = <Widget>[
                  if (canOpenIhm)
                    _liveSummaryTile(
                      count: ihmLiveJobs,
                      label: 'IHM live jobs',
                    ),
                  if (canOpenExSurvey)
                    _liveSummaryTile(
                      count: exSurveyLiveJobs,
                      label: 'EX-Survey live jobs',
                    ),
                ];

                if (stack) {
                  return Column(
                    children: [
                      for (var i = 0; i < summaries.length; i++) ...[
                        if (i > 0) const SizedBox(height: 8),
                        summaries[i],
                      ],
                    ],
                  );
                }

                return Row(
                  children: [
                    for (var i = 0; i < summaries.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(child: summaries[i]),
                    ],
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (canOpenIhm)
                Expanded(
                  child: _liveJobsActionButton(
                    label: 'Open IHM',
                    onPressed: () => _openDashboardPage(
                      const SurveyJobListScreen(
                        surveyType: 'IHM Survey',
                        titleOverride: 'IHM Live Jobs',
                        ihmCompletionFilter: 'live',
                      ),
                    ),
                  ),
                ),
              if (canOpenIhm && canOpenExSurvey) const SizedBox(width: 8),
              if (canOpenExSurvey)
                Expanded(
                  child: _liveJobsActionButton(
                    label: 'Open EX',
                    onPressed: () => _openDashboardPage(
                      const SurveyJobListScreen(
                        surveyType: 'Ex-Survey',
                        titleOverride: 'EX-Survey Live Jobs',
                        jobCompletionFilter: 'live',
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _liveSummaryTile({
    required int count,
    required String label,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF8),
        border: Border.all(color: const Color(0xFFDEDFD8)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count.toString(),
            style: const TextStyle(
              color: Color(0xFF050F0D),
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF6F7C77),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _liveJobsActionButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 38,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: const Color(0xFFE9E9FB),
          foregroundColor: const Color(0xFF4D4FB2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, size: 17),
            ],
          ),
        ),
      ),
    );
  }

  Widget _vesselPanel() {
    final vessels = _dashboardVessels.take(4).toList();
    return _adminPanel(
      title: 'Vessel Master',
      actionLabel: 'All vessels',
      onAction: () => _openDashboardPage(
        const VesselMasterScreen(),
      ),
      child: vessels.isEmpty
          ? _adminEmptyState(Icons.directions_boat_rounded, 'No vessels available')
          : Column(children: vessels.map(_vesselRow).toList()),
    );
  }

  Widget _vesselRow(Vessel vessel) {
    final location = vessel.flag?.trim().isNotEmpty == true
        ? vessel.flag!.trim()
        : (vessel.portOfRegistry?.trim().isNotEmpty == true
              ? vessel.portOfRegistry!.trim()
              : 'Location unknown');
    final status = vessel.status.trim().isEmpty ? 'Available' : vessel.status;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFDEDFD8))),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F2EE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.directions_boat_filled_rounded,
              color: Color(0xFF5F6A65),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vessel.vesselName.trim().isEmpty
                      ? 'Unnamed vessel'
                      : vessel.vesselName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF06120F),
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF6F7C77),
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFD8F1E9),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              status,
              style: const TextStyle(
                color: Color(0xFF007F67),
                fontWeight: FontWeight.w900,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recentActivityPanel() {
    final activities = <Widget>[
      ..._pendingUsers.take(2).map(
            (user) => _activityItem(
              '${user.fullName} requested ${user.requestedRole} approval',
              user.email,
              _AurasTone.amber,
            ),
          ),
      if ((report?.totalCertificates ?? 0) > 0)
        _activityItem(
          'Auras certificate records available',
          '${report!.totalCertificates} certificates',
          _AurasTone.green,
        ),
      if (_dashboardVessels.isNotEmpty)
        _activityItem(
          '${_dashboardVessels.first.vesselName} added to Vessel Master',
          _dashboardVessels.first.flag ?? 'Vessel master',
          _AurasTone.green,
        ),
    ].take(5).toList();

    return _adminPanel(
      title: 'Recent activity',
      actionLabel: 'View all',
      onAction: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AssignedReportsScreen(user: widget.user),
        ),
      ),
      child: activities.isEmpty
          ? _adminEmptyState(Icons.schedule_rounded, 'No recent activity available')
          : Column(children: activities),
    );
  }

  Widget _activityItem(String title, String meta, _AurasTone tone) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFDEDFD8))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(
              color: _toneColor(tone),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF06120F),
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  meta,
                  style: const TextStyle(
                    color: Color(0xFF6F7C77),
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _adminPanel({
    required String title,
    required String actionLabel,
    required VoidCallback onAction,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _aurasCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF06120F),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton(
                onPressed: onAction,
                child: Row(
                  children: [
                    Text(actionLabel),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded, size: 16),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _adminEmptyState(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF9AA5A0), size: 30),
            const SizedBox(height: 8),
            Text(
              text,
              style: const TextStyle(
                color: Color(0xFF6F7C77),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _aurasCardDecoration({Color? borderColor}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: borderColor ?? const Color(0xFFDEDFD8)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF06120F).withOpacity(0.08),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
        BoxShadow(
          color: const Color(0xFF06120F).withOpacity(0.04),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ],
    );
  }

  Widget _buildSurveyorDashboard(bool isDark) {
    final liveJobs = surveyStats.liveJobs;
    final completedJobs = surveyStats.completedJobs;
    final dueTodayJobs = surveyStats.dueTodayJobs;
    final totalAssigned = liveJobs + completedJobs;
    final successRate = totalAssigned == 0
        ? 0
        : ((completedJobs / totalAssigned) * 100).round();

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
            _buildSurveyorWelcomeHeader(isDark),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final stackCards = constraints.maxWidth < 620;
                final liveCard = _buildLargeKpiCard(
                  title: 'IHM Live Jobs',
                  count: liveJobs,
                  subtitle: 'Assigned & In Progress',
                  icon: Icons.assignment_turned_in_rounded,
                  gradient: const [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                  onTap: _openLiveSurveyJobs,
                );
                final completedCard = _buildLargeKpiCard(
                  title: 'IHM Completed Jobs',
                  count: completedJobs,
                  subtitle: 'Successfully Completed',
                  icon: Icons.check_circle_rounded,
                  gradient: const [Color(0xFF16A34A), Color(0xFF15803D)],
                  onTap: _openCompletedSurveyJobs,
                );

                if (stackCards) {
                  return Column(
                    children: [
                      liveCard,
                      const SizedBox(height: 16),
                      completedCard,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: liveCard),
                    const SizedBox(width: 16),
                    Expanded(child: completedCard),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            _dashboardSectionTitle("Today's Overview"),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final crossAxisCount = width >= 720
                    ? 3
                    : width >= 430
                    ? 2
                    : 1;
                final cards = [
                  _buildSmallKpiCard(
                    icon: Icons.assignment_turned_in,
                    count: completedJobs,
                    title: 'Surveys Done',
                    subtitle: 'Completed jobs',
                    color: const Color(0xFF2563EB),
                  ),
                  _buildSmallKpiCard(
                    icon: Icons.schedule,
                    count: liveJobs,
                    title: 'Pending Jobs',
                    subtitle: 'Assigned unfinished jobs',
                    color: const Color(0xFFF59E0B),
                  ),
                  _buildSmallKpiCard(
                    icon: Icons.today,
                    count: dueTodayJobs,
                    title: 'Due Today',
                    subtitle: 'End date is today',
                    color: const Color(0xFF7C3AED),
                  ),
                ];

                return GridView.builder(
                  itemCount: cards.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisExtent: 148,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) => cards[index],
                );
              },
            ),
            const SizedBox(height: 24),
            _dashboardSectionTitle('Performance'),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final cards = [
                  _buildPerformanceCard(
                    title: 'Total Assigned',
                    value: '$totalAssigned',
                    subtitle: 'Live + completed jobs',
                    icon: Icons.work_rounded,
                    color: const Color(0xFF2563EB),
                  ),
                  _buildPerformanceCard(
                    title: 'Success Rate',
                    value: '$successRate%',
                    subtitle: 'Completed vs assigned',
                    icon: Icons.insights_rounded,
                    color: const Color(0xFF7C3AED),
                  ),
                ];

                if (constraints.maxWidth < 620) {
                  return Column(
                    children: cards
                        .map(
                          (card) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: card,
                          ),
                        )
                        .toList(),
                  );
                }

                return Row(
                  children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 12),
                    Expanded(child: cards[1]),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            _dashboardSectionTitle('Quick Actions'),
            const SizedBox(height: 12),
            _buildActionTile(
              icon: Icons.directions_boat,
              title: 'Vessel Master',
              subtitle: 'Open vessel registry',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const VesselMasterScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _dashboardSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF0F172A),
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _buildLargeKpiCard({
    required String title,
    required int count,
    required String subtitle,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: gradient.last.withOpacity(0.28),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.82),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmallKpiCard({
    required IconData icon,
    required int count,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                '$count',
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(height: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      height: 1.18,
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

  Widget _buildPerformanceCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSurveyorWelcomeHeader(bool isDark) {
    final userName = _displayName;

    return Container(
      constraints: const BoxConstraints(minHeight: 142),
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
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.72),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      userName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                        height: 1.08,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
                      Icons.account_circle_rounded,
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

  Widget _buildStatCard(
    String title,
    int count,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    final theme = context.watch<ThemeNotifier>();
    final colors = theme.colors;

    return Expanded(
      child: MouseRegion(
        cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
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
                  color: Colors.black.withOpacity(
                    theme.isDarkMode ? 0.18 : 0.06,
                  ),
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
                      if (onTap != null) ...[
                        const SizedBox(height: 5),
                        Text(
                          'Tap to view',
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(
                    Icons.chevron_right_rounded,
                    color: color.withOpacity(0.75),
                    size: 22,
                  ),
              ],
            ),
          ),
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

  Widget _buildAppBarSyncButton(SyncSnapshot snapshot) {
    final label = snapshot.pendingCount > 0 && !snapshot.isSyncing
        ? '${snapshot.label} (${snapshot.pendingCount})'
        : snapshot.label;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextButton.icon(
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white70,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: const Size(0, 40),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: snapshot.isSyncing ? null : _runManualSync,
        onLongPress: () => _showSyncDetails(snapshot),
        icon: snapshot.isSyncing
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(_syncIcon(snapshot), size: 19),
        label: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  IconData _syncIcon(SyncSnapshot snapshot) {
    if (snapshot.state == 'offline') return Icons.cloud_off_rounded;
    if (snapshot.state == 'failed') return Icons.sync_problem_rounded;
    if (snapshot.state == 'synced') return Icons.cloud_done_rounded;
    return Icons.sync_rounded;
  }

  void _showSyncDetails(SyncSnapshot snapshot) {
    final lastSynced = snapshot.lastSyncedAt == null
        ? 'Never'
        : _formatSyncDateTime(snapshot.lastSyncedAt!);

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sync Status',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                _syncDetailRow('Status', snapshot.label),
                _syncDetailRow('Last synced', lastSynced),
                _syncDetailRow(
                  'Pending items',
                  snapshot.pendingCount.toString(),
                ),
                _syncDetailRow('Failed items', snapshot.failedCount.toString()),
                _syncDetailRow(
                  'Downloaded jobs',
                  snapshot.downloadedJobCount.toString(),
                ),
                _syncDetailRow(
                  'Uploaded items',
                  snapshot.uploadedItemCount.toString(),
                ),
                if ((snapshot.message ?? '').isNotEmpty)
                  _syncDetailRow('Message', snapshot.message!),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: snapshot.isSyncing
                            ? null
                            : () {
                                Navigator.pop(context);
                                _runManualSync();
                              },
                        icon: const Icon(Icons.sync_rounded),
                        label: Text(
                          snapshot.failedCount > 0 ? 'Retry' : 'Sync now',
                        ),
                      ),
                    ),
                    if (snapshot.isSyncing) ...[
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: SyncService.requestCancel,
                        child: const Text('Cancel'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _syncDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatSyncDateTime(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
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
          _dashboardTitle,
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
          ValueListenableBuilder<SyncSnapshot>(
            valueListenable: SyncService.syncStatus,
            builder: (context, snapshot, _) {
              return _buildAppBarSyncButton(snapshot);
            },
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
              try {
                await SyncService.logoutAndClearUserData();
              } catch (error) {
                debugPrint('Logout failed during cleanup: $error');
              }
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
            : isAdminOrManager
                ? const [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.dashboard),
                      label: "Dashboard",
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.manage_accounts),
                      label: "User Management",
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
