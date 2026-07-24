import 'dart:io';

import 'package:Auras/model/assigned_report.dart';
import 'package:Auras/model/client_dashboard.dart';
import 'package:Auras/service/api_service.dart';
import 'package:Auras/service/sync_service.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

class AssignedReportsScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const AssignedReportsScreen({super.key, required this.user});

  @override
  State<AssignedReportsScreen> createState() => _AssignedReportsScreenState();
}

class _AssignedReportsScreenState extends State<AssignedReportsScreen> {
  late Future<ClientDashboardSummary> _future;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _future = ApiService.fetchClientDashboardSummary();
  }

  Future<void> _refresh() async {
    setState(() => _future = ApiService.fetchClientDashboardSummary());
    await _future;
  }

  Future<void> _openReport(AssignedReport report) async {
    try {
      final bytes = await ApiService.downloadAssignedReportPdf(report);
      final dir = await getTemporaryDirectory();
      final safeType = report.reportType.replaceAll(
        RegExp(r'[^a-zA-Z0-9_-]'),
        '_',
      );
      final file = File(
        '${dir.path}/${safeType}_report_${report.reportId}.pdf',
      );
      await file.writeAsBytes(bytes, flush: true);
      await OpenFile.open(file.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _openSurveySummary(AssignedReport report) {
    final jobId = report.surveyJobId ?? report.reportId;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ClientSurveySummarySheet(
        jobId: jobId,
        reportTitle: report.reference.isEmpty
            ? report.vesselName
            : report.reference,
      ),
    );
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);

    try {
      await SyncService.logoutAndClearUserData();
    } catch (error) {
      debugPrint('Logout failed during cleanup: $error');
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }

    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Client Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: _isLoggingOut ? null : _logout,
            icon: _isLoggingOut
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout),
          ),
        ],
      ),
      body: FutureBuilder<ClientDashboardSummary>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 80),
                  const Icon(Icons.wifi_off, size: 56, color: Colors.orange),
                  const SizedBox(height: 14),
                  Text(
                    snapshot.error.toString().replaceFirst('Exception: ', ''),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final summary = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _hero(),
                const SizedBox(height: 16),
                _kpiGrid(summary.kpis),
                _sectionTitle('Survey Progress Summary'),
                if (summary.assignedJobs.isEmpty)
                  _empty('No survey jobs have been assigned to you.')
                else
                  ...summary.assignedJobs.map(_jobCard),
                _sectionTitle('Hazardous Materials Summary'),
                _hazardGrid(summary.hazardousMaterials),
                _sectionTitle('Assigned Reports'),
                if (summary.assignedReports.isEmpty)
                  _empty('No reports have been assigned to you.')
                else
                  ...summary.assignedReports.map(_reportCard),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _hero() {
    final name = widget.user['fullName']?.toString();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF12345B),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name == null || name.trim().isEmpty
                ? 'Assigned Survey Overview'
                : 'Assigned Survey Overview, $name',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Read-only progress, hazardous material summary and reports.',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _kpiGrid(ClientDashboardKpis kpis) {
    final items = [
      ('All Assigned Jobs', kpis.allAssignedJobs, Icons.work_outline),
      ('Completed Jobs', kpis.completedJobs, Icons.check_circle_outline),
      ('In Progress Jobs', kpis.inProgressJobs, Icons.sync),
      ('Pending Jobs', kpis.pendingJobs, Icons.schedule),
      ('Assigned Reports', kpis.assignedReports, Icons.description_outlined),
      ('Areas Covered', kpis.areasCovered, Icons.layers_outlined),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 620 ? 3 : 2;
        return GridView.builder(
          itemCount: items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.45,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(item.$3, color: Colors.blue),
                    Text(
                      item.$2.toString(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      item.$1,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
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

  Widget _jobCard(ClientJobProgress job) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ExpansionTile(
        title: Text(
          job.jobNumber,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text('${job.vesselName} - IMO ${job.imo}'),
        trailing: _statusChip(job.currentStatus),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          LinearProgressIndicator(
            value: job.completionPercentage.clamp(0, 100).toDouble() / 100,
            minHeight: 8,
          ),
          const SizedBox(height: 12),
          _detailGrid([
            ('Completion', '${job.completionPercentage.toStringAsFixed(1)}%'),
            ('Survey Date', _date(job.surveyDate)),
            ('Surveyor', job.surveyorName),
            ('Areas', '${job.completedAreas}/${job.totalAreas}'),
            ('Pending Areas', job.pendingAreas.toString()),
            (
              'Checkpoints',
              '${job.completedCheckpoints}/${job.totalCheckpoints}',
            ),
          ]),
        ],
      ),
    );
  }

  Widget _hazardGrid(ClientHazardousMaterials data) {
    final items = [
      ('Total records', data.totalHazardousMaterialRecords),
      ('Visual samples', data.visualSamplesCount),
      ('Physical samples', data.physicalSamplesCount),
      ('Positive findings', data.positiveFindings),
      ('Negative findings', data.negativeFindings),
      ('Pending lab results', data.pendingLabResults),
      ('Completed lab results', data.completedLabResults),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items
          .map(
            (item) => SizedBox(
              width: 160,
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.$2.toString(),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(item.$1),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _reportCard(AssignedReport report) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(label: Text(report.label)),
                const Spacer(),
                Text(report.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              report.vesselName,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            Text('Job: ${report.reference}'),
            Text('Created by: ${report.createdBy}'),
            Text('Assigned: ${_date(report.assignedAt)}'),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _openSurveySummary(report),
                icon: const Icon(Icons.search),
                label: const Text('View Survey Summary'),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openReport(report),
                    icon: const Icon(Icons.visibility),
                    label: const Text('View'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _openReport(report),
                    icon: const Icon(Icons.download),
                    label: const Text('Download'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailGrid(List<(String, String)> items) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map(
            (item) => Container(
              width: 150,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withValues(alpha: .06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.$1, style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    item.$2,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _statusChip(String status) {
    final color = switch (status.toLowerCase()) {
      'completed' => Colors.green,
      'pending' => Colors.orange,
      'in progress' => Colors.blue,
      _ => Colors.blueGrey,
    };
    return Chip(
      label: Text(status),
      side: BorderSide.none,
      backgroundColor: color.withValues(alpha: .14),
      labelStyle: TextStyle(color: color.shade700, fontWeight: FontWeight.w800),
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 10),
    child: Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
    ),
  );

  Widget _empty(String text) => Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Center(child: Text(text, textAlign: TextAlign.center)),
    ),
  );

  String _date(DateTime? value) {
    if (value == null) return 'Not selected';
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-${local.year}';
  }
}

class ClientSurveySummarySheet extends StatefulWidget {
  final int jobId;
  final String reportTitle;

  const ClientSurveySummarySheet({
    super.key,
    required this.jobId,
    required this.reportTitle,
  });

  @override
  State<ClientSurveySummarySheet> createState() =>
      _ClientSurveySummarySheetState();
}

class _ClientSurveySummarySheetState extends State<ClientSurveySummarySheet> {
  late Future<ClientJobSummary> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService.fetchClientJobSummary(widget.jobId);
  }

  void _retry() {
    setState(() => _future = ApiService.fetchClientJobSummary(widget.jobId));
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .9,
      minChildSize: .55,
      maxChildSize: .96,
      builder: (context, controller) {
        return FutureBuilder<ClientJobSummary>(
          future: _future,
          builder: (context, snapshot) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Survey Summary',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.reportTitle,
                            style: const TextStyle(color: Colors.blueGrey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (snapshot.hasError)
                  _error(snapshot.error)
                else if (snapshot.hasData)
                  _content(snapshot.data!),
              ],
            );
          },
        );
      },
    );
  }

  Widget _error(Object? error) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 42),
            const SizedBox(height: 10),
            Text(
              error.toString().replaceFirst('Exception: ', ''),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(ClientJobSummary summary) {
    final job = summary.job;
    final hazard = summary.hazardousMaterials;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (summary.fromCache)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Showing cached survey summary. Retry when online for latest data.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ExpansionTile(
          initiallyExpanded: true,
          title: const Text(
            'Job Progress',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          children: [
            LinearProgressIndicator(
              value: job.completionPercentage.clamp(0, 100).toDouble() / 100,
              minHeight: 8,
            ),
            const SizedBox(height: 12),
            _detailGrid([
              ('Job number', job.jobNumber),
              ('Vessel name', job.vesselName),
              ('IMO', job.imo),
              ('Survey date', _date(job.surveyDate)),
              ('Surveyor name', job.surveyorName),
              ('Current status', job.currentStatus),
              ('Completion', '${job.completionPercentage.toStringAsFixed(1)}%'),
              ('Areas', '${job.completedAreas}/${job.totalAreas}'),
              (
                'Checkpoints',
                '${job.completedCheckpoints}/${job.totalCheckpoints}',
              ),
            ]),
          ],
        ),
        ExpansionTile(
          initiallyExpanded: true,
          title: const Text(
            'Hazardous Materials',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          children: [
            _detailGrid([
              (
                'Total records',
                hazard.totalHazardousMaterialRecords.toString(),
              ),
              ('Visual count', hazard.visualSamplesCount.toString()),
              ('Physical sample count', hazard.physicalSamplesCount.toString()),
              ('Positive findings', hazard.positiveFindings.toString()),
              ('Negative findings', hazard.negativeFindings.toString()),
              ('Pending lab results', hazard.pendingLabResults.toString()),
              ('Completed lab results', hazard.completedLabResults.toString()),
            ]),
          ],
        ),
        ExpansionTile(
          initiallyExpanded: true,
          title: const Text(
            'Survey Details',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          children: summary.surveyDetails.isEmpty
              ? [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _empty('No survey work details are available yet.'),
                  ),
                ]
              : summary.surveyDetails.map(_surveyDetailTile).toList(),
        ),
      ],
    );
  }

  Widget _surveyDetailTile(ClientSurveyActivity item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.areaName,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text('Checkpoints completed: ${item.checkpointsCompleted}'),
            Text('Remarks: ${item.remarks}'),
            Text('Location: ${item.location}'),
            Text('Sample number: ${item.sampleNumber}'),
            Text('Visual/sample type: ${item.visualSampleType}'),
            Text('Photo count: ${item.surveyPhotosCount}'),
            Text('Last updated: ${_dateTime(item.lastUpdatedDate)}'),
            Text('Surveyor name: ${item.surveyorName}'),
          ],
        ),
      ),
    );
  }

  Widget _detailGrid(List<(String, String)> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items
            .map(
              (item) => Container(
                width: 150,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.withValues(alpha: .06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.$1, style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      item.$2,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _empty(String text) => Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Center(child: Text(text, textAlign: TextAlign.center)),
    ),
  );

  String _date(DateTime? value) {
    if (value == null) return 'Not selected';
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-${local.year}';
  }

  String _dateTime(DateTime? value) {
    if (value == null) return '-';
    final local = value.toLocal();
    return '${_date(local)} ${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}
