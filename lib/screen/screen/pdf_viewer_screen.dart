import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';

class PDFViewerScreen extends StatefulWidget {
  final String assetPath;
  const PDFViewerScreen({Key? key, required this.assetPath}) : super(key: key);

  @override
  State<PDFViewerScreen> createState() => _PDFViewerScreenState();
}

class _PDFViewerScreenState extends State<PDFViewerScreen> {
  String? localPDFPath;

  @override
  void initState() {
    super.initState();
    _loadAssetPDF();
  }

  Future<void> _loadAssetPDF() async {
    final byteData = await rootBundle.load(widget.assetPath);
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/temp.pdf');
    await file.writeAsBytes(byteData.buffer.asUint8List());

    setState(() {
      localPDFPath = file.path;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("PDF Preview")),
      body: localPDFPath == null
          ? const Center(child: CircularProgressIndicator())
          : PDFView(filePath: localPDFPath!),
    );
  }
}
