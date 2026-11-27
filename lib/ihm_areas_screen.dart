import 'package:Auras/ThemeNotifier.dart';
import 'package:Auras/ihm_area.dart';
import 'package:Auras/ihm_checkpoint_detail_screen.dart';
import 'package:Auras/model/ihm_checkpoint_submission.dart';
import 'package:Auras/model/survey_job.dart';
import 'package:Auras/service/IhmOfflineService.dart';
import 'package:Auras/service/api_service.dart'; // ← ADD THIS
import 'package:Auras/service/sync_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

// ─── Theme Colors ─────────────────────────────────────────────────────────────
class _TC {
  final Color bgDark, bgCard, bgCardAlt, textPrimary, textSecond, divider;
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

class _A {
  static const accent = Color(0xFF00D4AA);
  static const accentBlue = Color(0xFF1E90FF);
  static const accentAmber = Color(0xFFFFA040);
  static const accentRed = Color(0xFFFF5252);
  static const accentPurple = Color(0xFF9B7FFF);
  static const accentGreen = Color(0xFF4CAF8C);
}

// ─── Areas Screen ─────────────────────────────────────────────────────────────
class IhmAreasScreen extends StatefulWidget {
  final SurveyJob job;
  const IhmAreasScreen({super.key, required this.job});

  @override
  State<IhmAreasScreen> createState() => _IhmAreasScreenState();
}

class _IhmAreasScreenState extends State<IhmAreasScreen> {
  // ✅ These belong HERE — inside _IhmAreasScreenState
  final Map<int, bool> _uploadingLayout = {};
  late Future<List<IhmArea>> _areasFuture;
  bool _isLoggingOut = false;
  String _lastSyncState = '';

  _TC get _c =>
      context.watch<ThemeNotifier>().isDarkMode ? _TC.dark : _TC.light;

  Widget _sectionLabel(String text) => Text(
    text,
    style: TextStyle(
      color: _c.textSecond,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.5,
    ),
  );

  // ✅ This also belongs HERE
  @override
  void initState() {
    super.initState();
    _areasFuture = IhmOfflineService.getAreasForJob(widget.job.id);
    SyncService.syncStatus.addListener(_handleSyncStatusChanged);
  }

  @override
  void dispose() {
    SyncService.syncStatus.removeListener(_handleSyncStatusChanged);
    super.dispose();
  }

  void _handleSyncStatusChanged() {
    final snapshot = SyncService.syncStatus.value;
    if (snapshot.isSyncing || snapshot.state == _lastSyncState) return;
    _lastSyncState = snapshot.state;
    if (snapshot.state == 'synced' || snapshot.state == 'failed') {
      if (!mounted) return;
      setState(() {
        _areasFuture = IhmOfflineService.getLocalAreas(widget.job.id);
      });
    }
  }

  void _refreshAreas() {
    setState(() {
      _areasFuture = IhmOfflineService.getAreasForJob(widget.job.id);
    });
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);
    try {
      await SyncService.logoutAndClearUserData();
    } catch (error) {
      debugPrint('Logout failed during cleanup: $error');
    }
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  Future<void> _uploadAreaLayout(IhmArea a) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    setState(() => _uploadingLayout[a.id] = true);

    try {
      await ApiService.uploadAreaLayout(
        jobId: widget.job.id,
        areaId: a.id,
        file: result.files.first,
      );

      if (mounted) {
        _refreshAreas();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Layout uploaded for ${a.areaName}'),
            backgroundColor: _A.accentGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: _A.accentRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingLayout[a.id] = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _c.bgDark,
      appBar: AppBar(
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
        title: Text(
          'Survey Areas',
          style: TextStyle(
            color: _c.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: _isLoggingOut
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _isLoggingOut ? null : _logout,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _c.divider),
        ),
      ),
      body: FutureBuilder<List<IhmArea>>(
        future: _areasFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: _A.accent));
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                snapshot.error.toString(),
                style: TextStyle(color: _c.textSecond),
              ),
            );
          }

          final areas = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            children: [
              _sectionLabel('AREAS — ${areas.length} TOTAL'),
              const SizedBox(height: 14),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.82,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: areas.length,
                itemBuilder: (_, i) => _buildAreaCard(areas[i]),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAreaCard(IhmArea a) {
    final double progress = a.total == 0
        ? 0
        : (a.audited / a.total).clamp(0.0, 1.0);
    final Color accentColor = progress == 1.0 ? _A.accentGreen : _A.accentAmber;
    final bool uploading = _uploadingLayout[a.id] ?? false;

    return GestureDetector(
      onTap: () async {
        final changed = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) =>
                IhmAreaChecklistScreen(area: a, jobId: widget.job.id),
          ),
        );
        if (changed == true && mounted) _refreshAreas();
      },
      child: Container(
        decoration: BoxDecoration(
          color: _c.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.2),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      a.areaName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
            ),

            // ── Stats ──────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _statRow(
                      Icons.check_circle_outline_rounded,
                      'Total',
                      '${a.total}',
                      _c.textSecond,
                    ),
                    _statRow(
                      Icons.visibility_outlined,
                      'Visuals',
                      '${a.visual}',
                      _A.accentBlue,
                    ),
                    _statRow(
                      Icons.science_outlined,
                      'Samples',
                      '${a.sample}',
                      _A.accentPurple,
                    ),
                    _statRow(
                      Icons.task_alt_rounded,
                      'Audited',
                      '${a.audited}',
                      _A.accentGreen,
                    ),
                    _statRow(
                      Icons.hourglass_bottom_rounded,
                      'Pending',
                      '${a.pending}',
                      _A.accentAmber,
                    ),
                    const Spacer(),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: _c.divider,
                        valueColor: AlwaysStoppedAnimation(accentColor),
                        minHeight: 5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}% complete',
                      style: TextStyle(color: _c.textSecond, fontSize: 10),
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

  Widget _statRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: _c.textSecond, fontSize: 11)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Checklist Screen ─────────────────────────────────────────────────────────
class IhmAreaChecklistScreen extends StatefulWidget {
  final IhmArea area;
  final int jobId;
  final bool isDark;

  const IhmAreaChecklistScreen({
    super.key,
    required this.area,
    required this.jobId,
    this.isDark = true,
  });

  @override
  State<IhmAreaChecklistScreen> createState() => _IhmAreaChecklistScreenState();
}

class _IhmAreaChecklistScreenState extends State<IhmAreaChecklistScreen> {
  late List<IhmCheckpoint> checkpoints;
  Map<int, List<IhmCheckpointSubmission>> _submissionsByCheckpoint = {};
  bool _loadingSubmissions = true;
  bool _hasChanges = false;
  _TC get _c =>
      context.watch<ThemeNotifier>().isDarkMode ? _TC.dark : _TC.light;

  @override
  void initState() {
    super.initState();
    checkpoints = List.from(widget.area.checkpoints);
    _loadSubmissions();
  }

  Future<void> _loadSubmissions() async {
    try {
      final submissions = await ApiService.fetchIhmCheckpointSubmissions(
        widget.jobId,
      );
      final grouped = <int, List<IhmCheckpointSubmission>>{};
      for (final submission in submissions) {
        if (submission.status.toLowerCase() == 'rejected') continue;
        grouped.putIfAbsent(submission.checkpointId, () => []).add(submission);
      }
      if (!mounted) return;
      setState(() {
        _submissionsByCheckpoint = grouped;
        _loadingSubmissions = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingSubmissions = false);
    }
  }

  void _mergeCheckpoint(IhmCheckpoint updated) {
    final index = checkpoints.indexWhere((item) => item.id == updated.id);
    if (index < 0) return;
    checkpoints[index] = updated;
    _hasChanges = true;
  }

  Future<void> _refreshCurrentArea() async {
    try {
      final areas = await IhmOfflineService.getAreasForJob(widget.jobId);
      final matches = areas.where((area) => area.id == widget.area.id);
      if (!mounted || matches.isEmpty) return;
      setState(() {
        checkpoints = List.from(matches.first.checkpoints);
        _hasChanges = true;
      });
    } catch (_) {
      // The optimistic update above is enough if a background refresh fails.
    }
  }

  Future<void> _changeProcedure(IhmCheckpoint checkpoint, String type) async {
    final updated = await IhmOfflineService.saveCheckpointProcedure(
      checkpoint: checkpoint,
      procedureType: type,
    );
    setState(() {
      _mergeCheckpoint(updated);
    });
    await _loadSubmissions();
    await _refreshCurrentArea();
  }

  bool _hasEnteredNumber(IhmCheckpoint checkpoint) =>
      RegExp(r'^[SV]\d+$', caseSensitive: false)
          .hasMatch(checkpoint.sampleNo.trim());

  /// Lets the surveyor type the sample / visual number (S01, V01, ...).
  /// Numbers are no longer generated automatically.
  Future<void> _enterSampleNumber(IhmCheckpoint checkpoint) async {
    final prefix = checkpoint.isVisual
        ? 'V'
        : (checkpoint.isSample ? 'S' : '');
    final current = checkpoint.sampleNo.trim().toUpperCase();
    final controller = TextEditingController(
      text: _hasEnteredNumber(checkpoint) ? current : prefix,
    );
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
    String? errorText;

    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          void submit() {
            final text = controller.text.trim().toUpperCase();
            if (!RegExp(r'^[SV]\d+$').hasMatch(text)) {
              setDialogState(
                () => errorText = 'Enter S or V followed by a number, e.g. '
                    '${prefix.isEmpty ? 'S' : prefix}01',
              );
              return;
            }
            if (prefix.isNotEmpty && !text.startsWith(prefix)) {
              setDialogState(
                () => errorText = prefix == 'S'
                    ? 'This is a Sample checkpoint, so the number must start '
                          'with S. Use "Change to V" first to make it Visual.'
                    : 'This is a Visual checkpoint, so the number must start '
                          'with V. Use "Change to S" first to make it Sample.',
              );
              return;
            }
            Navigator.pop(dialogContext, text);
          }

          return AlertDialog(
            title: Text(
              prefix == 'V'
                  ? 'Visual Number'
                  : (prefix == 'S' ? 'Sample Number' : 'Sample / Visual Number'),
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: '${prefix.isEmpty ? 'S' : prefix}01',
                errorText: errorText,
                errorMaxLines: 3,
              ),
              onSubmitted: (_) => submit(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(onPressed: submit, child: const Text('Save')),
            ],
          );
        },
      ),
    );
    controller.dispose();
    if (value == null || value == current || !mounted) return;

    final used = await IhmOfflineService.isSampleNumberUsed(
      jobId: checkpoint.surveyJobId,
      sampleNo: value,
      excludeCheckpointId: checkpoint.id,
    );
    if (used && mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Number already used'),
          content: Text(
            '$value is already used by another checkpoint in this job. '
            'Save it anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save anyway'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    try {
      final saved = await IhmOfflineService.saveSampleNumber(
        checkpoint: checkpoint,
        sampleNo: value,
      );
      if (!mounted) return;
      setState(() => _mergeCheckpoint(saved));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save the number: $error')),
      );
    }
  }

  Future<void> _editCheckpoint(IhmCheckpoint checkpoint) async {
    final fields = <String, TextEditingController>{
      'sampleNo': TextEditingController(text: checkpoint.sampleNo),
      'description': TextEditingController(text: checkpoint.description ?? ''),
      'location': TextEditingController(text: checkpoint.location ?? ''),
      'equipment': TextEditingController(text: checkpoint.equipmentName ?? ''),
      'component': TextEditingController(text: checkpoint.component ?? ''),
      'hazmat': TextEditingController(text: checkpoint.hazardousMaterial ?? ''),
      'category': TextEditingController(
        text: checkpoint.materialCategory ?? '',
      ),
      'tableType': TextEditingController(text: checkpoint.tableType ?? ''),
      'quantityUnit': TextEditingController(
        text: checkpoint.quantityUnitKg ?? '',
      ),
      'quantityNo': TextEditingController(text: checkpoint.quantityNo ?? ''),
      'quantityTotal': TextEditingController(
        text: checkpoint.quantityTotalKg ?? '',
      ),
      'manufacturer': TextEditingController(
        text: checkpoint.manufacturerBrandName ?? '',
      ),
      'documentResult': TextEditingController(
        text: checkpoint.documentAnalysisResult ?? '',
      ),
      'checkResult': TextEditingController(text: checkpoint.checkResult ?? ''),
      'remarks': TextEditingController(text: checkpoint.remarks ?? ''),
      'locationRemarks': TextEditingController(
        text: checkpoint.locationRemarks ?? '',
      ),
    };
    var procedure = checkpoint.isSample ? 'Sample' : 'Visual';
    var isPchm = checkpoint.isPchm;

    final updated = await showDialog<IhmCheckpoint>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Checkpoint'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _editField(fields['sampleNo']!, 'Checkpoint Code *'),
                  _editField(fields['description']!, 'Description *', lines: 2),
                  _editField(fields['location']!, 'Location'),
                  _editField(fields['equipment']!, 'Equipment'),
                  _editField(fields['component']!, 'Component'),
                  _editField(fields['hazmat']!, 'Hazardous Material'),
                  _editField(fields['category']!, 'Material Category'),
                  _editField(fields['tableType']!, 'Table Type'),
                  Row(
                    children: [
                      Expanded(
                        child: _editField(fields['quantityUnit']!, 'Unit Kg'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _editField(fields['quantityNo']!, 'Quantity'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _editField(fields['quantityTotal']!, 'Total Kg'),
                      ),
                    ],
                  ),
                  _editField(fields['manufacturer']!, 'Manufacturer / Brand'),
                  _editField(
                    fields['documentResult']!,
                    'Document Analysis Result',
                  ),
                  _editField(fields['checkResult']!, 'Check Result'),
                  _editField(fields['remarks']!, 'Remarks', lines: 2),
                  _editField(
                    fields['locationRemarks']!,
                    'Location Remarks',
                    lines: 2,
                  ),
                  DropdownButtonFormField<String>(
                    value: procedure,
                    decoration: const InputDecoration(labelText: 'Procedure'),
                    items: const [
                      DropdownMenuItem(value: 'Visual', child: Text('Visual')),
                      DropdownMenuItem(value: 'Sample', child: Text('Sample')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => procedure = value);
                      }
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('PCHM'),
                    value: isPchm,
                    onChanged: (value) => setDialogState(() => isPchm = value),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save Changes'),
              onPressed: () async {
                if (fields['sampleNo']!.text.trim().isEmpty ||
                    fields['description']!.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Checkpoint code and description are required.',
                      ),
                    ),
                  );
                  return;
                }
                final value = checkpoint.copyWith(
                  sampleNo: fields['sampleNo']!.text.trim(),
                  description: fields['description']!.text.trim(),
                  location: fields['location']!.text.trim(),
                  equipmentName: fields['equipment']!.text.trim(),
                  component: fields['component']!.text.trim(),
                  hazardousMaterial: fields['hazmat']!.text.trim(),
                  materialCategory: fields['category']!.text.trim(),
                  tableType: fields['tableType']!.text.trim(),
                  quantityUnitKg: fields['quantityUnit']!.text.trim(),
                  quantityNo: fields['quantityNo']!.text.trim(),
                  quantityTotalKg: fields['quantityTotal']!.text.trim(),
                  manufacturerBrandName: fields['manufacturer']!.text.trim(),
                  documentAnalysisResult: fields['documentResult']!.text.trim(),
                  checkResult: fields['checkResult']!.text.trim(),
                  auditStatus: checkpoint.auditStatus,
                  remarks: fields['remarks']!.text.trim(),
                  locationRemarks: fields['locationRemarks']!.text.trim(),
                  samplingCheck: procedure == 'Sample' ? 'S' : '-',
                  visualCheck: procedure == 'Visual' ? 'V' : '-',
                  isPchm: isPchm,
                );
                try {
                  final saved = await IhmOfflineService.saveFullCheckpoint(
                    value,
                  );
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext, saved);
                  }
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Update failed: $error')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );

    for (final controller in fields.values) {
      controller.dispose();
    }
    if (updated != null && mounted) {
      setState(() {
        _mergeCheckpoint(updated);
      });
      await _loadSubmissions();
      await _refreshCurrentArea();
    }
  }

  Future<void> _openCheckpoint(IhmCheckpoint checkpoint) async {
    final updated = await Navigator.push<IhmCheckpoint>(
      context,
      MaterialPageRoute(
        builder: (_) => IhmCheckpointDetailScreen(
          checkpoint: checkpoint,
          displayLabel: _checkpointDisplayLabel(checkpoint),
        ),
      ),
    );
    if (updated == null || !mounted) return;
    setState(() {
      _mergeCheckpoint(updated);
    });
    await _loadSubmissions();
    await _refreshCurrentArea();
  }

  Future<void> _changeCheckpointAuditStatus(
    IhmCheckpoint checkpoint,
    String value,
  ) async {
    final normalized = _auditStatusValue(value);
    if (_auditStatusValue(checkpoint.auditStatus) == normalized) return;

    try {
      final saved = await IhmOfflineService.saveFullCheckpoint(
        checkpoint.copyWith(auditStatus: normalized),
      );
      if (!mounted) return;
      setState(() {
        _mergeCheckpoint(saved);
      });
      await _loadSubmissions();
      await _refreshCurrentArea();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Audit status update failed: $error')),
      );
    }
  }

  Widget _editField(
    TextEditingController controller,
    String label, {
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: controller,
      maxLines: lines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  Color _typeColor(IhmCheckpoint c) {
    if (c.isSample) return _A.accentRed;
    if (c.isVisual) return _A.accentGreen;
    return _c.textSecond;
  }

  String _typeLabel(IhmCheckpoint c) {
    if (c.isSample) return 'SAMPLE';
    if (c.isVisual) return 'VISUAL';
    return 'UNSET';
  }

  String _checkpointDisplayLabel(IhmCheckpoint checkpoint) {
    return checkpoint.sampleNo;
  }

  Widget _sectionLabel(String text) => Text(
    text,
    style: TextStyle(
      color: _c.textSecond,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.5,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _c.bgDark,
      appBar: AppBar(
        backgroundColor: _c.bgDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _c.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context, _hasChanges),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.area.areaName,
              style: TextStyle(
                color: _c.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${checkpoints.length} checkpoints',
              style: TextStyle(color: _c.textSecond, fontSize: 11),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _c.divider),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          _sectionLabel('CHECKPOINTS'),
          const SizedBox(height: 14),
          ...checkpoints.map((c) => _buildCheckpointCard(c)),
        ],
      ),
    );
  }

  Widget _buildCheckpointCard(IhmCheckpoint c) {
    final color = _typeColor(c);
    final label = _typeLabel(c);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _c.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1.2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openCheckpoint(c),
        child: Column(
          children: [
            // ── Header bar ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(c.procedureIcon, color: color, size: 13),
                        const SizedBox(width: 4),
                        Text(
                          label,
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () => _enterSampleNumber(c),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  _hasEnteredNumber(c)
                                      ? _checkpointDisplayLabel(c)
                                      : '${_checkpointDisplayLabel(c)}  '
                                            '· Enter no.',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _hasEnteredNumber(c)
                                        ? _c.textPrimary
                                        : _c.textSecond,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.edit_note_rounded,
                                size: 16,
                                color: color,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (c.isSample || c.isVisual)
                    OutlinedButton(
                      onPressed: () =>
                          _changeProcedure(c, c.isSample ? 'Visual' : 'Sample'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: color,
                        side: BorderSide(color: color.withValues(alpha: 0.7)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: Text('Change to ${c.isSample ? 'V' : 'S'}'),
                    ),
                  const SizedBox(width: 2),
                  IconButton(
                    tooltip: 'Edit checkpoint',
                    icon: Icon(
                      Icons.edit_outlined,
                      color: _c.textSecond,
                      size: 18,
                    ),
                    onPressed: () => _editCheckpoint(c),
                  ),
                ],
              ),
            ),

            // ── Detail rows ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _detailRow(
                    Icons.location_on_outlined,
                    'Location',
                    c.location,
                  ),
                  _detailRow(
                    Icons.settings_outlined,
                    'Equipment',
                    c.equipmentName,
                  ),
                  _detailRow(Icons.category_outlined, 'Component', c.component),
                  _detailRow(
                    Icons.warning_amber_rounded,
                    'Hazmat',
                    c.hazardousMaterial,
                  ),
                  const SizedBox(height: 4),
                  _buildSurveyAttribution(c),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSurveyAttribution(IhmCheckpoint checkpoint) {
    if (_loadingSubmissions) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final submissions =
        _submissionsByCheckpoint[checkpoint.id] ??
        const <IhmCheckpointSubmission>[];
    if (submissions.isEmpty) {
      if (checkpoint.isAudited) {
        return _surveyInfoRow(
          Icons.check_circle_outline_rounded,
          'Checkpoint updated',
          checkpoint,
          _A.accentGreen,
        );
      }
      return _surveyInfoRow(
        Icons.person_search_outlined,
        'Not surveyed yet',
        checkpoint,
        _c.textSecond,
      );
    }

    return Column(
      children: submissions.map((submission) {
        final status = submission.status.toLowerCase();
        final color = status == 'conflict' ? _A.accentRed : _A.accentGreen;
        return Padding(
          padding: const EdgeInsets.only(top: 5),
          child: _surveyInfoRow(
            Icons.verified_user_outlined,
            '${submission.surveyorName} surveyed',
            checkpoint,
            color,
          ),
        );
      }).toList(),
    );
  }

  Widget _surveyInfoRow(
    IconData icon,
    String title,
    IhmCheckpoint checkpoint,
    Color color,
  ) {
    final auditStatus = _auditStatusValue(checkpoint.auditStatus);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: _c.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 132),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: auditStatus,
                isDense: true,
                isExpanded: true,
                dropdownColor: _c.bgCard,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
                icon: Icon(Icons.keyboard_arrow_down_rounded, color: color),
                items: const [
                  DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'Done', child: Text('Done')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _changeCheckpointAuditStatus(checkpoint, value);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _auditStatusValue(Object? value) {
    switch (value?.toString().trim().toLowerCase().replaceAll(
      RegExp(r'[\s_-]'),
      '',
    )) {
      case '2':
      case 'inprogress':
        return 'Pending';
      case '3':
      case 'done':
      case 'completed':
        return 'Done';
      default:
        return 'Pending';
    }
  }

  Widget _detailRow(IconData icon, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: _c.textSecond),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(color: _c.textSecond, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              (value?.trim().isEmpty ?? true) ? '-' : value!,
              style: TextStyle(
                color: _c.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
