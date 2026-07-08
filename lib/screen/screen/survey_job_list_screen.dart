import 'package:Auras/ThemeNotifier.dart';
import 'package:Auras/ex_survey/ex_survey_screen.dart';
import 'package:Auras/model/survey_job.dart';
import 'package:Auras/model/vessel.dart';
import 'package:Auras/screen/screen/ihm_survey_screen.dart';
import 'package:Auras/service/api_service.dart';
import 'package:Auras/service/survey_job_offline_service.dart';
import 'package:Auras/utils/app_dialog.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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
  const SurveyJobListScreen({super.key, required this.surveyType});

  @override
  State<SurveyJobListScreen> createState() => _SurveyJobListScreenState();
}

class _SurveyJobListScreenState extends State<SurveyJobListScreen> {
  bool isLoading = true;
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

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SurveyJob> get _filteredJobs {
    if (_searchQuery.isEmpty) return jobs;
    final q = _searchQuery.toLowerCase();
    return jobs.where((j) {
      return j.jobNumber.toLowerCase().contains(q) ||
          (j.clientName ?? '').toLowerCase().contains(q) ||
          (j.vesselName ?? '').toLowerCase().contains(q) ||
          (j.siteName ?? '').toLowerCase().contains(q) ||
          j.status.toLowerCase().contains(q);
    }).toList();
  }

  void _openJob(SurveyJob job) {
    print('OPEN JOB ID = ${job.id}');

    if (widget.surveyType == 'IHM Survey') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => IHMSurveyScreen(userId: userId, job: job),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ExSurveyScreen(job: job)),
    );
  }

  Future<void> _uploadIhmExcel(SurveyJob job) async {
    if (job.id <= 0) {
      _showMessage('Job ID missing. Please create/save the job first.');
      return;
    }
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
      _showMessage('Excel checklist uploaded successfully.');
      await _loadJobs();
    } catch (e) {
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
      await _loadJobs();
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
      await _loadJobs();
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  void _showMessage(String message) {
    final normalized = message.replaceFirst('Exception: ', '');
    final failed = normalized.toLowerCase().contains('fail') ||
        normalized.toLowerCase().contains('error') ||
        normalized.toLowerCase().contains('missing');
    if (failed) {
      AppDialog.error(context, message: normalized);
    } else {
      AppDialog.success(
        context,
        title: 'Completed',
        message: normalized,
      );
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
      message:
          'Delete ${job.jobNumber}? This action cannot be undone.',
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
      await _loadJobs();
    }
  }
String _formatSurveyDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day-$month-${date.year}';
}

Future<void> _pickAndSaveSurveyDate(SurveyJob job) async {
  final picked = await showDatePicker(
    context: context,
    initialDate: job.surveyDate ?? DateTime.now(),
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
  );

  if (picked == null) return;

  try {
    await ApiService.updateSurveyDate(
      surveyJobId: job.id,
      surveyDate: picked,
    );

    _showMessage('Survey date saved successfully.');
    await _loadJobs();
  } catch (e) {
    _showMessage(e.toString());
  }
}
  Future<void> _loadJobs() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getInt('userId') ?? 0;
      final role = prefs.getString('userRole') ?? '';
      isAdmin =
          role.toLowerCase() == 'admin' || role.toLowerCase() == 'manager';

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

      final result = await SurveyJobOfflineService.getSurveyJobsByType(
        surveyType: widget.surveyType,
        isAdmin: isAdmin,
        userId: userId,
      );

      if (!mounted) return;
      setState(() {
        jobs = result;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage =
            'No saved offline jobs found. Please connect once to load your jobs.';
        isLoading = false;
      });
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Draft':
        return _AppColors.textMuted;
      case 'Assigned':
        return _AppColors.ocean;
      case 'InProgress':
        return _AppColors.amber;
      case 'Submitted':
        return _AppColors.deepPurple;
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
              insetPadding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 720,
                  maxHeight: 700,
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
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
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
      await _loadJobs();
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
              insetPadding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
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

                    Padding(
                      padding: const EdgeInsets.all(24),
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

                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
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
                              final removingAll = primarySurveyor == null &&
                                  secondarySurveyor == null;
                              final confirmed = await AppDialog.confirm(
                                context,
                                title: removingAll
                                    ? 'Remove surveyors?'
                                    : 'Update assignment?',
                                message: removingAll
                                    ? 'Remove all surveyors from ${job.jobNumber}?'
                                    : 'Save the selected primary and secondary surveyors for ${job.jobNumber}?',
                                confirmLabel:
                                    removingAll ? 'Remove' : 'Save assignment',
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
                                    primarySurveyorUserId:
                                        primarySurveyor?.id,
                                    secondarySurveyorUserId:
                                        secondarySurveyor?.id,
                                    assignedByUserId: userId,
                                  );
                                  await ApiService
                                      .updateSurveyJobAssignedManager(
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
      await _loadJobs();
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
                      '${widget.surveyType} Jobs',
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
                  ? 'No ${widget.surveyType} jobs created yet.'
                  : 'No assigned ${widget.surveyType} jobs found.',
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
    final statusColor = _statusColor(job.status);
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
                            _statusIcon(job.status),
                            size: 12,
                            color: statusColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            job.status,
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
                    if (isAdmin)
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
                    if (isAdmin)
                      _actionButton(
                        icon: Icons.delete_outline,
                        label: 'Delete',
                        color: _AppColors.red,
                        onTap: () => _deleteJob(job),
                      ),
                    if (isAdmin && isIhm) ...[
                      _actionButton(
                        icon: Icons.table_chart_outlined,
                        label: 'Upload Excel',
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

  final tiles = <Widget>[
    _metaTile(
      label: 'Survey Date',
      value: job.surveyDate == null
          ? 'Not selected'
          : _formatSurveyDate(job.surveyDate!),
      icon: Icons.calendar_today_outlined,
      color: _AppColors.ocean,
      onTap: isAdmin ? null : () => _pickAndSaveSurveyDate(job),
      actionText: isAdmin ? null : (job.surveyDate == null ? 'Select' : 'Change'),
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
