import 'package:flutter/material.dart';
import 'package:Auras/service/api_service.dart';

class ClientReportRemarksScreen extends StatefulWidget {
  const ClientReportRemarksScreen({super.key});

  @override
  State<ClientReportRemarksScreen> createState() =>
      _ClientReportRemarksScreenState();
}

class _ClientReportRemarksScreenState extends State<ClientReportRemarksScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService.fetchReportRemarks();
  }

  String _s(Map<String, dynamic> item, String key) =>
      (item[key] ?? item[key[0].toUpperCase() + key.substring(1)] ?? '-')
          .toString();

  void _viewRemark(String remark) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Client Remark'),
        content: SingleChildScrollView(child: Text(remark)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Client Remarks')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final remarks = snapshot.data!;
          if (remarks.isEmpty) {
            return const Center(child: Text('No client remarks received yet.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: remarks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, index) {
              final item = remarks[index];
              final remark = _s(item, 'remark');
              return Card(
                child: ListTile(
                  title: Text(_s(item, 'vesselName')),
                  subtitle: Text(
                    'Job: ${_s(item, 'jobNumber')}  Rev: ${_s(item, 'revisionNo')}\nClient: ${_s(item, 'clientName')}',
                  ),
                  trailing: IconButton(
                    tooltip: 'View remark',
                    icon: const Icon(Icons.visibility_outlined),
                    onPressed: () => _viewRemark(remark),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}