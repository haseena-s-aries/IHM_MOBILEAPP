import 'package:Auras/service/phone_gallery.dart';
import 'package:Auras/service/camera_recovery.dart';
import 'package:Auras/ThemeNotifier.dart';
import 'package:Auras/ihm_area.dart';
import 'package:Auras/screen/screen/ihm_conflict_review_screen.dart';
import 'package:Auras/service/IhmOfflineService.dart';
import 'package:Auras/service/api_service.dart';
import 'package:Auras/utils/app_dialog.dart';
import 'package:Auras/service/sync_service.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

// ─── Theme Colors ─────────────────────────────────────────────────────────────
class _TC {
  final Color bgDark, bgCard, bgCardAlt, textPrimary, textSecond, divider;
  const _TC({
    required this.bgDark,
    required this.bgCard,
    required this.bgCardAlt,
    required this.textPrimary,
    required this.textSecond,
    required this.divider,
  });
  static const dark = _TC(
    bgDark: Color(0xFF0D1B2A),
    bgCard: Color(0xFF152235),
    bgCardAlt: Color(0xFF1A2C42),
    textPrimary: Color(0xFFE8F0FE),
    textSecond: Color(0xFF8FA8C4),
    divider: Color(0xFF1E3A55),
  );
  static const light = _TC(
    bgDark: Color(0xFFF0F4FA),
    bgCard: Color(0xFFFFFFFF),
    bgCardAlt: Color(0xFFEAF0F9),
    textPrimary: Color(0xFF0D1B2A),
    textSecond: Color(0xFF4A6580),
    divider: Color(0xFFCDD9E8),
  );
}

class _A {
  static const accent = Color(0xFF00D4AA);
  static const accentBlue = Color(0xFF1E90FF);
  static const accentAmber = Color(0xFFFFA040);
  static const accentRed = Color(0xFFFF5252);
  static const accentPurple = Color(0xFF9B7FFF);
  static const accentGreen = Color(0xFF4CAF8C);
}

// ─── Main Screen ──────────────────────────────────────────────────────────────
class IhmCheckpointDetailScreen extends StatefulWidget {
  final IhmCheckpoint checkpoint;
  final String? displayLabel;
  final bool isDark;

  const IhmCheckpointDetailScreen({
    super.key,
    required this.checkpoint,
    this.displayLabel,
    this.isDark = true,
  });

  @override
  State<IhmCheckpointDetailScreen> createState() =>
      _IhmCheckpointDetailScreenState();
}

class _IhmCheckpointDetailScreenState extends State<IhmCheckpointDetailScreen> {
  late IhmCheckpoint checkpoint;
  late bool isPchm;
  late String auditStatus;
  bool _saving = false;
  bool _isLoggingOut = false;

  late bool _auditSaved;
  late TextEditingController remarks;
  late TextEditingController locationRemarks;

  _TC get _c =>
      context.watch<ThemeNotifier>().isDarkMode ? _TC.dark : _TC.light;

  @override
  void initState() {
    super.initState();
    checkpoint = widget.checkpoint;
    isPchm = checkpoint.isPchm;
    auditStatus = _normalizeAuditStatus(checkpoint.auditStatus);
    _auditSaved = checkpoint.isAudited;
    remarks = TextEditingController(text: checkpoint.remarks ?? '');
    locationRemarks = TextEditingController(
      text: checkpoint.locationRemarks ?? '',
    );
  }

  @override
  void dispose() {
    remarks.dispose();
    locationRemarks.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    // A checkpoint left blank (S/V) in the Excel must be set to Sample or
    // Visual before it can be marked Done.
    if (_normalizeAuditStatus(auditStatus) == 'Done' &&
        checkpoint.isUndecided) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.help_outline, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Expanded(child: Text('Choose Sample or Visual first')),
            ],
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final updated = await IhmOfflineService.saveCheckpointDetails(
        checkpoint: checkpoint,
        isPchm: isPchm,
        auditStatus: auditStatus,
        remarks: remarks.text.trim(),
        locationRemarks: locationRemarks.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        checkpoint = updated;
        isPchm = updated.isPchm;
        auditStatus = _normalizeAuditStatus(updated.auditStatus);
        _auditSaved = updated.isAudited;
        remarks.text = updated.remarks ?? remarks.text;
        locationRemarks.text = updated.locationRemarks ?? locationRemarks.text;
      });
      await AppDialog.success(
        context,
        title: 'Checkpoint saved',
        message: 'The audit result and checkpoint details were saved.',
      );
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '');
      final isConflict = message.contains('Primary surveyor review');
      if (!isConflict) {
        await AppDialog.error(
          context,
          title: 'Unable to save checkpoint',
          message: message,
        );
        return;
      }

      final openReview = await AppDialog.confirm(
        context,
        title: 'Checkpoint conflict',
        message: message,
        confirmLabel: 'Review conflicts',
        cancelLabel: 'Close',
      );
      if (openReview && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                IhmConflictReviewScreen(jobId: checkpoint.surveyJobId),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _normalizeAuditStatus(String value) {
    switch (value.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]'), '')) {
      case 'inprogress':
      case '2':
        return 'Pending';
      case 'done':
      case '3':
        return 'Done';
      default:
        return 'Pending';
    }
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);
    try {
      await SyncService.logoutAndClearUserData();
    } catch (error) {
      debugPrint('Logout failed during cleanup: $error');
    }
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  Future<bool> _returnToAreaScreen() async {
    Navigator.pop(context, checkpoint);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDarkMode;

    return WillPopScope(
      onWillPop: _returnToAreaScreen,
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          backgroundColor: _c.bgDark,
          appBar: AppBar(
            backgroundColor: _c.bgDark,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _c.textPrimary,
                size: 20,
              ),
              onPressed: _returnToAreaScreen,
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Audit Check Point',
                  style: TextStyle(
                    color: _c.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  widget.displayLabel ?? checkpoint.sampleNo,
                  style: TextStyle(color: _c.textSecond, fontSize: 11),
                ),
              ],
            ),
            actions: [
              // ── Theme toggle ──────────────────────────────────────────────
              // ── Save button ───────────────────────────────────────────────
              Container(
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 20),
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _A.accentGreen,
                    foregroundColor: const Color(0xFF0D1B2A),
                    elevation: 0,
                    minimumSize: const Size(60, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_saving)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        const Icon(Icons.save_rounded, size: 20),
                      const SizedBox(width: 5),
                      Text(
                        _saving ? 'Saving' : 'Save',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: _isLoggingOut
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.logout),
                tooltip: 'Logout',
                onPressed: _isLoggingOut ? null : _logout,
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(49),
              child: Column(
                children: [
                  Container(height: 1, color: _c.divider),
                  TabBar(
                    indicatorColor: _A.accent,
                    indicatorWeight: 2.5,
                    labelColor: _A.accent,
                    unselectedLabelColor: _c.textSecond,
                    labelStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                    tabs: const [
                      Tab(
                        text: 'DETAILS',
                        icon: Icon(Icons.description_outlined, size: 16),
                      ),
                      Tab(
                        text: 'AREA',
                        icon: Icon(Icons.location_on_outlined, size: 16),
                      ),
                      Tab(
                        text: 'IMAGES',
                        icon: Icon(Icons.camera_alt_outlined, size: 16),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          body: TabBarView(
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _DetailsTab(
                checkpoint: checkpoint,
                isPchm: isPchm,
                isDark: isDark,
                onPchmChanged: (v) => setState(() => isPchm = v),
                remarks: remarks,
                locationRemarks: locationRemarks,
              ),
              _AreaTab(checkpoint: checkpoint, isDark: isDark),
              _ImagesTab(checkpoint: checkpoint, isDark: isDark),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Details Tab ──────────────────────────────────────────────────────────────
class _DetailsTab extends StatelessWidget {
  final IhmCheckpoint checkpoint;
  final bool isPchm;
  final bool isDark;
  final ValueChanged<bool> onPchmChanged;
  final TextEditingController remarks;
  final TextEditingController locationRemarks;

  const _DetailsTab({
    required this.checkpoint,
    required this.isPchm,
    required this.isDark,
    required this.onPchmChanged,
    required this.remarks,
    required this.locationRemarks,
  });

  _TC get _c => isDark ? _TC.dark : _TC.light;

  String val(String? x) => x == null || x.trim().isEmpty ? '-' : x.trim();

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: TextStyle(
        color: _c.textSecond,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
    ),
  );

  Widget _infoCard(List<_InfoRow> rows) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _c.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _c.divider, width: 1),
      ),
      child: Column(
        children: rows
            .map((r) => _buildInfoRow(r.icon, r.label, r.value, r.color))
            .toList(),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
    Color? color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color ?? _c.textSecond),
          const SizedBox(width: 10),
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(color: _c.textSecond, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: color ?? _c.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        // ── Checkpoint Info ───────────────────────────────────────────────
        _sectionLabel('CHECKPOINT INFO'),
        _infoCard([
          _InfoRow(
            Icons.location_on_outlined,
            'Area',
            val(checkpoint.location),
          ),
          _InfoRow(Icons.place_outlined, 'Location', val(checkpoint.location)),
          _InfoRow(
            Icons.settings_outlined,
            'Equipment',
            val(checkpoint.equipmentName),
          ),
          _InfoRow(
            Icons.category_outlined,
            'Component',
            val(checkpoint.component),
          ),
          _InfoRow(
            Icons.search_outlined,
            'Object To Check',
            val(checkpoint.description),
          ),
          _InfoRow(
            Icons.warning_amber_rounded,
            'Hazmat',
            val(checkpoint.hazardousMaterial),
            color: checkpoint.hazardousMaterial != null ? _A.accentRed : null,
          ),
        ]),

        // ── Audit Results ─────────────────────────────────────────────────
        _sectionLabel('AUDIT RESULTS'),

        _infoCard([
          _InfoRow(
            Icons.article_outlined,
            'Document Analysis',
            val(checkpoint.documentAnalysisResult),
          ),
          _InfoRow(
            Icons.fact_check_outlined,
            'Result of Check',
            val(checkpoint.checkResult),
          ),
        ]),

        // ── PCHM & Remarks ────────────────────────────────────────────────
        _sectionLabel('FLAGS & REMARKS'),
        Container(
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _c.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isPchm ? _A.accentAmber.withOpacity(0.4) : _c.divider,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isPchm ? _A.accentAmber : _c.textSecond).withOpacity(
                    0.12,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.flag_rounded,
                  color: isPchm ? _A.accentAmber : _c.textSecond,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mark as PCHM',
                      style: TextStyle(
                        color: _c.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Potential Concentration of Hazardous Material',
                      style: TextStyle(color: _c.textSecond, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isPchm,
                onChanged: onPchmChanged,
                activeColor: _A.accentAmber,
                activeTrackColor: _A.accentAmber.withOpacity(0.3),
                inactiveThumbColor: _c.textSecond,
                inactiveTrackColor: _c.divider,
              ),
            ],
          ),
        ),

        // ── Text fields ───────────────────────────────────────────────────
        _ThemedTextField(
          controller: remarks,
          label: 'Remarks',
          icon: Icons.edit_note_rounded,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _ThemedTextField(
          controller: locationRemarks,
          label: 'Site Remarks (if any)',
          icon: Icons.add_location_alt_outlined,
          isDark: isDark,
        ),
      ],
    );
  }
}

class _InfoRow {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;
  const _InfoRow(this.icon, this.label, this.value, {this.color});
}

// ─── Themed TextField ─────────────────────────────────────────────────────────
class _ThemedTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool isDark;

  const _ThemedTextField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.isDark,
  });

  _TC get _c => isDark ? _TC.dark : _TC.light;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: 3,
      style: TextStyle(color: _c.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: _c.textSecond, fontSize: 13),
        prefixIcon: Icon(icon, color: _c.textSecond, size: 18),
        filled: true,
        fillColor: _c.bgCard,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _c.divider, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _A.accent, width: 1.5),
        ),
      ),
    );
  }
}

// ─── Area Tab ─────────────────────────────────────────────────────────────────
class _AreaTab extends StatefulWidget {
  final IhmCheckpoint checkpoint;
  final bool isDark;

  const _AreaTab({required this.checkpoint, required this.isDark});

  @override
  State<_AreaTab> createState() => _AreaTabState();
}

class _AreaTabState extends State<_AreaTab> {
  String? imagePath;
  List<IhmLayoutImage> layoutImages = [];
  List<IhmMarker> markers = [];
  bool loading = true;
  bool savingMarker = false;
  bool _online = false;

  String? layoutError;
  int _loadSeq = 0;
  final TransformationController _controller = TransformationController();
  final GlobalKey _layoutImageKey = GlobalKey();
  Size? _layoutImageSize;
  static const double _mobilePinWidth = 48;
  static const double _mobilePinHeight = 46;
  static const double _desktopPinWidth = 72;
  static const double _desktopPinHeight = 64;

  bool get _isMobileMap {
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    return shortestSide < 600;
  }

  double get _pinWidth => _isMobileMap ? _mobilePinWidth : _desktopPinWidth;
  double get _pinHeight => _isMobileMap ? _mobilePinHeight : _desktopPinHeight;

  double get mapWidth => _layoutImageSize?.width ?? 1400;
  double get mapHeight => _layoutImageSize?.height ?? 990;

  Rect getFittedImageRect({
    required Size containerSize,
    required Size imageSize,
    BoxFit fit = BoxFit.contain,
  }) {
    final fitted = applyBoxFit(fit, imageSize, containerSize);
    return Alignment.center.inscribe(
      fitted.destination,
      Offset.zero & containerSize,
    );
  }

  double _storedPercentToUnit(double value) {
    if (value > 1) return (value / 100).clamp(0.0, 1.0);
    return value.clamp(0.0, 1.0);
  }

  _TC get _c => widget.isDark ? _TC.dark : _TC.light;
  String _normalizeMarkerPath(String? path) {
    final value = (path ?? '').trim();
    if (value.isEmpty) return '';

    final parsed = Uri.tryParse(value);
    if (parsed != null && parsed.hasScheme) {
      return parsed.path.replaceFirst(RegExp(r'^/+'), '').toLowerCase();
    }

    return value
        .replaceFirst(RegExp(r'^https?://[^/]+', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^/+'), '')
        .toLowerCase();
  }

  bool _sameMarkerImage(String? left, String? right) {
    return _normalizeMarkerPath(left) == _normalizeMarkerPath(right);
  }

  IhmLayoutImage? _layoutForPath(String? path) {
    if (path == null) return null;
    for (final layout in layoutImages) {
      if (_sameMarkerImage(layout.filePath, path)) {
        return layout;
      }
    }
    return null;
  }

  String? _localLayoutPath(String? path) {
    final layout = _layoutForPath(path);
    final localPath = layout?.localFilePath;
    if (localPath == null || localPath.trim().isEmpty) return null;
    final file = File(localPath);
    final exists = file.existsSync();
    debugPrint(
      '[IHM offline image] area layout id=${layout?.id} '
      'remote=${layout?.filePath ?? path} local=$localPath exists=$exists',
    );
    return exists ? localPath : null;
  }

  ImageProvider? _layoutImageProvider(String path) {
    final localPath = _localLayoutPath(path);
    if (localPath != null) {
      return FileImage(File(localPath));
    }
    if (!_online) return null;
    return NetworkImage(ApiService.fileUrl(path));
  }

  Widget _buildLayoutImage(
    String path, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
  }) {
    final provider = _layoutImageProvider(path);
    if (provider == null) {
      return _offlineImagePlaceholder(width: width, height: height);
    }

    return Image(
      image: provider,
      width: width,
      height: height,
      fit: fit,
      filterQuality: FilterQuality.medium,
      isAntiAlias: true,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          width: width,
          height: height,
          color: _c.bgCardAlt,
          alignment: Alignment.center,
          child: const CircularProgressIndicator(strokeWidth: 2),
        );
      },
      errorBuilder: (_, __, ___) =>
          _offlineImagePlaceholder(width: width, height: height),
    );
  }

  Widget _offlineImagePlaceholder({double? width, double? height}) {
    return Container(
      width: width,
      height: height,
      color: _c.bgCardAlt,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(10),
      child: Text(
        'Image not available offline.\nPlease sync online once.',
        textAlign: TextAlign.center,
        style: TextStyle(color: _c.textSecond, fontSize: 11),
      ),
    );
  }

  String _markerSavePath(String path) {
    final value = path.trim();
    final parsed = Uri.tryParse(value);

    if (parsed != null && parsed.hasScheme) {
      return parsed.path.replaceFirst(RegExp(r'^/+'), '');
    }

    return value
        .replaceFirst(RegExp(r'^https?://[^/]+', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^/+'), '');
  }

  Future<void> _loadLayoutImageSize(String path) async {
    final provider = _layoutImageProvider(path);
    if (provider == null) return;
    final stream = provider.resolve(const ImageConfiguration());
    late ImageStreamListener listener;

    listener = ImageStreamListener(
      (info, _) {
        final size = Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        );

        if (mounted) {
          setState(() => _layoutImageSize = size);
        }

        stream.removeListener(listener);
      },
      onError: (_, __) {
        stream.removeListener(listener);
      },
    );

    stream.addListener(listener);
  }

  @override
  void initState() {
    super.initState();

    _load();
  }

  @override
  void didUpdateWidget(covariant _AreaTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    final changed =
        oldWidget.checkpoint.surveyJobId != widget.checkpoint.surveyJobId ||
        oldWidget.checkpoint.ihmAreaId != widget.checkpoint.ihmAreaId ||
        oldWidget.checkpoint.id != widget.checkpoint.id;

    if (changed) {
      setState(() {
        imagePath = null;
        layoutImages = [];
        layoutError = null;
        markers = [];
        loading = true;
      });
      _controller.value = Matrix4.identity();
      _load();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _zoomLayout(double factor) {
    final currentScale = _controller.value.getMaxScaleOnAxis();
    if (currentScale <= 0) {
      _controller.value = Matrix4.identity();
      return;
    }

    final nextScale = (currentScale * factor).clamp(0.5, 8.0).toDouble();
    final scaleDelta = nextScale / currentScale;
    _controller.value = _controller.value.clone()..scale(scaleDelta);
  }

  void _resetLayoutZoom() {
    _controller.value = Matrix4.identity();
  }

  Future<void> _load() async {
    final seq = ++_loadSeq;
    final jobId = widget.checkpoint.surveyJobId;
    final areaId = widget.checkpoint.ihmAreaId;

    List<IhmLayoutImage> layouts = [];
    List<IhmMarker> cachedMarkers = [];
    String? loadError;
    final online = await IhmOfflineService.isOnline;

    // Render the local cache first. This prevents a white screen while the
    // online refresh/download is in progress and makes cached layouts usable
    // immediately after the device goes offline.
    if (!kIsWeb) {
      try {
        layouts = await IhmOfflineService.getLocalLayouts(jobId, areaId);
        cachedMarkers = (await IhmOfflineService.getLocalMarkers(jobId))
            .where((m) => m.ihmAreaId == areaId)
            .toList();
        // When online and no layout is cached yet, keep the loader visible
        // instead of drawing pins on an empty placeholder; the network
        // request below will download and show the layout.
        final showCached =
            layouts.isNotEmpty || (!online && cachedMarkers.isNotEmpty);
        if (mounted && seq == _loadSeq && showCached) {
          final cachedPath = layouts.isNotEmpty
              ? layouts.first.filePath
              : cachedMarkers.first.imagePath;
          setState(() {
            layoutImages = layouts;
            imagePath = cachedPath;
            markers = _dedupeMarkers(cachedMarkers);
            _online = online;
            loading = false;
          });
          if (!cachedPath.toLowerCase().endsWith('.pdf')) {
            _loadLayoutImageSize(cachedPath);
          }
        }
      } catch (_) {
        // The remote request below remains the source of truth when cache is
        // unavailable.
      }
    }

    try {
      layouts = await IhmOfflineService.getLayouts(jobId, areaId);
    } catch (e) {
      loadError = e.toString();
    }

    try {
      final result = await IhmOfflineService.getMarkers(jobId, areaId);

      final jobMarkers = result.where((m) => m.surveyJobId == jobId).toList();

      if (!mounted || seq != _loadSeq) return;

      setState(() {
        layoutImages = layouts;
        layoutError = loadError;
        _online = online;
        imagePath = layouts.isNotEmpty
            ? layouts.first.filePath
            : (jobMarkers.isNotEmpty ? jobMarkers.first.imagePath : null);
        markers = _dedupeMarkers(jobMarkers);
        loading = false;
      });
      if (imagePath != null && !imagePath!.toLowerCase().endsWith('.pdf')) {
        _loadLayoutImageSize(imagePath!);
      }
    } catch (_) {
      if (!mounted || seq != _loadSeq) return;
      setState(() => loading = false);
    }
  }

  List<IhmMarker> _dedupeMarkers(List<IhmMarker> source) {
    final byCheckpointAndImage = <String, IhmMarker>{};
    final withoutCheckpoint = <IhmMarker>[];

    for (final marker in source) {
      final checkpointId = marker.ihmCheckpointId;
      if (checkpointId == null || checkpointId <= 0) {
        withoutCheckpoint.add(marker);
        continue;
      }

      final key = '$checkpointId|${_normalizeMarkerPath(marker.imagePath)}';
      final existing = byCheckpointAndImage[key];
      if (existing == null || marker.id > existing.id) {
        byCheckpointAndImage[key] = marker;
      }
    }

    return [...byCheckpointAndImage.values, ...withoutCheckpoint];
  }

  Future<void> _saveMarker(TapUpDetails details) async {
    if (imagePath == null || savingMarker) return;
    if (_layoutImageSize == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait until layout image is loaded'),
          duration: Duration(milliseconds: 900),
        ),
      );
      return;
    }
    final box =
        _layoutImageKey.currentContext?.findRenderObject() as RenderBox?;

    if (box == null || !box.hasSize) return;

    final tapPoint = box.globalToLocal(details.globalPosition);

    final imageRect = getFittedImageRect(
      containerSize: box.size,
      imageSize: _layoutImageSize!,
      fit: BoxFit.contain,
    );

    if (!imageRect.contains(tapPoint)) {
      return;
    }

    final localImageX = tapPoint.dx - imageRect.left;
    final localImageY = tapPoint.dy - imageRect.top;

    final imageX = localImageX / imageRect.width * _layoutImageSize!.width;
    final imageY = localImageY / imageRect.height * _layoutImageSize!.height;

    final xPercent = (imageX / _layoutImageSize!.width).clamp(0.0, 1.0);
    final yPercent = (imageY / _layoutImageSize!.height).clamp(0.0, 1.0);

    setState(() => savingMarker = true);

    try {
      final marker = await IhmOfflineService.saveMarker(
        checkpoint: widget.checkpoint,
        imagePath: _markerSavePath(imagePath!),
        xPercent: xPercent,
        yPercent: yPercent,
      );

      final persisted = await IhmOfflineService.getMarkers(
        widget.checkpoint.surveyJobId,
        widget.checkpoint.ihmAreaId,
      );
      if (!mounted) return;

      setState(() {
        markers = _dedupeMarkers([
          ...persisted.where(
            (m) => m.surveyJobId == widget.checkpoint.surveyJobId,
          ),
          marker,
        ]);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checkpoint pin saved'),
          duration: Duration(milliseconds: 900),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save checkpoint pin: $e'),
          backgroundColor: _A.accentRed,
        ),
      );
    } finally {
      if (mounted) setState(() => savingMarker = false);
    }
  }

  Future<void> _deleteMarker(IhmMarker marker) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Delete checkpoint pin?',
      message: 'Remove this pin from the layout image?',
      confirmLabel: 'Delete pin',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await IhmOfflineService.deleteMarker(marker);
      if (!mounted) return;
      final persisted = await IhmOfflineService.getMarkers(
        widget.checkpoint.surveyJobId,
        widget.checkpoint.ihmAreaId,
      );
      if (!mounted) return;
      setState(() {
        markers = _dedupeMarkers(
          persisted
              .where((m) => m.surveyJobId == widget.checkpoint.surveyJobId)
              .toList(),
        );
      });
      await AppDialog.success(
        context,
        title: 'Pin deleted',
        message: 'The checkpoint pin was removed from the layout.',
      );
    } catch (e) {
      if (!mounted) return;
      await AppDialog.error(context, title: 'Unable to delete pin', message: e);
    }
  }

  List<IhmMarker> get _visibleMarkers => _dedupeMarkers(
    markers
        .where(
          (m) =>
              m.surveyJobId == widget.checkpoint.surveyJobId &&
              _sameMarkerImage(m.imagePath, imagePath),
        )
        .toList(),
  );

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Center(child: CircularProgressIndicator(color: _A.accent));
    }

    if (imagePath == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, color: _c.textSecond, size: 48),
            const SizedBox(height: 12),
            Text(
              layoutError == null
                  ? 'No layout uploaded for this job.'
                  : 'Unable to load layout attachments.',
              style: TextStyle(color: _c.textSecond, fontSize: 14),
            ),
            if (layoutError != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  layoutError!,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _A.accentRed, fontSize: 11),
                ),
              ),
            ],
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () {
                setState(() => loading = true);
                _load();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (imagePath!.toLowerCase().endsWith('.pdf')) {
      final localPdfPath = _localLayoutPath(imagePath!);
      return localPdfPath != null
          ? SfPdfViewer.file(
              File(localPdfPath),
              canShowScrollHead: true,
              canShowScrollStatus: true,
              enableDoubleTapZooming: true,
            )
          : _online
          ? SfPdfViewer.network(
              ApiService.fileUrl(imagePath!),
              canShowScrollHead: true,
              canShowScrollStatus: true,
              enableDoubleTapZooming: true,
            )
          : _offlineImagePlaceholder();
    }

    return ClipRect(
      child: InteractiveViewer(
        transformationController: _controller,
        minScale: 0.15,
        maxScale: 10,
        panEnabled: true,
        scaleEnabled: true,
        constrained: false,
        alignment: Alignment.center,
        boundaryMargin: const EdgeInsets.all(double.infinity),
        interactionEndFrictionCoefficient: 0.000001,
        panAxis: PanAxis.free,
        child: SizedBox(
          key: _layoutImageKey,
          width: mapWidth,
          height: mapHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final widgetSize = Size(
                constraints.maxWidth,
                constraints.maxHeight,
              );

              final imageSize = _layoutImageSize ?? Size(mapWidth, mapHeight);

              final imageRect = getFittedImageRect(
                containerSize: widgetSize,
                imageSize: imageSize,
                fit: BoxFit.contain,
              );

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: _saveMarker,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(child: _buildLayoutImage(imagePath!)),

                    for (final marker in _visibleMarkers)
                      Builder(
                        builder: (context) {
                          final pinWidth = _isMobileMap ? 48.0 : 72.0;
                          final pinHeight = _isMobileMap ? 46.0 : 64.0;

                          final point = Offset(
                            imageRect.left +
                                (_storedPercentToUnit(marker.xPercent) *
                                    imageRect.width),
                            imageRect.top +
                                (_storedPercentToUnit(marker.yPercent) *
                                    imageRect.height),
                          );

                          return Positioned(
                            left: point.dx - (pinWidth / 2),
                            top: point.dy - pinHeight,
                            width: pinWidth,
                            height: pinHeight,
                            child: AnimatedBuilder(
                              animation: _controller,
                              builder: (context, child) {
                                final scale = _controller.value
                                    .getMaxScaleOnAxis();
                                final markerScale = scale <= 0
                                    ? 1.0
                                    : (1.0 / scale);

                                return Transform.scale(
                                  scale: markerScale,
                                  alignment: Alignment.bottomCenter,
                                  child: child,
                                );
                              },
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapUp: (_) {},
                                onDoubleTap: () async {
                                  await _deleteMarker(marker);
                                },
                                child: _GooglePin(
                                  label: marker.markerLabel ?? '',
                                  active:
                                      marker.ihmCheckpointId ==
                                      widget.checkpoint.id,
                                  compact: _isMobileMap,
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                    if (savingMarker)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Container(
                            color: Colors.black.withOpacity(0.12),
                            alignment: Alignment.center,
                            child: const CircularProgressIndicator(
                              color: _A.accent,
                            ),
                          ),
                        ),
                      ),

                    Positioned(
                      top: 12,
                      right: 12,
                      child: _LayoutZoomControls(
                        colorSet: _c,
                        onZoomIn: () => _zoomLayout(1.35),
                        onZoomOut: () => _zoomLayout(0.75),
                        onReset: _resetLayoutZoom,
                      ),
                    ),

                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _c.bgCard.withOpacity(0.92),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _c.divider, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.touch_app_rounded,
                                color: _c.textSecond,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Tap to add · Double-tap pin to remove',
                                style: TextStyle(
                                  color: _c.textSecond,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showLayoutAttachments() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _c.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Layout Attachments',
                style: TextStyle(
                  color: _c.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Common and area-specific images available here',
                style: TextStyle(color: _c.textSecond, fontSize: 12),
              ),
              const SizedBox(height: 16),

              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: layoutImages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, index) {
                    final layout = layoutImages[index];

                    return ListTile(
                      onTap: () {
                        setState(() {
                          imagePath = layout.filePath;
                          _layoutImageSize = null;
                          _loadLayoutImageSize(layout.filePath);
                        });

                        _controller.value = Matrix4.identity();
                        Navigator.pop(sheetContext);
                      },

                      tileColor: layout.filePath == imagePath
                          ? _A.accent.withOpacity(0.1)
                          : _c.bgCardAlt,

                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: _c.divider),
                      ),

                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: layout.filePath.toLowerCase().endsWith('.pdf')
                            ? Container(
                                width: 58,
                                height: 48,
                                color: _c.divider,
                                child: const Icon(
                                  Icons.picture_as_pdf_outlined,
                                  color: _A.accentRed,
                                ),
                              )
                            : _buildLayoutImage(
                                layout.filePath,
                                width: 58,
                                height: 48,
                                fit: BoxFit.cover,
                              ),
                      ),

                      title: Text(
                        layout.originalFileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _c.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      subtitle: Text(
                        layout.isCommon ? 'Common Layout' : 'Area Layout',
                        style: TextStyle(color: _c.textSecond, fontSize: 11),
                      ),

                      trailing: const Icon(
                        Icons.visibility_rounded,
                        color: _A.accent,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ); // <-- missing closing bracket was here
  }
}

// ─── Images Tab ───────────────────────────────────────────────────────────────
class _LayoutZoomControls extends StatelessWidget {
  final _TC colorSet;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;

  const _LayoutZoomControls({
    required this.colorSet,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colorSet.bgCard.withOpacity(0.94),
      elevation: 4,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colorSet.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _zoomButton(
              icon: Icons.remove_rounded,
              tooltip: 'Zoom out',
              onPressed: onZoomOut,
            ),
            _divider(),
            _zoomButton(
              icon: Icons.center_focus_strong_rounded,
              tooltip: 'Reset zoom',
              onPressed: onReset,
            ),
            _divider(),
            _zoomButton(
              icon: Icons.add_rounded,
              tooltip: 'Zoom in',
              onPressed: onZoomIn,
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 24, color: colorSet.divider);

  Widget _zoomButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onPressed,
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(icon, size: 20, color: colorSet.textPrimary),
        ),
      ),
    );
  }
}

class _ImagesTab extends StatefulWidget {
  final IhmCheckpoint checkpoint;
  final bool isDark;

  const _ImagesTab({required this.checkpoint, required this.isDark});

  @override
  State<_ImagesTab> createState() => _ImagesTabState();
}

class _ImagesTabState extends State<_ImagesTab> {
  final ImagePicker picker = ImagePicker();
  List<IhmSamplingPhoto> photos = [];
  bool loading = true;
  bool uploading = false;
  bool _online = false;

  _TC get _c => widget.isDark ? _TC.dark : _TC.light;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  String _displayPhotoPath(IhmSamplingPhoto photo) {
    final edited = photo.appendixThreeEditedFilePath;
    if (edited != null &&
        edited.trim().isNotEmpty &&
        (photo.appendixThreeWidth ?? 0) > 0 &&
        (photo.appendixThreeHeight ?? 0) > 0) {
      return edited;
    }

    return photo.filePath;
  }

  String? _localPhotoPath(IhmSamplingPhoto photo) {
    final displayPath = _displayPhotoPath(photo);
    final candidates = <String?>[
      if (displayPath == photo.appendixThreeEditedFilePath)
        photo.appendixThreeEditedLocalFilePath,
      photo.localFilePath,
    ];

    for (final path in candidates) {
      if (path == null || path.trim().isEmpty) continue;
      final exists = File(path).existsSync();
      debugPrint(
        '[IHM offline image] checkpoint photo id=${photo.id} '
        'remote=$displayPath local=$path exists=$exists',
      );
      if (exists) return path;
    }

    return null;
  }

  Future<void> _loadPhotos() async {
    try {
      final online = await IhmOfflineService.isOnline;
      final result = await IhmOfflineService.getCheckpointPhotos(
        widget.checkpoint,
      );

      if (!mounted) return;
      setState(() {
        photos = result;
        _online = online;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _pick(ImageSource source) async {
    try {
      setState(() => uploading = true);

      final List<XFile> files;
      if (source == ImageSource.gallery) {
        // The server keeps photos at max 1800px (JPEG 75), so resizing here
        // loses nothing and makes offline storage and sync uploads much smaller.
        files = await picker.pickMultiImage(
          imageQuality: 75,
          maxWidth: 1800,
          maxHeight: 1800,
        );
      } else {
        // Android may close the app while the camera is open (often on the
        // first camera launch). Remember the checkpoint so the photo can be
        // recovered and saved after the app restarts.
        if (source == ImageSource.camera) {
          await CameraRecovery.rememberCheckpoint(widget.checkpoint);
        }
        final XFile? file;
        try {
          file = await picker.pickImage(
            source: source,
            imageQuality: 75,
            maxWidth: 1800,
            maxHeight: 1800,
          );
        } finally {
          if (source == ImageSource.camera) {
            await CameraRecovery.clear();
          }
        }
        files = file == null ? <XFile>[] : <XFile>[file];
      }

      if (files.isEmpty) {
        if (mounted) setState(() => uploading = false);
        return;
      }

      final uploadedPhotos = <IhmSamplingPhoto>[];
      var phoneSaveFailed = false;

      for (final file in files) {
        final bytes = await file.readAsBytes();
        // Camera photos: also keep a copy in the phone's storage
        // (Pictures/IHM/<date>), online or offline.
        if (source == ImageSource.camera) {
          final savedTo = await PhoneGallery.saveCheckpointPhoto(
            bytes: bytes,
            sampleNo: widget.checkpoint.sampleNo,
          );
          if (savedTo == null) phoneSaveFailed = true;
        }
        final uploaded = await IhmOfflineService.saveCheckpointPhoto(
          checkpoint: widget.checkpoint,
          fileBytes: bytes,
          fileName: file.name,
        );
        uploadedPhotos.add(uploaded);
      }

      if (!mounted) return;
      setState(() {
        photos.addAll(uploadedPhotos);
        uploading = false;
      });
      if (phoneSaveFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Photo added to the checkpoint, but the copy in phone storage '
              '(Pictures/IHM) could not be saved.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => uploading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _toggleAppendixThree(IhmSamplingPhoto photo) async {
    final selectedIds = photos
        .where((x) => x.showInAppendixThree)
        .map((x) => x.id)
        .toList();

    if (selectedIds.contains(photo.id)) {
      selectedIds.remove(photo.id);
    } else {
      if (selectedIds.length >= 2) {
        await AppDialog.error(
          context,
          title: 'Limit exceeded',
          message: 'Only 2 images can be selected for Appendix 3.',
        );
        return;
      }
      selectedIds.add(photo.id);
    }

    await ApiService.saveAppendixThreeSelection(
      checkpointId: widget.checkpoint.id,
      photoIds: selectedIds,
    );

    if (!mounted) return;
    await _loadPhotos();
  }

  Future<void> _editAppendixThreeImage(IhmSamplingPhoto photo) async {
    await ApiService.rotateAppendixThreeImage(photoId: photo.id);

    if (!mounted) return;
    await _loadPhotos();
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _c.bgCard,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.camera_alt, color: _c.textPrimary),
                title: Text(
                  'Capture from Camera',
                  style: TextStyle(color: _c.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pick(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library, color: _c.textPrimary),
                title: Text(
                  'Upload from Gallery',
                  style: TextStyle(color: _c.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pick(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deletePhoto(IhmSamplingPhoto photo) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Delete attachment?',
      message: 'Remove this checkpoint photo permanently?',
      confirmLabel: 'Delete attachment',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await IhmOfflineService.deleteCheckpointPhoto(photo);
      if (!mounted) return;
      setState(() => photos.remove(photo));
      await AppDialog.success(
        context,
        title: 'Attachment deleted',
        message: 'The checkpoint photo was removed.',
      );
    } catch (e) {
      if (!mounted) return;
      await AppDialog.error(
        context,
        title: 'Unable to delete attachment',
        message: e,
      );
    }
  }

  Widget _buildPhotoImage(IhmSamplingPhoto photo) {
    final imageWidget = () {
      final resolvedLocalPath = _localPhotoPath(photo);

      if (resolvedLocalPath != null) {
        return Image.file(
          File(resolvedLocalPath),
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _brokenPhoto(),
        );
      }

      if (!_online) return _offlinePhotoPlaceholder();

      return Image.network(
        ApiService.fileUrl(_displayPhotoPath(photo)),
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _offlinePhotoPlaceholder(),
      );
    }();

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: _c.bgCardAlt,
      alignment: Alignment.center,
      child: imageWidget,
    );
  }

  Widget _brokenPhoto() {
    return Container(
      color: _c.bgCardAlt,
      alignment: Alignment.center,
      child: const Icon(Icons.broken_image_outlined, color: _A.accentRed),
    );
  }

  Widget _offlinePhotoPlaceholder() {
    return Container(
      color: _c.bgCardAlt,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(10),
      child: Text(
        'Image not available offline.\nPlease sync online once.',
        textAlign: TextAlign.center,
        style: TextStyle(color: _c.textSecond, fontSize: 11),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Center(child: CircularProgressIndicator(color: _A.accent));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              icon: uploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_a_photo),
              label: Text(uploading ? 'Uploading...' : 'Add Checkpoint Image'),
              onPressed: uploading ? null : _showImageOptions,
            ),
          ),
        ),
        Expanded(
          child: photos.isEmpty
              ? Center(
                  child: Text(
                    'No checkpoint images uploaded yet',
                    style: TextStyle(color: _c.textSecond),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.05,
                  ),
                  itemCount: photos.length,
                  itemBuilder: (context, index) {
                    final photo = photos[index];
                    final selected = photo.showInAppendixThree == true;

                    return Container(
                      decoration: BoxDecoration(
                        color: _c.bgCardAlt,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _c.divider),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Positioned.fill(
                            child: Container(
                              color: _c.bgCardAlt,
                              alignment: Alignment.center,
                              child: _buildPhotoImage(photo),
                            ),
                          ),

                          Positioned(
                            left: 8,
                            top: 8,
                            child: Material(
                              color: Colors.black.withOpacity(0.58),
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => _toggleAppendixThree(photo),
                                child: SizedBox(
                                  width: 38,
                                  height: 38,
                                  child: Center(
                                    child: Checkbox(
                                      value: selected,
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      activeColor: _A.accent,
                                      checkColor: Colors.white,
                                      side: const BorderSide(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                      onChanged: (_) =>
                                          _toggleAppendixThree(photo),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          if (selected)
                            Positioned(
                              left: 8,
                              bottom: 8,
                              child: Material(
                                color: Colors.black.withOpacity(0.62),
                                shape: const CircleBorder(),
                                child: IconButton(
                                  tooltip: 'Rotate image',
                                  icon: const Icon(
                                    Icons.rotate_right,
                                    color: Colors.white,
                                    size: 21,
                                  ),
                                  onPressed: () =>
                                      _editAppendixThreeImage(photo),
                                ),
                              ),
                            ),

                          Positioned(
                            top: 6,
                            right: 6,
                            child: Material(
                              color: Colors.black.withOpacity(0.58),
                              shape: const CircleBorder(),
                              child: IconButton(
                                tooltip: 'Delete image',
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.white,
                                  size: 19,
                                ),
                                onPressed: () => _deletePhoto(photo),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─── Pin Widget ───────────────────────────────────────────────────────────────
class _GooglePin extends StatelessWidget {
  final String label;
  final bool active;
  final bool compact;

  const _GooglePin({
    required this.label,
    required this.active,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? _A.accentBlue : _A.accentRed;

    return SizedBox(
      width: compact ? 48 : 72,
      height: compact ? 46 : 64,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: BoxConstraints(
              minWidth: compact ? 24 : 34,
              maxWidth: compact ? 44 : 68,
              minHeight: compact ? 18 : 24,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 5 : 7,
              vertical: compact ? 2 : 4,
            ),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.22),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label.isEmpty ? '-' : label,
                maxLines: 1,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 9 : 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          Icon(Icons.location_pin, color: color, size: compact ? 24 : 32),
        ],
      ),
    );
  }
}
