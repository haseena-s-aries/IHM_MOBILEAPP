import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:Auras/Db/database_helper.dart';
import 'package:Auras/app_config.dart';
import 'package:Auras/model/CarogDetails_model.dart';
import 'package:Auras/model/DRecommendation.dart';
import 'package:Auras/model/towage.dart';
import 'package:Auras/pdf/TowagePdf.dart';
import 'package:Auras/service/api_service.dart';
import 'package:Auras/utils/json_storage.dart';
import 'package:Auras/utils/app_dialog.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:signature/signature.dart';
// import 'package:pdf/pdf.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import 'package:intl/intl.dart';

class TowageCertificateScreen extends StatefulWidget {
  const TowageCertificateScreen({super.key});

  @override
  State<TowageCertificateScreen> createState() =>
      _TowageCertificateScreenState();
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

// Widget buildValidatedTextField({
//   required TextEditingController controller,
//   required String label,

// // }) {
// //   return TextFormField(
// //     controller: controller,
// //     inputFormatters: [
// //       UpperCaseTextFormatter(),
// //       LengthLimitingTextInputFormatter(maxLength),
// //     ],
// //     maxLength: maxLength,
// //     maxLengthEnforcement: MaxLengthEnforcement.enforced,
// //     decoration: InputDecoration(
// //       labelText: label,
// //       counterText: '', // optional: hides character count
// //     ),
// //     validator: (value) {
// //       if (value == null || value.isEmpty) {
// //         return 'Please enter $label';
// //       }
// //       if (value.length > maxLength) {
// //         return '$label must be $maxLength characters or less';
// //       }
// //       return null;
// //     },
// //   );
// }

class _TowageCertificateScreenState extends State<TowageCertificateScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 1;

  // Controllers
  final _certificateNoController = TextEditingController();
  final _jobNoController = TextEditingController();
  final _certificateTitleManual = TextEditingController();
  final _projectTitleController = TextEditingController();
  final _clientNameController = TextEditingController();
  final _towNameController = TextEditingController();
  final _tugNameController = TextEditingController();
  final _cargoController = TextEditingController();
  final _fromPortController = TextEditingController();
  final _toPortController = TextEditingController();
  final _surveyedByController = TextEditingController();
  final _reviewedByController = TextEditingController();
  String? cargo;
  String? _selectedHeader;
  String? _selectedCertificateTitle;
  DateTime? _issuedDate;
  bool _noDateChecked = false;
  List<DefaultRecommendation> _recommendations = [];
  bool _isCargoNA = false;
  List<Map<String, TextEditingController>> _cargoDetails = [];
  bool _signatureNotApplicable = false;
  XFile? _surveyorSignature;
  Uint8List? _drawnSignature;
  XFile? _approverSignature;
  final ImagePicker _picker = ImagePicker();
  String? _selectedPredefinedStamp;
  bool _useDrawMode = false;
  bool _approverSignatureNA = false;
  final ImagePicker _picker1 = ImagePicker();
  XFile? _stampFile;
  bool _isStampNA = false;

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

  @override
  void dispose() {
    _signatureController.dispose();
    super.dispose();
  }

  @override
  void dispose1() {
    _approverSignatureController.dispose();
    super.dispose();
  }

  void _removeCargoRow(int index) {
    setState(() {
      _cargoDetails.removeAt(index);
    });
  }

  Future<bool> isConnected() async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  final List<String> _certificateTitles = [
    "ARIES MARINE L.L.C",
    "ARIES OIL FIELD SERVICES L.L.C",
    "BAHRAIN MARINE W.L.L",
    "ARIES MARINE SERVICES CO. LTD",
    "ARIES MARINE CO. WLL.",
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
      appBar: AppBar(title: const Text("Towage Certificate")),
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
                  return _buildRecommendationsSection();
                case 3:
                  return _buildCargoDetailsSection();
                case 4:
                  return _buildSurveyorSignatureSection();

                case 5:
                  return _buildApproverSignatureSection();

                case 6:
                  return _buildStampUploadSection();

                case 7:
                  return _buildSubmitSection(context);
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
          _buildTextField(_towNameController, "Name of Tow"),
          _buildTextField(_tugNameController, "Name of Tug"),
          _buildTextField(_cargoController, "Cargo"),
          _buildTextField(_fromPortController, "From Location"),
          _buildTextField(_toPortController, "To Location"),
          _buildTextField(_surveyedByController, "Surveyed By"),
          _buildTextField(_reviewedByController, "Reviewed By"),

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
                        : "${_issuedDate!.day}-${_issuedDate!.month}-${_issuedDate!.year}",
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

  // ---------------- STEP 2 ----------------
  @override
  void initState() {
    super.initState();
    _recommendations = [
      "Voyage to commence within 24 hours from the time of our survey.",
      "Tow to depart in favorable weather conditions and forecast, typically less than Beaufort Force 5.",
      "Good seamanship to be followed, including but not limited to the following.",
      "Frequent weather conditions to be obtained by the tug boat from meteorological authorities en-route.",
      "Speed of tow to be controlled, commensurate with sea and weather conditions to prevent damage to vessel(s).",
      "Visual check to be kept at all times to the towed vessel with particular attention to lashing arrangements, towing gear, navigational lights and shapes and draft marks.",
      "Tug boat’s log book to be kept updated, showing above supervisions as well as towing speed, weather conditions and forecasts, radio communication and other relevant particulars.",
      "Vessel’s courses and positions to be plotted at regular intervals on navigational charts and same together with official log book to be available for review with relevant authorities.",
      "Additional tug assistance to be provided for steering in restricted channels as necessary.",
      "Pilots to be engaged on arrival in local waters, restricted channels and intermediate ports if any.",
      "All flush scuttles on both units to be properly closed and sealed at all times during the passage. All water tight doors on both units to be properly closed at all times of passage except when essential access by personnel is required.",
      "Daylight towing signals to be created and navigations light to be lit during the hours of darkness on both units.",
      "All parts of towage arrangements are to be free without any obstacles.",
      "The Master/operator is to provide Aries Oil Field Services L.L.C office with a daily report on the vessel’s course, speed, heading, ROB figures, weather conditions, distance covered and ETA at the destination port. Any deviation for weather routing etc. is to be reported to ariesmarine@ariesgroup.ae",
    ].map((text) => DefaultRecommendation(recommendationText: text)).toList();
  }

  Widget _buildRecommendationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Step 2: Default Recommendations",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        ..._recommendations.asMap().entries.map((entry) {
          final index = entry.key;
          final recommendation = entry.value;

          return Card(
            child: ListTile(
              title: Text(recommendation.recommendationText ?? ''),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _editRecommendation(index),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _removeRecommendation(index),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: _addRecommendation,
          icon: const Icon(Icons.add),
          label: const Text("Add Recommendation"),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton(
              onPressed: () => setState(() => _currentStep = 1),
              child: const Text("Back"),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() => _currentStep = 3);
              },
              child: const Text("Next"),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCargoDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Step 3: Cargo Details",
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
                setState(() => _currentStep = 2);
              },
              child: const Text("Back"),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() => _currentStep = 4);
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
          "Step 4: Surveyor Signature",
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

  Widget _buildApproverSignatureSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Step 5: Approver Signature",
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
              onPressed: () => setState(() => _currentStep = 4),
              child: const Text("Back"),
            ),
            ElevatedButton(
              onPressed: () => setState(() => _currentStep = 6),
              child: const Text("Next"),
            ),
          ],
        ),
      ],
    );
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
              onPressed: () => setState(() => _currentStep = 5),
              child: const Text("Back"),
            ),
            ElevatedButton(
              onPressed: () => setState(() => _currentStep = 7),

              child: const Text("Finish"),
            ),
          ],
        ),
      ],
    );
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////////////////
  Widget _buildSubmitSection(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Step 7: Submit & Generate PDF",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // Buttons Row
          Row(
            children: [
              // ✅ Generate PDF & Sync
              ElevatedButton.icon(
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text("Generate PDF"),
                onPressed: () async {
                  if (_formKey.currentState?.validate() ?? false) {
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
                      /// 🔹 Your existing Generate PDF logic
                      final db = DatabaseHelper();

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

                      if (!_signatureNotApplicable &&
                          _surveyorSignature != null) {
                        signatureBytes = await _surveyorSignature!
                            .readAsBytes();
                      }

                      if (!_signatureNotApplicable &&
                          _approverSignature != null) {
                        clientBytes = await _approverSignature!.readAsBytes();
                      }

                      final cargoList = _cargoDetails.asMap().entries.map((
                        entry,
                      ) {
                        final index = entry.key;
                        final row = entry.value;
                        return CargoDetail(
                          id: null,
                          serialNo: index + 1,
                          location: row['Location']?.text ?? '',
                          cargos: row['Cargo']?.text ?? '',
                          idMarkings: row['IDMarkings']?.text ?? '',
                          weight: row['Weight']?.text ?? '',
                          dimensions: row['Dimensions']?.text ?? '',
                          remarks: row['Remarks']?.text ?? '',
                        );
                      }).toList();

                      final updatedRecommendations = _recommendations
                          .map(
                            (r) => DefaultRecommendation(
                              id: null,
                              recommendationText: r.recommendationText,
                            ),
                          )
                          .toList();

                      final cert = TowageCertificate(
                        certificateType: _selectedCertificateTitle == "manual"
                            ? _certificateTitleManual.text
                            : _selectedCertificateTitle ?? '',
                        jobNumber: _jobNoController.text,
                        projectTitle: _projectTitleController.text,
                        certificateNumber: _certificateNoController.text,
                        clientName: _clientNameController.text,
                        towName: _towNameController.text,
                        tugName: _tugNameController.text,
                        cargo: _cargoController.text,
                        departurePort: _fromPortController.text,
                        arrivalPort: _toPortController.text,
                        surveyedBy: _surveyedByController.text,
                        reviewedBy: _reviewedByController.text,
                        issuedDate: _issuedDate != null
                            ? DateFormat('dd/MMM/yyy').format(_issuedDate!)
                            : "",
                        noDateCheckbox: _noDateChecked,
                        isCargoDetailsNA: _isCargoNA,
                        includeCargoDetails: _isCargoNA,
                        includeAnnexure2: true,
                        signatureClient: '',
                        stampPath: '',
                        signaturePath: '',
                        headerImagePath: _selectedHeader ?? '',
                        defaultRecommendations: updatedRecommendations,
                        cargoDetails: cargoList,
                      );

                      final certId = await db.insertCertificate(cert);
                      await db.insertRecommendations(
                        updatedRecommendations,
                        certId,
                      );
                      await db.insertCargoDetails(
                        cargoList.map((e) {
                          e.certificateId = certId;
                          return e;
                        }).toList(),
                      );

                      try {
                        final isOnline = await isConnected();
                        if (isOnline) {
                          final certJson = cert
                              .copyWith(certificateId: certId)
                              .toJson();
                          certJson.remove('id');

                          if (certJson['defaultRecommendations'] != null) {
                            certJson['defaultRecommendations'] =
                                (certJson['defaultRecommendations'] as List)
                                    .map((item) {
                                      final fixed = Map<String, dynamic>.from(
                                        item,
                                      );
                                      fixed.remove('id');
                                      fixed.remove('certificateId');
                                      return fixed;
                                    })
                                    .toList();
                          }

                          if (certJson['CargoDetails'] != null) {
                            certJson['CargoDetails'] =
                                (certJson['CargoDetails'] as List).map((item) {
                                  final fixed = Map<String, dynamic>.from(item);
                                  fixed.remove('id');
                                  fixed.remove('certificateId');
                                  return fixed;
                                }).toList();
                          }

                          certJson['issuedDate'] ??= DateTime.now()
                              .toIso8601String();

                          final responseMessage =
                              await ApiService.submitTowageCertificate(
                                certJson,
                              );
                          print("✅ Synced to server: $responseMessage");

                          await db.markTowageCertificateAsSynced(certId);
                        } else {
                          print("📴 Offline: certificate queued for sync.");
                        }
                      } catch (e) {
                        print("❌ Sync failed: $e");
                      }

                      final fullCert = await db.getTowageCertificateById(
                        certId,
                      );
                      fullCert?.defaultRecommendations = await db
                          .getRecommendations(certId);
                      fullCert?.cargoDetails = await db.getCargoDetails(certId);

                      if (fullCert != null) {
                        await generateTowagePdfWithHeader(
                          certificateId: certId,
                          CertificateType: fullCert.certificateType ?? '',
                          HeaderImagePath: fullCert.headerImagePath ?? '',
                          jobNumber: fullCert.jobNumber ?? '',
                          certificateNumber: fullCert.certificateNumber ?? '',
                          projectTitle: fullCert.projectTitle ?? '',
                          clientName: fullCert.clientName ?? '',
                          towName: fullCert.towName ?? '',
                          tugName: fullCert.tugName ?? '',
                          cargo: fullCert.cargo ?? '',
                          fromPort: fullCert.departurePort ?? '',
                          toPort: fullCert.arrivalPort ?? '',
                          stampBytes: stampBytes,
                          signatureBytes: signatureBytes,
                          clientBytes: clientBytes,
                          issuedDate: fullCert.issuedDate ?? '',
                          surveyedBy: fullCert.surveyedBy ?? '',
                          isCargoDetailsNA: _isCargoNA,
                          includeAnnexure2: true,
                        );
                      }

                      AppDialog.success(
                        context,
                        title: 'PDF generated',
                        message: 'The towage certificate PDF is ready.',
                      );

                      setState(() {
                        _currentStep = 1;
                      });
                    }
                  }
                },
              ),

              const SizedBox(width: 12),

              ElevatedButton.icon(
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

                  // ✅ Build cargo details for preview
                  final previewCargoDetails = _cargoDetails.asMap().entries.map(
                    (entry) {
                      return CargoDetail(
                        serialNo: entry.key + 1,
                        location: entry.value['Location']?.text ?? '',
                        cargos: entry.value['Cargo']?.text ?? '',
                        idMarkings: entry.value['IDMarkings']?.text ?? '',
                        weight: entry.value['Weight']?.text ?? '',
                        dimensions: entry.value['Dimensions']?.text ?? '',
                        remarks: entry.value['Remarks']?.text ?? '',
                      );
                    },
                  ).toList();

                  // ✅ Convert recommendations to DefaultRecommendation
                  final previewRecommendations = _recommendations.map((r) {
                    return DefaultRecommendation(
                      id: null,
                      recommendationText: r.recommendationText,
                    );
                  }).toList();

                  await generateTowagePdfWithHeader(
                    certificateId: 0,
                    CertificateType: _selectedCertificateTitle ?? '',
                    HeaderImagePath: _selectedHeader ?? '',
                    recommendations: _recommendations,
                    jobNumber: _jobNoController.text,
                    certificateNumber: _certificateNoController.text,
                    projectTitle: _projectTitleController.text,
                    clientName: _clientNameController.text,
                    towName: _towNameController.text,
                    tugName: _tugNameController.text,
                    cargo: _cargoController.text,
                    fromPort: _fromPortController.text,
                    toPort: _toPortController.text,
                    stampBytes: stampBytes,
                    signatureBytes: signatureBytes,
                    clientBytes: clientBytes,
                    issuedDate: _issuedDate != null
                        ? DateFormat('dd/MMM/yyy').format(_issuedDate!)
                        : '',
                    surveyedBy: _surveyedByController.text,
                    isCargoDetailsNA: _isCargoNA,
                    includeAnnexure2: true,
                    cargoDetails: _cargoDetails.asMap().entries.map((entry) {
                      final row = entry.value;
                      return CargoDetail(
                        serialNo: entry.key + 1,
                        location: row['Location']?.text ?? '',
                        cargos: row['Cargo']?.text ?? '',
                        idMarkings: row['IDMarkings']?.text ?? '',
                        weight: row['Weight']?.text ?? '',
                        dimensions: row['Dimensions']?.text ?? '',
                        remarks: row['Remarks']?.text ?? '',
                      );
                    }).toList(),

                    // defa: previewRecommendations, // ✅ fixed
                  );

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("👁️ Preview generated")),
                  );
                },
              ),

              const SizedBox(width: 12),
            ],
          ),

          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () => setState(() => _currentStep = 6),
            child: const Text("Back"),
          ),
        ],
      ),
    );
  }

  Future<void> _submitFormData() async {
    print("HeaderImagePath: $_selectedHeader");
    print("CertificateType: $_selectedCertificateTitle");
    print("JobNumber: ${_jobNoController.text}");
    print("ProjectTitle: ${_projectTitleController.text}");
    print("CertificateNumber: ${_certificateNoController.text}");
    print("ClientName: ${_clientNameController.text}");
    print("Cargo: ${_cargoController.text}");
    print("DeparturePort: ${_fromPortController.text}");
    print("ArrivalPort: ${_toPortController.text}");
    print("SurveyedBy: ${_surveyedByController.text}");
    print("ReviewedBy: ${_reviewedByController.text}");
    print("TowName: ${_towNameController.text}");
    print("TugName: ${_tugNameController.text}");
    print("IssuedDate: $_issuedDate");
    print("defaultRecommendations: ${_recommendations.length}");

    // Upload images
    final stampPath = await uploadImage(
      _stampFile,
      '${AppConfig.baseUrl}Certificate/upload-stamp',
    );
    final signPath = await uploadImage(
      _surveyorSignature,
      '${AppConfig.baseUrl}Certificate/upload-signature',
    );
    final clientSignPath = await uploadImage(
      _approverSignature,
      '${AppConfig.baseUrl}Certificate/upload-signature-client',
    );
    // Build the final form data
    final formData = _buildTowageFormData(
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
    final url = Uri.parse('${AppConfig.baseUrl}Certificate/create');
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
      final file = File('${dir.path}/TowageCertificate.pdf');
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
    if (_clientNameController.text.trim().length < 30) {
      _showError("Client Name is required.");
      return;
    }
    if (_towNameController.text.trim().isEmpty) {
      _showError("Tow Name is required.");
      return;
    }
    if (_tugNameController.text.trim().isEmpty) {
      _showError("Tug Name is required.");
      return;
    }
    if (_cargoController.text.trim().isEmpty) {
      _showError("Cargo is required.");
      return;
    }
    if (_fromPortController.text.trim().isEmpty) {
      _showError("Departure Port is required.");
      return;
    }
    if (_toPortController.text.trim().isEmpty) {
      _showError("Arrival Port is required.");
      return;
    }
    if (_surveyedByController.text.trim().isEmpty) {
      _showError("Surveyed By is required.");
      return;
    }
    if (_reviewedByController.text.trim().isEmpty) {
      _showError("Reviewed By is required.");
      return;
    }

    if (_recommendations.isEmpty) {
      _showError("At least one recommendation is required.");
      return;
    }

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

  Map<String, dynamic> _buildTowageFormData({
    required String? stampPath,
    required String? signaturePath,
    required String? clientSignaturePath,
    Uint8List? signatureBytes, // ✅ Add this, // ✅ Add this
  }) {
    return {
      "HeaderImagePath": _selectedHeader ?? "",
      "CertificateType": _selectedCertificateTitle == "manual"
          ? _certificateTitleManual.text.trim()
          : _selectedCertificateTitle ?? "",
      "JobNumber": _jobNoController.text.trim(),
      "CertificateNumber": _certificateNoController.text.trim(),
      "ProjectTitle": _projectTitleController.text.trim(),
      "ClientName": _clientNameController.text.trim().length > 30,
      "Cargo": _cargoController.text.trim(),
      "DeparturePort": _fromPortController.text.trim(),
      "ArrivalPort": _toPortController.text.trim(),
      "IssuedDate": _issuedDate != null
          ? "${_issuedDate!.year.toString().padLeft(4, '0')}-${_issuedDate!.month.toString().padLeft(2, '0')}-${_issuedDate!.day.toString().padLeft(2, '0')}"
          : null,
      "NoDateCheckbox": _noDateChecked,
      "SurveyedBy": _surveyedByController.text.trim(),
      "ReviewedBy": _reviewedByController.text.trim(),
      "TowName": _towNameController.text.trim(),
      "TugName": _tugNameController.text.trim(),
      "StampPath": stampPath ?? "",
      "SignaturePath": signaturePath ?? "",
      "SignatureClient": clientSignaturePath ?? "",
      "IsCargoDetailsNA": _isCargoNA,
      "IncludeAnnexure2": true,
      "IncludeCargoDetails": true,
      "defaultRecommendations": _recommendations
          .map((text) => {"RecommendationText": text})
          .toList(),
      "CargoDetails": _cargoDetails.map((row) {
        return {
          "Location": row["Location"]?.text ?? "",
          "Cargos": row["Cargo"]?.text ?? "",
          "IDMarkings": row["IDMarkings"]?.text ?? "",
          "Weight": row["Weight"]?.text ?? "",
          "Dimensions": row["Dimensions"]?.text ?? "",
          "Remarks": row["Remarks"]?.text ?? "",
        };
      }).toList(),
    };
  }

  void _addRecommendation() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Recommendation"),
        content: TextField(controller: controller, maxLines: 3),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _recommendations.add(
                  DefaultRecommendation(recommendationText: controller.text),
                );
              });
              Navigator.pop(context);
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  void _editRecommendation(int index) {
    final controller = TextEditingController(
      text: _recommendations[index].recommendationText ?? '',
    );
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Recommendation"),
        content: TextField(controller: controller, maxLines: 3),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _recommendations[index] = DefaultRecommendation(
                  recommendationText: controller.text,
                );
              });
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _removeRecommendation(int index) {
    setState(() {
      _recommendations.removeAt(index);
    });
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
      // validator: (value) {
      //   if (value == null || value.trim().isEmpty) {
      //     return 'Please enter $label';
      //   }
      //   if (value.length > maxLength) {
      //     return '$label must be at most $maxLength characters';
      //   }
      //   return null;
      // },
    );
  }
}
