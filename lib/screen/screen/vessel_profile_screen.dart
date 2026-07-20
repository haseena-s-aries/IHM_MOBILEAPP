import 'package:Auras/model/survey_job.dart';
import 'package:Auras/model/vessel.dart';
import 'package:Auras/screen/screen/survey_job_details_screen.dart';
import 'package:Auras/service/api_service.dart';
import 'package:flutter/material.dart';

class VesselProfileScreen extends StatefulWidget {
  final Vessel vessel;

  const VesselProfileScreen({super.key, required this.vessel});

  @override
  State<VesselProfileScreen> createState() => _VesselProfileScreenState();
}

class _VesselProfileScreenState extends State<VesselProfileScreen> {
  bool isLoading = true;
  String? errorMessage;
  List<SurveyJob> jobs = [];

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final result = await ApiService.fetchSurveyJobsByVessel(widget.vessel.id);
      setState(() {
        jobs = result;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Completed':
        return Colors.green;
      case 'Pending':
        return Colors.orange;
      case 'In Progress':
        return Colors.blue;
      case 'Not Started':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final vessel = widget.vessel;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F4FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
          'Vessel Info', // or whatever the title is
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadJobs,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            _vesselHeader(vessel),
            const SizedBox(height: 18),
            _summaryRow(),
            const SizedBox(height: 22),
            const Text(
              'Job History',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _jobHistory(),
          ],
        ),
      ),
    );
  }

  Widget _vesselHeader(Vessel vessel) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4527A0), Color(0xFF6A1B9A)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.directions_boat, color: Colors.white, size: 36),
          const SizedBox(height: 12),
          Text(
            vessel.vesselName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            [
              if (vessel.imoNumber != null && vessel.imoNumber!.isNotEmpty)
                'IMO ${vessel.imoNumber}',
              if (vessel.flag != null && vessel.flag!.isNotEmpty) vessel.flag!,
              if (vessel.classSociety != null &&
                  vessel.classSociety!.isNotEmpty)
                vessel.classSociety!,
            ].join(' | '),
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Text(
            'Owner: ${vessel.ownerName ?? "-"}',
            style: const TextStyle(color: Colors.white),
          ),
          Text(
            'Manager: ${vessel.managerName ?? "-"}',
            style: const TextStyle(color: Colors.white),
          ),
          Text(
            'Client: ${vessel.clientName ?? "-"}',
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow() {
    final ihmCount = jobs.where((x) => x.moduleType == 'IhmSurvey').length;
    final exCount = jobs.where((x) => x.moduleType == 'ExSurvey').length;
    final closedCount = jobs.where((x) => x.status == 'Closed').length;

    return Row(
      children: [
        _summaryCard('IHM', ihmCount, Icons.inventory_2, Colors.indigo),
        _summaryCard(
          'Ex',
          exCount,
          Icons.electrical_services,
          Colors.deepOrange,
        ),
        _summaryCard('Closed', closedCount, Icons.lock, Colors.black54),
      ],
    );
  }

  Widget _summaryCard(String title, int count, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(
              '$count',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(title),
          ],
        ),
      ),
    );
  }

  Widget _jobHistory() {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (errorMessage != null) {
      return Text(errorMessage!, style: const TextStyle(color: Colors.red));
    }

    if (jobs.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No jobs mapped to this vessel yet.'),
        ),
      );
    }

    return Column(
      children: jobs.map((job) {
        final surveyType = job.moduleType == 'IhmSurvey'
            ? 'IHM Survey'
            : 'Ex-Survey';

        return Card(
          elevation: 2,
          child: ListTile(
            leading: Icon(
              job.moduleType == 'IhmSurvey'
                  ? Icons.inventory_2
                  : Icons.electrical_services,
              color: Colors.deepPurple,
            ),
            title: Text(job.jobNumber),
            subtitle: Text('${job.projectName ?? "-"}\n$surveyType'),
            isThreeLine: true,
            trailing: Chip(
              label: Text(
                job.displayStatus,
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: _statusColor(job.displayStatus),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      SurveyJobDetailsScreen(job: job, surveyType: surveyType),
                ),
              );
            },
          ),
        );
      }).toList(),
    );
  }
}
