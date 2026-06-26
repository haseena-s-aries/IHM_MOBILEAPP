import 'package:flutter/material.dart';

class CreateCertificateScreen extends StatelessWidget {
  const CreateCertificateScreen({super.key});

  void _showCreateDialog(BuildContext context) {
    String selectedDocument = '-- Select Document Type --';
    String selectedTemplate = '-- Select Certificate Template --';

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ), // reduces dialog size
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: const Color(0xFF2F2F2F),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Create Certificate',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Select Document Type:',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 8),

                    DropdownButtonFormField<String>(
                      value: selectedDocument,
                      items:
                          [
                            '-- Select Document Type --',
                            'Certificate',
                            'QHSE Form',
                            'Survey Divison Form',
                            'Reports',
                          ].map((type) {
                            return DropdownMenuItem<String>(
                              value: type,
                              child: Text(type),
                            );
                          }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedDocument = value);
                        }
                      },
                      dropdownColor: Colors.grey[850],
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Colors.white24,
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Select Certificate Template:',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 8),

                    DropdownButtonFormField<String>(
                      value: selectedTemplate,
                      items:
                          [
                            '-- Select Certificate Template --',
                            'Template A',
                            'Template B',
                          ].map((template) {
                            return DropdownMenuItem<String>(
                              value: template,
                              child: Text(template),
                            );
                          }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedTemplate = value);
                        }
                      },
                      dropdownColor: Colors.grey[850],
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Colors.white24,
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Close',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            if (selectedDocument.contains("Select") ||
                                selectedTemplate.contains("Select")) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Please select both options"),
                                ),
                              );
                            } else {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Document: $selectedDocument\nTemplate: $selectedTemplate',
                                  ),
                                ),
                              );
                            }
                          },
                          child: const Text('Proceed'),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Certificate')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => _showCreateDialog(context),
          child: const Text('Create Certificate'),
        ),
      ),
    );
  }
}
