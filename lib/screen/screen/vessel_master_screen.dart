import 'package:Auras/model/vessel.dart';
import 'package:Auras/service/api_service.dart';
import 'package:Auras/utils/app_dialog.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// â”€â”€â”€ Color Palette â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _AppColors {
  static const Color navy = Color(0xFF0B1D33);
  static const Color deepBlue = Color(0xFF132B4A);
  static const Color slate = Color(0xFF1E3A5F);
  static const Color ocean = Color(0xFF1976D2);
  static const Color teal = Color(0xFF00897B);
  static const Color lightTeal = Color(0xFF4DB6AC);
  static const Color surface = Color(0xFFF4F6FA);
  static const Color card = Colors.white;
  static const Color divider = Color(0xFFE0E4EC);
  static const Color textPrimary = Color(0xFF1A2333);
  static const Color textSecondary = Color(0xFF607080);
  static const Color textMuted = Color(0xFF90A0B0);
  static const Color success = Color(0xFF43A047);
  static const Color amber = Color(0xFFFFA726);
  static const Color red = Color(0xFFEF5350);
}

class VesselMasterScreen extends StatefulWidget {
  const VesselMasterScreen({super.key});

  @override
  State<VesselMasterScreen> createState() => _VesselMasterScreenState();
}

class _VesselMasterScreenState extends State<VesselMasterScreen> {
  bool isLoading = true;
  bool _isRefreshingVessels = false;
  String? errorMessage;
  List<Vessel> vessels = [];
  String _searchQuery = '';
  String _role = '';
  final TextEditingController _searchController = TextEditingController();

  bool get _isClient => _role == 'client';

  bool get _canCreateVessels => _role == 'admin' || _role == 'manager';

  @override
  void initState() {
    super.initState();
    _loadCurrentRole();
    _loadVessels();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      _role = (prefs.getString('userRole') ?? '').trim().toLowerCase();
    });
  }

  Future<void> _loadVessels({bool showLoading = true}) async {
    if (_isRefreshingVessels) return;
    _isRefreshingVessels = true;

    if (showLoading && mounted) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    } else if (mounted) {
      setState(() => errorMessage = null);
    }

    try {
      final result = await ApiService.fetchVessels();
      if (!mounted) return;
      setState(() {
        vessels = result;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (showLoading || vessels.isEmpty) {
          errorMessage = e.toString();
        }
        isLoading = false;
      });
    } finally {
      _isRefreshingVessels = false;
    }
  }

  List<Vessel> get _filteredVessels {
    if (_searchQuery.isEmpty) return vessels;
    final q = _searchQuery.toLowerCase();
    return vessels.where((v) {
      return v.vesselName.toLowerCase().contains(q) ||
          (v.imoNumber ?? '').toLowerCase().contains(q) ||
          (v.flag ?? '').toLowerCase().contains(q) ||
          (v.vesselType ?? '').toLowerCase().contains(q) ||
          (v.callSign ?? '').toLowerCase().contains(q);
    }).toList();
  }

  // â”€â”€â”€ Create Dialog â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _showCreateDialog() => _showVesselFormDialog();

  Future<void> _showEditDialog(Vessel vessel) {
    if (!vessel.canEdit) return Future.value();
    return _showVesselFormDialog(vessel: vessel);
  }

  Future<void> _showVesselFormDialog({Vessel? vessel}) async {
    final isEditing = vessel != null;
    final vesselName = TextEditingController(text: vessel?.vesselName ?? '');
    final vesselType = TextEditingController(text: vessel?.vesselType ?? '');
    final classSociety = TextEditingController(text: vessel?.classSociety ?? '');
    final callSign = TextEditingController(text: vessel?.callSign ?? '');
    final imo = TextEditingController(text: vessel?.imoNumber ?? '');
    final officialNumber = TextEditingController(
      text: vessel?.officialNumber ?? '',
    );
    final builderName = TextEditingController(text: vessel?.builder ?? '');
    final dateOfBuild = TextEditingController(
      text: vessel?.dateOfBuild == null
          ? ''
          : _displayDateValue(vessel?.dateOfBuild),
    );
    final portOfRegistry = TextEditingController(
      text: vessel?.portOfRegistry ?? '',
    );
    final flag = TextEditingController(text: vessel?.flag ?? '');
    final loa = TextEditingController(
      text: _numberInput(vessel?.lengthOverall),
    );
    final lbp = TextEditingController(
      text: _numberInput(vessel?.lengthBetweenPerpendiculars),
    );
    final breadthMld = TextEditingController(
      text: _numberInput(vessel?.breadth),
    );
    final depthMld = TextEditingController(text: _numberInput(vessel?.depth));
    final draughtMld = TextEditingController(
      text: _numberInput(vessel?.draughtMoulded),
    );
    final grt = TextEditingController(
      text: _numberInput(vessel?.grossTonnage),
    );
    final nrt = TextEditingController(text: _numberInput(vessel?.netTonnage));
    final owner = TextEditingController(text: vessel?.ownerName ?? '');
    final manager = TextEditingController(text: vessel?.managerName ?? '');
    final client = TextEditingController(text: vessel?.clientName ?? '');

    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          insetPadding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 680),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // â”€â”€ Dialog Header â”€â”€
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 18,
                  ),
                  decoration: const BoxDecoration(
                    color: _AppColors.navy,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.add_circle_outline,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        isEditing ? 'Edit Vessel' : 'Register New Vessel',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white54,
                          size: 22,
                        ),
                        onPressed: () => Navigator.pop(context, false),
                      ),
                    ],
                  ),
                ),

                // â”€â”€ Dialog Body â”€â”€
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionLabel('IDENTIFICATION'),
                        _dialogRow([
                          _dialogField(vesselName, 'Vessel Name *', flex: 2),
                          _dialogField(vesselType, 'Type'),
                        ]),
                        _dialogRow([
                          _dialogField(imo, 'IMO Number'),
                          _dialogField(callSign, 'Call Sign'),
                        ]),
                        _dialogRow([
                          _dialogField(officialNumber, 'Official Number'),
                          _dialogField(classSociety, 'Classification Society'),
                        ]),
                        const SizedBox(height: 8),
                        _sectionLabel('BUILD & REGISTRATION'),
                        _dialogRow([
                          _dialogField(builderName, 'Builder'),
                          _dialogDateField(dateOfBuild, 'Date of Build'),
                        ]),
                        _dialogRow([
                          _dialogField(portOfRegistry, 'Port of Registry'),
                          _dialogField(flag, 'Flag'),
                        ]),
                        const SizedBox(height: 8),
                        _sectionLabel('DIMENSIONS & TONNAGE'),
                        _dialogRow([
                          _dialogNumberField(loa, 'L.O.A'),
                          _dialogNumberField(lbp, 'L.B.P'),
                          _dialogNumberField(breadthMld, 'Breadth (MLD)'),
                        ]),
                        _dialogRow([
                          _dialogNumberField(depthMld, 'Depth (MLD)'),
                          _dialogNumberField(draughtMld, 'Draught (MLD)'),
                          _dialogNumberField(grt, 'GRT'),
                        ]),
                        _dialogRow([
                          _dialogNumberField(nrt, 'NRT'),
                          const Expanded(child: SizedBox()),
                          const Expanded(child: SizedBox()),
                        ]),
                        const SizedBox(height: 8),
                        _sectionLabel('STAKEHOLDERS'),
                        _dialogRow([
                          _dialogField(owner, 'Owner'),
                          _dialogField(manager, 'Manager'),
                          _dialogField(client, 'Client'),
                        ]),
                      ],
                    ),
                  ),
                ),

                // â”€â”€ Dialog Actions â”€â”€
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: _AppColors.surface,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(16),
                    ),
                    border: Border(
                      top: BorderSide(color: _AppColors.divider, width: 1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: TextButton.styleFrom(
                          foregroundColor: _AppColors.textSecondary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.check, size: 18),
                        label: Text(isEditing ? 'Update Vessel' : 'Save Vessel'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _AppColors.ocean,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 13,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () async {
                          if (vesselName.text.trim().isEmpty) {
                            await AppDialog.error(
                              context,
                              title: 'Vessel name required',
                              message:
                                  'Enter a vessel name before saving this record.',
                            );
                            return;
                          }
                          final saved = await AppDialog.execute<bool>(
                            context,
                            loadingMessage: 'Saving vessel...',
                            action: () async {
                              final payload = {
                                'vesselName': vesselName.text.trim(),
                                'vesselType': vesselType.text.trim(),
                                'classSociety': classSociety.text.trim(),
                                'callSign': callSign.text.trim(),
                                'imoNumber': imo.text.trim(),
                                'officialNumber': officialNumber.text.trim(),
                                'builder': builderName.text.trim(),
                                'dateOfBuild': _dateDisplayToApi(
                                  dateOfBuild.text,
                                ),
                                'portOfRegistry': portOfRegistry.text.trim(),
                                'flag': flag.text.trim(),
                                'lengthOverall': _toDouble(loa.text),
                                'lengthBetweenPerpendiculars':
                                    _toDouble(lbp.text),
                                'breadth': _toDouble(breadthMld.text),
                                'depth': _toDouble(depthMld.text),
                                'draughtMoulded': _toDouble(draughtMld.text),
                                'grossTonnage': _toDouble(grt.text),
                                'netTonnage': _toDouble(nrt.text),
                                'ownerName': owner.text.trim(),
                                'managerName': manager.text.trim(),
                                'clientName': client.text.trim(),
                              };
                              if (isEditing) {
                                await ApiService.updateVessel(
                                  vesselId: vessel!.id,
                                  data: payload,
                                );
                              } else {
                                await ApiService.createVessel(
                                  vesselName: vesselName.text.trim(),
                                  vesselType: vesselType.text.trim(),
                                  classSociety: classSociety.text.trim(),
                                  callSign: callSign.text.trim(),
                                  imoNumber: imo.text.trim(),
                                  officialNumber: officialNumber.text.trim(),
                                  builder: builderName.text.trim(),
                                  dateOfBuild: _dateDisplayToApi(
                                    dateOfBuild.text,
                                  ),
                                  portOfRegistry: portOfRegistry.text.trim(),
                                  flag: flag.text.trim(),
                                  lengthOverall: _toDouble(loa.text),
                                  lengthBetweenPerpendiculars:
                                      _toDouble(lbp.text),
                                  breadth: _toDouble(breadthMld.text),
                                  depth: _toDouble(depthMld.text),
                                  draughtMoulded: _toDouble(draughtMld.text),
                                  grossTonnage: _toDouble(grt.text),
                                  netTonnage: _toDouble(nrt.text),
                                  ownerName: owner.text.trim(),
                                  managerName: manager.text.trim(),
                                  clientName: client.text.trim(),
                                );
                              }
                              return true;
                            },
                            successTitle:
                                isEditing ? 'Vessel updated' : 'Vessel saved',
                            successMessage:
                                '${vesselName.text.trim()} was ${isEditing ? 'updated' : 'created'} successfully.',
                            errorTitle: 'Unable to save vessel',
                          );
                          if (saved == true && context.mounted) {
                            Navigator.pop(context, true);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (created == true) _loadVessels(showLoading: false);
  }

  // â”€â”€â”€ Dialog Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: _AppColors.ocean,
          letterSpacing: 1.4,
        ),
      ),
    );
  }

  Widget _dialogRow(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: children
            .expand(
              (w) => [
                if (children.indexOf(w) > 0) const SizedBox(width: 12),
                w is Expanded ? w : Expanded(child: w),
              ],
            )
            .toList(),
      ),
    );
  }

  Widget _dialogDateField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      readOnly: true,
      style: const TextStyle(fontSize: 14, color: _AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: 'dd-MM-yyyy',
        suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
        labelStyle: const TextStyle(
          fontSize: 13,
          color: _AppColors.textSecondary,
        ),
        filled: true,
        fillColor: _AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _AppColors.ocean, width: 1.5),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _parseDisplayDate(controller.text) ?? DateTime.now(),
          firstDate: DateTime(1800),
          lastDate: DateTime(DateTime.now().year + 5),
        );
        if (picked != null) {
          controller.text = _dateToDisplay(picked);
        }
      },
    );
  }

  Widget _dialogField(
    TextEditingController controller,
    String label, {
    int flex = 1,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 14, color: _AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          fontSize: 13,
          color: _AppColors.textSecondary,
        ),
        filled: true,
        fillColor: _AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _AppColors.ocean, width: 1.5),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _dialogNumberField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(fontSize: 14, color: _AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          fontSize: 13,
          color: _AppColors.textSecondary,
        ),
        filled: true,
        fillColor: _AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _AppColors.ocean, width: 1.5),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),
    );
  }

  double? _toDouble(String value) {
    if (value.trim().isEmpty) return null;
    return double.tryParse(value.trim());
  }

  String _numberInput(double? value) {
    if (value == null) return '';
    return value % 1 == 0
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  Future<void> _deleteVessel(Vessel vessel) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Delete vessel?',
      message:
          'Delete ${vessel.vesselName}? The vessel will no longer be available for new jobs.',
      confirmLabel: 'Delete vessel',
      destructive: true,
    );

    if (!confirmed) return;
    final deleted = await AppDialog.execute<bool>(
      context,
      loadingMessage: 'Deleting vessel...',
      action: () async {
        await ApiService.deleteVessel(vessel.id);
        return true;
      },
      successTitle: 'Vessel deleted',
      successMessage: '${vessel.vesselName} was deleted successfully.',
      errorTitle: 'Unable to delete vessel',
    );
    if (deleted == true && mounted) {
      await _loadVessels(showLoading: false);
    }
  }

  String _val(String? value) {
    if (value == null || value.trim().isEmpty) return 'â€”';
    return value.trim();
  }

  String _displayDateValue(String? value) {
    if (value == null || value.trim().isEmpty) return '---';
    return _dateToDisplay(_parseApiDate(value) ?? _parseDisplayDate(value));
  }

  String? _dateDisplayToApi(String value) {
    if (value.trim().isEmpty) return null;
    final parsed = _parseDisplayDate(value) ?? _parseApiDate(value);
    if (parsed == null) return value.trim();
    return _dateToApi(parsed);
  }

  DateTime? _parseApiDate(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  DateTime? _parseDisplayDate(String value) {
    final text = value.trim();
    final parts = text.split('-');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    return DateTime(year, month, day);
  }

  String _dateToDisplay(DateTime? value) {
    if (value == null) return '---';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day-$month-${value.year}';
  }

  String _dateToApi(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  String _numVal(double? value) {
    if (value == null) return 'â€”';
    return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2);
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return _AppColors.success;
      case 'inactive':
        return _AppColors.textMuted;
      case 'pending':
        return _AppColors.amber;
      default:
        return _AppColors.ocean;
    }
  }

  IconData _vesselIcon(String? type) {
    final t = (type ?? '').toLowerCase();
    if (t.contains('tanker')) return Icons.local_gas_station;
    if (t.contains('cargo')) return Icons.inventory_2;
    if (t.contains('passenger')) return Icons.groups;
    if (t.contains('tug')) return Icons.swap_calls;
    return Icons.directions_boat_filled;
  }

  // â”€â”€â”€ Build â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _AppColors.surface,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 24,
        right: 24,
        bottom: 16,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_AppColors.navy, _AppColors.deepBlue, _AppColors.slate],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x30000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // â”€â”€ Row 1: Back | Icon | Title â”€â”€
          Row(
            children: [
              Material(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => Navigator.pop(context),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white70,
                      size: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.sailing, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vessel Master',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Fleet Registry & Management',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // â”€â”€ Row 2: Stats capsule | Refresh | Add Vessel â”€â”€
          Row(
            children: [
              if (!isLoading && errorMessage == null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.directions_boat,
                        color: _AppColors.lightTeal,
                        size: 15,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${vessels.length} Vessel${vessels.length != 1 ? 's' : ''}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              _headerButton(Icons.refresh, 'Refresh', _loadVessels),
              if (_canCreateVessels) ...[
                const SizedBox(width: 8),
                _addVesselButton(),
              ],
            ],
          ),

          const SizedBox(height: 14),

          // â”€â”€ Search Bar â”€â”€
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search by name, IMO, flag, type, call signâ€¦',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.35)),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.white.withOpacity(0.4),
                  size: 20,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.close,
                          color: Colors.white.withOpacity(0.4),
                          size: 18,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerButton(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: Colors.white70, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _addVesselButton() {
    return Material(
      color: _AppColors.ocean,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: _showCreateDialog,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: const Row(
            children: [
              Icon(Icons.add, color: Colors.white, size: 18),
              SizedBox(width: 6),
              Text(
                'Add Vessel',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // â”€â”€â”€ Body â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: _AppColors.ocean,
              strokeWidth: 2.5,
            ),
            SizedBox(height: 16),
            Text(
              'Loading vesselsâ€¦',
              style: TextStyle(color: _AppColors.textMuted, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _AppColors.red.withOpacity(0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: _AppColors.red, size: 48),
              const SizedBox(height: 14),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _loadVessels,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _AppColors.ocean,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _filteredVessels;

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _searchQuery.isNotEmpty
                  ? Icons.search_off
                  : Icons.directions_boat_outlined,
              color: _AppColors.textMuted,
              size: 56,
            ),
            const SizedBox(height: 14),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No vessels match your search'
                  : 'No vessels registered yet',
              style: const TextStyle(
                color: _AppColors.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try a different keyword'
                  : _canCreateVessels
                  ? 'Tap "Add Vessel" to register your first vessel'
                  : 'No vessels are available yet',
              style: const TextStyle(color: _AppColors.textMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    // â”€â”€ 2-Column Grid â”€â”€
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900
            ? 3
            : constraints.maxWidth > 560
            ? 2
            : 1;
        return GridView.builder(
          padding: const EdgeInsets.all(20),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.9,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) => _vesselCard(filtered[index]),
        );
      },
    );
  }

  // â”€â”€â”€ Vessel Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _vesselCard(Vessel vessel) {
    return Container(
      decoration: BoxDecoration(
        color: _AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _AppColors.divider.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showVesselDetail(vessel),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // â”€â”€ Card Header â”€â”€
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_AppColors.navy, _AppColors.slate],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _vesselIcon(vessel.vesselType),
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vessel.vesselName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _AppColors.textPrimary,
                            ),
                          ),
                          if (vessel.vesselType != null &&
                              vessel.vesselType!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                vessel.vesselType!,
                                style: const TextStyle(
                                  color: _AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _statusColor(vessel.status).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        vessel.status,
                        style: TextStyle(
                          color: _statusColor(vessel.status),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(color: _AppColors.divider.withOpacity(0.5), height: 1),
                const SizedBox(height: 14),

                // â”€â”€ Key Info Grid â”€â”€
                Expanded(
                  child: Column(
                    children: [
                      _cardInfoRow(Icons.tag, 'IMO', _val(vessel.imoNumber)),
                      _cardInfoRow(
                        Icons.flag_outlined,
                        'Flag',
                        _val(vessel.flag),
                      ),
                      _cardInfoRow(
                        Icons.verified_outlined,
                        'Class',
                        _val(vessel.classSociety),
                      ),
                      _cardInfoRow(
                        Icons.radio,
                        'Call Sign',
                        _val(vessel.callSign),
                      ),
                      if (vessel.ownerName != null &&
                          vessel.ownerName!.isNotEmpty)
                        _cardInfoRow(
                          Icons.business,
                          'Owner',
                          _val(vessel.ownerName),
                        ),
                    ],
                  ),
                ),

                // â”€â”€ Bottom Metrics â”€â”€
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _metric('LOA', _numVal(vessel.lengthOverall)),
                      _metricDivider(),
                      _metric('GRT', _numVal(vessel.grossTonnage)),
                      _metricDivider(),
                      _metric('NRT', _numVal(vessel.netTonnage)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _cardActionButton(
                        icon: Icons.info_outline,
                        label: 'Details',
                        color: _AppColors.ocean,
                        onTap: () => _showVesselDetail(vessel),
                      ),
                    ),
                    if (vessel.canEdit) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: _cardActionButton(
                          icon: Icons.edit_outlined,
                          label: 'Edit',
                          color: _AppColors.amber,
                          onTap: () => _showEditDialog(vessel),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _cardActionButton(
                          icon: Icons.delete_outline,
                          label: 'Delete',
                          color: _AppColors.red,
                          onTap: () => _deleteVessel(vessel),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cardInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 15, color: _AppColors.textMuted),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: _AppColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: _AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: _AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _metricDivider() {
    return Container(width: 1, height: 22, color: _AppColors.divider);
  }

  // â”€â”€â”€ Vessel Detail Sheet â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _cardActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVesselDetail(Vessel vessel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: _AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Vessel name + status
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_AppColors.navy, _AppColors.slate],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          _vesselIcon(vessel.vesselType),
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vessel.vesselName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: _AppColors.textPrimary,
                              ),
                            ),
                            if (vessel.vesselType != null &&
                                vessel.vesselType!.isNotEmpty)
                              Text(
                                vessel.vesselType!,
                                style: const TextStyle(
                                  color: _AppColors.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor(vessel.status).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          vessel.status,
                          style: TextStyle(
                            color: _statusColor(vessel.status),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _detailSection('Identification', [
                    _detailItem('IMO Number', _val(vessel.imoNumber)),
                    _detailItem('Call Sign', _val(vessel.callSign)),
                    _detailItem('Official Number', _val(vessel.officialNumber)),
                    _detailItem(
                      'Classification Society',
                      _val(vessel.classSociety),
                    ),
                  ]),

                  _detailSection('Build & Registration', [
                    _detailItem('Builder', _val(vessel.builder)),
                    _detailItem('Date of Build', _displayDateValue(vessel.dateOfBuild)),
                    _detailItem(
                      'Port of Registry',
                      _val(vessel.portOfRegistry),
                    ),
                    _detailItem('Flag', _val(vessel.flag)),
                  ]),

                  _detailSection('Dimensions & Tonnage', [
                    _detailItem('L.O.A', _numVal(vessel.lengthOverall)),
                    _detailItem(
                      'L.B.P',
                      _numVal(vessel.lengthBetweenPerpendiculars),
                    ),
                    _detailItem('Breadth (MLD)', _numVal(vessel.breadth)),
                    _detailItem('Depth (MLD)', _numVal(vessel.depth)),
                    _detailItem(
                      'Draught (MLD)',
                      _numVal(vessel.draughtMoulded),
                    ),
                    _detailItem('GRT', _numVal(vessel.grossTonnage)),
                    _detailItem('NRT', _numVal(vessel.netTonnage)),
                  ]),

                  _detailSection('Stakeholders', [
                    _detailItem('Owner', _val(vessel.ownerName)),
                    _detailItem('Manager', _val(vessel.managerName)),
                    _detailItem('Client', _val(vessel.clientName)),
                  ]),
                  if (vessel.canEdit) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit Vessel'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _AppColors.ocean,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _showEditDialog(vessel);
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Delete Vessel'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _AppColors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteVessel(vessel);
                        },
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _detailSection(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: _AppColors.ocean,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _AppColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _detailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: _AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: _AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


