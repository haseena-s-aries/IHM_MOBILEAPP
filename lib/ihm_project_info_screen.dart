import 'package:Auras/ThemeNotifier.dart';
import 'package:Auras/model/survey_job.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class IhmProjectInfoScreen extends StatelessWidget {
  final SurveyJob job;

  const IhmProjectInfoScreen({super.key, required this.job});

  String _val(String? x) => x == null || x.trim().isEmpty ? '-' : x.trim();

  Widget _item(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 155,
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeNotifier>();
    final c = theme.colors;

    final primary = _val(job.primarySurveyorName ?? job.assignedSurveyorName);
    final secondary = _val(job.secondarySurveyorName);

    return Scaffold(
      backgroundColor: c.bgCard,
      appBar: AppBar(
        backgroundColor: c.bgCard, // ✅ or keep your brand color
        title: Text(
          "Project Information",
          style: TextStyle(color: c.textPrimary),
        ),
        iconTheme: IconThemeData(color: c.textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            _val(job.projectName),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            _val(job.clientName),
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 20),

          _section('Vessel Details', [
            _item('Vessel', _val(job.vesselName)),
            _item('IMO Number', _val(job.imoNumber)),
          ]),

          _section('Auditors', [
            _item('Primary Auditor', primary),
            _item('Secondary Auditor', secondary),
          ]),

          _section('Audit Details', [
            _item('Audit Port', _val(job.auditPort ?? job.siteName)),
            _item('Audit Address', _val(job.auditAddress)),
            _item('Start Date', _formatDate(job.startDate)),
            _item('Finish Date', _formatDate(job.endDate)),
          ]),
        ],
      ),
    );
  }
}
