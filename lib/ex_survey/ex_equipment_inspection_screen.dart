import 'dart:io';

import 'package:Auras/ex_survey/ex_survey_models.dart';
import 'package:Auras/ex_survey/ex_survey_offline_service.dart';
import 'package:Auras/utils/app_dialog.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ExEquipmentInspectionScreen extends StatefulWidget {
  final ExEquipment equipment;

  const ExEquipmentInspectionScreen({super.key, required this.equipment});

  @override
  State<ExEquipmentInspectionScreen> createState() =>
      _ExEquipmentInspectionScreenState();
}

class _ExEquipmentInspectionScreenState
    extends State<ExEquipmentInspectionScreen> {
  static const _navy = Color(0xFF102A43);
  static const _blue = Color(0xFF1976D2);
  static const _surface = Color(0xFFF4F7FB);

  String _inspectionType = 'Visual';
  bool _loadingChecklist = true;
  bool _loadingEvidence = true;
  List<ExChecklistQuestion> _questions = [];
  List<ExDefect> _defects = [];
  List<ExSurveyPhoto> _photos = [];
  final Map<int, String> _results = {};
  final Map<int, TextEditingController> _comments = {};

  @override
  void initState() {
    super.initState();
    _loadChecklist();
    _loadEvidence();
  }

  @override
  void dispose() {
    for (final controller in _comments.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadChecklist() async {
    setState(() => _loadingChecklist = true);
    try {
      final values = await Future.wait([
        ExSurveyOfflineService.fetchQuestions(_inspectionType),
        ExSurveyOfflineService.fetchAnswers(widget.equipment.id, _inspectionType),
      ]);
      final questions = values[0] as List<ExChecklistQuestion>;
      final answers = values[1] as List<ExChecklistAnswer>;
      final answerByQuestion = {
        for (final answer in answers) answer.questionId: answer,
      };

      for (final controller in _comments.values) {
        controller.dispose();
      }
      _comments.clear();
      _results.clear();
      for (final question in questions) {
        final answer = answerByQuestion[question.id];
        if (answer != null) _results[question.id] = answer.result;
        _comments[question.id] = TextEditingController(
          text: answer?.comment ?? '',
        );
      }

      if (!mounted) return;
      setState(() {
        _questions = questions;
        _loadingChecklist = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingChecklist = false);
      _message(error.toString(), error: true);
    }
  }

  Future<void> _loadEvidence() async {
    setState(() => _loadingEvidence = true);
    try {
      final values = await Future.wait([
        ExSurveyOfflineService.fetchDefects(widget.equipment.surveyJobId),
        ExSurveyOfflineService.fetchPhotos(
          widget.equipment.surveyJobId,
          equipmentId: widget.equipment.id,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _defects = (values[0] as List<ExDefect>)
            .where((item) => item.equipmentId == widget.equipment.id)
            .toList();
        _photos = values[1] as List<ExSurveyPhoto>;
        _loadingEvidence = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingEvidence = false);
      _message(error.toString(), error: true);
    }
  }

  Future<void> _saveAnswer(ExChecklistQuestion question) async {
    final result = _results[question.id];
    final comment = _comments[question.id]!.text.trim();
    if (result == null) {
      _message('Select Pass, Fail, or N/A first.', error: true);
      return;
    }
    if (result == 'Fail' && comment.isEmpty) {
      _message('A comment is required for a failed point.', error: true);
      return;
    }

    try {
      await ExSurveyOfflineService.saveAnswer(
        equipmentId: widget.equipment.id,
        questionId: question.id,
        result: result,
        comment: comment.isEmpty ? null : comment,
      );
      if (!mounted) return;
      _message('${question.questionCode} saved.');
    } catch (error) {
      if (!mounted) return;
      _message(error.toString(), error: true);
    }
  }

  Future<void> _addDefect() async {
    final defectNo = TextEditingController();
    final description = TextEditingController();
    final recommendation = TextEditingController();
    var severity = 'Minor';

    final payload = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New finding'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: defectNo,
                  decoration: const InputDecoration(labelText: 'Defect number'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: severity,
                  decoration: const InputDecoration(labelText: 'Severity'),
                  items: const [
                    DropdownMenuItem(value: 'Minor', child: Text('Minor')),
                    DropdownMenuItem(value: 'Major', child: Text('Major')),
                    DropdownMenuItem(
                      value: 'Critical',
                      child: Text('Critical'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => severity = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: description,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Finding / defect *',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: recommendation,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Recommendation',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (description.text.trim().isEmpty) return;
                Navigator.pop(dialogContext, {
                  'defectNumber': defectNo.text.trim(),
                  'description': description.text.trim(),
                  'severity': severity,
                  'recommendation': recommendation.text.trim(),
                });
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    defectNo.dispose();
    description.dispose();
    recommendation.dispose();
    if (payload == null) return;

    try {
      await ExSurveyOfflineService.createDefect(
        equipmentId: widget.equipment.id,
        defectNumber: payload['defectNumber'],
        description: payload['description']!,
        severity: payload['severity']!,
        recommendation: payload['recommendation'],
      );
      await _loadEvidence();
      if (mounted) _message('Finding added.');
    } catch (error) {
      if (mounted) _message(error.toString(), error: true);
    }
  }

  Future<void> _setDefectStatus(ExDefect defect, String status) async {
    try {
      await ExSurveyOfflineService.updateDefectStatus(defect.id, status);
      await _loadEvidence();
    } catch (error) {
      if (mounted) _message(error.toString(), error: true);
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final image = await ImagePicker().pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 1800,
    );
    if (image == null) return;

    try {
      await ExSurveyOfflineService.uploadPhoto(
        jobId: widget.equipment.surveyJobId,
        equipmentId: widget.equipment.id,
        bytes: await image.readAsBytes(),
        fileName: image.name,
      );
      await _loadEvidence();
      if (mounted) _message('Evidence photo uploaded.');
    } catch (error) {
      if (mounted) _message(error.toString(), error: true);
    }
  }

  void _showPhotoSource() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _message(String value, {bool error = false}) {
    if (error) {
      AppDialog.error(context, message: value);
    } else {
      AppDialog.success(
        context,
        title: 'Saved',
        message: value,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: _surface,
        appBar: AppBar(
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.equipment.equipmentId,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                widget.equipment.area,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: [
              Tab(text: 'Checklist', icon: Icon(Icons.fact_check_outlined)),
              Tab(text: 'Findings', icon: Icon(Icons.report_problem_outlined)),
              Tab(text: 'Photos', icon: Icon(Icons.photo_camera_outlined)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _checklistTab(),
            _findingsTab(),
            _photosTab(),
          ],
        ),
      ),
    );
  }

  Widget _checklistTab() {
    if (_loadingChecklist) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadChecklist,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _equipmentHeader(),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _inspectionType,
            decoration: const InputDecoration(
              labelText: 'Inspection level',
              prefixIcon: Icon(Icons.manage_search),
            ),
            items: const [
              DropdownMenuItem(value: 'Visual', child: Text('Visual')),
              DropdownMenuItem(value: 'Close', child: Text('Close')),
              DropdownMenuItem(value: 'Detailed', child: Text('Detailed')),
            ],
            onChanged: (value) {
              if (value == null || value == _inspectionType) return;
              _inspectionType = value;
              _loadChecklist();
            },
          ),
          const SizedBox(height: 14),
          if (_questions.isEmpty)
            const _EmptyState(
              icon: Icons.playlist_add_check_circle_outlined,
              text: 'No checklist questions configured.',
            )
          else
            ..._questions.map(_questionCard),
        ],
      ),
    );
  }

  Widget _equipmentHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_navy, Color(0xFF264E70)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.equipment.description ??
                widget.equipment.equipmentType ??
                'Ex equipment',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill(Icons.location_on_outlined, widget.equipment.location),
              _pill(Icons.category_outlined, widget.equipment.equipmentType),
              _pill(Icons.nfc_outlined, widget.equipment.rfidTag),
            ],
          ),
        ],
      ),
    );
  }

  Widget _questionCard(ExChecklistQuestion question) {
    final result = _results[question.id];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.blueGrey.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    question.questionCode,
                    style: const TextStyle(
                      color: _blue,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    question.questionText,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              children: ['Pass', 'Fail', 'NA'].map((value) {
                final color = value == 'Pass'
                    ? Colors.green
                    : value == 'Fail'
                    ? Colors.red
                    : Colors.blueGrey;
                return ChoiceChip(
                  label: Text(value == 'NA' ? 'N/A' : value),
                  selected: result == value,
                  selectedColor: color.withOpacity(0.18),
                  labelStyle: TextStyle(
                    color: result == value ? color.shade700 : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: (_) => setState(() => _results[question.id] = value),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _comments[question.id],
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: result == 'Fail'
                    ? 'Comment / finding *'
                    : 'Comment (optional)',
                suffixIcon: IconButton(
                  tooltip: 'Save checklist point',
                  onPressed: () => _saveAnswer(question),
                  icon: const Icon(Icons.save_outlined),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _findingsTab() {
    if (_loadingEvidence) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _loadEvidence,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
            onPressed: _addDefect,
            icon: const Icon(Icons.add_alert_outlined),
            label: const Text('Add finding'),
          ),
          const SizedBox(height: 14),
          if (_defects.isEmpty)
            const _EmptyState(
              icon: Icons.verified_outlined,
              text: 'No findings recorded for this equipment.',
            )
          else
            ..._defects.map((defect) {
              final isOpen = defect.status == 'Open';
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              defect.defectNumber ?? 'Finding #${defect.id}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          PopupMenuButton<String>(
                            initialValue: defect.status,
                            onSelected: (value) =>
                                _setDefectStatus(defect, value),
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'Open', child: Text('Open')),
                              PopupMenuItem(
                                value: 'Accepted',
                                child: Text('Accepted'),
                              ),
                              PopupMenuItem(
                                value: 'Closed',
                                child: Text('Closed'),
                              ),
                            ],
                            child: Chip(
                              label: Text(defect.status),
                              backgroundColor: isOpen
                                  ? Colors.orange.shade100
                                  : Colors.green.shade100,
                            ),
                          ),
                        ],
                      ),
                      Text(defect.description),
                      if (defect.severity != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Severity: ${defect.severity}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                      if (defect.recommendation != null) ...[
                        const SizedBox(height: 6),
                        Text('Recommendation: ${defect.recommendation}'),
                      ],
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _photosTab() {
    if (_loadingEvidence) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _loadEvidence,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
            onPressed: _showPhotoSource,
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('Add evidence photo'),
          ),
          const SizedBox(height: 14),
          if (_photos.isEmpty)
            const _EmptyState(
              icon: Icons.photo_library_outlined,
              text: 'No evidence photos uploaded.',
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _photos.length,
              itemBuilder: (context, index) {
                final photo = _photos[index];
                return ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _photoImage(photo),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          color: Colors.black54,
                          child: Text(
                            photo.originalFileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String? value) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white70),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _photoImage(ExSurveyPhoto photo) {
    final localPath = photo.localFilePath;
    if (localPath != null && localPath.isNotEmpty) {
      return Image.file(
        File(localPath),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _brokenImage(),
      );
    }

    return Image.network(
      ExSurveyOfflineService.publicUrl(photo.filePath),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _brokenImage(),
    );
  }

  Widget _brokenImage() {
    return Container(
      color: Colors.blueGrey.shade100,
      child: const Icon(Icons.broken_image_outlined),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyState({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(icon, size: 44, color: Colors.blueGrey.shade300),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.blueGrey.shade600),
          ),
        ],
      ),
    );
  }
}
