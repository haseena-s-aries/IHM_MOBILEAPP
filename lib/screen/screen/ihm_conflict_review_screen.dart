import 'package:Auras/model/ihm_checkpoint_submission.dart';
import 'package:Auras/service/api_service.dart';
import 'package:Auras/utils/app_dialog.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class IhmConflictReviewScreen extends StatefulWidget {
  final int jobId;

  const IhmConflictReviewScreen({super.key, required this.jobId});

  @override
  State<IhmConflictReviewScreen> createState() =>
      _IhmConflictReviewScreenState();
}

class _IhmConflictReviewScreenState extends State<IhmConflictReviewScreen> {
  bool loading = true;
  String? error;
  int reviewerUserId = 0;
  List<IhmCheckpointSubmission> submissions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      reviewerUserId = prefs.getInt('userId') ?? 0;
      submissions = await ApiService.fetchIhmCheckpointSubmissions(
        widget.jobId,
      );
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _approve(IhmCheckpointSubmission submission) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Approve this submission?',
      message:
          'This surveyor result will become the approved checkpoint result.',
      confirmLabel: 'Approve result',
    );
    if (!confirmed) return;
    final approved = await AppDialog.execute<bool>(
      context,
      loadingMessage: 'Approving checkpoint result...',
      action: () async {
        await ApiService.approveIhmCheckpointSubmission(
          submissionId: submission.id,
          reviewerUserId: reviewerUserId,
          notes: 'Selected during checkpoint conflict review.',
        );
        return true;
      },
      successTitle: 'Submission approved',
      successMessage:
          'The selected surveyor result is now the approved checkpoint result.',
      errorTitle: 'Unable to approve submission',
    );
    if (approved == true && mounted) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final conflicts = submissions.where((item) => item.isConflict).toList();
    final grouped = <int, List<IhmCheckpointSubmission>>{};
    for (final submission in conflicts) {
      grouped.putIfAbsent(submission.checkpointId, () => []).add(submission);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkpoint Conflict Review'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(child: Text(error!))
          : grouped.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_outlined, size: 54, color: Colors.green),
                  SizedBox(height: 12),
                  Text('No unresolved checkpoint conflicts'),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: grouped.entries.map((entry) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Checkpoint ${entry.key}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        ...entry.value.map(_submissionCard),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _submissionCard(IhmCheckpointSubmission submission) {
    final hiddenKeys = {'UpdatedByUserId'};
    final values = submission.data.entries
        .where(
          (entry) =>
              !hiddenKeys.contains(entry.key) &&
              entry.value != null &&
              entry.value.toString().trim().isNotEmpty,
        )
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE3EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Surveyor ${submission.surveyorUserId}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                submission.submittedAt?.toLocal().toString().split('.').first ??
                    '',
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
          const Divider(height: 22),
          ...values.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 145,
                    child: Text(
                      _label(entry.key),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  Expanded(child: Text(entry.value.toString())),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: reviewerUserId > 0
                  ? () => _approve(submission)
                  : null,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Approve this version'),
            ),
          ),
        ],
      ),
    );
  }

  String _label(String key) {
    return key
        .replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'),
          (match) => '${match.group(1)} ${match.group(2)}',
        )
        .trim();
  }
}
