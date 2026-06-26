import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class NetworkPdfViewerScreen extends StatelessWidget {
  final String url;
  final String title;

  const NetworkPdfViewerScreen({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    print('PDF URL: $url');

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SfPdfViewer.network(
        url,
        onDocumentLoadFailed: (details) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(details.description)));
        },
      ),
    );
  }
}
