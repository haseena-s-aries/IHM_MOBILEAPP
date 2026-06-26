import 'package:Auras/model/survey_job.dart';
import 'package:Auras/service/api_service.dart';
import 'package:Auras/screen/screen/ihm_conflict_review_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Color Palette ────────────────────────────────────────────────────────────
class _AppColors {
  static const Color navy = Color(0xFF0B1D33);
  static const Color deepBlue = Color(0xFF132B4A);
  static const Color slate = Color(0xFF1E3A5F);
  static const Color ocean = Color(0xFF1976D2);
  static const Color teal = Color(0xFF00897B);
  static const Color lightTeal = Color(0xFF4DB6AC);
  static const Color surface = Color(0xFFF4F6FA);
  static const Color divider = Color(0xFFE0E4EC);
  static const Color textPrimary = Color(0xFF1A2333);
  static const Color textSecondary = Color(0xFF607080);
  static const Color textMuted = Color(0xFF90A0B0);
  static const Color success = Color(0xFF43A047);
  static const Color amber = Color(0xFFFFA726);
  static const Color red = Color(0xFFEF5350);
  static const Color purple = Color(0xFF7B1FA2);
}

class SurveyJobDetailsScreen extends StatelessWidget {
  final SurveyJob job;
  final String surveyType;

  const SurveyJobDetailsScreen({
    super.key,
    required this.job,
    required this.surveyType,
  });

  Color _statusColor(String status) {
    switch (status) {
      case 'Draft':
        return _AppColors.textMuted;
      case 'Assigned':
        return _AppColors.ocean;
      case 'InProgress':
        return _AppColors.amber;
      case 'Submitted':
        return _AppColors.purple;
      case 'Approved':
        return _AppColors.success;
      case 'ReportGenerated':
        return _AppColors.teal;
      case 'Closed':
        return _AppColors.textSecondary;
      case 'QcReturned':
        return _AppColors.red;
      default:
        return _AppColors.textMuted;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Draft':
        return Icons.edit_note;
      case 'Assigned':
        return Icons.person_pin_circle;
      case 'InProgress':
        return Icons.pending_actions;
      case 'Submitted':
        return Icons.upload_file;
      case 'Approved':
        return Icons.verified;
      case 'ReportGenerated':
        return Icons.summarize;
      case 'Closed':
        return Icons.lock_outline;
      case 'QcReturned':
        return Icons.replay_circle_filled;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIhm = surveyType == 'IHM Survey';
    final statusColor = _statusColor(job.status);

    return Scaffold(
      backgroundColor: _AppColors.surface,
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              left: 24,
              right: 24,
              bottom: 20,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _AppColors.navy,
                  _AppColors.deepBlue,
                  _AppColors.slate,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x30000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row
                Row(
                  children: [
                    Material(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => Navigator.pop(context),
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white70,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isIhm ? Icons.assignment_outlined : Icons.engineering,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job.jobNumber,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            surveyType,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Status chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: statusColor.withOpacity(0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _statusIcon(job.status),
                            size: 13,
                            color: statusColor,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            job.status,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Quick info pills
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    if (job.vesselName != null && job.vesselName!.isNotEmpty)
                      _headerPill(
                        Icons.directions_boat_filled,
                        job.vesselName!,
                      ),
                    if (job.imoNumber != null && job.imoNumber!.isNotEmpty)
                      _headerPill(Icons.tag, 'IMO ${job.imoNumber!}'),
                    if (job.clientName != null && job.clientName!.isNotEmpty)
                      _headerPill(Icons.business_outlined, job.clientName!),
                  ],
                ),
              ],
            ),
          ),

          // ── Body ────────────────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              children: [
                // ── Job Info Card ──
                _sectionTitle('JOB DETAILS'),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _AppColors.divider.withOpacity(0.6),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _infoRow(Icons.tag, 'Job Number', job.jobNumber),
                      _infoRow(
                        Icons.category_outlined,
                        'Survey Type',
                        surveyType,
                      ),
                      _infoRow(
                        Icons.business_outlined,
                        'Client',
                        job.clientName,
                      ),
                      _infoRow(
                        Icons.folder_outlined,
                        'Project',
                        job.projectName,
                      ),
                      _infoRow(
                        Icons.directions_boat_filled,
                        isIhm ? 'Vessel' : 'Vessel / Site',
                        job.vesselName,
                      ),
                      if (isIhm)
                        _infoRow(Icons.numbers, 'IMO Number', job.imoNumber),
                      _infoRow(
                        Icons.location_on_outlined,
                        'Site',
                        job.siteName,
                        isLast: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Modules ──
                _sectionTitle(isIhm ? 'IHM MODULES' : 'EX SURVEY MODULES'),
                const SizedBox(height: 10),

                if (isIhm) ...[
                  _moduleTile(
                    context: context,
                    icon: Icons.rule_folder_outlined,
                    iconColor: _AppColors.red,
                    title: 'Conflict Review',
                    subtitle:
                        'Compare surveyor submissions and approve one version',
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();
                      final userId = prefs.getInt('userId') ?? 0;
                      final role =
                          prefs.getString('userRole')?.toLowerCase() ?? '';
                      final canReview =
                          role == 'admin' ||
                          role == 'manager' ||
                          job.primarySurveyorUserId == userId;
                      if (!context.mounted) return;
                      if (!canReview) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Only the primary surveyor or admin can review conflicts.',
                            ),
                          ),
                        );
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              IhmConflictReviewScreen(jobId: job.id),
                        ),
                      );
                    },
                  ),
                  _moduleTile(
                    context: context,
                    icon: Icons.checklist_rtl,
                    iconColor: _AppColors.ocean,
                    title: 'Checklist',
                    subtitle: 'View IHM checklist items',
                    onTap: () => _showComingSoon(context, 'IHM Checklist'),
                  ),
                  _moduleTile(
                    context: context,
                    icon: Icons.map_outlined,
                    iconColor: _AppColors.teal,
                    title: 'Areas',
                    subtitle: 'Open vessel areas and checkpoints',
                    onTap: () => _showComingSoon(context, 'IHM Areas'),
                  ),
                  _moduleTile(
                    context: context,
                    icon: Icons.edit_location_alt_outlined,
                    iconColor: _AppColors.amber,
                    title: 'Layout Marking',
                    subtitle: 'Mark hazardous material locations',
                    onTap: () => _showComingSoon(context, 'Layout Marking'),
                  ),
                  _moduleTile(
                    context: context,
                    icon: Icons.photo_camera_outlined,
                    iconColor: _AppColors.purple,
                    title: 'Sampling Photos',
                    subtitle: 'Capture and attach survey photos',
                    onTap: () => _showComingSoon(context, 'Sampling Photos'),
                    isLast: true,
                  ),
                ] else ...[
                  _moduleTile(
                    context: context,
                    icon: Icons.precision_manufacturing_outlined,
                    iconColor: _AppColors.ocean,
                    title: 'Equipment Register',
                    subtitle: 'View Ex equipment list',
                    onTap: () => _showComingSoon(context, 'Equipment Register'),
                  ),
                  _moduleTile(
                    context: context,
                    icon: Icons.fact_check_outlined,
                    iconColor: _AppColors.teal,
                    title: 'Checklist',
                    subtitle: 'Complete pass/fail/NA checklist',
                    onTap: () => _showComingSoon(context, 'Ex Checklist'),
                  ),
                  _moduleTile(
                    context: context,
                    icon: Icons.report_problem_outlined,
                    iconColor: _AppColors.amber,
                    title: 'Defects',
                    subtitle: 'Add defects and comments',
                    onTap: () => _showComingSoon(context, 'Defects'),
                  ),
                  _moduleTile(
                    context: context,
                    icon: Icons.photo_camera_outlined,
                    iconColor: _AppColors.purple,
                    title: 'Photos',
                    subtitle: 'Capture and attach evidence photos',
                    onTap: () => _showComingSoon(context, 'Photos'),
                    isLast: true,
                  ),
                ],

                // ── Close Job Button ──
                if (job.status == 'ReportGenerated') ...[
                  const SizedBox(height: 28),
                  _sectionTitle('ACTIONS'),
                  const SizedBox(height: 10),
                  Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => Dialog(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 18,
                                  ),
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        _AppColors.navy,
                                        _AppColors.slate,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(16),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.lock_outline,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      const Text(
                                        'Close Job',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    24,
                                    20,
                                    24,
                                    8,
                                  ),
                                  child: Text(
                                    'Are you sure you want to close job ${job.jobNumber}? This action cannot be undone.',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: _AppColors.textSecondary,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    24,
                                    12,
                                    24,
                                    20,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        style: TextButton.styleFrom(
                                          foregroundColor:
                                              _AppColors.textSecondary,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 12,
                                          ),
                                        ),
                                        child: const Text(
                                          'Cancel',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.lock, size: 16),
                                        label: const Text('Close Job'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _AppColors.red,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 22,
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );

                        if (confirmed != true) return;
                        await ApiService.closeSurveyJob(job.id);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Job closed successfully.'),
                            backgroundColor: _AppColors.navy,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _AppColors.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _AppColors.red.withOpacity(0.25),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.lock_outline,
                              color: _AppColors.red,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Close Job',
                              style: TextStyle(
                                color: _AppColors.red,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  Widget _headerPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: _AppColors.lightTeal),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: _AppColors.ocean,
        letterSpacing: 1.4,
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String? value, {
    bool isLast = false,
  }) {
    final displayValue = value == null || value.trim().isEmpty
        ? '—'
        : value.trim();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 16, color: _AppColors.textMuted),
              const SizedBox(width: 10),
              SizedBox(
                width: 110,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  displayValue,
                  style: const TextStyle(
                    fontSize: 14,
                    color: _AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            color: _AppColors.divider.withOpacity(0.6),
            height: 1,
            indent: 26,
          ),
      ],
    );
  }

  Widget _moduleTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _AppColors.divider.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: _AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: _AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String featureName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$featureName will be added in the next phase.'),
        backgroundColor: _AppColors.navy,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
