import 'package:Auras/model/certificatedto.dart';
import 'package:flutter/material.dart';

class CertificateDetailsScreen extends StatelessWidget {
  final CertificateDto certificate;

  const CertificateDetailsScreen({super.key, required this.certificate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Certificate Details"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              "📄 Certificate Number: ${certificate.certificateNumber}",
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 10),
            Text(
              "🏗️ Project Title: ${certificate.projectTitle}",
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 10),
            Text(
              "👤 Client Name: ${certificate.clientName}",
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 10),
            Text(
              "🧾 Job Number: ${certificate.jobNumber}",
              style: TextStyle(fontSize: 18),
            ),
            // Add more fields as needed
          ],
        ),
      ),
    );
  }
}
