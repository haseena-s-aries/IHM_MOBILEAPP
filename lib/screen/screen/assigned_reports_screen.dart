import 'dart:io';

import 'package:Auras/model/assigned_report.dart';
import 'package:Auras/screen/screen/login_screen.dart';
import 'package:Auras/screen/screen/vessel_master_screen.dart';
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
  late Future<List<AssignedReport>> _future;
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _future = ApiService.fetchMyAssignedReports();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    try {
      await SyncService.logoutAndClearUserData();
    } catch (error) {
      debugPrint('Logout failed during cleanup: $error');
    }
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
            tooltip: 'Vessel Master',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const VesselMasterScreen(),
                ),
              );
            },
            icon: const Icon(Icons.directions_boat),
          ),
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
            final filteredReports = reports.where(_matchesSearch).toList();
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

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _searchBox(),
                const SizedBox(height: 14),
                if (filteredReports.isEmpty) ...[
                  const SizedBox(height: 60),
                  const Icon(
                    Icons.search_off_rounded,
                    size: 54,
                    color: Colors.blueGrey,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'No assigned reports match your search.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ] else ...[
                  ...filteredReports.map(_reportCard),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  bool _matchesSearch(AssignedReport report) {
    final term = _searchTerm.trim().toLowerCase();
    if (term.isEmpty) return true;

    final haystack = [
      report.vesselName,
      report.title,
      report.reference,
      report.label,
      report.createdBy,
      if (report.assignedAt != null)
        '${report.assignedAt!.day.toString().padLeft(2, '0')}-'
            '${report.assignedAt!.month.toString().padLeft(2, '0')}-'
            '${report.assignedAt!.year}',
    ].join(' ').toLowerCase();

    return haystack.contains(term);
  }

  Widget _searchBox() => TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search vessel, job, report type, created by or date...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchTerm.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchTerm = '');
                  },
                  icon: const Icon(Icons.close),
                ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onChanged: (value) => setState(() => _searchTerm = value),
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
