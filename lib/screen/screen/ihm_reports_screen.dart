import 'dart:io';

import 'package:Auras/service/api_service.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

class IhmReportsScreen extends StatefulWidget {
  final String initialCategory;
  const IhmReportsScreen({super.key, this.initialCategory = 'ihm'});

  @override
  State<IhmReportsScreen> createState() => _IhmReportsScreenState();
}

class _IhmReportsScreenState extends State<IhmReportsScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  final Map<int, List<Map<String, dynamic>>> _assignments = {};
  final Map<int, int?> _selectedClientByReport = {};
  List<Map<String, dynamic>> _clients = [];
  String _search = '';
  String _clientSearch = '';
  bool _clientsLoading = true;

  @override
  void initState() {
    super.initState();
    _future = _loadReports();
    _loadClients();
  }

  Future<List<Map<String, dynamic>>> _loadReports() async {
    final category = widget.initialCategory.toLowerCase();
    final reports = await ApiService.fetchSavedReports();
    final ihmReports = reports
        .where((x) => _value(x, 'reportType').toLowerCase() == category)
        .toList();
    for (final report in ihmReports) {
      final id = _intValue(report, 'id');
      if (id > 0) {
        _assignments[id] = await ApiService.fetchReportAssignments(
          reportType: category,
          reportId: id,
        );
      }
    }
    return ihmReports;
  }

  Future<void> _loadClients() async {
    setState(() => _clientsLoading = true);
    try {
      final clients = await ApiService.fetchReportClients(
        projectType: widget.initialCategory.toLowerCase(),
        search: _clientSearch,
      );
      if (!mounted) return;
      setState(() => _clients = clients);
    } catch (e) {
      if (!mounted) return;
      _show(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _clientsLoading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() => _future = _loadReports());
    await _future;
  }

  String _value(Map<String, dynamic> map, String key) =>
      (map[key] ?? map[_upper(key)] ?? '').toString();

  int _intValue(Map<String, dynamic> map, String key) =>
      int.tryParse(_value(map, key)) ?? 0;

  String _upper(String key) => key.isEmpty
      ? key
      : '${key[0].toUpperCase()}${key.substring(1)}';

  String _clientLabel(Map<String, dynamic> client) {
    final name = _value(client, 'fullName');
    final email = _value(client, 'email');
    if (name.isEmpty) return email.isEmpty ? 'Client' : email;
    return email.isEmpty ? name : '$name ($email)';
  }

  String _createdBy(Map<String, dynamic> report) {
    final name = _value(report, 'createdBy');
    if (name.isNotEmpty) return name;
    final id = _intValue(report, 'createdByUserId');
    return id > 0 ? 'User $id' : 'Creator unavailable';
  }

  Future<void> _sendReport(Map<String, dynamic> report) async {
    final category = widget.initialCategory.toLowerCase();
    final reportId = _intValue(report, 'id');
    final clientUserId = _selectedClientByReport[reportId] ?? 0;
    if (reportId <= 0 || clientUserId <= 0) {
      _show('Please select a Client user.');
      return;
    }

    try {
      final message = await ApiService.assignReportToClient(
        reportType: category,
        reportId: reportId,
        surveyJobId: reportId,
        clientUserId: clientUserId,
      );
      _assignments[reportId] = await ApiService.fetchReportAssignments(
        reportType: category,
        reportId: reportId,
      );
      if (!mounted) return;
      setState(() {});
      _show(message);
    } catch (e) {
      _show(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _removeAssignment(int reportId, int assignmentId) async {
    final category = widget.initialCategory.toLowerCase();
    try {
      final message = await ApiService.revokeReportAssignment(assignmentId);
      _assignments[reportId] = await ApiService.fetchReportAssignments(
        reportType: category,
        reportId: reportId,
      );
      if (!mounted) return;
      setState(() {});
      _show(message);
    } catch (e) {
      _show(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _openPdf(Map<String, dynamic> report) async {
    try {
      final category = widget.initialCategory.toLowerCase();
      final id = _intValue(report, 'id');
      final bytes = await ApiService.downloadSavedReportPdf(
        reportType: category,
        reportId: id,
      );
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$category-report-$id.pdf');
      await file.writeAsBytes(bytes, flush: true);
      await OpenFile.open(file.path);
    } catch (e) {
      _show(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.initialCategory.toLowerCase() == 'exsurvey'
        ? 'EX-Survey Reports'
        : 'IHM Reports';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _stateList(
                Icons.error_outline,
                snapshot.error.toString().replaceFirst('Exception: ', ''),
              );
            }

            final sourceReports = snapshot.data ?? const <Map<String, dynamic>>[];
            final reports = sourceReports
                .where((report) {
                  final term = _search.trim().toLowerCase();
                  if (term.isEmpty) return true;
                  final text =
                      '${_value(report, 'vesselName')} ${_value(report, 'title')} ${_value(report, 'reference')} ${_createdBy(report)}'
                          .toLowerCase();
                  return text.contains(term);
                })
                .toList();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search report, vessel, job, created by',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() => _search = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.person_search),
                    suffixIcon: _clientsLoading
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: _loadClients,
                          ),
                    hintText: 'Search Client name or email',
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (value) {
                    _clientSearch = value;
                    _loadClients();
                  },
                ),
                const SizedBox(height: 16),
                if (reports.isEmpty)
                  _emptyCard('No IHM reports available.')
                else
                  ...reports.map(_reportCard),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _reportCard(Map<String, dynamic> report) {
    final id = _intValue(report, 'id');
    final assigned = _assignments[id] ?? const <Map<String, dynamic>>[];

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _value(report, 'vesselName').isEmpty
                  ? 'Vessel not specified'
                  : _value(report, 'vesselName'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(_value(report, 'title').isEmpty ? 'IHM Report' : _value(report, 'title')),
            Text('Job/Ref: ${_value(report, 'reference')}'),
            Text('Created by: ${_createdBy(report)}'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openPdf(report),
                    icon: const Icon(Icons.visibility),
                    label: const Text('View'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _openPdf(report),
                    icon: const Icon(Icons.download),
                    label: const Text('Download'),
                  ),
                ),
              ],
            ),
            const Divider(height: 26),
            DropdownButtonFormField<int>(
              value: _selectedClientByReport[id],
              decoration: const InputDecoration(
                labelText: 'Send Report to Client',
                border: OutlineInputBorder(),
              ),
              items: _clients
                  .map((client) => DropdownMenuItem<int>(
                        value: _intValue(client, 'id'),
                        child: Text(
                          _clientLabel(client),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: (value) =>
                  setState(() => _selectedClientByReport[id] = value),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _sendReport(report),
                icon: const Icon(Icons.send),
                label: const Text('Send'),
              ),
            ),
            const SizedBox(height: 10),
            if (assigned.isEmpty)
              const Text('No clients assigned')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: assigned.map((assignment) {
                  final assignmentId = _intValue(assignment, 'id');
                  final label = _value(assignment, 'clientName').isEmpty
                      ? _value(assignment, 'clientEmail')
                      : _value(assignment, 'clientName');
                  return InputChip(
                    label: Text(label.isEmpty ? 'Client' : label),
                    onDeleted: () {
                      _removeAssignment(id, assignmentId);
                    },
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _stateList(IconData icon, String text) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          Icon(icon, size: 60, color: Colors.blueGrey),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
        ],
      );

  Widget _emptyCard(String text) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(text, textAlign: TextAlign.center),
        ),
      );
}
