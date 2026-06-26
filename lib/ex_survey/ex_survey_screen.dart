import 'dart:io';

import 'package:Auras/ex_survey/ex_equipment_inspection_screen.dart';
import 'package:Auras/ex_survey/ex_survey_models.dart';
import 'package:Auras/ex_survey/ex_survey_service.dart';
import 'package:Auras/utils/app_dialog.dart';
import 'package:Auras/model/survey_job.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class ExSurveyScreen extends StatefulWidget {
  final SurveyJob job;

  const ExSurveyScreen({super.key, required this.job});

  @override
  State<ExSurveyScreen> createState() => _ExSurveyScreenState();
}

class _ExSurveyScreenState extends State<ExSurveyScreen> {
  static const _navy = Color(0xFF102A43);
  static const _blue = Color(0xFF1976D2);
  static const _teal = Color(0xFF00897B);
  static const _surface = Color(0xFFF4F7FB);

  bool _loading = true;
  String? _error;
  String _role = '';
  String _status = '';
  String _search = '';
  ExSurveySummary? _summary;
  List<ExEquipment> _equipment = [];
  List<ExDefect> _defects = [];
  List<ExSurveyDocument> _documents = [];

  bool get _canManage => _role == 'admin' || _role == 'manager';

  @override
  void initState() {
    super.initState();
    _status = widget.job.status;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final values = await Future.wait([
        ExSurveyService.fetchSummary(widget.job.id),
        ExSurveyService.fetchEquipment(widget.job.id),
        ExSurveyService.fetchDefects(widget.job.id),
        ExSurveyService.fetchDocuments(widget.job.id),
      ]);
      if (!mounted) return;
      final summary = values[0] as ExSurveySummary;
      setState(() {
        _role = (prefs.getString('userRole') ?? '').toLowerCase();
        _summary = summary;
        _status = summary.status;
        _equipment = values[1] as List<ExEquipment>;
        _defects = values[2] as List<ExDefect>;
        _documents = values[3] as List<ExSurveyDocument>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Map<String, List<ExEquipment>> get _groupedEquipment {
    final query = _search.trim().toLowerCase();
    final visible = _equipment.where((item) {
      if (!item.isActive) return false;
      if (query.isEmpty) return true;
      return item.equipmentId.toLowerCase().contains(query) ||
          item.area.toLowerCase().contains(query) ||
          (item.location ?? '').toLowerCase().contains(query) ||
          (item.description ?? '').toLowerCase().contains(query) ||
          (item.equipmentType ?? '').toLowerCase().contains(query);
    });
    final grouped = <String, List<ExEquipment>>{};
    for (final item in visible) {
      grouped.putIfAbsent(item.area, () => []).add(item);
    }
    final keys = grouped.keys.toList()..sort();
    return {for (final key in keys) key: grouped[key]!};
  }

  Future<void> _addEquipment() async {
    final equipmentId = TextEditingController();
    final area = TextEditingController();
    final location = TextEditingController();
    final type = TextEditingController();
    final description = TextEditingController();
    final rfid = TextEditingController();
    final manufacturer = TextEditingController();
    final model = TextEditingController();
    final serial = TextEditingController();

    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add equipment'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(equipmentId, 'Equipment ID *', Icons.tag),
                _field(area, 'Area *', Icons.grid_view_outlined),
                _field(location, 'Location', Icons.location_on_outlined),
                _field(type, 'Equipment type', Icons.category_outlined),
                _field(
                  description,
                  'Description',
                  Icons.description_outlined,
                ),
                _field(rfid, 'RFID tag (optional)', Icons.nfc_outlined),
                _field(
                  manufacturer,
                  'Manufacturer',
                  Icons.factory_outlined,
                ),
                _field(model, 'Model', Icons.memory_outlined),
                _field(serial, 'Serial number', Icons.numbers),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (equipmentId.text.trim().isEmpty ||
                  area.text.trim().isEmpty) {
                return;
              }
              Navigator.pop(dialogContext, {
                'equipmentId': equipmentId.text.trim(),
                'area': area.text.trim(),
                'location': location.text.trim(),
                'equipmentType': type.text.trim(),
                'description': description.text.trim(),
                'rfidTag': rfid.text.trim(),
                'manufacturer': manufacturer.text.trim(),
                'model': model.text.trim(),
                'serialNumber': serial.text.trim(),
              });
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    for (final controller in [
      equipmentId,
      area,
      location,
      type,
      description,
      rfid,
      manufacturer,
      model,
      serial,
    ]) {
      controller.dispose();
    }
    if (payload == null) return;

    try {
      await ExSurveyService.createEquipment(widget.job.id, payload);
      await _load();
      if (mounted) _message('Equipment added.');
    } catch (error) {
      if (mounted) _message(error.toString(), error: true);
    }
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
        ),
      ),
    );
  }

  Future<void> _openEquipment(ExEquipment equipment) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExEquipmentInspectionScreen(equipment: equipment),
      ),
    );
    await _load();
  }

  Future<void> _uploadDocument() async {
    final documentType = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Choose document type'),
        children: [
          _documentTypeTile(
            dialogContext,
            'Drawing',
            'Hazardous area drawing / layout',
            Icons.map_outlined,
          ),
          _documentTypeTile(
            dialogContext,
            'EquipmentRegister',
            'HAER / equipment register',
            Icons.table_chart_outlined,
          ),
          _documentTypeTile(
            dialogContext,
            'ChecklistTemplate',
            'Standard or client checklist',
            Icons.fact_check_outlined,
          ),
        ],
      ),
    );
    if (documentType == null) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'xlsx', 'xls', 'csv'],
      withData: true,
    );
    final file = result?.files.single;
    if (file?.bytes == null) return;

    try {
      await ExSurveyService.uploadDocument(
        jobId: widget.job.id,
        documentType: documentType,
        bytes: file!.bytes!,
        fileName: file.name,
      );
      await _load();
      if (mounted) _message('Project document uploaded.');
    } catch (error) {
      if (mounted) _message(error.toString(), error: true);
    }
  }

  Widget _documentTypeTile(
    BuildContext context,
    String value,
    String label,
    IconData icon,
  ) {
    return SimpleDialogOption(
      onPressed: () => Navigator.pop(context, value),
      child: ListTile(
        leading: Icon(icon, color: _blue),
        title: Text(label),
      ),
    );
  }

  Future<void> _openDocument(ExSurveyDocument document) async {
    final uri = Uri.parse(ExSurveyService.publicUrl(document.filePath));
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) _message('Could not open the document.', error: true);
    }
  }

  void _showDocuments() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Ex-Survey project files',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _uploadDocument();
                    },
                    icon: const Icon(Icons.upload_file),
                  ),
                ],
              ),
              if (_documents.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Text('No drawings or templates uploaded yet.'),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _documents.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final document = _documents[index];
                      return ListTile(
                        leading: const Icon(
                          Icons.description_outlined,
                          color: _blue,
                        ),
                        title: Text(document.originalFileName),
                        subtitle: Text(_documentTypeLabel(document.documentType)),
                        trailing: const Icon(Icons.open_in_new),
                        onTap: () => _openDocument(document),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _documentTypeLabel(String value) {
    return switch (value) {
      'EquipmentRegister' => 'Equipment register',
      'ChecklistTemplate' => 'Checklist template',
      _ => 'Hazardous area drawing',
    };
  }

  void _showDefects() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        maxChildSize: 0.92,
        builder: (context, controller) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Defect register',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _defects.isEmpty
                    ? const Center(child: Text('No findings recorded.'))
                    : ListView.separated(
                        controller: controller,
                        itemCount: _defects.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final defect = _defects[index];
                          return Card(
                            elevation: 0,
                            child: ListTile(
                              leading: Icon(
                                defect.status == 'Open'
                                    ? Icons.error_outline
                                    : Icons.task_alt,
                                color: defect.status == 'Open'
                                    ? Colors.orange
                                    : Colors.green,
                              ),
                              title: Text(
                                defect.defectNumber ??
                                    'Finding #${defect.id}',
                              ),
                              subtitle: Text(
                                '${defect.equipmentCode ?? "Equipment"}\n${defect.description}',
                              ),
                              isThreeLine: true,
                              trailing: Text(defect.status),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitForQc() async {
    try {
      await ExSurveyService.submitForQc(widget.job.id);
      await _load();
      if (mounted) _message('Inspection submitted for QC review.');
    } catch (error) {
      if (mounted) _message(error.toString(), error: true);
    }
  }

  Future<void> _review(String status) async {
    try {
      await ExSurveyService.review(widget.job.id, status);
      await _load();
      if (mounted) {
        _message(status == 'Approved' ? 'Survey approved.' : 'Survey returned.');
      }
    } catch (error) {
      if (mounted) _message(error.toString(), error: true);
    }
  }

  Future<void> _generateReport() async {
    try {
      _message('Preparing Ex-Survey report...');
      final bytes = await ExSurveyService.generateReport(widget.job.id);
      final directory = await getTemporaryDirectory();
      final safeJob = widget.job.jobNumber.replaceAll(
        RegExp(r'[^A-Za-z0-9_-]'),
        '-',
      );
      final file = File('${directory.path}/Ex-Survey-$safeJob.pdf');
      await file.writeAsBytes(bytes, flush: true);
      await _load();
      await OpenFile.open(file.path);
    } catch (error) {
      if (mounted) _message(error.toString(), error: true);
    }
  }

  void _message(String value, {bool error = false}) {
    if (error) {
      AppDialog.error(context, message: value);
    } else {
      AppDialog.success(
        context,
        title: 'Completed',
        message: value,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.job.jobNumber,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const Text(
              'Ex-Survey workspace',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Project files',
            onPressed: _showDocuments,
            icon: Badge(
              label: Text('${_documents.length}'),
              child: const Icon(Icons.folder_copy_outlined),
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addEquipment,
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Equipment'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _errorState()
          : RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _header()),
                  SliverToBoxAdapter(child: _summaryCards()),
                  SliverToBoxAdapter(child: _actions()),
                  SliverToBoxAdapter(child: _searchField()),
                  ..._areaSlivers(),
                  const SliverToBoxAdapter(child: SizedBox(height: 96)),
                ],
              ),
            ),
    );
  }

  Widget _header() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_navy, Color(0xFF264E70)]),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.job.projectName ??
                      widget.job.vesselName ??
                      widget.job.siteName ??
                      'Ex-Survey project',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _status,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            [
              widget.job.clientName,
              widget.job.vesselName ?? widget.job.siteName,
            ].whereType<String>().where((value) => value.isNotEmpty).join(' | '),
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _summaryCards() {
    final summary = _summary!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _summaryCard('Areas', summary.areaCount, Icons.grid_view_outlined),
          _summaryCard(
            'Equipment',
            summary.equipmentCount,
            Icons.precision_manufacturing_outlined,
          ),
          _summaryCard(
            'Inspected',
            summary.answeredEquipmentCount,
            Icons.fact_check_outlined,
          ),
          _summaryCard(
            'Open defects',
            summary.openDefectCount,
            Icons.report_problem_outlined,
            color: summary.openDefectCount > 0 ? Colors.orange : _teal,
            onTap: _showDefects,
          ),
          _summaryCard(
            'Photos',
            summary.photoCount,
            Icons.photo_camera_outlined,
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(
    String label,
    int value,
    IconData icon, {
    Color color = _blue,
    VoidCallback? onTap,
  }) {
    return SizedBox(
      width: 122,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(height: 8),
                Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.blueGrey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actions() {
    final actions = <Widget>[
      OutlinedButton.icon(
        onPressed: _showDocuments,
        icon: const Icon(Icons.folder_open_outlined),
        label: const Text('Project files'),
      ),
      OutlinedButton.icon(
        onPressed: _showDefects,
        icon: const Icon(Icons.warning_amber_outlined),
        label: const Text('Defect register'),
      ),
    ];
    if (_status != 'Submitted' &&
        _status != 'Approved' &&
        _status != 'ReportGenerated' &&
        _status != 'Closed') {
      actions.add(
        FilledButton.icon(
          onPressed: _submitForQc,
          icon: const Icon(Icons.send_outlined),
          label: const Text('Submit to QC'),
        ),
      );
    }
    if (_canManage && _status == 'Submitted') {
      actions.add(
        OutlinedButton.icon(
          onPressed: () => _review('QcReturned'),
          icon: const Icon(Icons.undo),
          label: const Text('Return'),
        ),
      );
      actions.add(
        FilledButton.icon(
          onPressed: () => _review('Approved'),
          icon: const Icon(Icons.verified_outlined),
          label: const Text('Approve'),
        ),
      );
    }
    if (_status == 'Approved' || _status == 'ReportGenerated') {
      actions.add(
        FilledButton.icon(
          onPressed: _generateReport,
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('Generate report'),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Wrap(spacing: 8, runSpacing: 8, children: actions),
    );
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
      child: TextField(
        onChanged: (value) => setState(() => _search = value),
        decoration: const InputDecoration(
          hintText: 'Search area or equipment',
          prefixIcon: Icon(Icons.search),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  List<Widget> _areaSlivers() {
    final grouped = _groupedEquipment;
    if (grouped.isEmpty) {
      return [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 42, horizontal: 24),
            child: Column(
              children: [
                Icon(
                  Icons.precision_manufacturing_outlined,
                  size: 48,
                  color: Colors.blueGrey,
                ),
                SizedBox(height: 12),
                Text(
                  'No equipment found. Add the first item to start the area-wise inspection.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ];
    }

    final slivers = <Widget>[];
    for (final entry in grouped.entries) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              children: [
                const Icon(Icons.grid_view_outlined, size: 18, color: _teal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.key,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${entry.value.length} item${entry.value.length == 1 ? "" : "s"}',
                  style: const TextStyle(color: Colors.blueGrey),
                ),
              ],
            ),
          ),
        ),
      );
      slivers.add(
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _equipmentCard(entry.value[index]),
            childCount: entry.value.length,
          ),
        ),
      );
    }
    return slivers;
  }

  Widget _equipmentCard(ExEquipment item) {
    final defectCount = _defects
        .where((defect) => defect.equipmentId == item.id)
        .length;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 5, 16, 5),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.blueGrey.shade100),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.precision_manufacturing_outlined,
            color: _blue,
          ),
        ),
        title: Text(
          item.equipmentId,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          [
            item.equipmentType,
            item.location,
            item.description,
          ].whereType<String>().where((value) => value.isNotEmpty).join(' | '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (defectCount > 0)
              Badge(
                label: Text('$defectCount'),
                backgroundColor: Colors.orange,
                child: const Icon(Icons.warning_amber_outlined),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => _openEquipment(item),
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
