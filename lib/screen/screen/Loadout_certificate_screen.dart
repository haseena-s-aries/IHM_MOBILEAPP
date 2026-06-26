import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:Auras/Db/database_helper.dart';
import 'package:Auras/app_config.dart';
import 'package:Auras/model/CarogDetails_model.dart';
import 'package:Auras/model/loadout.dart';
import 'package:Auras/pdf/LoadoutPdf..dart';
import 'package:Auras/screen/screen/Seafastening_certificate_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart' as db;
import 'package:image_picker/image_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:Auras/service/api_service.dart';
import 'package:Auras/utils/app_dialog.dart';
import 'package:intl/intl.dart';
import 'package:signature/signature.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LoadoutCertificateScreen extends StatefulWidget {
  const LoadoutCertificateScreen({super.key});

  @override
  State<LoadoutCertificateScreen> createState() => _LoadoutCertificateScreen();
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class _LoadoutCertificateScreen extends State<LoadoutCertificateScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 1;
  // Controllers
  final _certificateNoController = TextEditingController();
  final _jobNoController = TextEditingController();
  final _certificateTitleManual = TextEditingController();
  final _projectTitleController = TextEditingController();
  final _clientNameController = TextEditingController();
  final _OperationTypeController = TextEditingController();
  final _cargoController = TextEditingController();
  final _LocationController = TextEditingController();
  final _BargeVesselController = TextEditingController();
  final _surveyedByController = TextEditingController();

  String? _selectedHeader;
  String? _selectedCertificateTitle;
  DateTime? _issuedDate;
  bool _noDateChecked = false;
  bool _isCargoNA = false;
  List<Map<String, TextEditingController>> _cargoDetails = [];
  bool _signatureNotApplicable = false;
  XFile? _surveyorSignature;
  final ImagePicker _picker = ImagePicker();
  XFile? _approverSignature;
  bool _approverSignatureNA = false;
  XFile? _stampFile;
  Uint8List? stampImageBytes;
  String? _selectedPredefinedStamp;
  bool _isStampNA = false;
  String? _selectedOperationType;
  String? _selectedModeOfOperation;
  String toUpper(String value) => value.trim().toUpperCase();
  void _addCargoRow() {
    if (_cargoDetails.length >= 15) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Limit Reached"),
          content: const Text("You can only add up to 15 cargo detail rows."),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("OK"),
            ),
          ],
        ),
      );
      return;
    }

    setState(() {
      _cargoDetails.add({
        'Location': TextEditingController(),
        'Cargo': TextEditingController(),
        'IDMarkings': TextEditingController(),
        'Weight': TextEditingController(),
        'Dimensions': TextEditingController(),
        'Remarks': TextEditingController(),
      });
    });
  }

  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  final SignatureController _approverSignatureController = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  void _removeCargoRow(int index) {
    setState(() {
      _cargoDetails.removeAt(index);
    });
  }

  final List<String> _certificateTitles = [
    "ARIES MARINE L.L.C",
    "ARIES MARINE SERVICES CO. LTD",
    "ARIES OIL FIELD SERVICES L.L.C",
    "ARIES MARINE CO. WLL.",
    "ARIES BAHRAIN MARINE W.L.L",
    "manual",
  ];

  final Map<String, String> _predefinedStamps = {
    'Aries Marine L.L.C': 'assets/stamps/aries_marine_logo.png',
    'Aries Oil Field Services': 'assets/stamps/A_O_F_S.jpeg',
    'Aries Marine S.P.C': 'assets/stamps/Aries_Marine_S_P_C.jpeg',
  };

  final Map<String, String> _headerOptions = {
    "assets/images/MARINE.LLC.png": "Aries Marine LLC.",
    "assets/images/saudilogo.png": "Aries Marine Services CO.LTD",
    "assets/images/QatarLogo.jpg": "Aries Marine CO.WLL.",
    "assets/images/OILFIELDSERVICELOGO.png": "Aries Oil Field Services LLC",
    "assets/images/Baharin.W.L.L.png": "Aries Bahrain Marine W.L.L",
    "assets/images/blank.png": "No Header",
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Loadout Certificate")),
      body: InteractiveViewer(
        panEnabled: true,
        scaleEnabled: true,
        minScale: 1.0,
        maxScale: 3.0,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Builder(
            builder: (_) {
              switch (_currentStep) {
                case 1:
                  return _buildStep1Form();

                case 2:
                  return _buildCargoDetailsSection();
                case 3:
                  return _buildSurveyorSignatureSection();

                case 4:
                  return _buildApproverSignatureSection();

                case 5:
                  return _buildStampUploadSection();

                case 6:
                  return _buildSubmitSection();
                default:
                  return const Center(child: Text("Unknown step"));
              }
            },
          ),
        ),
      ),
    );
  }

  // ---------------- STEP 1 ----------------

  Widget _buildStep1Form() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: _selectedHeader,
            decoration: const InputDecoration(labelText: "Select Header"),
            items: _headerOptions.entries
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: (val) => setState(() => _selectedHeader = val),
            validator: (val) => val == null ? "Please select header" : null,
          ),
          const SizedBox(height: 16),

          _buildTextField(_certificateNoController, "Certificate Number"),

          _buildTextField(_jobNoController, "Job Number"),

          DropdownButtonFormField<String>(
            value: _selectedCertificateTitle,
            decoration: const InputDecoration(labelText: "Certificate Title"),
            items: _certificateTitles
                .map(
                  (title) => DropdownMenuItem(
                    value: title,
                    child: Text(
                      title == 'manual' ? "Other (Enter manually)" : title,
                    ),
                  ),
                )
                .toList(),
            onChanged: (val) => setState(() => _selectedCertificateTitle = val),
            validator: (val) =>
                val == null ? "Please select certificate title" : null,
          ),
          const SizedBox(height: 16),

          if (_selectedCertificateTitle == "manual")
            _buildTextField(_certificateTitleManual, "Enter Certificate Title"),

          _buildTextField(_projectTitleController, "Project Name"),
          _buildTextField(_clientNameController, "Client Name"),
          DropdownButtonFormField<String>(
            value: _selectedOperationType,
            decoration: const InputDecoration(labelText: "Operation Type"),
            items: const [
              DropdownMenuItem(
                value: '',
                child: Text('-- Select Operation Type --'),
              ),
              DropdownMenuItem(value: 'LOAD-IN', child: Text('LOAD-IN')),
              DropdownMenuItem(value: 'LOAD-OUT', child: Text('LOAD-OUT')),
            ],
            onChanged: (val) => setState(() => _selectedOperationType = val),
            validator: (val) => (val == null || val.isEmpty)
                ? 'Please select operation type'
                : null,
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Mode of Operation",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...[
                "ROLL ON",
                "ROLL OFF",
                "LIFTED ON",
                "LIFTED OFF",
                "FLOAT ON",
                "FLOAT OFF",
              ].map(
                (option) => RadioListTile<String>(
                  title: Text(option),
                  value: option,
                  groupValue: _selectedModeOfOperation,
                  onChanged: (value) {
                    setState(() {
                      _selectedModeOfOperation = value;
                    });
                  },
                ),
              ),
            ],
          ),

          _buildTextField(_cargoController, "Cargo"),
          _buildTextField(_BargeVesselController, "Barge Vessel"),
          _buildTextField(_LocationController, "At Location"),
          _buildTextField(_surveyedByController, "Surveyed By"),

          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _noDateChecked
                      ? null
                      : () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() => _issuedDate = picked);
                          }
                        },
                  child: Text(
                    _issuedDate == null
                        ? "Select Issued Date"
                        : DateFormat('dd/MMM/yyyy').format(_issuedDate!),
                  ),
                ),
              ),
              Checkbox(
                value: _noDateChecked,
                onChanged: (val) =>
                    setState(() => _noDateChecked = val ?? false),
              ),
              const Text("NA"),
            ],
          ),

          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Back"),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    setState(() => _currentStep = 2);
                  }
                },
                child: const Text("Next"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCargoDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Step 2: Cargo Details",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),

        // N/A Checkbox
        CheckboxListTile(
          value: _isCargoNA,
          onChanged: (val) {
            setState(() {
              _isCargoNA = val ?? false;
            });
          },
          title: const Text("Mark Cargo Details as N/A"),
        ),

        if (!_isCargoNA) ...[
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _addCargoRow,
              icon: const Icon(Icons.add),
              label: const Text("Add Cargo Detail"),
            ),
          ),
          const SizedBox(height: 10),

          // Table Rows (Vertical per item)
          ..._cargoDetails.asMap().entries.map((entry) {
            final index = entry.key;
            final row = entry.value;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Cargo #${index + 1}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),

                    const SizedBox(height: 8),
                    TextField(
                      controller: row['Location'],
                      decoration: const InputDecoration(labelText: "Location"),
                    ),
                    TextField(
                      controller: row['Cargo'],
                      decoration: const InputDecoration(labelText: "Cargo"),
                    ),
                    TextField(
                      controller: row['IDMarkings'],
                      decoration: const InputDecoration(
                        labelText: "ID Markings",
                      ),
                    ),
                    TextField(
                      controller: row['Weight'],
                      decoration: const InputDecoration(labelText: "Weight"),
                    ),
                    TextField(
                      controller: row['Dimensions'],
                      decoration: const InputDecoration(
                        labelText: "Dimensions",
                      ),
                    ),
                    TextField(
                      controller: row['Remarks'],
                      decoration: const InputDecoration(labelText: "Remarks"),
                    ),

                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removeCargoRow(index),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],

        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton(
              onPressed: () {
                setState(() => _currentStep = 1);
              },
              child: const Text("Back"),
            ),
            ElevatedButton(
              onPressed: () {
                setState(
                  () => _currentStep = 3,
                ); // 👈 Move to Surveyor Signature step
              },
              child: const Text("Next"),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSurveyorSignatureSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Step 3: Surveyor Signature",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // N/A Checkbox
        CheckboxListTile(
          title: const Text("Surveyor Signature Not Applicable"),
          value: _signatureNotApplicable,
          onChanged: (val) {
            setState(() {
              _signatureNotApplicable = val ?? false;
            });
          },
        ),

        if (!_signatureNotApplicable) ...[
          const Text("Upload from Gallery or Draw Digitally:"),
          Row(
            children: [
              // Draw Signature Button
              ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text("Draw Signature"),
                      content: SizedBox(
                        width: double.maxFinite,
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Signature(
                                controller: _signatureController,
                                height: 200,
                                backgroundColor: Colors.grey[200]!,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      _signatureController.clear();
                                    },
                                    child: const Text("Clear"),
                                  ),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: () async {
                                      if (_signatureController.isNotEmpty) {
                                        final signatureData =
                                            await _signatureController
                                                .toPngBytes();
                                        if (signatureData != null) {
                                          setState(() {
                                            _surveyorSignature = XFile.fromData(
                                              signatureData,
                                            );
                                          });
                                          Navigator.of(context).pop();
                                        }
                                      }
                                    },
                                    child: const Text("Save"),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
                child: const Text("Draw Signature"),
              ),

              const SizedBox(width: 12),

              // Upload from Gallery Button
              ElevatedButton(
                onPressed: () async {
                  final ImagePicker picker = ImagePicker();
                  final XFile? image = await picker.pickImage(
                    source: ImageSource.gallery,
                  );
                  if (image != null) {
                    setState(() {
                      _surveyorSignature = image;
                    });
                  }
                },
                child: const Text("Upload Signature"),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Show signature preview if available
          if (_surveyorSignature != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: FutureBuilder(
                future: _surveyorSignature!.readAsBytes(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done &&
                      snapshot.hasData) {
                    return Image.memory(
                      snapshot.data as Uint8List,
                      height: 100,
                    );
                  } else {
                    return const CircularProgressIndicator();
                  }
                },
              ),
            ),
        ],

        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton(
              onPressed: () => setState(() => _currentStep = 2),
              child: const Text("Back"),
            ),
            ElevatedButton(
              onPressed: () => setState(() => _currentStep = 4),
              child: const Text("Next"),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildApproverSignatureSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Step 4: Approver Signature",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // Checkbox
        CheckboxListTile(
          value: _approverSignatureNA,
          onChanged: (val) =>
              setState(() => _approverSignatureNA = val ?? false),
          title: const Text("Approver Signature Not Applicable"),
        ),

        if (!_approverSignatureNA) ...[
          const Text("Upload from Gallery or Draw Digitally:"),
          Row(
            children: [
              ElevatedButton(
                onPressed: () async {
                  final ImagePicker picker = ImagePicker();
                  final XFile? image = await picker.pickImage(
                    source: ImageSource.gallery,
                  );
                  if (image != null) {
                    setState(() {
                      _approverSignature = image;
                    });
                  }
                },
                child: const Text("Upload Signature"),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text("Draw Signature"),
                      content: SizedBox(
                        width: double.maxFinite,
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Signature(
                                controller: _approverSignatureController,
                                height: 200,
                                backgroundColor: Colors.grey[200]!,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      _approverSignatureController.clear();
                                    },
                                    child: const Text("Clear"),
                                  ),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: () async {
                                      if (_approverSignatureController
                                          .isNotEmpty) {
                                        final signatureData =
                                            await _approverSignatureController
                                                .toPngBytes();
                                        if (signatureData != null) {
                                          setState(() {
                                            _approverSignature = XFile.fromData(
                                              signatureData,
                                            );
                                          });
                                          Navigator.of(context).pop();
                                        }
                                      }
                                    },
                                    child: const Text("Save"),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
                child: const Text("Draw Signature"),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (_approverSignature != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: FutureBuilder(
                future: _approverSignature!.readAsBytes(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done &&
                      snapshot.hasData) {
                    return Image.memory(
                      snapshot.data as Uint8List,
                      height: 100,
                    );
                  } else {
                    return const CircularProgressIndicator();
                  }
                },
              ),
            ),
        ],

        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton(
              onPressed: () => setState(() => _currentStep = 3),
              child: const Text("Back"),
            ),
            ElevatedButton(
              onPressed: () => setState(() => _currentStep = 5),
              child: const Text("Next"),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickApproverSignature() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _approverSignature = picked;
      });
    }
  }

  Widget _buildStampUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Step 6: Stamp Upload",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // N/A Checkbox
        CheckboxListTile(
          title: const Text("Stamp Not Applicable"),
          value: _isStampNA,
          onChanged: (val) {
            setState(() {
              _isStampNA = val ?? false;
              if (_isStampNA) {
                _selectedPredefinedStamp = null;
                _stampFile = null;
              }
            });
          },
        ),

        if (!_isStampNA) ...[
          Row(
            children: [
              ElevatedButton(
                onPressed: () async {
                  final XFile? picked = await _picker.pickImage(
                    source: ImageSource.gallery,
                  );
                  if (picked != null) {
                    setState(() {
                      _stampFile = picked;
                      _selectedPredefinedStamp =
                          null; // clear dropdown if manual
                    });
                  }
                },
                child: const Text("Upload Stamp Image"),
              ),
              const SizedBox(width: 20),

              // ➤ Predefined Stamp Dropdown
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: "Select Predefined Stamp",
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedPredefinedStamp,
                  items: _predefinedStamps.keys.map((label) {
                    return DropdownMenuItem<String>(
                      value: label,
                      child: Text(label),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedPredefinedStamp = value;
                      _stampFile = null; // clear file if dropdown selected
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Preview selected stamp (from file or predefined)
          if (_stampFile != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: FutureBuilder(
                future: _stampFile!.readAsBytes(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done &&
                      snapshot.hasData) {
                    return Image.memory(
                      snapshot.data as Uint8List,
                      height: 100,
                    );
                  } else {
                    return const CircularProgressIndicator();
                  }
                },
              ),
            )
          else if (_selectedPredefinedStamp != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Image.asset(
                _predefinedStamps[_selectedPredefinedStamp!]!,
                height: 100,
              ),
            ),
        ],

        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton(
              onPressed: () => setState(() => _currentStep = 4),
              child: const Text("Back"),
            ),
            ElevatedButton(
              onPressed: () => setState(() => _currentStep = 6),

              child: const Text("Finish"),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubmitSection() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Step 6: Submit & Generate PDF",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          /// ✅ Generate PDF Button with Confirmation
          ElevatedButton.icon(
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text("Generate PDF"),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) {
                  return AlertDialog(
                    title: const Text("Confirm"),
                    content: const Text(
                      "Are you sure you want to generate this PDF and submit the data?",
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text("Cancel"),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text("OK"),
                      ),
                    ],
                  );
                },
              );

              if (confirmed == true) {
                _handleGeneratePdfAndSubmit();
              }
            },
          ),

          const SizedBox(height: 10),

          /// 👁️ Preview Button
          OutlinedButton.icon(
            icon: const Icon(Icons.remove_red_eye),
            label: const Text("Preview Certificate"),
            onPressed: () async {
              Uint8List? stampBytes;
              Uint8List? signatureBytes;
              Uint8List? clientBytes;

              if (_stampFile != null) {
                stampBytes = await _stampFile!.readAsBytes();
              } else if (_selectedPredefinedStamp != null) {
                final byteData = await rootBundle.load(
                  _predefinedStamps[_selectedPredefinedStamp!]!,
                );
                stampBytes = byteData.buffer.asUint8List();
              }

              if (!_signatureNotApplicable && _surveyorSignature != null) {
                signatureBytes = await _surveyorSignature!.readAsBytes();
              }

              if (!_signatureNotApplicable && _approverSignature != null) {
                clientBytes = await _approverSignature!.readAsBytes();
              }

              final cargoList = _cargoDetails.asMap().entries.map((entry) {
                final index = entry.key;
                final row = entry.value;
                return CargoDetail(
                  serialNo: index + 1,
                  location: row['Location']?.text ?? '',
                  cargos: row['Cargo']?.text ?? '',
                  idMarkings: row['IDMarkings']?.text ?? '',
                  weight: row['Weight']?.text ?? '',
                  dimensions: row['Dimensions']?.text ?? '',
                  remarks: row['Remarks']?.text ?? '',
                );
              }).toList();

              await generateLoadoutPdfWithHeader(
                certificateId: 0,
                certificateTitle: _selectedCertificateTitle ?? '',
                headerImagePath: _selectedHeader ?? '',
                jobNumber: _jobNoController.text,
                certificateNumber: _certificateNoController.text,
                projectTitle: _projectTitleController.text,
                client: _clientNameController.text,
                cargo: _cargoController.text,
                OperationType: _selectedOperationType ?? '',
                bargeVessel: _BargeVesselController.text,
                modeOfOperation: _selectedModeOfOperation ?? '',
                location: _LocationController.text,
                issuedDate: _issuedDate != null
                    ? DateFormat('dd/MMM/yyyy').format(_issuedDate!)
                    : '',
                issuedBy: _surveyedByController.text,
                clientBytes: clientBytes,
                stampBytes: stampBytes,
                signatureBytes: signatureBytes,
                isCargoDetailsNA: _isCargoNA,
                cargoDetails: cargoList,
                cargoDetailsInput: cargoList,
              );

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("👁️ Preview PDF generated")),
              );
            },
          ),

          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () => setState(() => _currentStep = 5),
            child: const Text("Back"),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  /// 🔹 This is your existing logic, moved into a separate function
  Future<void> _handleGeneratePdfAndSubmit() async {
    if (_formKey.currentState?.validate() ?? false) {
      final db = DatabaseHelper.instance;

      Uint8List? stampBytes;
      Uint8List? signatureBytes;
      Uint8List? clientBytes;

      if (_stampFile != null) {
        stampBytes = await _stampFile!.readAsBytes();
      } else if (_selectedPredefinedStamp != null) {
        final byteData = await rootBundle.load(
          _predefinedStamps[_selectedPredefinedStamp!]!,
        );
        stampBytes = byteData.buffer.asUint8List();
      }

      if (!_signatureNotApplicable && _surveyorSignature != null) {
        signatureBytes = await _surveyorSignature!.readAsBytes();
      }

      if (!_signatureNotApplicable && _approverSignature != null) {
        clientBytes = await _approverSignature!.readAsBytes();
      }

      final cert = LoadoutCertificate(
        headerImagePath: _selectedHeader ?? '',
        certificateTitle: _selectedCertificateTitle ?? '',
        jobNumber: _jobNoController.text,
        certificateNumber: _certificateNoController.text,
        projectTitle: _projectTitleController.text,
        client: _clientNameController.text,
        cargo: _cargoController.text,
        location: _LocationController.text,
        modeOfOperation: _selectedModeOfOperation,
        operationType: _selectedOperationType,
        bargeVessel: _BargeVesselController.text,
        issuedDate: _issuedDate != null
            ? DateFormat('yyyy/MMM/dd').format(_issuedDate!)
            : '',
        issuedBy: _surveyedByController.text,
        isCargoDetailsNA: _isCargoNA,
        includeCargoDetails: !_isCargoNA,
        stampPath: '',
        signaturePath: '',
        signatureClient: '',
      );

      final certId = await db.insertLoadoutCertificate(cert);

      if (!_isCargoNA && _cargoDetails.isNotEmpty) {
        final cargoList = _cargoDetails.asMap().entries.map((entry) {
          final index = entry.key;
          final row = entry.value;
          return CargoDetail(
            serialNo: index + 1,
            location: row['Location']?.text ?? '',
            cargos: row['Cargo']?.text ?? '',
            idMarkings: row['IDMarkings']?.text ?? '',
            weight: row['Weight']?.text ?? '',
            dimensions: row['Dimensions']?.text ?? '',
            remarks: row['Remarks']?.text ?? '',
          )..certificateId = certId;
        }).toList();

        await db.insertCargoDetails(cargoList);
      }

      final fullCert = await db.getLoadoutCertificateById(certId);
      fullCert?.cargoDetails = await db.getCargoDetails(certId);

      try {
        final isOnline = await isConnected();
        if (isOnline && fullCert != null) {
          final certJson = fullCert.toJson()
            ..['model'] = 'Loadout'
            ..remove('id');

          if (certJson['cargoDetails'] != null &&
              certJson['cargoDetails'] is List) {
            certJson['cargoDetails'] = (certJson['cargoDetails'] as List).map((
              item,
            ) {
              final fixed = Map<String, dynamic>.from(item);
              fixed.remove('id');
              return fixed;
            }).toList();
          }

          final response = await ApiService.submitLoadoutCertificate(certJson);
          print("✅ Synced to server: $response");
          await db.markLoadoutCertificateAsSynced(certId);
        } else {
          print("📴 Offline: certificate queued for sync.");
        }
      } catch (e) {
        print("❌ Sync failed: $e");
      }

      await generateLoadoutPdfWithHeader(
        certificateId: certId,
        certificateTitle: cert.certificateTitle ?? '',
        headerImagePath: cert.headerImagePath ?? '',
        jobNumber: cert.jobNumber ?? '',
        certificateNumber: cert.certificateNumber ?? '',
        projectTitle: cert.projectTitle ?? '',
        client: cert.client ?? '',
        cargo: cert.cargo ?? '',
        OperationType: cert.operationType ?? '',
        bargeVessel: cert.bargeVessel ?? '',
        modeOfOperation: cert.modeOfOperation ?? '',
        location: cert.location ?? '',
        issuedDate: cert.issuedDate ?? '',
        issuedBy: cert.issuedBy ?? '',
        clientBytes: clientBytes,
        stampBytes: stampBytes,
        signatureBytes: signatureBytes,
        isCargoDetailsNA: _isCargoNA,
      );

      AppDialog.success(
        context,
        title: 'PDF generated',
        message: 'The loadout certificate PDF is ready.',
      );

      setState(() {
        _currentStep = 1;
      });
    }
  }

  Future<void> syncLoadoutCertificate(LoadoutCertificate cert) async {
    final String apiUrl = '${AppConfig.baseUrl}LoadOut/create-Loadout';
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(cert.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("✅ Loadout Certificate synced successfully");
      } else {
        print("❌ Failed to sync Loadout Certificate");
        print("Status: ${response.statusCode}");
        print("Body: ${response.body}");
      }
    } catch (e) {
      print("❌ Exception while syncing certificate: $e");
    }
  }

  Future<void> _submitFormData() async {
    print("HeaderImagePath: $_selectedHeader");
    print("CertificateType: $_selectedCertificateTitle");
    print("JobNumber: ${_jobNoController.text}");
    print("ProjectTitle: ${_projectTitleController.text}");
    print("CertificateNumber: ${_certificateNoController.text}");
    print("ClientName: ${_clientNameController.text}");
    print("Cargo: ${_cargoController.text}");
    print("DeparturePort: ${_selectedModeOfOperation}");
    print("ArrivalPort: ${_LocationController.text}");
    print("SurveyedBy: ${_surveyedByController.text}");
    print("Operationtype: ${_OperationTypeController.text}");
    print("BargeVessel: ${_BargeVesselController.text}");
    print("IssuedDate: $_issuedDate");

    // Upload images
    final stampPath = await uploadImage(
      _stampFile,
      '${AppConfig.baseUrl}LoadOut/upload-stamp',
    );
    final signPath = await uploadImage(
      _surveyorSignature,
      '${AppConfig.baseUrl}LoadOut/upload-signature',
    );
    final clientSignPath = await uploadImage(
      _approverSignature,
      '${AppConfig.baseUrl}LoadOut/upload-signature-client',
    );

    // Build the final form data
    final formData = _buildTLoadoutFormData(
      stampPath: stampPath,
      signaturePath: signPath,
      clientSignaturePath: clientSignPath,
    );

    // ✅ Debug full JSON payload
    print("📤 JSON Payload:");
    print(jsonEncode(formData));

    // ✅ Debug each cargo row
    final cargoList = formData["CargoDetails"] as List;
    for (int i = 0; i < cargoList.length; i++) {
      print("📦 Cargo #${i + 1}: ${cargoList[i]}");
    }

    // Submit to API
    // 🔁 Step 3: Send JSON to /create API
    final url = Uri.parse('${AppConfig.baseUrl}LoadOut/create-Loadout');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(formData),
    );

    // 🔍 Debug
    print('Status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final bytes = response.bodyBytes; // PDF is binary content
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/LoadoutCertificate.pdf');
      await file.writeAsBytes(bytes);
      print("✅ PDF saved to: ${file.path}");

      // Open the PDF using default viewer
      final result = await OpenFile.open(file.path);
      print("📂 Open result: ${result.message}");
    } else {
      print('❌ Failed to generate PDF');
      print('Response: ${response.body}');
    }
    print('Status: ${response.statusCode}');
  }

  Future<String?> uploadImage(XFile? image, String url) async {
    if (image == null) return null;

    final request = http.MultipartRequest('POST', Uri.parse(url));
    request.files.add(await http.MultipartFile.fromPath('file', image.path));

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final json = jsonDecode(responseBody);
      return json['filePath']; // Example: "/signatures/sign1.png"
    } else {
      print("Upload failed: $responseBody");
      return null;
    }
  }

  void _validateBeforeSubmit() {
    if (_selectedHeader == null || _selectedHeader!.isEmpty) {
      _showError("Please select a header image.");
      return;
    }

    if ((_selectedCertificateTitle ?? "").isEmpty &&
        _certificateTitleManual.text.trim().isEmpty) {
      _showError("Certificate title is required.");
      return;
    }

    if (_jobNoController.text.trim().isEmpty) {
      _showError("Job Number is required.");
      return;
    }
    if (_certificateNoController.text.trim().isEmpty) {
      _showError("Certificate Number is required.");
      return;
    }
    if (_projectTitleController.text.trim().isEmpty) {
      _showError("Project Title is required.");
      return;
    }
    if (_clientNameController.text.trim().isEmpty) {
      _showError("Client Name is required.");
      return;
    }
    if ((_selectedOperationType ?? "").isEmpty) {
      _showError("Please select an Operation Type.");
      return;
    }

    if (_cargoController.text.trim().isEmpty) {
      _showError("Cargo is required.");
      return;
    }
    if ((_selectedModeOfOperation ?? "").isEmpty) {
      _showError("Please select Mode of Operation.");
      return;
    }

    if (_BargeVesselController.text.trim().isEmpty) {
      _showError("BargeVessel  is required.");
      return;
    }
    if (_LocationController.text.trim().isEmpty) {
      _showError("Location is required.");
      return;
    }
    if (_surveyedByController.text.trim().isEmpty) {
      _showError("Surveyed By is required.");
      return;
    }

    // if (_recommendations.isEmpty) {
    //   _showError("At least one recommendation is required.");
    //   return;
    // }

    // ✅ All good → submit!
    _submitFormData();
  }

  void _showError(String message) {
    AppDialog.error(
      context,
      title: 'Check required information',
      message: message,
    );
  }

  // ---------------- HELPERS ----------------
  Map<String, dynamic> _buildTLoadoutFormData({
    required String? stampPath,
    required String? signaturePath,
    required String? clientSignaturePath,
  }) {
    return {
      "model": "Loadout",
      "HeaderImagePath": _selectedHeader ?? "",
      "CertificateTitle": _selectedCertificateTitle == "manual"
          ? _certificateTitleManual.text.trim()
          : _selectedCertificateTitle ?? "",
      "OperationType": _selectedOperationType ?? "",

      "JobNumber": _jobNoController.text.trim(),
      "ProjectTitle": _projectTitleController.text.trim(),
      "CertificateNumber": _certificateNoController.text.trim(),
      "Client": _clientNameController.text.trim(), // ✅ MATCHED
      "Cargo": _cargoController.text.trim(),
      "Modeofoperation": _selectedModeOfOperation ?? "",

      "BargeVessel": _BargeVesselController.text.trim(), // ✅ MATCHED
      "IssuedBy": _surveyedByController.text.trim(), // ✅ MATCHED
      "Location": _LocationController.text.trim(), // ✅ MATCHED
      "issuedDate": _issuedDate?.toIso8601String(),
      "NoDateCheckbox": _noDateChecked,
      "StampPath": stampPath ?? "",
      "SignaturePath": signaturePath ?? "",
      "SignatureClient": clientSignaturePath ?? "",
      "IncludeCargoDetails": true,
      "IsCargoDetailsNA": _isCargoNA,
      "CargoDetails": _cargoDetails
          .map(
            (row) => {
              "Location": row["Location"]?.text ?? "",
              "Cargos": row["Cargo"]?.text ?? "",
              "IDMarkings": row["IDMarkings"]?.text ?? "",
              "Weight": row["Weight"]?.text ?? "",
              "Dimensions": row["Dimensions"]?.text ?? "",
              "Remarks": row["Remarks"]?.text ?? "",
            },
          )
          .toList(),
    };
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    int maxLength = 100, // default to 100
  }) {
    return TextFormField(
      controller: controller,
      maxLength: maxLength,
      decoration: InputDecoration(labelText: label),
      textCapitalization: TextCapitalization.characters,
      inputFormatters: [
        UpperCaseTextFormatter(), // your custom formatter
      ],
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter $label';
        }
        if (value.length > maxLength) {
          return '$label must be at most $maxLength characters';
        }
        return null;
      },
    );
  }
}
