import 'package:Auras/ThemeNotifier.dart';
import 'package:Auras/screen/screen/network_pdf_viewer_screen.dart';
import 'package:Auras/service/api_service.dart';
import 'package:Auras/utils/app_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';

class IhmReportInfoScreen extends StatefulWidget {
  final int jobId;
  final Future<List<Map<String, dynamic>>> Function()? loadVessels;

  const IhmReportInfoScreen({
    super.key,
    required this.jobId,
    this.loadVessels,
  });

  @override
  State<IhmReportInfoScreen> createState() => _IhmReportInfoScreenState();
}

class _IhmReportInfoScreenState extends State<IhmReportInfoScreen> {
  bool loading = true;
  bool saving = false;
  bool showNewCustomAppendix = false;
  int? selectedVesselId;
  final List<Map<String, dynamic>> vessels = [];

  final Map<String, TextEditingController> c = {
    'vesselName': TextEditingController(),
    'imoNumber': TextEditingController(),
    'officialNumber': TextEditingController(),
    'vesselType': TextEditingController(),
    'flag': TextEditingController(),
    'portOfRegistry': TextEditingController(),
    'classSociety': TextEditingController(),
    'callSign': TextEditingController(),
    'builder': TextEditingController(),
    'dateOfBuild': TextEditingController(),
    'loaM': TextEditingController(),
    'lbpM': TextEditingController(),
    'breadthM': TextEditingController(),
    'depthM': TextEditingController(),
    'draughtM': TextEditingController(),
    'grt': TextEditingController(),
    'nrt': TextEditingController(),
    'companyName': TextEditingController(),
    'companyAddress': TextEditingController(),
    'companyTel': TextEditingController(),
    'companyFax': TextEditingController(),
    'companyWebsite': TextEditingController(),
    'companyEmail': TextEditingController(),
    'companyLogoPath': TextEditingController(),
    'clientLogoPath': TextEditingController(),
    'clientName': TextEditingController(),
    'preparedBy': TextEditingController(),
    'checkedBy': TextEditingController(),
    'approvedBy': TextEditingController(),
    'uid': TextEditingController(),
    'jobNumber': TextEditingController(),
    'documentNo': TextEditingController(),
    'documentDate': TextEditingController(),
    'revisionNo': TextEditingController(text: '0'),
    'hazardousMaterialFindings': TextEditingController(),
    'labReportNo': TextEditingController(),
    'labReportingDate': TextEditingController(),
    'hazmatExpert': TextEditingController(),
    'shipManager': TextEditingController(),
    'shipManagerContact': TextEditingController(),
    'siteOfCheck': TextEditingController(),
    'dateOfSurvey': TextEditingController(),
    'samplingMethodology': TextEditingController(text: 'Wet the Sampling location prior to cutting and allow it to harden after cutting to prevent scatter.\nAppropriate Safety procedures are followed during onboard survey.'),
    'samplingOfFragmentsOfPaints': TextEditingController(text: 'Paint suspected to contain Lead & Lead Compounds are collected and analyzed from Deck area.'),
    'laboratory': TextEditingController(text: 'CHEM VI LABORATORY SDN BHD.'),
    'chemicalAnalysisMethod': TextEditingController(text: 'Refer Appendix 2'),
    'locationOfVisualSamplingCheck': TextEditingController(text: 'Refer to lists for visual / sampling check'),

    'ohsJobDetail': TextEditingController(),
    'ohsClient': TextEditingController(),
    'ohsJobLocation': TextEditingController(),
    'ohsJobNo': TextEditingController(),
    'ohsProjectInCharge': TextEditingController(),
    'ohsDivisionBranch': TextEditingController(),
    'ohsRaNo': TextEditingController(),
    'ohsRevNo': TextEditingController(),
    'ohsRevisionDate': TextEditingController(),
    'ohsPreparedBy': TextEditingController(),
    'ohsPreparedBySignPath': TextEditingController(),
    'ohsPreparedDate': TextEditingController(),
    'ohsApprovedBy': TextEditingController(),
    'ohsApprovedBySignPath': TextEditingController(),
    'ohsApprovedDate': TextEditingController(),

    'appendixFiveInformation': TextEditingController(),
    'customAppendixName': TextEditingController(),
  };

  final revisions = <Map<String, TextEditingController>>[];
  final paintRows = <Map<String, TextEditingController>>[];
  final equipmentRows = <Map<String, TextEditingController>>[];
  final structureRows = <Map<String, TextEditingController>>[];
  final necessaryInfo = <TextEditingController>[];
  final hseOfficers = <TextEditingController>[];
  final responsibleSupervisors = <TextEditingController>[];
  final participants = <TextEditingController>[];
  final ohsRiskRows = <Map<String, TextEditingController>>[];
  final appendixOnePoints = <Map<String, TextEditingController>>[];

  final appendixOneText = TextEditingController();
  final necessaryInfoText = TextEditingController();
  final appendixTwoFiles = <Map<String, dynamic>>[];
  final appendixFiveFiles = <Map<String, dynamic>>[];
  final appendixSevenFiles = <Map<String, dynamic>>[];
  final customAppendixFiles = <Map<String, dynamic>>[];
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in c.values) {
      controller.dispose();
    }
    for (final row in [...revisions, ...paintRows, ...equipmentRows, ...structureRows]) {
      for (final controller in row.values) {
        controller.dispose();
      }
    }
    for (final controller in necessaryInfo) {
      controller.dispose();
    }
    appendixOneText.dispose();
    necessaryInfoText.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      if (widget.loadVessels != null) {
        vessels
          ..clear()
          ..addAll(await widget.loadVessels!());
      }

      final data = await ApiService.fetchIhmReportInfo(widget.jobId);
      if (!mounted || data == null) return;
      if (data['vessels'] is List) {
        vessels
          ..clear()
          ..addAll((data['vessels'] as List)
              .map((e) => Map<String, dynamic>.from(e)));
      }

      final reportInfo = Map<String, dynamic>.from(data['reportInfo'] ?? data);
      final vessel = Map<String, dynamic>.from(data['vessel'] ?? data['jobVessel'] ?? {});
      _fillReportInfo(reportInfo);
      _fillVessel(vessel.isEmpty ? reportInfo : vessel);

      final job = Map<String, dynamic>.from(data['job'] ?? {});
      c['siteOfCheck']!.text = _s(job['auditPort'] ?? job['AuditPort']);
      c['dateOfSurvey']!.text = _date(job['startDate'] ?? job['StartDate']);

      if (c['ohsJobDetail']!.text.isEmpty) {
        c['ohsJobDetail']!.text = _s(job['projectName'] ?? job['ProjectName']);
      }
      if (c['ohsClient']!.text.isEmpty) {
        c['ohsClient']!.text = _s(job['clientName'] ?? job['ClientName']);
      }
      if (c['ohsJobLocation']!.text.isEmpty) {
        c['ohsJobLocation']!.text = _s(job['siteName'] ?? job['SiteName']);
      }
      if (c['ohsJobNo']!.text.isEmpty) {
        c['ohsJobNo']!.text = _s(job['jobNumber'] ?? job['JobNumber']);
      }
      if (c['ohsProjectInCharge']!.text.isEmpty) {
        c['ohsProjectInCharge']!.text =
            _s(reportInfo['hazmatExpert']);
      }
      if (c['ohsRevNo']!.text.isEmpty) {
        c['ohsRevNo']!.text =
            _s(reportInfo['revisionNo']);
      }
    
      if (c['ohsPreparedBy']!.text.isEmpty) {
        c['ohsPreparedBy']!.text =
            _s(reportInfo['preparedBy']);
      }
      if (c['ohsApprovedBy']!.text.isEmpty) {
        c['ohsApprovedBy']!.text =
            _s(reportInfo['approvedBy']);
      }

      _loadPeople(data['ohsPeople']);
      _replaceRows(ohsRiskRows, data['ohsRiskAssessmentRows'], _ohsRiskRow, (row, item) {
        row['activity']!.text = _s(item['activity'] ?? item['Activity']);
        row['hazardDescription']!.text = _s(item['hazardDescription'] ?? item['HazardDescription']);
        row['risks']!.text = _s(item['risks'] ?? item['Risks']);
        row['initialRiskP']!.text = _s(item['initialRiskP'] ?? item['InitialRiskP']);
        row['initialRiskS']!.text = _s(item['initialRiskS'] ?? item['InitialRiskS']);
        row['initialRiskR']!.text = _s(item['initialRiskR'] ?? item['InitialRiskR']);
        row['initialAlarp']!.text = _s(item['initialAlarp'] ?? item['InitialAlarp']);
        row['controlMeasures']!.text = _s(item['controlMeasures'] ?? item['ControlMeasures']);
        row['residualRiskP']!.text = _s(item['residualRiskP'] ?? item['ResidualRiskP']);
        row['residualRiskS']!.text = _s(item['residualRiskS'] ?? item['ResidualRiskS']);
        row['residualRiskR']!.text = _s(item['residualRiskR'] ?? item['ResidualRiskR']);
        row['residualAlarp']!.text = _s(item['residualAlarp'] ?? item['ResidualAlarp']);
        row['responsiblePerson']!.text = _s(item['responsiblePerson'] ?? item['ResponsiblePerson']);
      });
      if (ohsRiskRows.isEmpty) ohsRiskRows.add(_ohsRiskRow());

      _replaceRows(revisions, data['revisions'], _revisionRow, (row, item) {
        row['uid']!.text = _s(item['uid'] ?? reportInfo['uid']);
        row['rev']!.text = _s(item['revisionNo'] ?? reportInfo['revisionNo']);
        row['date']!.text = _date(item['revisionDate'] ?? reportInfo['documentDate']);
        row['description']!.text = _s(item['description']);
        row['pre']!.text = _s(item['preparedBy'] ?? reportInfo['preparedBy']);
        row['chk']!.text = _s(item['checkedBy'] ?? reportInfo['checkedBy']);
        row['apr']!.text = _s(item['approvedBy'] ?? reportInfo['approvedBy']);
      });

      _replaceRows(paintRows, data['paintAndCoatingSystems'], _paintRow, (row, item) {
        row['applicationOfPaint']!.text = _s(item['applicationOfPaint']);
        row['nameOfPaint']!.text = _s(item['nameOfPaint']);
        row['location']!.text = _s(item['location']);
        row['materials']!.text = _s(item['materialClassification']);
        row['mass']!.text = _s(item['mass']);
        row['unit']!.text = _s(item['unit']);
        row['remarks']!.text = _s(item['remarks']);
      });

      _replaceRows(equipmentRows, data['equipmentAndMachinery'], _equipmentRow, (row, item) {
        row['ihmCheckpointId']!.text = _s(item['ihmCheckpointId']);
        row['equipmentName']!.text = _s(item['equipmentName']);
        row['location']!.text = _s(item['location']);
        row['materials']!.text = _s(item['materialClassification']);
        row['partsWereUsed']!.text = _s(item['partsWereUsed']);
        row['unitKg']!.text = _s(item['unitKg']);
        row['quantityNo']!.text = _s(item['quantityNo']);
        row['totalKg']!.text = _s(item['totalKg']);
        row['remarks']!.text = _s(item['remarks']);
      });

      _replaceRows(structureRows, data['structureAndHull'], _structureRow, (row, item) {
        row['equipmentName']!.text = _s(item['equipmentName']);
        row['location']!.text = _s(item['location']);
        row['materials']!.text = _s(item['materialClassification']);
        row['partsWereUsed']!.text = _s(item['partsWereUsed']);
        row['approximateQuantity']!.text = _s(item['approximateQuantity']);
        row['remarks']!.text = _s(item['remarks']);
      });

      necessaryInfoText.text = (((data['necessaryInformationPoints'] as List?) ?? [])
        .map((e) => _s(e['description'] ?? e['Description']).trim())
        .where((x) => x.isNotEmpty)
        .join('\n'));

      _replaceRows(appendixOnePoints, data['appendixOneResultPoints'], _appendixOneRow, (row, item) {
        row['title']!.text = _s(item['title'] ?? item['Title']);
        row['description']!.text = _s(item['description'] ?? item['Description']);
      });

      if (appendixOnePoints.isEmpty) {
        appendixOnePoints.addAll(_defaultAppendixOneRows());
      }

      final appendixFiveInfo = ((data['appendixFiveInformationPoints'] as List?) ?? [])
        .map((e) => _s(e['description'] ?? e['Description']))
        .where((x) => x.trim().isNotEmpty)
        .join('\n');

    if (appendixFiveInfo.isNotEmpty) {
      c['appendixFiveInformation']!.text = appendixFiveInfo;
    } else if (c['appendixFiveInformation']!.text.isEmpty) {
      c['appendixFiveInformation']!.text = necessaryInfoText.text;
    }
   appendixTwoFiles
  ..clear()
  ..addAll(((data['appendixTwoAttachments'] as List?) ?? [])
      .map((e) => Map<String, dynamic>.from(e)));

appendixFiveFiles
  ..clear()
  ..addAll(((data['appendixFiveAttachments'] as List?) ?? [])
      .map((e) => Map<String, dynamic>.from(e)));

appendixSevenFiles
  ..clear()
  ..addAll(((data['appendixSevenAttachments'] as List?) ?? [])
      .map((e) => Map<String, dynamic>.from(e)));

customAppendixFiles
  ..clear()
  ..addAll(((data['customAppendices'] as List?) ?? [])
      .map((e) => Map<String, dynamic>.from(e)));

appendixOneText.text = (((data['appendixOneResultPoints'] as List?) ?? [])
    .map((e) {
      final title = _s(e['title'] ?? e['Title']).trim();
      final desc = _s(e['description'] ?? e['Description']).trim();
      return [title, desc].where((x) => x.isNotEmpty).join('\n');
    })
    .where((x) => x.trim().isNotEmpty)
    .join('\n\n'));

      if (revisions.isEmpty) _addRevision();
      if (paintRows.isEmpty) paintRows.add(_paintRow());
      if (equipmentRows.isEmpty) equipmentRows.add(_equipmentRow());
      if (structureRows.isEmpty) structureRows.add(_structureRow());
      if (necessaryInfo.isEmpty) necessaryInfo.add(TextEditingController());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }


  Future<void> _refreshAppendixFiles() async {
  final data = await ApiService.fetchIhmReportInfo(widget.jobId);
  if (!mounted || data == null) return;

  setState(() {
    appendixTwoFiles
      ..clear()
      ..addAll(((data['appendixTwoAttachments'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e)));

    appendixFiveFiles
      ..clear()
      ..addAll(((data['appendixFiveAttachments'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e)));

    appendixSevenFiles
      ..clear()
      ..addAll(((data['appendixSevenAttachments'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e)));

    customAppendixFiles
      ..clear()
      ..addAll(((data['customAppendices'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e)));
  });
}
  void _fillReportInfo(Map<String, dynamic> x) {
    c['companyName']!.text = _s(x['companyName']);
    c['companyAddress']!.text = _s(x['companyAddress']);
    c['companyTel']!.text = _s(x['companyTel']);
    c['companyFax']!.text = _s(x['companyFax']);
    c['companyWebsite']!.text = _s(x['companyWebsite']);
    c['companyEmail']!.text = _s(x['companyEmail']);
    c['companyLogoPath']!.text = _s(x['companyLogoPath']);
    c['clientLogoPath']!.text = _s(x['clientLogoPath']);
    c['clientName']!.text = _s(x['clientName']);
    c['preparedBy']!.text = _s(x['preparedBy']);
    c['checkedBy']!.text = _s(x['checkedBy']);
    c['approvedBy']!.text = _s(x['approvedBy']);
    c['uid']!.text = _s(x['uid']);
    c['jobNumber']!.text = _s(x['jobNumber']);
    c['documentNo']!.text = _s(x['documentNo']);
    c['documentDate']!.text = _date(x['documentDate']);
    c['revisionNo']!.text = _s(x['revisionNo']).isEmpty ? '0' : _s(x['revisionNo']);
    c['hazardousMaterialFindings']!.text = _s(x['hazardousMaterialFindings']);
    c['labReportNo']!.text = _s(x['labReportNo']);
    c['labReportingDate']!.text = _date(x['labReportingDate']);
    c['hazmatExpert']!.text = _s(x['hazmatExpert']);

    c['shipManagerContact']!.text = _s(x['shipManagerContact']);
    c['samplingMethodology']!.text = _s(x['samplingMethodology']).isEmpty ? c['samplingMethodology']!.text : _s(x['samplingMethodology']);
    c['samplingOfFragmentsOfPaints']!.text = _s(x['samplingOfFragmentsOfPaints']).isEmpty ? c['samplingOfFragmentsOfPaints']!.text : _s(x['samplingOfFragmentsOfPaints']);
    c['laboratory']!.text = _s(x['laboratory']).isEmpty ? c['laboratory']!.text : _s(x['laboratory']);
    c['chemicalAnalysisMethod']!.text = _s(x['chemicalAnalysisMethod']).isEmpty ? c['chemicalAnalysisMethod']!.text : _s(x['chemicalAnalysisMethod']);
    c['locationOfVisualSamplingCheck']!.text = _s(x['locationOfVisualSamplingCheck']).isEmpty ? c['locationOfVisualSamplingCheck']!.text : _s(x['locationOfVisualSamplingCheck']);

    c['ohsJobDetail']!.text = _s(x['ohsJobDetail']);
    c['ohsClient']!.text = _s(x['ohsClient']);
    c['ohsJobLocation']!.text = _s(x['ohsJobLocation']);
    c['ohsJobNo']!.text = _s(x['ohsJobNo']);
    c['ohsProjectInCharge']!.text = _s(x['ohsProjectInCharge']);
    c['ohsDivisionBranch']!.text = _s(x['ohsDivisionBranch']);
    c['ohsRaNo']!.text = _s(x['ohsRaNo']);
    c['ohsRevNo']!.text = _s(x['ohsRevNo']);
    c['ohsRevisionDate']!.text = _date(x['ohsRevisionDate']);
    c['ohsPreparedBy']!.text = _s(x['ohsPreparedBy']);
    c['ohsPreparedBySignPath']!.text = _s(x['ohsPreparedBySignPath']);
    c['ohsPreparedDate']!.text = _date(x['ohsPreparedDate']);
    c['ohsApprovedBy']!.text = _s(x['ohsApprovedBy']);
    c['ohsApprovedBySignPath']!.text = _s(x['ohsApprovedBySignPath']);
    c['ohsApprovedDate']!.text = _date(x['ohsApprovedDate']);
  }

  void _fillVessel(Map<String, dynamic> x) {
  selectedVesselId = int.tryParse(_s(x['id'] ?? x['Id']));
  c['vesselName']!.text = _s(x['vesselName'] ?? x['VesselName']);
  c['imoNumber']!.text = _s(x['imoNumber'] ?? x['ImoNumber']);
  c['officialNumber']!.text = _s(x['officialNumber'] ?? x['OfficialNumber']);
  c['vesselType']!.text = _s(x['vesselType'] ?? x['VesselType']);
  c['flag']!.text = _s(x['flag'] ?? x['Flag']);
  c['portOfRegistry']!.text = _s(x['portOfRegistry'] ?? x['PortOfRegistry']);
  c['classSociety']!.text = _s(x['classSociety'] ?? x['ClassSociety']);
  c['callSign']!.text = _s(x['callSign'] ?? x['CallSign']);
  c['builder']!.text = _s(x['builder'] ?? x['Builder']);
  c['dateOfBuild']!.text = _date(x['dateOfBuild'] ?? x['DateOfBuild']);
  c['loaM']!.text = _s(x['lengthOverall'] ?? x['LengthOverall']);
  c['lbpM']!.text = _s(x['lengthBetweenPerpendiculars'] ?? x['LengthBetweenPerpendiculars']);
  c['breadthM']!.text = _s(x['breadth'] ?? x['Breadth']);
  c['depthM']!.text = _s(x['depth'] ?? x['Depth']);
  c['draughtM']!.text = _s(x['draughtMoulded'] ?? x['DraughtMoulded']);
  c['grt']!.text = _s(x['grossTonnage'] ?? x['GrossTonnage']);
  c['nrt']!.text = _s(x['netTonnage'] ?? x['NetTonnage']);
  c['shipManager']!.text = _s(x['managerName'] ?? x['ManagerName']);
}

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeNotifier>().colors;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colors.bgCard,
        title: const Text('IHM Report'),
        actions: [
          IconButton(
            tooltip: 'Generate PDF',
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: saving ? null : generatePdf,
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _section('Vessel Information', [
                      ..._vesselFields(),
                      const SizedBox(height: 12),
                      _jobPickerField(),
                    ]),
                  _section('Cover Page Company Details and Document Details', _coverFields()),
                  _section('Revision History', [_revisionTable()]),
                  _section('Introduction and Scope of Work', _scopeFields()),
                  _section('HAZARDOUS MATERIALS CONTAINED IN THE SHIP’S STRUCTURE AND EQUIPMENT', [
                    _editableTable(
                      'I-1 Paints and coating systems containing materials listed in Table A and Table B of appendix 1 of the guidelines',
                      paintRows,
                      ['No.', 'Application of Paint', 'Name of Paint', 'Location', 'Materials', 'Mass', 'Unit', 'Remarks'],
                      ['applicationOfPaint', 'nameOfPaint', 'location', 'materials', 'mass', 'unit', 'remarks'],
                      () => setState(() => paintRows.add(_paintRow())),
                    ),
                    _editableTable(
                      'I-2 Equipment and Machinery containing materials listed in Table A and B of appendix of the guidelines',
                      equipmentRows,
                      ['No.', 'Name of equipment and machinery', 'Location', 'Materials', 'Parts were used', 'Unit(kg)', 'No.', 'Total(kg)', 'Remarks'],
                      ['equipmentName', 'location', 'materials', 'partsWereUsed', 'unitKg', 'quantityNo', 'totalKg', 'remarks'],
                      () => setState(() => equipmentRows.add(_equipmentRow())),
                    ),
                    _editableTable(
                      'I-3 Structure and hull containing materials listed in Table A and Table B of appendix 1 of the guidelines',
                      structureRows,
                      ['No.', 'Name of equipment and machinery', 'Location', 'Materials', 'Parts were used', 'Approximate quantity', 'Remarks'],
                      ['equipmentName', 'location', 'materials', 'partsWereUsed', 'approximateQuantity', 'remarks'],
                      () => setState(() => structureRows.add(_structureRow())),
                    ),
                  ]),
                  _section('Collection of Necessary Information', [_necessaryInformationTextArea()]),
                  _section('Visual / Sampling Check Plan', _visualSamplingFields()),
                  _section('OHS Risk Assessment', _ohsFields()),
                  _section('Appendix 1 Results From The Sampling Check / Visual', _appendixOneFields()),
                  _section('Appendix 2 - Test Results For Hazardous Materials', [
                    _attachmentList(appendixTwoFiles),
                    _uploadButton('Upload Appendix 2 Files', 'AppendixTwo'),
                  ]),
                  _section('Appendix 5 - Vessel Documents', _appendixFiveFields()),
                  _section('Appendix 7 - Qualification and Capability Certificate', [
                    _attachmentList(appendixSevenFiles),
                    _uploadButton('Upload Appendix 7 Files', 'AppendixSeven'),
                  ]),
                  _section('More Appendix', _customAppendixFields()),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save),
                    label: Text(saving ? 'Saving...' : 'Save Report Info'),
                    onPressed: saving ? null : save,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Generate PDF Report'),
                    onPressed: saving ? null : generatePdf,
                  ),
                ],
              ),
            ),
    );
  }

  List<Widget> _vesselFields() => [
        _field('imoNumber', 'IMO Number'),
        _field('officialNumber', 'Official Number'),
        _field('vesselType', 'Vessel Type'),
        _field('flag', 'Flag'),
        _field('portOfRegistry', 'Port of Registry'),
        _field('classSociety', 'Class Society'),
        _field('callSign', 'Call Sign'),
        _field('builder', 'Builder'),
        _dateField('dateOfBuild', 'Date of Build'),
        _field('loaM', 'LOA (m)'),
        _field('lbpM', 'LBP (m)'),
        _field('breadthM', 'Breadth (m)'),
        _field('depthM', 'Depth (m)'),
        _field('draughtM', 'Draught (m)'),
        _field('grt', 'GRT'),
        _field('nrt', 'NRT'),
      ];

  List<Widget> _coverFields() => [
        _field('companyName', 'Company Name'),
        _field('companyAddress', 'Address', maxLines: 3),
        _field('companyTel', 'Tel'),
        _field('companyFax', 'Fax'),
        _field('companyWebsite', 'Website URL'),
        _field('companyEmail', 'Email'),
        _field('companyLogoPath', 'Company Logo'),
        _assetUploadButton('Upload Company Logo', 'companyLogoPath'),
        _field('clientLogoPath', 'Client Logo'),
        _assetUploadButton('Upload Client Logo', 'clientLogoPath'),
        if (c['clientLogoPath']!.text.trim().isEmpty) _field('clientName', 'Client Name'),
        _field('preparedBy', 'Prepared By'),
        _field('checkedBy', 'Checked By'),
        _field('approvedBy', 'Approved By'),
        _field('uid', 'UID Number'),
        _field('jobNumber', 'Job Number'),
        _field('documentNo', 'Doc Number'),
        _dateField('documentDate', 'Date'),
        _field('revisionNo', 'Revision Number'),
      ];

  List<Widget> _scopeFields() => [
        _field('hazardousMaterialFindings', 'Hazardous Material Findings', maxLines: 4),
        _field('labReportNo', 'Lab Test Report No'),
        _field('labReportingDate', 'Reporting Date'),
        _field('hazmatExpert', 'Hazmat Expert'),
      ];

  Widget _section(String title, List<Widget> children) {
  final colors = context.watch<ThemeNotifier>().colors;

  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: colors.bgCard,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.grey.shade300),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  );
}

  Widget _field(String key, String label, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c[key],
        maxLines: maxLines,
        onChanged: key == 'clientLogoPath' ? (_) => setState(() {}) : null,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }

  Widget _necessaryInformationTextArea() {
  return TextField(
    controller: necessaryInfoText,
    maxLines: 10,
    decoration: const InputDecoration(
      labelText: 'Necessary Information Points',
      helperText: 'One point per line. Add, edit, or delete lines.',
      border: OutlineInputBorder(),
    ),
  );
}


  Widget _jobPickerField() {
  return InkWell(
    onTap: _pickJobReport,
    child: InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Open another vessel job report',
        border: OutlineInputBorder(),
        suffixIcon: Icon(Icons.arrow_drop_down),
      ),
      child: Text(
        '${c['vesselName']!.text.trim()} - ${c['jobNumber']!.text.trim()}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
}

Future<void> _pickJobReport() async {
  final search = TextEditingController();

  final picked = await showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      var items = <Map<String, dynamic>>[];

      return StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> load(String query) async {
            final result = await ApiService.fetchIhmJobReportOptions(query: query);
            setSheetState(() => items = result);
          }

          if (items.isEmpty) {
            load('');
          }

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: search,
                    decoration: const InputDecoration(
                      labelText: 'Search vessel or job number',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: load,
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final vesselName = _s(item['vesselName'] ?? item['VesselName']);
                        final jobNumber = _s(item['jobNumber'] ?? item['JobNumber']);
                        return ListTile(
                          title: Text('$vesselName - $jobNumber'),
                          onTap: () => Navigator.pop(context, item),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  search.dispose();

  if (picked == null) return;

  final jobId = int.tryParse(_s(picked['jobId'] ?? picked['JobId'] ?? picked['id'] ?? picked['Id']));
  if (jobId == null) return;

  if (!mounted) return;
  await _loadTemplateFromJob(jobId);
}
Future<void> _loadTemplateFromJob(int sourceJobId) async {
  setState(() => loading = true);

  try {
    final data = await ApiService.fetchIhmReportInfo(sourceJobId);
    if (!mounted || data == null) return;

    final reportInfo = Map<String, dynamic>.from(data['reportInfo'] ?? {});
    final job = Map<String, dynamic>.from(data['job'] ?? {});

    _fillReportInfo(reportInfo);

    c['jobNumber']!.text = _s(job['jobNumber'] ?? job['JobNumber']);
    c['siteOfCheck']!.text = _s(job['auditPort'] ?? job['AuditPort']);
    c['dateOfSurvey']!.text = _date(job['startDate'] ?? job['StartDate']);

    c['ohsJobDetail']!.text = _s(job['projectName'] ?? job['ProjectName']);
    c['ohsClient']!.text = _s(job['clientName'] ?? job['ClientName']);
    c['ohsJobLocation']!.text = _s(job['siteName'] ?? job['SiteName']);
    c['ohsJobNo']!.text = _s(job['jobNumber'] ?? job['JobNumber']);

    _loadPeople(data['ohsPeople']);

    _replaceRows(
      ohsRiskRows,
      data['ohsRiskAssessmentRows'],
      _ohsRiskRow,
      (row, item) {
        row['activity']!.text = _s(item['activity'] ?? item['Activity']);
        row['hazardDescription']!.text =
            _s(item['hazardDescription'] ?? item['HazardDescription']);
        row['risks']!.text = _s(item['risks'] ?? item['Risks']);
        row['initialRiskP']!.text =
            _s(item['initialRiskP'] ?? item['InitialRiskP']);
        row['initialRiskS']!.text =
            _s(item['initialRiskS'] ?? item['InitialRiskS']);
        row['initialRiskR']!.text =
            _s(item['initialRiskR'] ?? item['InitialRiskR']);
        row['initialAlarp']!.text =
            _s(item['initialAlarp'] ?? item['InitialAlarp']);
        row['controlMeasures']!.text =
            _s(item['controlMeasures'] ?? item['ControlMeasures']);
        row['residualRiskP']!.text =
            _s(item['residualRiskP'] ?? item['ResidualRiskP']);
        row['residualRiskS']!.text =
            _s(item['residualRiskS'] ?? item['ResidualRiskS']);
        row['residualRiskR']!.text =
            _s(item['residualRiskR'] ?? item['ResidualRiskR']);
        row['residualAlarp']!.text =
            _s(item['residualAlarp'] ?? item['ResidualAlarp']);
        row['responsiblePerson']!.text =
            _s(item['responsiblePerson'] ?? item['ResponsiblePerson']);
      },
    );

    if (ohsRiskRows.isEmpty) {
      ohsRiskRows.add(_ohsRiskRow());
    }

    necessaryInfoText.text =
        (((data['necessaryInformationPoints'] as List?) ?? [])
            .map((e) => _s(e['description'] ?? e['Description']).trim())
            .where((x) => x.isNotEmpty)
            .join('\n'));

    appendixOneText.text =
        (((data['appendixOneResultPoints'] as List?) ?? [])
            .map((e) {
              final title = _s(e['title'] ?? e['Title']).trim();
              final desc = _s(e['description'] ?? e['Description']).trim();
              return [title, desc].where((x) => x.isNotEmpty).join('\n');
            })
            .where((x) => x.trim().isNotEmpty)
            .join('\n\n'));

    final appendixFiveInfo =
        ((data['appendixFiveInformationPoints'] as List?) ?? [])
            .map((e) => _s(e['description'] ?? e['Description']))
            .where((x) => x.trim().isNotEmpty)
            .join('\n');

    c['appendixFiveInformation']!.text =
        appendixFiveInfo.isNotEmpty ? appendixFiveInfo : necessaryInfoText.text;

    await ApiService.copyIhmAppendicesFromJob(
  currentJobId: widget.jobId,
  sourceJobId: sourceJobId,
);

await _refreshAppendixFiles();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Selected job details loaded into current report'),
      ),
    );
  } finally {
    if (mounted) setState(() => loading = false);
  }
}
  Future<void> _pickVessel() async {
    final search = TextEditingController();
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        var filtered = List<Map<String, dynamic>>.from(vessels);
        return StatefulBuilder(
          builder: (context, setSheetState) => Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * .65,
              child: Column(
                children: [
                  TextField(
                    controller: search,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Search vessel', prefixIcon: Icon(Icons.search)),
                    onChanged: (value) {
                      final q = value.toLowerCase();
                      setSheetState(() {
                        filtered = vessels
                          .where((v) => _s(v['vesselName'] ?? v['VesselName']).toLowerCase().contains(q))
                          .toList();
                      });
                    },
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final item = filtered[i];
                        return ListTile(
                          title: Text(_s(item['vesselName'] ?? item['VesselName'])),
                          subtitle: Text(_s(item['imoNumber'] ?? item['ImoNumber'])),
                          onTap: () => Navigator.pop(context, item),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    search.dispose();
    if (picked != null) setState(() => _fillVessel(picked));
  }

  Widget _revisionTable() {
    return _editableTable(
      '',
      revisions,
      ['UID', 'Rev', 'Date', 'Description', 'Pre', 'Chk', 'Apr'],
      ['uid', 'rev', 'date', 'description', 'pre', 'chk', 'apr'],
      () => setState(_addRevision),
    );
  }

  Widget _editableTable(
    String heading,
    List<Map<String, TextEditingController>> rows,
    List<String> headers,
    List<String> keys,
    VoidCallback onAdd,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (heading.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(heading)),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [
                for (final header in headers) DataColumn(label: Text(header)),
                const DataColumn(label: Text('')),
              ],
              rows: [
                for (var i = 0; i < rows.length; i++)
                  DataRow(cells: [
                    if (headers.first == 'No.')
                      DataCell(Text('${i + 1}'))
                    else
                      DataCell(_cell(rows[i][keys.first]!)),
                    for (final key in headers.first == 'No.' ? keys : keys.skip(1)) DataCell(_cell(rows[i][key]!)),
                    DataCell(IconButton(
                      tooltip: 'Remove row',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: rows.length == 1 ? null : () => setState(() => rows.removeAt(i)),
                    )),
                  ]),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(icon: const Icon(Icons.add), label: const Text('Add Row'), onPressed: onAdd),
          ),
        ],
      ),
    );
  }

  Widget _cell(TextEditingController controller) {
    return SizedBox(
      width: 170,
      child: TextField(
        controller: controller,
        decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
      ),
    );
  }

  Widget _necessaryInformationList() {
    return Column(
      children: [
        for (var i = 0; i < necessaryInfo.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: necessaryInfo[i],
                    maxLines: 2,
                    decoration: InputDecoration(labelText: 'Point ${i + 1}', border: const OutlineInputBorder()),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove point',
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: necessaryInfo.length == 1 ? null : () => setState(() => necessaryInfo.removeAt(i)),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Point'),
            onPressed: () => setState(() => necessaryInfo.add(TextEditingController())),
          ),
        ),
      ],
    );
  }

  List<Widget> _visualSamplingFields() => [
  _field('shipManager', 'Ship Manager'),
  _field('shipManagerContact', 'Ship Manager Contact Point', maxLines: 2),
  _field('siteOfCheck', 'Site of Check'),
  _dateField('dateOfSurvey', 'Date of Survey'),
  _field('samplingMethodology', 'Sampling Methodology', maxLines: 4),
  _field('samplingOfFragmentsOfPaints', 'Sampling of Fragments of Paints', maxLines: 3),
  _field('laboratory', 'Laboratory'),
  _field('chemicalAnalysisMethod', 'Chemical Analysis Method'),
  _field('locationOfVisualSamplingCheck', 'Location of Visual / Sampling Check', maxLines: 3),
];

  List<Widget> _ohsFields() => [
    _field('ohsJobDetail', 'Job Detail'),
    _field('ohsClient', 'Client Name'),
    _field('ohsJobLocation', 'Job Location'),
    _field('ohsJobNo', 'Job Number'),
    _field('ohsProjectInCharge', 'Project In Charge'),
    _field('ohsDivisionBranch', 'Division / Branch'),
    _field('ohsRaNo', 'RA No'),
    _field('ohsRevNo', 'Rev No'),
    _dateField('ohsRevisionDate', 'Rev Date'),
    _limitedPeople('HSE Officer', hseOfficers, 3),
    _limitedPeople('Responsible Supervisor', responsibleSupervisors, 6),
    _limitedPeople('Participants', participants, 12),
    _ohsRiskTable(),
    _field('ohsPreparedBy', 'Prepared By'),
    _field('ohsPreparedBySignPath', 'Prepared By Sign'),
    _assetUploadButton('Upload Prepared By Sign', 'ohsPreparedBySignPath'),
    _dateField('ohsPreparedDate', 'Prepared By Date'),
    _field('ohsApprovedBy', 'Approved By'),
    _field('ohsApprovedBySignPath', 'Approved By Sign'),
    _assetUploadButton('Upload Approved By Sign', 'ohsApprovedBySignPath'),
   _dateField('ohsApprovedDate', 'Approved By Date'),
  ];

  Widget _limitedPeople(String title, List<TextEditingController> list, int max) {
    if (list.isEmpty) list.add(TextEditingController());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        for (var i = 0; i < list.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: list[i],
                    decoration: InputDecoration(
                      labelText: '$title ${i + 1}',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: list.length == 1 ? null : () => setState(() => list.removeAt(i)),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add'),
            onPressed: list.length >= max ? null : () => setState(() => list.add(TextEditingController())),
          ),
        ),
      ],
    );
  }

  Widget _ohsRiskTable() {
    return _editableTable(
      'OHS Risk Assessment Table',
      ohsRiskRows,
      ['Activity', 'Hazard Description', 'Risks', 'P', 'S', 'R', 'ALARP', 'Control measures', 'P', 'S', 'R', 'ALARP', 'Responsible Person'],
      ['activity', 'hazardDescription', 'risks', 'initialRiskP', 'initialRiskS', 'initialRiskR', 'initialAlarp', 'controlMeasures', 'residualRiskP', 'residualRiskS', 'residualRiskR', 'residualAlarp', 'responsiblePerson'],
      () => setState(() => ohsRiskRows.add(_ohsRiskRow())),
    );
  }
  List<Widget> _appendixOneFields() => [
  TextField(
    controller: appendixOneText,
    maxLines: 12,
    decoration: const InputDecoration(
      labelText: 'Appendix 1 Points',
      helperText: 'One point per line. Remove a line to delete old point.',
      border: OutlineInputBorder(),
    ),
  ),
];

List<Widget> _appendixFiveFields() => [
  TextField(
    controller: c['appendixFiveInformation'],
    maxLines: 8,
    decoration: const InputDecoration(
      labelText: 'Collection of Necessary Information',
      border: OutlineInputBorder(),
    ),
  ),
  const SizedBox(height: 10),
  _attachmentList(appendixFiveFiles),
  _uploadButton('Upload Appendix 5 Files', 'AppendixFive'),
];

List<Widget> _customAppendixFields() => [
  ..._customAppendixList(),
  const SizedBox(height: 12),
  if (!showNewCustomAppendix)
    Align(
      alignment: Alignment.centerLeft,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.add),
        label: const Text('Add More Appendix'),
        onPressed: () => setState(() => showNewCustomAppendix = true),
      ),
    ),
  if (showNewCustomAppendix) ...[
    _field('customAppendixName', 'Appendix Name'),
    _uploadButton(
      'Upload Files',
      'Custom',
      appendixNameController: c['customAppendixName'],
    ),
  ],
];

List<Widget> _customAppendixList() {
  final grouped = <int, List<Map<String, dynamic>>>{};

  for (final file in customAppendixFiles) {
    final appendixNo = int.tryParse(
      _s(file['appendixNo'] ?? file['AppendixNo']),
    );

    if (appendixNo == null) continue;

    grouped.putIfAbsent(appendixNo, () => []);
    grouped[appendixNo]!.add(file);
  }

  if (grouped.isEmpty) {
    return [
      const Text('No custom appendix uploaded'),
    ];
  }

  return grouped.entries.map((entry) {
    final appendixNo = entry.key;
    final files = entry.value;
    final title = _s(
      files.first['appendixTitle'] ??
          files.first['AppendixTitle'] ??
          'Appendix $appendixNo',
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
            children: [
              Expanded(
                child: Text(
                  title.isEmpty ? 'Appendix $appendixNo' : title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () async {
                  final controller = TextEditingController(text: title);

                  final updatedTitle = await showDialog<String>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Edit Appendix Name'),
                      content: TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          labelText: 'Appendix Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, controller.text.trim()),
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  );

                  controller.dispose();

                  if (updatedTitle == null || updatedTitle.isEmpty) return;

                  await ApiService.updateCustomAppendixTitle(
                    jobId: widget.jobId,
                    appendixNo: appendixNo,
                    appendixTitle: updatedTitle,
                  );

                  await _refreshAppendixFiles();
                },
              ),
            ],
          ),
            const SizedBox(height: 8),
            _attachmentList(files),
            const SizedBox(height: 8),
            _uploadButton(
              'Add More Files',
              'Custom',
              appendixNameController: TextEditingController(text: title),
              appendixNo: appendixNo,
            ),
          ],
        ),
      ),
    );
  }).toList();
}

Widget _assetUploadButton(String label, String controllerKey) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        // Paste button
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.content_paste, size: 18),
            label: const Text('Paste Screenshot'),
            onPressed: () async {
              try {
                final bytes = await Pasteboard.image;
                if (bytes == null || bytes.isEmpty) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'No image in clipboard. Take a screenshot first, then paste.',
                        style: TextStyle(color: Colors.white),
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                final path = await ApiService.uploadIhmReportAssetBytes(
                  jobId: widget.jobId,
                  bytes: bytes,
                  fileName: '${controllerKey}_${DateTime.now().millisecondsSinceEpoch}.png',
                );
                if (!mounted) return;
                setState(() => c[controllerKey]!.text = path);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Image uploaded from clipboard',
                        style: TextStyle(color: Colors.white)),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Paste failed: $e',
                        style: const TextStyle(color: Colors.white)),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        // Browse button
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.upload_file, size: 18),
            label: const Text('Browse File'),
            onPressed: () async {
              final result = await FilePicker.platform.pickFiles(
                allowMultiple: false,
                withData: true,
                type: FileType.custom,
                allowedExtensions: ['jpg', 'jpeg', 'png'],
              );
              if (result == null || result.files.isEmpty) return;
              try {
                final path = await ApiService.uploadIhmReportAsset(
                  jobId: widget.jobId,
                  file: result.files.first,
                );
                if (!mounted) return;
                setState(() => c[controllerKey]!.text = path);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Image uploaded',
                        style: TextStyle(color: Colors.white)),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(e.toString(),
                        style: const TextStyle(color: Colors.white)),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
        ),
      ],
    ),
  );
}

Widget _dateField(String key, String label) {
  return Padding(                          // ← ഇത് add ചെയ്യൂ
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: c[key],
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: const Icon(Icons.calendar_month),
          onPressed: () async {
            final current = DateTime.tryParse(c[key]!.text);
            final picked = await showDatePicker(
              context: context,
              initialDate: current ?? DateTime.now(),
              firstDate: DateTime(1950),
              lastDate: DateTime(2100),
            );
            if (picked == null) return;
            setState(() {
              c[key]!.text = picked.toIso8601String().split('T').first;
            });
          },
        ),
      ),
    ),
  );
}
Widget _attachmentList(List<Map<String, dynamic>> files) {
  if (files.isEmpty) {
    return const Text('No files uploaded');
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: files.map((file) {
      final id = file['id'] ?? file['Id'];
      final name = _s(file['originalFileName'] ?? file['OriginalFileName']);
      final path = _s(file['filePath'] ?? file['FilePath']);

      return ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(name.isEmpty ? path : name),
        subtitle: Text(path),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            await ApiService.deleteIhmAppendixFile(
              jobId: widget.jobId,
              attachmentId: int.parse(id.toString()),
            );
            await _refreshAppendixFiles();
          },
        ),
      );
    }).toList(),
  );
}

Widget _uploadButton(
  String label,
  String appendixType, {
  TextEditingController? appendixNameController,
  int? appendixNo,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      InkWell(
        onTap: () async {
          final result = await FilePicker.platform.pickFiles(
            allowMultiple: true,
            withData: true,
            type: FileType.custom,
            allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
          );

          if (result == null || result.files.isEmpty) return;

          await ApiService.uploadIhmAppendixFiles(
            jobId: widget.jobId,
            appendixType: appendixType,
            appendixName: appendixNameController?.text,
            appendixNo: appendixNo,
            files: result.files,
          );

          await _refreshAppendixFiles();

          if (appendixType == 'Custom' && appendixNo == null) {
            c['customAppendixName']!.clear();
            if (mounted) setState(() => showNewCustomAppendix = false);
          }

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Files uploaded')),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.attach_file),
              SizedBox(width: 10),
              Text('Choose Files'),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'No file chosen',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

Future<void> generatePdf() async {
    setState(() => saving = true);
    try {
      await save(showMessage: false);
      final pdfUrl = await ApiService.generateIhmReport(widget.jobId);
      if (!mounted) return;
      await AppDialog.success(
        context,
        title: 'PDF generated',
        message: 'The latest IHM report is ready to view and download.',
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => NetworkPdfViewerScreen(url: pdfUrl, title: 'IHM Report')),
      );
    } catch (e) {
      if (mounted) {
        await AppDialog.error(
          context,
          title: 'PDF generation failed',
          message: e,
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> save({bool showMessage = true}) async {
    setState(() => saving = true);
    try {
      if (selectedVesselId != null) {
        await ApiService.updateVessel(
          vesselId: selectedVesselId!,
          data: _vesselPayload(),
        );
      }
      await ApiService.saveIhmReportInfo(
        jobId: widget.jobId,
        data: _payload(),
      );
      if (showMessage && mounted) {
        await AppDialog.success(
          context,
          title: 'Report saved',
          message: 'The IHM report information was saved successfully.',
        );
      }
    } catch (error) {
      if (showMessage && mounted) {
        await AppDialog.error(
          context,
          title: 'Unable to save report',
          message: error,
        );
      }
      rethrow;
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

Map<String, dynamic> _vesselPayload() => {
  'vesselName': c['vesselName']!.text.trim(),
  'imoNumber': c['imoNumber']!.text.trim(),
  'officialNumber': c['officialNumber']!.text.trim(),
  'vesselType': c['vesselType']!.text.trim(),
  'flag': c['flag']!.text.trim(),
  'portOfRegistry': c['portOfRegistry']!.text.trim(),
  'classSociety': c['classSociety']!.text.trim(),
  'callSign': c['callSign']!.text.trim(),
  'builder': c['builder']!.text.trim(),
  'dateOfBuild': _nullable(c['dateOfBuild']!.text),
  'lengthOverall': _decimal(c['loaM']!.text),
  'lengthBetweenPerpendiculars': _decimal(c['lbpM']!.text),
  'breadth': _decimal(c['breadthM']!.text),
  'depth': _decimal(c['depthM']!.text),
  'draughtMoulded': _decimal(c['draughtM']!.text),
  'grossTonnage': _decimal(c['grt']!.text),
  'netTonnage': _decimal(c['nrt']!.text),
  'managerName': c['shipManager']!.text.trim(),
};
  Map<String, dynamic> _payload() => {
        'vesselId': selectedVesselId,
        'vesselName': c['vesselName']!.text.trim(),
        'imoNumber': c['imoNumber']!.text.trim(),
        'officialNumber': c['officialNumber']!.text.trim(),
        'vesselType': c['vesselType']!.text.trim(),
        'flag': c['flag']!.text.trim(),
        'portOfRegistry': c['portOfRegistry']!.text.trim(),
        'classSociety': c['classSociety']!.text.trim(),
        'callSign': c['callSign']!.text.trim(),
        'builder': c['builder']!.text.trim(),
        'dateOfBuild': _nullable(c['dateOfBuild']!.text),
        'lengthOverall': _decimal(c['loaM']!.text),
        'lengthBetweenPerpendiculars': _decimal(c['lbpM']!.text),
        'breadth': _decimal(c['breadthM']!.text),
        'depth': _decimal(c['depthM']!.text),
        'draughtMoulded': _decimal(c['draughtM']!.text),
        'grossTonnage': _decimal(c['grt']!.text),
        'netTonnage': _decimal(c['nrt']!.text),
        'companyName': c['companyName']!.text.trim(),
        'companyAddress': c['companyAddress']!.text.trim(),
        'companyTel': c['companyTel']!.text.trim(),
        'companyFax': c['companyFax']!.text.trim(),
        'companyWebsite': c['companyWebsite']!.text.trim(),
        'companyEmail': c['companyEmail']!.text.trim(),
        'companyLogoPath': c['companyLogoPath']!.text.trim(),
        'clientLogoPath': c['clientLogoPath']!.text.trim(),
        'clientName': c['clientLogoPath']!.text.trim().isEmpty ? c['clientName']!.text.trim() : null,
        'preparedBy': c['preparedBy']!.text.trim(),
        'checkedBy': c['checkedBy']!.text.trim(),
        'approvedBy': c['approvedBy']!.text.trim(),
        'uid': c['uid']!.text.trim(),
        'jobNumber': c['jobNumber']!.text.trim(),
        'documentNo': c['documentNo']!.text.trim(),
        'documentDate': _nullable(c['documentDate']!.text),
        'revisionNo': int.tryParse(c['revisionNo']!.text.trim()) ?? 0,
        'hazardousMaterialFindings': c['hazardousMaterialFindings']!.text.trim(),
        'labReportNo': c['labReportNo']!.text.trim(),
        'labReportingDate': _nullable(c['labReportingDate']!.text),
        'hazmatExpert': c['hazmatExpert']!.text.trim(),
        'shipManagerContact': c['shipManagerContact']!.text.trim(),
        'samplingMethodology': c['samplingMethodology']!.text.trim(),
        'samplingOfFragmentsOfPaints': c['samplingOfFragmentsOfPaints']!.text.trim(),
        'laboratory': c['laboratory']!.text.trim(),
        'chemicalAnalysisMethod': c['chemicalAnalysisMethod']!.text.trim(),
        'locationOfVisualSamplingCheck': c['locationOfVisualSamplingCheck']!.text.trim(),

        'ohsJobDetail': c['ohsJobDetail']!.text.trim(),
        'ohsClient': c['ohsClient']!.text.trim(),
        'ohsJobLocation': c['ohsJobLocation']!.text.trim(),
        'ohsJobNo': c['ohsJobNo']!.text.trim(),
        'ohsProjectInCharge': c['ohsProjectInCharge']!.text.trim(),
        'ohsDivisionBranch': c['ohsDivisionBranch']!.text.trim(),
        'ohsRaNo': c['ohsRaNo']!.text.trim(),
        'ohsRevNo': c['ohsRevNo']!.text.trim(),
        'ohsRevisionDate': _nullable(c['ohsRevisionDate']!.text),
        'ohsPreparedBy': c['ohsPreparedBy']!.text.trim(),
        'ohsPreparedBySignPath': c['ohsPreparedBySignPath']!.text.trim(),
        'ohsPreparedDate': _nullable(c['ohsPreparedDate']!.text),
        'ohsApprovedBy': c['ohsApprovedBy']!.text.trim(),
        'ohsApprovedBySignPath': c['ohsApprovedBySignPath']!.text.trim(),
        'ohsApprovedDate': _nullable(c['ohsApprovedDate']!.text),

        'ohsPeople': [
          ...hseOfficers.where((x) => x.text.trim().isNotEmpty).map((x) => {
            'roleType': 'HseOfficer',
            'name': x.text.trim(),
            'sortOrder': hseOfficers.indexOf(x) + 1,
          }),
          ...responsibleSupervisors.where((x) => x.text.trim().isNotEmpty).map((x) => {
            'roleType': 'ResponsibleSupervisor',
            'name': x.text.trim(),
            'sortOrder': responsibleSupervisors.indexOf(x) + 1,
          }),
          ...participants.where((x) => x.text.trim().isNotEmpty).map((x) => {
            'roleType': 'Participant',
            'name': x.text.trim(),
            'sortOrder': participants.indexOf(x) + 1,
          }),
        ],
        'ohsRiskAssessmentRows': ohsRiskRows.asMap().entries.map((entry) {
          final r = entry.value;
          return {
            'activity': r['activity']!.text.trim(),
            'hazardDescription': r['hazardDescription']!.text.trim(),
            'risks': r['risks']!.text.trim(),
            'initialRiskP': r['initialRiskP']!.text.trim(),
            'initialRiskS': r['initialRiskS']!.text.trim(),
            'initialRiskR': r['initialRiskR']!.text.trim(),
            'initialAlarp': r['initialAlarp']!.text.trim(),
            'controlMeasures': r['controlMeasures']!.text.trim(),
            'residualRiskP': r['residualRiskP']!.text.trim(),
            'residualRiskS': r['residualRiskS']!.text.trim(),
            'residualRiskR': r['residualRiskR']!.text.trim(),
            'residualAlarp': r['residualAlarp']!.text.trim(),
            'responsiblePerson': r['responsiblePerson']!.text.trim(),
            'sortOrder': entry.key + 1,
          };
        }).toList(),
        'revisions': revisions.map((r) => {
              'uid': r['uid']!.text.trim(),
              'revisionNo': int.tryParse(r['rev']!.text.trim()),
              'revisionDate': _nullable(r['date']!.text),
              'description': r['description']!.text.trim(),
              'preparedBy': r['pre']!.text.trim(),
              'checkedBy': r['chk']!.text.trim(),
              'approvedBy': r['apr']!.text.trim(),
            }).toList(),
        'paintAndCoatingSystems': paintRows.map((r) => {
              'applicationOfPaint': r['applicationOfPaint']!.text.trim(),
              'nameOfPaint': r['nameOfPaint']!.text.trim(),
              'location': r['location']!.text.trim(),
              'materialClassification': r['materials']!.text.trim(),
              'mass': r['mass']!.text.trim(),
              'unit': r['unit']!.text.trim(),
              'remarks': r['remarks']!.text.trim(),
            }).toList(),
        'equipmentAndMachinery': equipmentRows.asMap().entries.map((entry) {
          final r = entry.value;
          return {
            'ihmCheckpointId': int.tryParse(r['ihmCheckpointId']!.text.trim()),
            'equipmentName': r['equipmentName']!.text.trim(),
            'location': r['location']!.text.trim(),
            'materialClassification': r['materials']!.text.trim(),
            'partsWereUsed': r['partsWereUsed']!.text.trim(),
            'unitKg': r['unitKg']!.text.trim(),
            'quantityNo': r['quantityNo']!.text.trim(),
            'totalKg': r['totalKg']!.text.trim(),
            'remarks': r['remarks']!.text.trim(),
            'sortOrder': entry.key + 1,
            'isHidden': false,
          };
        }).toList(),
        'structureAndHull': structureRows.map((r) => {
              'equipmentName': r['equipmentName']!.text.trim(),
              'location': r['location']!.text.trim(),
              'materialClassification': r['materials']!.text.trim(),
              'partsWereUsed': r['partsWereUsed']!.text.trim(),
              'approximateQuantity': r['approximateQuantity']!.text.trim(),
              'remarks': r['remarks']!.text.trim(),
            }).toList(),
              'necessaryInformationPoints': necessaryInfoText.text
                .split('\n')
                .map((x) => x.trim())
                .where((x) => x.isNotEmpty)
                .toList()
                .asMap()
                .entries
                .map((entry) => {
                      'description': entry.value,
                      'sortOrder': entry.key + 1,
                    })
              .toList(),
          'appendixFiveInformationPoints': c['appendixFiveInformation']!
            .text
            .split('\n')
            .map((x) => x.trim())
            .where((x) => x.isNotEmpty)
            .toList()
            .asMap()
            .entries
            .map((entry) => {
                  'description': entry.value,
                  'sortOrder': entry.key + 1,
                })
            .toList(),
        'appendixOneResultPoints': _appendixOnePayload(),
            };
List<Map<String, dynamic>> _appendixOnePayload() {
  final blocks = appendixOneText.text
      .split(RegExp(r'\n\s*\n'))
      .map((x) => x.trim())
      .where((x) => x.isNotEmpty)
      .toList();

  return blocks.asMap().entries.map((entry) {
    final lines = entry.value
        .split('\n')
        .map((x) => x.trim())
        .where((x) => x.isNotEmpty)
        .toList();

    return {
      'title': lines.isNotEmpty ? lines.first : '',
      'description': lines.length > 1 ? lines.skip(1).join(' ') : '',
      'sortOrder': entry.key + 1,
    };
  }).toList();
}
  void _addRevision() {
    final row = _revisionRow();
    row['uid']!.text = c['uid']!.text;
    row['rev']!.text = c['revisionNo']!.text;
    row['date']!.text = c['documentDate']!.text;
    row['pre']!.text = c['preparedBy']!.text;
    row['chk']!.text = c['checkedBy']!.text;
    row['apr']!.text = c['approvedBy']!.text;
    revisions.add(row);
  }

  Map<String, TextEditingController> _revisionRow() => {
        'uid': TextEditingController(),
        'rev': TextEditingController(),
        'date': TextEditingController(),
        'description': TextEditingController(),
        'pre': TextEditingController(),
        'chk': TextEditingController(),
        'apr': TextEditingController(),
      };

  Map<String, TextEditingController> _paintRow() => {
        'applicationOfPaint': TextEditingController(),
        'nameOfPaint': TextEditingController(),
        'location': TextEditingController(),
        'materials': TextEditingController(),
        'mass': TextEditingController(),
        'unit': TextEditingController(),
        'remarks': TextEditingController(),
      };

  Map<String, TextEditingController> _equipmentRow() => {
        'ihmCheckpointId': TextEditingController(),
        'equipmentName': TextEditingController(),
        'location': TextEditingController(),
        'materials': TextEditingController(),
        'partsWereUsed': TextEditingController(),
        'unitKg': TextEditingController(),
        'quantityNo': TextEditingController(),
        'totalKg': TextEditingController(),
        'remarks': TextEditingController(),
      };

  Map<String, TextEditingController> _structureRow() => {
        'equipmentName': TextEditingController(),
        'location': TextEditingController(),
        'materials': TextEditingController(),
        'partsWereUsed': TextEditingController(),
        'approximateQuantity': TextEditingController(),
        'remarks': TextEditingController(),
      };

  Map<String, TextEditingController> _appendixOneRow() => {
  'title': TextEditingController(),
  'description': TextEditingController(),
};

List<Map<String, TextEditingController>> _defaultAppendixOneRows() {
  final rows = [
    ['Asbestos', 'Refer Appendix 2 for Analysis report for Asbestos.'],
    ['Polychlorinated biphenyls (PCBs)', 'Refer Appendix 2 for Analysis report for Polychlorinated biphenyls (PCBs)'],
    ['Lead and Lead Compounds', 'Refer Appendix 2 for Analysis report for Lead and Lead Compounds.'],
    ['Cadmium and Cadmium Compounds.', 'Refer Appendix 2 for Analysis report for Cadmium and Cadmium Compounds.'],
    ['Polychlorinated Napthalenes (PCNs)', 'Refer Appendix 2 for Analysis report for Polychlorinated Napthalenes (PCNs)'],
    ['HBCDD - Brominated Flame Retardant', 'Refer Appendix 2 for Analysis report for HBCDD.'],
    ['PFOS - Perfluro Octane Sulfonic Acid', 'Refer Appendix 2 for Analysis report for PFOS.'],
    ['Polybrominated biphenyl (PBBs)', 'Refer Appendix 2 for Analysis report for PBBs.'],
    ['Polybrominated diphenyl ethers (PBDEs)', 'Refer Appendix 2 for Analysis report for PBDEs.'],
    ['Hexavalent Chromium and Hexavalent Chromium Compounds.', 'Refer Appendix 2 for Analysis report for Hexavalent Chromium and Hexavalent Chromium Compounds.'],
    ['SCCP - Certain shortchain chlorinated paraffins.', 'Refer Appendix 2 for Analysis report for SCCP.'],
    ['Mercury & Mercury Compounds', 'Refer Appendix 2 for Analysis report for Mercury & Mercury Compounds.'],
    ['Ozone Depleting Substances (ODSs)', 'Refer Appendix 2 for Analysis report for ODSs.'],
  ];

  return rows.map((x) => {
    'title': TextEditingController(text: x[0]),
    'description': TextEditingController(text: x[1]),
  }).toList();
}

  Map<String, TextEditingController> _ohsRiskRow() => {
  'activity': TextEditingController(),
  'hazardDescription': TextEditingController(),
  'risks': TextEditingController(),
  'initialRiskP': TextEditingController(),
  'initialRiskS': TextEditingController(),
  'initialRiskR': TextEditingController(),
  'initialAlarp': TextEditingController(),
  'controlMeasures': TextEditingController(),
  'residualRiskP': TextEditingController(),
  'residualRiskS': TextEditingController(),
  'residualRiskR': TextEditingController(),
  'residualAlarp': TextEditingController(),
  'responsiblePerson': TextEditingController(),
};

void _loadPeople(dynamic source) {
  hseOfficers.clear();
  responsibleSupervisors.clear();
  participants.clear();

  for (final item in ((source as List?) ?? [])) {
    final row = Map<String, dynamic>.from(item);
    final role = _s(row['roleType'] ?? row['RoleType']).toLowerCase();
    final name = _s(row['name'] ?? row['Name']);

    if (name.isEmpty) continue;

    if (role == 'hseofficer') hseOfficers.add(TextEditingController(text: name));
    if (role == 'responsiblesupervisor') responsibleSupervisors.add(TextEditingController(text: name));
    if (role == 'participant') participants.add(TextEditingController(text: name));
  }

  if (hseOfficers.isEmpty) hseOfficers.add(TextEditingController());
  if (responsibleSupervisors.isEmpty) responsibleSupervisors.add(TextEditingController());
  if (participants.isEmpty) participants.add(TextEditingController());
}
  void _replaceRows(
    List<Map<String, TextEditingController>> target,
    dynamic source,
    Map<String, TextEditingController> Function() create,
    void Function(Map<String, TextEditingController>, Map<String, dynamic>) fill,
  ) {
    target.clear();
    for (final item in ((source as List?) ?? [])) {
      final row = create();
      fill(row, Map<String, dynamic>.from(item));
      target.add(row);
    }
  }

  String _s(dynamic value) => value?.toString() ?? '';
  String? _nullable(String value) => value.trim().isEmpty ? null : value.trim();
  double? _decimal(String value) => double.tryParse(value.trim());
  String _date(dynamic value) => _s(value).split('T').first;
}
