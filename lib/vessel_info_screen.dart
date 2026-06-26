import 'package:Auras/model/vessel.dart';
import 'package:Auras/service/api_service.dart';
import 'package:flutter/material.dart';

class VesselInfoScreen extends StatelessWidget {
  final int vesselId;
  final String? jobNumber;

  const VesselInfoScreen({super.key, required this.vesselId, this.jobNumber});

  String _val(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? '-' : text;
  }

  String _numVal(num? value) {
    if (value == null) return '-';
    return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2);
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
          jobNumber == null ? 'Vessel Info' : 'Vessel Info - $jobNumber',
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: FutureBuilder<Vessel>(
        future: ApiService.fetchVesselById(vesselId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }

          final vessel = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Text(
                vessel.vesselName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _val(vessel.vesselType),
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 20),

              _section('Identification', [
                _item('IMO Number', _val(vessel.imoNumber)),
                _item('Call Sign', _val(vessel.callSign)),
                _item('Official Number', _val(vessel.officialNumber)),
                _item('Classification Society', _val(vessel.classSociety)),
              ]),

              _section('Build & Registration', [
                _item('Builder', _val(vessel.builder)),
                _item('Date of Build', _val(vessel.dateOfBuild)),
                _item('Port of Registry', _val(vessel.portOfRegistry)),
                _item('Flag', _val(vessel.flag)),
              ]),

              _section('Dimensions & Tonnage', [
                _item('L.O.A', _numVal(vessel.lengthOverall)),
                _item('L.B.P', _numVal(vessel.lengthBetweenPerpendiculars)),
                _item('Breadth MLD', _numVal(vessel.breadth)),
                _item('Depth MLD', _numVal(vessel.depth)),
                _item('Draught MLD', _numVal(vessel.draughtMoulded)),
                _item('GRT', _numVal(vessel.grossTonnage)),
                _item('NRT', _numVal(vessel.netTonnage)),
              ]),

              _section('Stakeholders', [
                _item('Owner', _val(vessel.ownerName)),
                _item('Manager', _val(vessel.managerName)),
                _item('Client', _val(vessel.clientName)),
              ]),
            ],
          );
        },
      ),
    );
  }
}
