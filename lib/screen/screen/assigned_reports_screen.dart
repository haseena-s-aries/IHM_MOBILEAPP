import 'dart:io';

import 'package:Auras/model/assigned_report.dart';
import 'package:Auras/screen/screen/login_screen.dart';
import 'package:Auras/service/api_service.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AssignedReportsScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const AssignedReportsScreen({super.key, required this.user});

  @override
  State<AssignedReportsScreen> createState() => _AssignedReportsScreenState();
}

class _AssignedReportsScreenState extends State<AssignedReportsScreen> {
  late Future<List<AssignedReport>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService.fetchMyAssignedReports();
  }

  Future<void> _refresh() async {
    setState(() => _future = ApiService.fetchMyAssignedReports());
    await _future;
  }

  Future<void> _openReport(AssignedReport report) async {
    try {
      final bytes = await ApiService.downloadAssignedReportPdf(report);
      final dir = await getTemporaryDirectory();
      final safeType = report.reportType.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final file = File('${dir.path}/${safeType}_report_${report.reportId}.pdf');
      await file.writeAsBytes(bytes, flush: true);
      await OpenFile.open(file.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.user['fullName']?.toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assigned Reports'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<AssignedReport>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Icon(Icons.wifi_off, size: 54, color: Colors.orange),
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
              );
            }

            final reports = snapshot.data ?? const <AssignedReport>[];
            if (reports.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 80),
                  const Icon(Icons.folder_open, size: 64, color: Colors.blueGrey),
                  const SizedBox(height: 14),
                  Text(
                    name == null || name.isEmpty
                        ? 'No reports have been assigned to you.'
                        : 'Hi $name, no reports have been assigned to you.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              );
            }

            final ihmReports = reports
                .where((x) => x.reportType.toLowerCase() == 'ihm')
                .toList();
            final exReports = reports
                .where((x) => x.reportType.toLowerCase() == 'exsurvey')
                .toList();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (ihmReports.isNotEmpty) ...[
                  _sectionTitle('IHM Reports'),
                  ...ihmReports.map(_reportCard),
                ],
                if (exReports.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _sectionTitle('EX-Survey Reports'),
                  ...exReports.map(_reportCard),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      );

  Widget _reportCard(AssignedReport report) {
    final assignedDate = report.assignedAt == null
        ? 'Assigned date unavailable'
        : '${report.assignedAt!.day.toString().padLeft(2, '0')}-'
            '${report.assignedAt!.month.toString().padLeft(2, '0')}-'
            '${report.assignedAt!.year}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(label: Text(report.label)),
                const Spacer(),
                Text(report.status, style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 10),
            Text(report.vesselName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(report.title),
            if (report.reference.isNotEmpty) Text('Job/Ref: ${report.reference}'),
            Text('Created by: ${report.createdBy}'),
            Text('Assigned: $assignedDate'),
            const SizedBox(height: 12),
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
}
