import 'dart:convert';
import 'dart:io';

import 'package:Auras/ThemeNotifier.dart';
import 'package:Auras/ex_survey/ex_survey_screen.dart';
import 'package:Auras/model/survey_job.dart';
import 'package:Auras/model/vessel.dart';
import 'package:Auras/screen/screen/ihm_survey_screen.dart';
import 'package:Auras/service/api_service.dart';
import 'package:Auras/service/IhmOfflineService.dart';
import 'package:Auras/service/survey_job_offline_service.dart';
import 'package:Auras/utils/app_dialog.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Color Palette (matches VesselMasterScreen) ───────────────────────────────
class _AppColors {
  static const Color navy = Color(0xFF0B1D33);
  static const Color deepBlue = Color(0xFF132B4A);
  static const Color slate = Color(0xFF1E3A5F);
  static const Color ocean = Color(0xFF1976D2);
  static const Color teal = Color(0xFF00897B);
  static const Color lightTeal = Color(0xFF4DB6AC);
  static const Color surface = Color(0xFFF4F6FA);
  static const Color card = Colors.white;
  static const Color divider = Color(0xFFE0E4EC);
  static const Color textPrimary = Color(0xFF1A2333);
  static const Color textSecondary = Color(0xFF607080);
  static const Color textMuted = Color(0xFF90A0B0);
  static const Color success = Color(0xFF43A047);
  static const Color amber = Color(0xFFFFA726);
  static const Color red = Color(0xFFEF5350);
  static const Color purple = Color(0xFF7B1FA2);
  static const Color deepPurple = Color(0xFF512DA8);
}

class SurveyJobListScreen extends StatefulWidget {
  final String surveyType;
  final List<String> statusFilters;
  final String? ihmCompletionFilter;
  final String? jobCompletionFilter;
  final String? titleOverride;

  const SurveyJobListScreen({
    super.key,
    required this.surveyType,
    this.statusFilters = const [],
    this.ihmCompletionFilter,
    this.jobCompletionFilter,
    this.titleOverride,
  });

  @override
  State<SurveyJobListScreen> createState() => _SurveyJobListScreenState();
}

class _SurveyJobListScreenState extends State<SurveyJobListScreen>
    with WidgetsBindingObserver {
  bool isLoading = true;
  bool _isRefreshingJobs = false;
  bool isAdmin = false;
  int userId = 0;
  String? errorMessage;
  List<SurveyJob> jobs = [];
  List<Vessel> vessels = [];
  Vessel? selectedVessel;
  List<SurveyorOption> surveyors = [];
  List<SurveyorOption> managers = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  AppThemeColors get _theme => context.read<ThemeNotifier>().colors;
  bool get _isDarkTheme => context.read<ThemeNotifier>().isDarkMode;
  bool get _isAllSurveyTypes => widget.surveyType == 'All Surveys';
  String get _screenTitle =>
      widget.titleOverride ?? '${widget.surveyType} Jobs';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadJobs();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _loadJobs(showLoading: false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  List<SurveyJob> get _filteredJobs {
    final normalizedStatuses = widget.statusFilters
        .map((status) => status.toLowerCase())
        .toSet();
    final statusFiltered = normalizedStatuses.isEmpty
        ? jobs
        : jobs
              .where(
                (job) =>
                    normalizedStatuses.contains(
                      job.displayStatus.toLowerCase(),
                    ) ||
                    normalizedStatuses.contains(job.status.toLowerCase()),
              )
              .toList();

    if (_searchQuery.isEmpty) return statusFiltered;
    final q = _searchQuery.toLowerCase();
    return statusFiltered.where((j) {
      return j.jobNumber.toLowerCase().contains(q) ||
          (j.clientName ?? '').toLowerCase().contains(q) ||
          (j.vesselName ?? '').toLowerCase().contains(q) ||
          (j.siteName ?? '').toLowerCase().contains(q) ||
          j.displayStatus.toLowerCase().contains(q) ||
          j.status.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _openJob(SurveyJob job) async {
    print('OPEN JOB ID = ${job.id}');

    final moduleType = job.moduleType.toLowerCase();
    if (widget.surveyType == 'IHM Survey' ||
        (_isAllSurveyTypes && moduleType.contains('ihm'))) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => IHMSurveyScreen(userId: userId, job: job),
        ),
      );
      if (mounted) {
        await _loadJobs(showLoading: false);
      }
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ExSurveyScreen(job: job)),
    );
    if (mounted) {
      await _loadJobs(showLoading: false);
    }
  }

  Future<void> _uploadIhmExcel(SurveyJob job) async {
    if (job.id <= 0) {
      _showMessage('Job ID missing. Please create/save the job first.');
      return;
    }
    final hadChecklist = (job.vscpChecklistFilePath ?? '').trim().isNotEmpty;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;
    try {
      await ApiService.uploadIhmExcel(
        jobId: job.id,
        fileBytes: result.files.single.bytes!,
        fileName: result.files.single.name,
      );
      await IhmOfflineService.getAreasForJob(job.id);
      _showMessage(
        hadChecklist
            ? 'VSCP Checklist Template replaced successfully.'
            : 'VSCP Checklist Template uploaded successfully.',
      );
      await _loadJobs(showLoading: false);
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<void> _viewVscpChecklist(SurveyJob job) async {
    if (job.id <= 0) {
      _showMessage('Job ID missing. Please create/save the job first.');
      return;
    }

    try {
      final bytes = await ApiService.downloadVscpChecklist(job.id);
      final dir = await getTemporaryDirectory();
      final fallbackName = 'vscp-checklist-${job.id}.xlsx';
      final fileName =
          ((job.vscpChecklistFileName ?? '').trim().isEmpty
                  ? fallbackName
                  : job.vscpChecklistFileName!.trim())
              .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final file = File('${dir.path}/$fileName');

      await file.writeAsBytes(bytes, flush: true);
      await OpenFile.open(file.path);
    } catch (e) {
      final cachedPath =
          await IhmOfflineService.getCachedVscpChecklistLocalPath(job.id);
      if (cachedPath != null && cachedPath.isNotEmpty) {
        await OpenFile.open(cachedPath);
        return;
      }
      _showMessage(e.toString());
    }
  }

  Future<void> _uploadIhmLayout(SurveyJob job) async {
    if (job.id <= 0) {
      _showMessage('Job ID missing. Please create/save the job first.');
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'pdf'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;
    try {
      final responseBody = await ApiService.uploadIhmLayout(
        jobId: job.id,
        fileBytes: result.files.single.bytes!,
        fileName: result.files.single.name,
      );

      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final message =
          json['message']?.toString() ?? 'Layout uploaded successfully.';

      _showMessage(message);
      await _loadJobs(showLoading: false);
    } catch (e) {
      _showMessage(e.toString().isEmpty ? 'Upload failed.' : e.toString());
    }
  }

  Future<void> _uploadIhmImage(SurveyJob job) async {
    if (job.id <= 0) {
      _showMessage('Job ID missing. Please create/save the job first.');
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;
    try {
      await ApiService.uploadIhmImage(
        jobId: job.id,
        fileBytes: result.files.single.bytes!,
        fileName: result.files.single.name,
      );
      _showMessage('Image uploaded successfully.');
      await _loadJobs(showLoading: false);
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  void _showMessage(String message) {
    final normalized = message.replaceFirst('Exception: ', '');
    final failed =
        normalized.toLowerCase().contains('fail') ||
        normalized.toLowerCase().contains('error') ||
        normalized.toLowerCase().contains('missing');
    if (failed) {
      AppDialog.error(context, message: normalized);
    } else {
      AppDialog.success(context, title: 'Completed', message: normalized);
    }
  }

  Future<T?> _showSearchPicker<T>({
    required String title,
    required List<T> items,
    required String Function(T item) label,
    T? selected,
    bool allowClear = false,
  }) {
    return showDialog<T?>(
      context: context,
      builder: (pickerContext) {
        var query = '';
        return StatefulBuilder(
          builder: (context, setPickerState) {
            final filtered = items.where((item) {
              return label(item).toLowerCase().contains(query.toLowerCase());
            }).toList();

            return AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
              contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              title: Row(
                children: [
                  Expanded(child: Text(title)),
                  IconButton(
                    onPressed: () => Navigator.pop(pickerContext),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              content: SizedBox(
                width: 430,
                height: 420,
                child: Column(
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: _AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: _AppColors.divider,
                          ),
                        ),
                      ),
                      onChanged: (value) {
                        setPickerState(() => query = value.trim());
                      },
                    ),
                    const SizedBox(height: 10),
                    if (allowClear)
                      ListTile(
                        leading: const Icon(Icons.person_off_outlined),
                        title: const Text('Not Assign'),
                        onTap: () => Navigator.pop(pickerContext, null),
                      ),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('No matching results'))
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, index) {
                                final item = filtered[index];
                                return ListTile(
                                  title: Text(label(item)),
                                  trailing: item == selected
                                      ? const Icon(
                                          Icons.check_circle,
                                          color: _AppColors.ocean,
                                        )
                                      : null,
                                  onTap: () =>
                                      Navigator.pop(pickerContext, item),
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

  Future<void> _deleteJob(SurveyJob job) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Delete survey job?',
      message: 'Delete ${job.jobNumber}? This action cannot be undone.',
      confirmLabel: 'Delete job',
      destructive: true,
    );

    if (!confirmed) return;
    final deleted = await AppDialog.execute<bool>(
      context,
      loadingMessage: 'Deleting survey job...',
      action: () async {
        await ApiService.deleteSurveyJob(job.id);
        return true;
      },
      successTitle: 'Job deleted',
      successMessage: '${job.jobNumber} was deleted successfully.',
      errorTitle: 'Unable to delete job',
    );
    if (deleted == true && mounted) {
      await _loadJobs(showLoading: false);
    }
  }

  String _formatSurveyDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day-$month-${date.year}';
  }

  Future<void> _pickAndSaveSurveyDate(SurveyJob job) async {
    if (!_canEditSurveyDate(job)) {
      _showMessage('You are not allowed to edit the survey date for this job.');
      return;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: job.surveyDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    // Create the updated object before the API/offline operation.
    final updatedJob = SurveyJob.fromJson({
      ...job.toJson(),
      'surveyDate': picked.toIso8601String(),
      'displayStatus':
          job.totalItems > 0 && job.completedItems >= job.totalItems
          ? 'Completed'
          : job.completedItems > 0
          ? 'Pending'
          : 'In Progress',
    });

    // Immediately reflect the selected date in the UI.
    if (mounted) {
      setState(() {
        jobs = jobs
            .map((item) => item.id == job.id ? updatedJob : item)
            .toList();
      });
    }

    try {
      await SurveyJobOfflineService.updateSurveyDate(
        job: updatedJob,
        surveyDate: picked,
      );

      if (!mounted) return;

      _showMessage('Survey date saved successfully.');

      // Do not call _loadJobs() here.
      // It can reload an older cached/API value and overwrite the UI.
    } catch (e) {
      // Restore the previous job when saving fails.
      if (mounted) {
        setState(() {
          jobs = jobs.map((item) => item.id == job.id ? job : item).toList();
        });
      }

      _showMessage(e.toString());
    }
  }

  bool _canEditSurveyDate(SurveyJob job) {
    if (job.canEdit) return true;
    if (userId <= 0) return false;
    if (job.assignedUserId == userId) return true;
    if (job.primarySurveyorUserId == userId) return true;
    if (job.secondarySurveyorUserId == userId) return true;
    return false;
  }

  Future<void> _loadJobs({bool showLoading = true}) async {
    if (_isRefreshingJobs) return;
    _isRefreshingJobs = true;

    if (showLoading && mounted) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    } else if (mounted) {
      setState(() => errorMessage = null);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getInt('userId') ?? 0;
      final role = prefs.getString('userRole') ?? '';
      final normalizedRole = role.toLowerCase();
      isAdmin =
          normalizedRole == 'admin' ||
          normalizedRole == 'global admin' ||
          normalizedRole == 'globaladmin' ||
          normalizedRole == 'administrator' ||
          normalizedRole == 'manager';

      final hasIhmCompletionFilter =
          widget.ihmCompletionFilter != null &&
          widget.ihmCompletionFilter!.trim().isNotEmpty;
      final cachedJobs = hasIhmCompletionFilter
          ? await SurveyJobOfflineService.getCachedSurveyJobs(
              surveyType: widget.surveyType,
              isAdmin: isAdmin,
              userId: userId,
              ihmCompletionFilter: widget.ihmCompletionFilter,
              jobCompletionFilter: widget.jobCompletionFilter,
            )
          : _isAllSurveyTypes
          ? [
              ...await SurveyJobOfflineService.getCachedSurveyJobs(
                surveyType: 'IHM Survey',
                isAdmin: isAdmin,
                userId: userId,
                jobCompletionFilter: widget.jobCompletionFilter,
              ),
              ...await SurveyJobOfflineService.getCachedSurveyJobs(
                surveyType: 'Ex-Survey',
                isAdmin: isAdmin,
                userId: userId,
                jobCompletionFilter: widget.jobCompletionFilter,
              ),
            ]
          : await SurveyJobOfflineService.getCachedSurveyJobs(
              surveyType: widget.surveyType,
              isAdmin: isAdmin,
              userId: userId,
              jobCompletionFilter: widget.jobCompletionFilter,
            );

      if (cachedJobs.isNotEmpty && mounted) {
        setState(() {
          jobs = cachedJobs;
          isLoading = false;
          errorMessage = null;
        });
      }

      if (isAdmin) {
        try {
          vessels = await ApiService.fetchVessels();
        } catch (_) {
          vessels = [];
        }
        try {
          surveyors = await ApiService.fetchSurveyors();
        } catch (_) {
          surveyors = [];
        }
        try {
          managers = await ApiService.fetchManagers();
        } catch (_) {
          managers = [];
        }
      }

      final result = _isAllSurveyTypes
          ? [
              ...await SurveyJobOfflineService.getSurveyJobsByType(
                surveyType: 'IHM Survey',
                isAdmin: isAdmin,
                userId: userId,
                ihmCompletionFilter: widget.ihmCompletionFilter,
                jobCompletionFilter: widget.jobCompletionFilter,
              ),
              ...await SurveyJobOfflineService.getSurveyJobsByType(
                surveyType: 'Ex-Survey',
                isAdmin: isAdmin,
                userId: userId,
                jobCompletionFilter: widget.jobCompletionFilter,
              ),
            ]
          : await SurveyJobOfflineService.getSurveyJobsByType(
              surveyType: widget.surveyType,
              isAdmin: isAdmin,
              userId: userId,
              ihmCompletionFilter: widget.ihmCompletionFilter,
              jobCompletionFilter: widget.jobCompletionFilter,
            );

      if (!mounted) return;
      setState(() {
        jobs = result;
        isLoading = false;
        errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (jobs.isEmpty) {
          errorMessage =
              'No saved offline jobs found. Please connect once to load your jobs.';
        } else {
          errorMessage = null;
        }
        isLoading = false;
      });
    } finally {
      _isRefreshingJobs = false;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Completed':
        return _AppColors.success;
      case 'Pending':
        return _AppColors.amber;
      case 'In Progress':
        return _AppColors.ocean;
      case 'Not Started':
        return _AppColors.textMuted;
      default:
        return _AppColors.textMuted;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Completed':
        return Icons.check_circle_outline;
      case 'Pending':
        return Icons.schedule_rounded;
      case 'In Progress':
        return Icons.pending_actions;
      case 'Not Started':
        return Icons.radio_button_unchecked;
      default:
        return Icons.help_outline;
    }
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return '-';
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day-$month-$year $hour:$minute';
  }

  String _formatApiDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _AppColors.ocean,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      controller.text = _formatApiDate(picked);
    }
  }

  // ─── Shared Dialog Widgets ──────────────────────────────────────────────────
  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: _AppColors.ocean,
          letterSpacing: 1.4,
        ),
      ),
    );
  }

  Widget _dialogRow(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: children
            .expand(
              (w) => [
                if (children.indexOf(w) > 0) const SizedBox(width: 12),
                w is Expanded ? w : Expanded(child: w),
              ],
            )
            .toList(),
      ),
    );
  }

  Widget _dialogField(
    TextEditingController controller,
    String label, {
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    final theme = _theme;

    return TextField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      style: TextStyle(fontSize: 14, color: theme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 13, color: theme.textSecond),
        filled: true,
        fillColor: theme.bgCardAlt,
        suffixIcon: readOnly
            ? Icon(Icons.calendar_today, size: 18, color: theme.textSecond)
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: theme.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: theme.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _AppColors.ocean, width: 1.5),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),
    );
  }

  // ─── Create Dialog ──────────────────────────────────────────────────────────
  Future<void> _showCreateSurveyJobDialog() async {
    final jobNo = TextEditingController();
    final client = TextEditingController();
    final project = TextEditingController();
    final auditPort = TextEditingController();
    final auditAddress = TextEditingController();

    SurveyorOption? primarySurveyor;
    SurveyorOption? secondarySurveyor;
    SurveyorOption? assignedManager;

    final startDate = TextEditingController();
    final endDate = TextEditingController();
    Vessel? dialogSelectedVessel;

    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = context.watch<ThemeNotifier>().colors;

            return Dialog(
              backgroundColor: theme.bgCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 720,
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
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
                            _AppColors.deepBlue,
                            _AppColors.slate,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
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
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.add_circle_outline,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'New ${widget.surveyType} Job',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const Text(
                                'Fill in the job details below',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white54,
                              size: 22,
                            ),
                            onPressed: () => Navigator.pop(context, false),
                          ),
                        ],
                      ),
                    ),

                    Flexible(
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.fromLTRB(
                          24,
                          20,
                          24,
                          24 + MediaQuery.of(context).viewInsets.bottom,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionLabel('JOB DETAILS'),
                            _dialogRow([_dialogField(jobNo, 'Job Number *')]),
                            _dialogRow([
                              _dialogField(project, 'Project Name'),
                              _dialogField(auditPort, 'Audit Port *'),
                            ]),
                            _dialogRow([
                              _dialogField(auditAddress, 'Audit Address'),
                            ]),

                            const SizedBox(height: 4),
                            _sectionLabel('VESSEL'),

                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: DropdownButtonFormField<Vessel>(
                                value: dialogSelectedVessel,
                                decoration: InputDecoration(
                                  labelText: 'Select Vessel *',
                                  suffixIcon: IconButton(
                                    tooltip: 'Search vessels',
                                    icon: const Icon(Icons.search),
                                    onPressed: () async {
                                      final value = await _showSearchPicker<Vessel>(
                                        title: 'Search Vessel',
                                        items: vessels,
                                        selected: dialogSelectedVessel,
                                        label: (vessel) =>
                                            '${vessel.vesselName}${vessel.imoNumber == null || vessel.imoNumber!.isEmpty ? '' : ' - IMO ${vessel.imoNumber}'}',
                                      );
                                      if (value != null) {
                                        setDialogState(() {
                                          dialogSelectedVessel = value;
                                          client.text = value.clientName ?? '';
                                        });
                                      }
                                    },
                                  ),
                                  labelStyle: const TextStyle(
                                    fontSize: 13,
                                    color: _AppColors.textSecondary,
                                  ),
                                  filled: true,
                                  fillColor: _AppColors.surface,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: _AppColors.divider,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: _AppColors.divider,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: _AppColors.ocean,
                                      width: 1.5,
                                    ),
                                  ),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                ),
                                items: vessels.map((vessel) {
                                  return DropdownMenuItem<Vessel>(
                                    value: vessel,
                                    child: Text(
                                      vessel.imoNumber == null ||
                                              vessel.imoNumber!.isEmpty
                                          ? vessel.vesselName
                                          : '${vessel.vesselName} — IMO ${vessel.imoNumber}',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setDialogState(() {
                                    dialogSelectedVessel = value;
                                    client.text = value?.clientName ?? '';
                                  });
                                },
                              ),
                            ),

                            if (dialogSelectedVessel != null)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: _AppColors.ocean.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _AppColors.ocean.withOpacity(0.18),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: _AppColors.navy,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.directions_boat_filled,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            dialogSelectedVessel!.vesselName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              color: _AppColors.textPrimary,
                                            ),
                                          ),
                                          Text(
                                            'IMO: ${dialogSelectedVessel!.imoNumber ?? "—"}  |  Flag: ${dialogSelectedVessel!.flag ?? "—"}  |  Class: ${dialogSelectedVessel!.classSociety ?? "—"}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: _AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            _dialogRow([_dialogField(client, 'Client Name')]),

                            const SizedBox(height: 4),
                            _sectionLabel('SCHEDULE'),

                            _dialogRow([
                              _dialogField(
                                startDate,
                                'Start Date *',
                                readOnly: true,
                                onTap: () => _pickDate(startDate),
                              ),
                              _dialogField(
                                endDate,
                                'End Date *',
                                readOnly: true,
                                onTap: () => _pickDate(endDate),
                              ),
                            ]),

                            const SizedBox(height: 4),
                            _sectionLabel('ASSIGNMENT'),

                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: DropdownButtonFormField<SurveyorOption?>(
                                value: assignedManager,
                                decoration: InputDecoration(
                                  labelText: 'Assign Manager (Optional)',
                                  suffixIcon: IconButton(
                                    tooltip: 'Search managers',
                                    icon: const Icon(Icons.search),
                                    onPressed: () async {
                                      final value =
                                          await _showSearchPicker<
                                            SurveyorOption
                                          >(
                                            title: 'Search Manager',
                                            items: managers,
                                            selected: assignedManager,
                                            label: (manager) =>
                                                manager.displayName,
                                          );
                                      if (value != null) {
                                        setDialogState(
                                          () => assignedManager = value,
                                        );
                                      }
                                    },
                                  ),
                                  labelStyle: const TextStyle(
                                    fontSize: 13,
                                    color: _AppColors.textSecondary,
                                  ),
                                  filled: true,
                                  fillColor: _AppColors.surface,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: _AppColors.divider,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: _AppColors.divider,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: _AppColors.ocean,
                                      width: 1.5,
                                    ),
                                  ),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                ),
                                items: [
                                  const DropdownMenuItem<SurveyorOption?>(
                                    value: null,
                                    child: Text('No manager assigned'),
                                  ),
                                  ...managers.map((manager) {
                                    return DropdownMenuItem<SurveyorOption?>(
                                      value: manager,
                                      child: Text(
                                        manager.displayName,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    );
                                  }),
                                ],
                                onChanged: (value) {
                                  setDialogState(() {
                                    assignedManager = value;
                                  });
                                },
                              ),
                            ),

                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: DropdownButtonFormField<SurveyorOption?>(
                                value: primarySurveyor,
                                decoration: InputDecoration(
                                  labelText: 'Primary Surveyor',
                                  suffixIcon: IconButton(
                                    tooltip: 'Search surveyors',
                                    icon: const Icon(Icons.search),
                                    onPressed: () async {
                                      final value =
                                          await _showSearchPicker<
                                            SurveyorOption
                                          >(
                                            title: 'Search Primary Surveyor',
                                            items: surveyors,
                                            selected: primarySurveyor,
                                            label: (surveyor) =>
                                                surveyor.displayName,
                                          );
                                      if (value != null) {
                                        setDialogState(() {
                                          primarySurveyor = value;
                                          if (secondarySurveyor?.id ==
                                              value.id) {
                                            secondarySurveyor = null;
                                          }
                                        });
                                      }
                                    },
                                  ),
                                  labelStyle: const TextStyle(
                                    fontSize: 13,
                                    color: _AppColors.textSecondary,
                                  ),
                                  filled: true,
                                  fillColor: _AppColors.surface,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: _AppColors.divider,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: _AppColors.divider,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: _AppColors.ocean,
                                      width: 1.5,
                                    ),
                                  ),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                ),
                                items: [
                                  const DropdownMenuItem<SurveyorOption?>(
                                    value: null,
                                    child: Text('Not Assign'),
                                  ),
                                  ...surveyors.map((surveyor) {
                                    return DropdownMenuItem<SurveyorOption?>(
                                      value: surveyor,
                                      child: Text(
                                        surveyor.displayName,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    );
                                  }),
                                ],
                                onChanged: (value) {
                                  setDialogState(() {
                                    primarySurveyor = value;
                                    if (secondarySurveyor?.id == value?.id) {
                                      secondarySurveyor = null;
                                    }
                                  });
                                },
                              ),
                            ),

                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: DropdownButtonFormField<SurveyorOption?>(
                                value: secondarySurveyor,
                                decoration: InputDecoration(
                                  labelText: 'Secondary Surveyor',
                                  suffixIcon: IconButton(
                                    tooltip: 'Search surveyors',
                                    icon: const Icon(Icons.search),
                                    onPressed: () async {
                                      final available = surveyors
                                          .where(
                                            (item) =>
                                                primarySurveyor == null ||
                                                item.id != primarySurveyor!.id,
                                          )
                                          .toList();
                                      final value =
                                          await _showSearchPicker<
                                            SurveyorOption
                                          >(
                                            title: 'Search Secondary Surveyor',
                                            items: available,
                                            selected: secondarySurveyor,
                                            label: (surveyor) =>
                                                surveyor.displayName,
                                          );
                                      if (value != null) {
                                        setDialogState(
                                          () => secondarySurveyor = value,
                                        );
                                      }
                                    },
                                  ),
                                  labelStyle: const TextStyle(
                                    fontSize: 13,
                                    color: _AppColors.textSecondary,
                                  ),
                                  filled: true,
                                  fillColor: _AppColors.surface,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: _AppColors.divider,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: _AppColors.divider,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: _AppColors.ocean,
                                      width: 1.5,
                                    ),
                                  ),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                ),
                                items: [
                                  const DropdownMenuItem<SurveyorOption?>(
                                    value: null,
                                    child: Text('Not Assign'),
                                  ),
                                  ...surveyors
                                      .where(
                                        (x) =>
                                            primarySurveyor == null ||
                                            x.id != primarySurveyor!.id,
                                      )
                                      .map((surveyor) {
                                        return DropdownMenuItem<
                                          SurveyorOption?
                                        >(
                                          value: surveyor,
                                          child: Text(
                                            surveyor.displayName,
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                        );
                                      }),
                                ],
                                onChanged: (value) {
                                  setDialogState(() {
                                    secondarySurveyor = value;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      decoration: const BoxDecoration(
                        color: _AppColors.surface,
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(16),
                        ),
                        border: Border(
                          top: BorderSide(color: _AppColors.divider, width: 1),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            style: TextButton.styleFrom(
                              foregroundColor: _AppColors.textSecondary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Create Job'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _AppColors.ocean,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                                vertical: 13,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () async {
                              if (jobNo.text.trim().isEmpty ||
                                  dialogSelectedVessel == null ||
                                  auditPort.text.trim().isEmpty ||
                                  startDate.text.trim().isEmpty ||
                                  endDate.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                      'Job number, vessel, audit port and dates are required.',
                                    ),
                                    backgroundColor: _AppColors.red,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                );
                                return;
                              }

                              try {
                                late SurveyJob job;

                                if (widget.surveyType == 'IHM Survey') {
                                  job = await ApiService.createIhmSurveyJob(
                                    jobNumber: jobNo.text.trim(),
                                    clientName: client.text.trim(),
                                    projectName: project.text.trim(),
                                    vesselId: dialogSelectedVessel!.id,
                                    siteName: auditPort.text.trim(),
                                    auditPort: auditPort.text.trim(),
                                    auditAddress: auditAddress.text.trim(),
                                    startDate: startDate.text.trim(),
                                    endDate: endDate.text.trim(),
                                    createdByUserId: userId,
                                    assignedManagerId: assignedManager?.id,
                                  );
                                } else {
                                  job = await ApiService.createExSurveyJob(
                                    jobNumber: jobNo.text.trim(),
                                    clientName: client.text.trim(),
                                    projectName: project.text.trim(),
                                    vesselId: dialogSelectedVessel!.id,
                                    siteName: auditPort.text.trim(),
                                    startDate: startDate.text.trim(),
                                    endDate: endDate.text.trim(),
                                    createdByUserId: userId,
                                    assignedManagerId: assignedManager?.id,
                                  );
                                }

                                await ApiService.assignSurveyJobSurveyors(
                                  surveyJobId: job.id,
                                  primarySurveyorUserId: primarySurveyor?.id,
                                  secondarySurveyorUserId:
                                      secondarySurveyor?.id,
                                  assignedByUserId: userId,
                                );

                                if (context.mounted) {
                                  Navigator.pop(context, true);
                                }
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(e.toString()),
                                    backgroundColor: _AppColors.red,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
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

    if (created == true) {
      await _loadJobs(showLoading: false);
    }
  }

  SurveyorOption? _findSurveyorOption(int surveyorUserId) {
    for (final surveyor in surveyors) {
      if (surveyor.id == surveyorUserId) return surveyor;
    }
    return null;
  }

  SurveyorOption? _findManagerOption(int managerUserId) {
    for (final manager in managers) {
      if (manager.id == managerUserId) return manager;
    }
    return null;
  }

  String _dateInput(DateTime? value) {
    if (value == null) return '';
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  Future<void> _showEditJobDialog(SurveyJob job) async {
    if (!job.canEdit) return;

    final clientName = TextEditingController(text: job.clientName ?? '');
    final projectName = TextEditingController(text: job.projectName ?? '');
    final auditPort = TextEditingController(
      text: job.auditPort ?? job.siteName ?? '',
    );
    final auditAddress = TextEditingController(text: job.auditAddress ?? '');
    final startDate = TextEditingController(text: _dateInput(job.startDate));
    final surveyDate = TextEditingController(text: _dateInput(job.surveyDate));
    final endDate = TextEditingController(text: _dateInput(job.endDate));
    Vessel? selectedJobVessel;
    for (final vessel in vessels) {
      if (vessel.id == job.vesselId) selectedJobVessel = vessel;
    }
    selectedJobVessel ??= job.vesselId == null
        ? null
        : Vessel(
            id: job.vesselId!,
            vesselName: job.vesselName ?? 'Selected vessel',
            imoNumber: job.imoNumber,
            status: 'Active',
          );
    final vesselOptions = [...vessels];
    if (selectedJobVessel != null &&
        !vesselOptions.any((vessel) => vessel.id == selectedJobVessel!.id)) {
      vesselOptions.add(selectedJobVessel!);
    }
    SurveyorOption? assignedManager = job.assignedManagerId == null
        ? null
        : _findManagerOption(job.assignedManagerId!);

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Edit ${job.jobNumber}'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<Vessel>(
                        value: selectedJobVessel,
                        decoration: const InputDecoration(
                          labelText: 'Vessel *',
                          border: OutlineInputBorder(),
                        ),
                        items: vesselOptions.map((vessel) {
                          return DropdownMenuItem<Vessel>(
                            value: vessel,
                            child: Text(
                              '${vessel.vesselName}${(vessel.imoNumber ?? '').isEmpty ? '' : ' - IMO ${vessel.imoNumber}'}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedJobVessel = value;
                            if ((value?.clientName ?? '').isNotEmpty) {
                              clientName.text = value!.clientName!;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: clientName,
                        decoration: const InputDecoration(
                          labelText: 'Client',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: projectName,
                        decoration: const InputDecoration(
                          labelText: 'Project',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: auditPort,
                        decoration: const InputDecoration(
                          labelText: 'Site / Audit Port *',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: auditAddress,
                        decoration: const InputDecoration(
                          labelText: 'Audit Address',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: startDate,
                        decoration: const InputDecoration(
                          labelText: 'Start Date *',
                          hintText: 'YYYY-MM-DD',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: surveyDate,
                        decoration: const InputDecoration(
                          labelText: 'Survey Date',
                          hintText: 'YYYY-MM-DD',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: endDate,
                        decoration: const InputDecoration(
                          labelText: 'End Date *',
                          hintText: 'YYYY-MM-DD',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<SurveyorOption?>(
                        value: assignedManager,
                        decoration: const InputDecoration(
                          labelText: 'Assigned Manager',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<SurveyorOption?>(
                            value: null,
                            child: Text('No manager assigned'),
                          ),
                          ...managers.map(
                            (manager) => DropdownMenuItem<SurveyorOption?>(
                              value: manager,
                              child: Text(manager.displayName),
                            ),
                          ),
                        ],
                        onChanged: (value) =>
                            setDialogState(() => assignedManager = value),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Save'),
                  onPressed: () async {
                    if (selectedJobVessel == null ||
                        auditPort.text.trim().isEmpty ||
                        startDate.text.trim().isEmpty ||
                        endDate.text.trim().isEmpty) {
                      AppDialog.warning(
                        context,
                        title: 'Missing details',
                        message:
                            'Vessel, audit port, start date and end date are required.',
                      );
                      return;
                    }

                    final result = await AppDialog.execute<bool>(
                      context,
                      loadingMessage: 'Updating job...',
                      action: () async {
                        await ApiService.updateSurveyJob(
                          jobId: job.id,
                          vesselId: selectedJobVessel!.id,
                          clientName: clientName.text.trim(),
                          projectName: projectName.text.trim(),
                          siteName: auditPort.text.trim(),
                          auditPort: auditPort.text.trim(),
                          auditAddress: auditAddress.text.trim(),
                          startDate: startDate.text.trim(),
                          surveyDate: surveyDate.text.trim().isEmpty
                              ? null
                              : surveyDate.text.trim(),
                          endDate: endDate.text.trim(),
                          assignedManagerId: assignedManager?.id,
                        );
                        await ApiService.updateSurveyJobAssignedManager(
                          surveyJobId: job.id,
                          assignedManagerId: assignedManager?.id,
                        );
                        return true;
                      },
                      successTitle: 'Job updated',
                      successMessage:
                          '${job.jobNumber} was updated successfully.',
                      errorTitle: 'Unable to update job',
                    );

                    if (result == true && dialogContext.mounted) {
                      Navigator.pop(dialogContext, true);
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );

    clientName.dispose();
    projectName.dispose();
    auditPort.dispose();
    auditAddress.dispose();
    startDate.dispose();
    surveyDate.dispose();
    endDate.dispose();

    if (saved == true && mounted) {
      await _loadJobs(showLoading: false);
    }
  }

  // ─── Assign Surveyor Dialog ─────────────────────────────────────────────────
  Future<void> _showAssignSurveyorDialog(SurveyJob job) async {
    final activeAssignments = job.activeAssignments;
    SurveyorOption? primarySurveyor = activeAssignments.isNotEmpty
        ? _findSurveyorOption(activeAssignments[0].surveyorUserId)
        : null;
    SurveyorOption? secondarySurveyor = activeAssignments.length > 1
        ? _findSurveyorOption(activeAssignments[1].surveyorUserId)
        : null;
    SurveyorOption? assignedManager = job.assignedManagerId == null
        ? null
        : _findManagerOption(job.assignedManagerId!);

    final assigned = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = context.watch<ThemeNotifier>().colors;

            return Dialog(
              backgroundColor: theme.bgCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 520,
                  maxHeight: MediaQuery.of(context).size.height * 0.86,
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
                          colors: [_AppColors.navy, _AppColors.slate],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
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
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.swap_horiz,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  job.hasAssignedSurveyors
                                      ? 'Reassign Surveyors'
                                      : 'Assign Surveyors',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  job.jobNumber,
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white54,
                              size: 20,
                            ),
                            onPressed: () => Navigator.pop(context, false),
                          ),
                        ],
                      ),
                    ),

                    Flexible(
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.fromLTRB(
                          24,
                          24,
                          24,
                          24 + MediaQuery.of(context).viewInsets.bottom,
                        ),
                        child: Column(
                          children: [
                            DropdownButtonFormField<SurveyorOption?>(
                              value: assignedManager,
                              decoration: InputDecoration(
                                labelText: 'Assign Manager (Optional)',
                                suffixIcon: IconButton(
                                  tooltip: 'Search managers',
                                  icon: const Icon(Icons.search),
                                  onPressed: () async {
                                    final value =
                                        await _showSearchPicker<SurveyorOption>(
                                          title: 'Search Manager',
                                          items: managers,
                                          selected: assignedManager,
                                          label: (manager) =>
                                              manager.displayName,
                                        );
                                    if (value != null) {
                                      setDialogState(
                                        () => assignedManager = value,
                                      );
                                    }
                                  },
                                ),
                                labelStyle: const TextStyle(
                                  fontSize: 13,
                                  color: _AppColors.textSecondary,
                                ),
                                filled: true,
                                fillColor: _AppColors.surface,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: _AppColors.divider,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: _AppColors.divider,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: _AppColors.ocean,
                                    width: 1.5,
                                  ),
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14,
                                ),
                              ),
                              items: [
                                const DropdownMenuItem<SurveyorOption?>(
                                  value: null,
                                  child: Text('No manager assigned'),
                                ),
                                ...managers.map((manager) {
                                  return DropdownMenuItem<SurveyorOption?>(
                                    value: manager,
                                    child: Text(
                                      manager.displayName,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  );
                                }),
                              ],
                              onChanged: (value) {
                                setDialogState(() {
                                  assignedManager = value;
                                });
                              },
                            ),

                            const SizedBox(height: 14),

                            DropdownButtonFormField<SurveyorOption?>(
                              value: primarySurveyor,
                              decoration: InputDecoration(
                                labelText: 'Primary Surveyor',
                                suffixIcon: IconButton(
                                  tooltip: 'Search surveyors',
                                  icon: const Icon(Icons.search),
                                  onPressed: () async {
                                    final value =
                                        await _showSearchPicker<SurveyorOption>(
                                          title: 'Search Primary Surveyor',
                                          items: surveyors,
                                          selected: primarySurveyor,
                                          label: (surveyor) =>
                                              surveyor.displayName,
                                        );
                                    if (value != null) {
                                      setDialogState(() {
                                        primarySurveyor = value;
                                        if (secondarySurveyor?.id == value.id) {
                                          secondarySurveyor = null;
                                        }
                                      });
                                    }
                                  },
                                ),
                                labelStyle: const TextStyle(
                                  fontSize: 13,
                                  color: _AppColors.textSecondary,
                                ),
                                filled: true,
                                fillColor: _AppColors.surface,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: _AppColors.divider,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: _AppColors.divider,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: _AppColors.ocean,
                                    width: 1.5,
                                  ),
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14,
                                ),
                              ),
                              items: [
                                const DropdownMenuItem<SurveyorOption?>(
                                  value: null,
                                  child: Text('Not Assign'),
                                ),
                                ...surveyors.map((surveyor) {
                                  return DropdownMenuItem<SurveyorOption?>(
                                    value: surveyor,
                                    child: Text(
                                      surveyor.displayName,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  );
                                }),
                              ],
                              onChanged: (value) {
                                setDialogState(() {
                                  primarySurveyor = value;
                                  if (secondarySurveyor?.id == value?.id) {
                                    secondarySurveyor = null;
                                  }
                                });
                              },
                            ),

                            const SizedBox(height: 14),

                            DropdownButtonFormField<SurveyorOption?>(
                              value: secondarySurveyor,
                              decoration: InputDecoration(
                                labelText: 'Secondary Surveyor',
                                suffixIcon: IconButton(
                                  tooltip: 'Search surveyors',
                                  icon: const Icon(Icons.search),
                                  onPressed: () async {
                                    final available = surveyors
                                        .where(
                                          (item) =>
                                              primarySurveyor == null ||
                                              item.id != primarySurveyor!.id,
                                        )
                                        .toList();
                                    final value =
                                        await _showSearchPicker<SurveyorOption>(
                                          title: 'Search Secondary Surveyor',
                                          items: available,
                                          selected: secondarySurveyor,
                                          label: (surveyor) =>
                                              surveyor.displayName,
                                        );
                                    if (value != null) {
                                      setDialogState(
                                        () => secondarySurveyor = value,
                                      );
                                    }
                                  },
                                ),
                                labelStyle: const TextStyle(
                                  fontSize: 13,
                                  color: _AppColors.textSecondary,
                                ),
                                filled: true,
                                fillColor: _AppColors.surface,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: _AppColors.divider,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: _AppColors.divider,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: _AppColors.ocean,
                                    width: 1.5,
                                  ),
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14,
                                ),
                              ),
                              items: [
                                const DropdownMenuItem<SurveyorOption?>(
                                  value: null,
                                  child: Text('Not Assign'),
                                ),
                                ...surveyors
                                    .where(
                                      (x) =>
                                          primarySurveyor == null ||
                                          x.id != primarySurveyor!.id,
                                    )
                                    .map((surveyor) {
                                      return DropdownMenuItem<SurveyorOption?>(
                                        value: surveyor,
                                        child: Text(
                                          surveyor.displayName,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      );
                                    }),
                              ],
                              onChanged: (value) {
                                setDialogState(() {
                                  secondarySurveyor = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                      decoration: const BoxDecoration(
                        color: _AppColors.surface,
                        border: Border(
                          top: BorderSide(color: _AppColors.divider, width: 1),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            style: TextButton.styleFrom(
                              foregroundColor: _AppColors.textSecondary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Save'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _AppColors.ocean,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 13,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () async {
                              final removingAll =
                                  primarySurveyor == null &&
                                  secondarySurveyor == null;
                              final confirmed = await AppDialog.confirm(
                                context,
                                title: removingAll
                                    ? 'Remove surveyors?'
                                    : 'Update assignment?',
                                message: removingAll
                                    ? 'Remove all surveyors from ${job.jobNumber}?'
                                    : 'Save the selected primary and secondary surveyors for ${job.jobNumber}?',
                                confirmLabel: removingAll
                                    ? 'Remove'
                                    : 'Save assignment',
                                destructive: removingAll,
                              );
                              if (!confirmed || !context.mounted) return;
                              final saved = await AppDialog.execute<bool>(
                                context,
                                loadingMessage: removingAll
                                    ? 'Removing surveyors...'
                                    : 'Updating assignment...',
                                action: () async {
                                  await ApiService.assignSurveyJobSurveyors(
                                    surveyJobId: job.id,
                                    primarySurveyorUserId: primarySurveyor?.id,
                                    secondarySurveyorUserId:
                                        secondarySurveyor?.id,
                                    assignedByUserId: userId,
                                  );
                                  await ApiService.updateSurveyJobAssignedManager(
                                    surveyJobId: job.id,
                                    assignedManagerId: assignedManager?.id,
                                  );
                                  return true;
                                },
                                errorTitle: 'Unable to update assignment',
                              );
                              if (saved == true && context.mounted) {
                                Navigator.pop(context, true);
                              }
                            },
                          ),
                        ],
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

    if (assigned == true) {
      _showMessage('Surveyors updated successfully.');
      await _loadJobs(showLoading: false);
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeNotifier>().colors;

    return Scaffold(
      backgroundColor: theme.bg,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final isIhm = widget.surveyType == 'IHM Survey';
    final theme = _theme;
    final headerColors = _isDarkTheme
        ? [theme.bg, theme.bgCard, theme.bgCardAlt]
        : [_AppColors.navy, _AppColors.deepBlue, _AppColors.slate];

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 24,
        right: 24,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: headerColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        boxShadow: const [
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
          // ── Row 1: Back | Icon | Title | Refresh | New Job ──
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
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isIhm ? Icons.assignment_outlined : Icons.engineering,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _screenTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Text(
                      'Survey Job Management',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Row 2: Stats capsule | Refresh | New Job ──
          Row(
            children: [
              if (!isLoading && errorMessage == null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.work_outline,
                        color: _AppColors.lightTeal,
                        size: 15,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${jobs.length} Job${jobs.length != 1 ? 's' : ''}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              // Refresh
              Tooltip(
                message: 'Refresh',
                child: Material(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: _loadJobs,
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(
                        Icons.refresh,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
              if (isAdmin) ...[
                const SizedBox(width: 8),
                Material(
                  color: _AppColors.ocean,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: _showCreateSurveyJobDialog,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, color: Colors.white, size: 18),
                          SizedBox(width: 5),
                          Text(
                            'New Job',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
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

          const SizedBox(height: 14),

          // ── Search Bar ──
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search by job number, client, vessel, status…',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.35)),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.white.withOpacity(0.4),
                  size: 20,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.close,
                          color: Colors.white.withOpacity(0.4),
                          size: 18,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Body ───────────────────────────────────────────────────────────────────
  Widget _buildBody() {
    final theme = _theme;

    if (isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: _AppColors.ocean,
              strokeWidth: 2.5,
            ),
            const SizedBox(height: 16),
            Text(
              'Loading jobs…',
              style: TextStyle(color: theme.textSecond, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _AppColors.red.withOpacity(0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: _AppColors.red, size: 48),
              const SizedBox(height: 14),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.textSecond, fontSize: 14),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _loadJobs,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _AppColors.ocean,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _filteredJobs;

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _searchQuery.isNotEmpty
                  ? Icons.search_off
                  : Icons.assignment_outlined,
              color: theme.textSecond,
              size: 56,
            ),
            const SizedBox(height: 14),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No jobs match your search'
                  : isAdmin
                  ? 'No $_screenTitle found.'
                  : 'No assigned $_screenTitle found.',
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try a different keyword'
                  : isAdmin
                  ? 'Tap "New Job" to create one'
                  : 'Contact your admin to get assigned',
              style: TextStyle(color: theme.textSecond, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadJobs,
      color: _AppColors.ocean,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _jobCard(filtered[index]),
      ),
    );
  }

  // ─── Job Card ────────────────────────────────────────────────────────────────
  Widget _jobCard(SurveyJob job) {
    final isIhm = widget.surveyType == 'IHM Survey';
    final displayStatus = job.displayStatus;
    final statusColor = _statusColor(displayStatus);
    final theme = _theme;

    return Container(
      decoration: BoxDecoration(
        color: theme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDarkTheme ? 0.18 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openJob(job),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Card Header ──
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_AppColors.navy, _AppColors.slate],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isIhm ? Icons.assignment_outlined : Icons.engineering,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job.jobNumber,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: theme.textPrimary,
                            ),
                          ),
                          if (job.clientName != null &&
                              job.clientName!.isNotEmpty)
                            Text(
                              job.clientName!,
                              style: TextStyle(
                                color: theme.textSecond,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Status chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _statusIcon(displayStatus),
                            size: 12,
                            color: statusColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            displayStatus,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                Divider(color: theme.divider, height: 1),
                const SizedBox(height: 12),

                // ── Info rows ──
                if (job.vesselName != null && job.vesselName!.isNotEmpty)
                  _cardInfoRow(
                    Icons.directions_boat_filled,
                    'Vessel',
                    job.vesselName!,
                  ),
                if (job.imoNumber != null && job.imoNumber!.isNotEmpty)
                  _cardInfoRow(Icons.tag, 'IMO', job.imoNumber!),
                if (job.siteName != null && job.siteName!.isNotEmpty)
                  _cardInfoRow(
                    Icons.location_on_outlined,
                    'Site',
                    job.siteName!,
                  ),

                const SizedBox(height: 12),

                _buildJobMetaGrid(job),

                // ── Action Buttons ──
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _actionButton(
                      icon: Icons.open_in_new,
                      label: 'Open',
                      color: _AppColors.ocean,
                      onTap: () => _openJob(job),
                    ),
                    if (job.canEdit)
                      _actionButton(
                        icon: Icons.edit_outlined,
                        label: 'Edit',
                        color: _AppColors.amber,
                        onTap: () => _showEditJobDialog(job),
                      ),
                    if (job.canEdit)
                      _actionButton(
                        icon: job.hasAssignedSurveyors
                            ? Icons.swap_horiz
                            : Icons.person_add_outlined,
                        label: job.hasAssignedSurveyors
                            ? 'Reassign Surveyor'
                            : 'Assign Surveyor',
                        color: _AppColors.teal,
                        onTap: () => _showAssignSurveyorDialog(job),
                      ),
                    if (job.canEdit)
                      _actionButton(
                        icon: Icons.delete_outline,
                        label: 'Delete',
                        color: _AppColors.red,
                        onTap: () => _deleteJob(job),
                      ),
                    if (isAdmin && isIhm) ...[
                      if ((job.vscpChecklistFilePath ?? '').trim().isNotEmpty)
                        _actionButton(
                          icon: Icons.visibility_outlined,
                          label: 'View VSCP Checklist',
                          color: _AppColors.deepPurple,
                          onTap: () => _viewVscpChecklist(job),
                        ),
                      _actionButton(
                        icon: Icons.table_chart_outlined,
                        label:
                            (job.vscpChecklistFilePath ?? '').trim().isNotEmpty
                            ? 'Replace VSCP Checklist Template'
                            : 'Upload VSCP Checklist Template',
                        color: _AppColors.success,
                        onTap: () => _uploadIhmExcel(job),
                      ),
                      _actionButton(
                        icon: Icons.map_outlined,
                        label: 'Upload Layouts',
                        color: _AppColors.amber,
                        onTap: () => _uploadIhmLayout(job),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJobMetaGrid(SurveyJob job) {
    final primaryName = job.primarySurveyorName;
    final secondaryName = job.secondarySurveyorName;
    final canEditSurveyDate = _canEditSurveyDate(job);

    final tiles = <Widget>[
      _metaTile(
        label: 'Survey Date',
        value: job.surveyDate == null
            ? 'Not selected'
            : _formatSurveyDate(job.surveyDate!),
        icon: Icons.calendar_today_outlined,
        color: _AppColors.ocean,
        onTap: canEditSurveyDate ? () => _pickAndSaveSurveyDate(job) : null,
        actionText: canEditSurveyDate
            ? (job.surveyDate == null ? 'Select' : 'Change')
            : null,
      ),
      if (job.assignedManagerName != null &&
          job.assignedManagerName!.trim().isNotEmpty)
        _metaTile(
          label: 'Assigned Manager',
          value: job.assignedManagerName!,
          icon: Icons.admin_panel_settings_outlined,
          color: _AppColors.purple,
        ),
      if (primaryName != null && primaryName.trim().isNotEmpty)
        _metaTile(
          label: 'Primary Surveyor',
          value: primaryName,
          icon: Icons.person_outline,
          color: _AppColors.success,
        ),
      if (secondaryName != null && secondaryName.trim().isNotEmpty)
        _metaTile(
          label: 'Secondary Surveyor',
          value: secondaryName,
          icon: Icons.person_outline,
          color: _AppColors.success,
        ),
      if ((primaryName == null || primaryName.trim().isEmpty) &&
          (secondaryName == null || secondaryName.trim().isEmpty) &&
          job.assignedSurveyorName != null &&
          job.assignedSurveyorName!.trim().isNotEmpty)
        _metaTile(
          label: 'Surveyor',
          value: job.assignedSurveyorName!,
          icon: Icons.person_outline,
          color: _AppColors.success,
        ),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          for (int i = 0; i < tiles.length; i++) ...[
            Expanded(child: tiles[i]),
            if (i != tiles.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _metaTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
    String? actionText,
  }) {
    final content = Container(
      constraints: const BoxConstraints(minHeight: 62),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9.5,
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (actionText != null) ...[
                const SizedBox(width: 4),
                Text(
                  actionText,
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );

    if (onTap == null) return content;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: content,
    );
  }

  Widget _assignmentLine(String label, String name) {
    return Row(
      children: [
        const Icon(Icons.person_outline, size: 14, color: _AppColors.success),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 12,
            color: _AppColors.success,
            fontWeight: FontWeight.w800,
          ),
        ),
        Expanded(
          child: Text(
            name,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: _AppColors.success,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _cardInfoRow(IconData icon, String label, String value) {
    final theme = _theme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 15, color: theme.textSecond),
          const SizedBox(width: 8),
          SizedBox(
            width: 52,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: theme.textSecond,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: theme.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // helper kept for _dialogField flex param signature compat
  // ignore: unused_element
  Widget _input(TextEditingController controller, String label) {
    final theme = _theme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        style: TextStyle(fontSize: 14, color: theme.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: theme.textSecond),
          filled: true,
          fillColor: theme.bgCardAlt,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: theme.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: theme.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _AppColors.ocean, width: 1.5),
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}
