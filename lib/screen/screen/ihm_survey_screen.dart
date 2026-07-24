import 'package:Auras/ThemeNotifier.dart';
import 'package:Auras/ihm_area.dart';
import 'package:Auras/ihm_areas_screen.dart';
import 'package:Auras/ihm_project_info_screen.dart';
import 'package:Auras/model/survey_job.dart';
import 'package:Auras/service/IhmOfflineService.dart';
import 'package:Auras/service/api_service.dart';

import 'package:Auras/vessel_info_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ─── Theme Colors ─────────────────────────────────────────────────────────────
class _TC {
  final Color bgDark;
  final Color bgCard;
  final Color bgCardAlt;
  final Color textPrimary;
  final Color textSecond;
  final Color divider;

  const _TC({
    required this.bgDark,
    required this.bgCard,
    required this.bgCardAlt,
    required this.textPrimary,
    required this.textSecond,
    required this.divider,
  });

  static const dark = _TC(
    bgDark: Color(0xFF0D1B2A),
    bgCard: Color(0xFF152235),
    bgCardAlt: Color(0xFF1A2C42),
    textPrimary: Color(0xFFE8F0FE),
    textSecond: Color(0xFF8FA8C4),
    divider: Color(0xFF1E3A55),
  );

  static const light = _TC(
    bgDark: Color(0xFFF0F4FA),
    bgCard: Color(0xFFFFFFFF),
    bgCardAlt: Color(0xFFEAF0F9),
    textPrimary: Color(0xFF0D1B2A),
    textSecond: Color(0xFF4A6580),
    divider: Color(0xFFCDD9E8),
  );
}

// ─── Accent Palette (unchanged across themes) ────────────────────────────────
class _A {
  static const accent = Color(0xFF00D4AA);
  static const accentBlue = Color(0xFF1E90FF);
  static const accentAmber = Color(0xFFFFA040);
  static const accentRed = Color(0xFFFF5252);
  static const accentPurple = Color(0xFF9B7FFF);
  static const accentGreen = Color(0xFF4CAF8C);
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class IHMSurveyScreen extends StatefulWidget {
  final int userId;
  final SurveyJob job;

  final int totalVisuals;
  final int totalSamples;
  final int auditedCount;
  final int missingCount;
  final int pendingUploads;
  final int pendingImages;

  const IHMSurveyScreen({
    required this.userId,
    required this.job,
    this.totalVisuals = 0,
    this.totalSamples = 0,
    this.auditedCount = 0,
    this.missingCount = 0,
    this.pendingUploads = 0,
    this.pendingImages = 0,
    super.key,
  });

  @override
  State<IHMSurveyScreen> createState() => _IHMSurveyScreenState();
}

class _IHMSurveyScreenState extends State<IHMSurveyScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  int _pendingSyncCount = 0;
  bool _syncingIhm = false;
  bool _loadingAuditStats = true;
  List<IhmArea> _areas = const <IhmArea>[];

  _TC get _c {
    final theme = context.watch<ThemeNotifier>();
    return theme.isDarkMode ? _TC.dark : _TC.light;
  }

  // Derived totals
  Iterable<IhmCheckpoint> get _checkpoints =>
      _areas.expand((area) => area.checkpoints);
  int get _totalVisuals => _areas.isEmpty
      ? widget.totalVisuals
      : _checkpoints.where((x) => x.isVisual).length;
  int get _totalSamples => _areas.isEmpty
      ? widget.totalSamples
      : _checkpoints.where((x) => x.isSample).length;
  int get _totalCheckpoints => _areas.isEmpty
      ? widget.totalVisuals + widget.totalSamples
      : _checkpoints.length;
  int get _auditedCount => _areas.isEmpty
      ? widget.auditedCount
      : _checkpoints.where((x) => x.isAudited).length;
  int get _missingCount => _areas.isEmpty
      ? widget.missingCount
      : _checkpoints.where((x) => !x.isAudited).length;
  int get _pendingCount =>
      (_totalCheckpoints - _auditedCount).clamp(0, _totalCheckpoints);
  double get _auditProgress => _totalCheckpoints == 0
      ? 0
      : (_auditedCount / _totalCheckpoints).clamp(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
    _refreshPendingSyncCount();
    _refreshAuditStats();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _c.bgDark,
      appBar: _buildAppBar(),

      body: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel("NAVIGATION"),
              const SizedBox(height: 14),
              Row(
                children: [
                  _buildNavCard(
                    Icons.directions_boat_rounded,
                    "Vessel Info",
                    _A.accentBlue,
                    onTap: _openVesselInfo,
                  ),
                  const SizedBox(width: 12),
                  _buildNavCard(
                    Icons.folder_open_rounded,
                    "Project Info",
                    _A.accentAmber,
                    onTap: _openProjectInfo,
                  ),
                  const SizedBox(width: 12),
                  _buildNavCard(
                    Icons.map_rounded,
                    "Survey Areas",
                    _A.accentGreen,
                    onTap: () {
                      _openAreas();
                    },
                  ),
                ],
              ),

              const SizedBox(height: 32),

              _sectionLabel("AUDIT SUMMARY"),
              const SizedBox(height: 14),
              _buildAuditSummary(),

              const SizedBox(height: 32),

              _sectionLabel("CHECKPOINT BREAKDOWN"),
              const SizedBox(height: 14),
              Row(
                children: [
                  _buildBreakdownCard(
                    "Visuals",
                    _totalVisuals,
                    Icons.visibility_rounded,
                    _A.accentBlue,
                  ),
                  const SizedBox(width: 14),
                  _buildBreakdownCard(
                    "Samples",
                    _totalSamples,
                    Icons.science_rounded,
                    _A.accentAmber,
                  ),
                ],
              ),

              const SizedBox(height: 32),

              _sectionLabel("SURVEY COMPLETENESS"),
              const SizedBox(height: 14),
              _buildValidationPanel(),

              const SizedBox(height: 32),

              _sectionLabel("UPLOAD STATUS"),
              const SizedBox(height: 14),
              _buildUploadPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openAreas() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => IhmAreasScreen(job: widget.job)),
    );
    await _refreshPendingSyncCount();
    await _refreshAuditStats();
  }

  Future<void> _refreshAuditStats() async {
    if (mounted) setState(() => _loadingAuditStats = true);
    try {
      final areas = await IhmOfflineService.getAreasForJob(widget.job.id);
      if (!mounted) return;
      setState(() {
        _areas = areas;
        _loadingAuditStats = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingAuditStats = false);
    }
  }

  Future<void> _refreshPendingSyncCount() async {
    final count = await IhmOfflineService.pendingSyncCount();
    if (!mounted) return;
    setState(() => _pendingSyncCount = count);
  }

  Future<void> _syncIhmNow() async {
    if (_syncingIhm) return;
    setState(() => _syncingIhm = true);

    try {
      await IhmOfflineService.syncPendingIhmData();
      await _refreshPendingSyncCount();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF16A34A),
          content: Text('All offline changes synced successfully'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sync failed. Your data is still saved on this device — we\'ll retry when you\'re back online.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _syncingIhm = false);
    }
  }

  void _openProjectInfo() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => IhmProjectInfoScreen(job: widget.job)),
    );
  }

  Future<void> _openVesselInfo() async {
    var vesselId = widget.job.vesselId;

    if (vesselId == null || vesselId <= 0) {
      try {
        final refreshedJob = await ApiService.fetchSurveyJobById(widget.job.id);
        vesselId = refreshedJob.vesselId;
      } catch (_) {
        vesselId = null;
      }
    }

    if (vesselId == null || vesselId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No vessel linked to this job.')),
      );
      return;
    }

    final resolvedVesselId =
        vesselId; // now a non-nullable, non-reassignable int

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VesselInfoScreen(
          vesselId: resolvedVesselId,
          jobNumber: widget.job.jobNumber,
        ),
      ),
    );
  }

  // ─── AppBar ────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _c.bgDark,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          color: _c.textPrimary,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.job.jobNumber} | ${widget.job.vesselName ?? "-"}',
            style: TextStyle(
              color: _c.textSecond,
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
      actions: [
        // ── Theme toggle ──────────────────────────────────────────────────
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _c.divider),
      ),
    );
  }

  // ─── Section Label ─────────────────────────────────────────────────────────
  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: _c.textSecond,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
    );
  }

  // ─── Nav Cards ─────────────────────────────────────────────────────────────
  Widget _buildNavCard(
    IconData icon,
    String label,
    Color color, {
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: _c.bgCard,

            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2), width: 1.2),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  color: _c.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Audit Summary ─────────────────────────────────────────────────────────
  Widget _buildAuditSummary() {
    final pct = (_auditProgress * 100).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _c.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _A.accent.withOpacity(0.18), width: 1),
      ),
      child: Column(
        children: [
          // ── Top row: progress ring + pct ──
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: _auditProgress,
                      backgroundColor: _c.divider,
                      valueColor: const AlwaysStoppedAnimation(_A.accent),
                      strokeWidth: 7,
                    ),
                    Text(
                      "$pct%",
                      style: const TextStyle(
                        color: _A.accent,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Stat triplet row ──
          Row(
            children: [
              Expanded(
                child: _buildAuditStat(
                  value: _loadingAuditStats
                      ? "..."
                      : _totalCheckpoints.toString(),
                  label: "Total",
                  sublabel: "Visuals + Samples",
                  color: _A.accentBlue,
                ),
              ),
              Container(width: 1, height: 56, color: _c.divider),
              Expanded(
                child: _buildAuditStat(
                  value: _loadingAuditStats ? "..." : _auditedCount.toString(),
                  label: "Audited",
                  sublabel: "Completed",
                  color: _A.accentGreen,
                ),
              ),
              Container(width: 1, height: 56, color: _c.divider),
              Expanded(
                child: _buildAuditStat(
                  value: _pendingCount.toString(),
                  label: "Pending",
                  sublabel: "Remaining",
                  color: _A.accentAmber,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Progress bar ──
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _auditProgress,
              backgroundColor: _c.divider,
              valueColor: const AlwaysStoppedAnimation(_A.accent),
              minHeight: 8,
            ),
          ),

          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "$_auditedCount audited",
                style: TextStyle(color: _c.textSecond, fontSize: 12),
              ),
              Text(
                "$_pendingCount remaining",
                style: const TextStyle(
                  color: _A.accentAmber,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAuditStat({
    required String value,
    required String label,
    required String sublabel,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: _c.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            sublabel,
            style: TextStyle(color: _c.textSecond, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _vertDivider() => Container(
    width: 1,
    height: 56,
    color: _c.divider,
    margin: const EdgeInsets.symmetric(horizontal: 16),
  );

  // ─── Breakdown Cards ───────────────────────────────────────────────────────
  Widget _buildBreakdownCard(
    String label,
    int count,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _c.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.18), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 14),
            Text(
              '$count',
              style: TextStyle(
                color: color,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: _c.textSecond,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Validation Panel ──────────────────────────────────────────────────────
  Widget _buildValidationPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _c.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _c.divider, width: 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildValidationStat(
                _loadingAuditStats ? "..." : _auditedCount.toString(),
                "Captured",
                _A.accentGreen,
              ),
              Container(
                width: 1,
                height: 48,
                color: _c.divider,
                margin: const EdgeInsets.symmetric(horizontal: 20),
              ),
              _buildValidationStat(
                _loadingAuditStats ? "..." : _missingCount.toString(),
                "Missing",
                _A.accentRed,
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _loadingAuditStats ? null : _refreshAuditStats,
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 18,
                ), // changed from check_circle_outline_rounded
                label: const Text(
                  "Refresh",
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _A.accentGreen,
                  foregroundColor: _TC.dark.bgDark,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _c.bgCardAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: _c.textSecond,
                  size: 16,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _loadingAuditStats
                        ? "Checking the latest audit checkpoint data..."
                        : _missingCount == 0
                        ? "Validation complete. All $_totalCheckpoints checkpoints are captured."
                        : "$_missingCount of $_totalCheckpoints checkpoints still require audit data.",
                    style: TextStyle(color: _c.textSecond, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValidationStat(String value, String label, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: _c.textSecond,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ─── Upload Panel ──────────────────────────────────────────────────────────
  Widget _buildUploadPanel() {
    final bool hasPending =
        widget.pendingUploads > 0 ||
        widget.pendingImages > 0 ||
        _pendingSyncCount > 0;

    final title = hasPending ? "Saved offline" : "All synced";

    final subtitle = hasPending
        ? "Your data is saved on this device. It'll upload automatically once you're online, or tap Upload to sync now."
        : "All your survey data is saved and backed up to the server.";

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _c.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasPending ? _A.accentAmber.withOpacity(0.3) : _c.divider,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (hasPending ? _A.accentAmber : _A.accentGreen).withOpacity(
                0.12,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              hasPending
                  ? Icons.cloud_upload_outlined
                  : Icons.cloud_done_rounded,
              color: hasPending ? _A.accentAmber : _A.accentGreen,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: _c.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: _c.textSecond,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                if (hasPending) ...[
                  const SizedBox(height: 6),
                  Text(
                    "Queued: $_pendingSyncCount  ·  Checkpoints: ${widget.pendingUploads}  ·  Images: ${widget.pendingImages}",
                    style: TextStyle(
                      color: _c.textSecond,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _syncingIhm ? null : _syncIhmNow,
            style: ElevatedButton.styleFrom(
              backgroundColor: hasPending ? _A.accentAmber : _A.accentGreen,
              foregroundColor: _TC.dark.bgDark,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              _syncingIhm ? "Syncing..." : (hasPending ? "Upload" : "Synced"),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
