// test_report_detail_screen.dart
// Full view of a test report — info cards, image gallery, edit/delete.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/theme_colors.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/utils/file_utils.dart';
import '../models/test_report.dart';
import '../services/test_report_service.dart';
import 'add_edit_test_report_screen.dart';

class TestReportDetailScreen extends StatefulWidget {
  final TestReport  report;
  final bool       canEdit;
  final bool       canDelete;
  final Future<void> Function(TestReport)? onEditOverride;
  final Future<void> Function(String prescriptionId)? onPrescriptionTap;

  const TestReportDetailScreen({
    super.key,
    required this.report,
    this.canEdit           = true,
    this.canDelete         = true,
    this.onEditOverride,
    this.onPrescriptionTap,
  });

  @override
  State<TestReportDetailScreen> createState() =>
      _TestReportDetailScreenState();
}

class _TestReportDetailScreenState extends State<TestReportDetailScreen> {
  final _service = TestReportService();

  late TestReport _r;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _r = widget.report;
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final fresh = await _service.fetchOne(_r.id);
      if (fresh != null && mounted) setState(() => _r = fresh);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Edit ──────────────────────────────────────────────────────────────────

  Future<void> _edit() async {
    if (widget.onEditOverride != null) {
      await widget.onEditOverride!(_r);
      if (mounted) Navigator.of(context).pop(true);
      return;
    }
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
          builder: (_) => AddEditTestReportScreen(existing: _r)),
    );
    if (changed == true) {
      await _refresh();
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> _delete() async {
    final c = context.colors;
    final s = S.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.card,
        title: Text(s.deleteTestReport,
            style: GoogleFonts.poppins(
                color: c.textPrimary, fontWeight: FontWeight.w600)),
        content: Text(s.deleteReportConfirm,
            style: GoogleFonts.poppins(
                fontSize: 13, color: c.textSec)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.cancel,
                style: GoogleFonts.poppins(color: c.textSec)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete',
                style: GoogleFonts.poppins(
                    color: c.red,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _loading = true);
    try {
      await _service.delete(_r.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _loading = false);
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = S.of(context);

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
      statusBarIconBrightness: c.statusBarIconBrightness,
    ));

    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          _buildHeader(c, s),
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(
                        color: c.cyan))
                : SingleChildScrollView(
                    padding:
                        const EdgeInsets.fromLTRB(20, 20, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category badge
                        if (_r.category?.isNotEmpty == true) ...[
                          _CategoryBadgeLarge(label: _r.category!),
                          const SizedBox(height: 20),
                        ],

                        // Test & doctor info
                        _SectionLabel(text: 'Test Information'),
                        const SizedBox(height: 10),
                        _InfoCard(
                          accentColor: c.cyan,
                          child: Column(children: [
                            _InfoRow(
                              icon:      Icons.science_rounded,
                              iconColor: c.cyan,
                              label:     s.testName,
                              value:     _r.testName,
                            ),
                            if (_r.testDate != null)
                              _InfoRow(
                                icon:      Icons.calendar_today_rounded,
                                iconColor: c.purpleBright,
                                label:     s.testDate,
                                value:     _fmtDate(_r.testDate!),
                              ),
                            if (_r.doctorName?.isNotEmpty == true)
                              _InfoRow(
                                icon:      Icons.person_rounded,
                                iconColor: c.green,
                                label:     s.doctorName,
                                value:     'Dr. ${_r.doctorName!}',
                              ),
                            if (_r.hospital?.isNotEmpty == true)
                              _InfoRow(
                                icon:      Icons.local_hospital_rounded,
                                iconColor: c.amber,
                                label:     s.labHospital,
                                value:     _r.hospital!,
                                isLast:    true,
                              )
                            else
                              const SizedBox.shrink(),
                          ]),
                        ).animate().fadeIn(delay: 60.ms).slideY(begin: 0.06),

                        // Notes
                        if (_r.notes?.isNotEmpty == true) ...[
                          const SizedBox(height: 20),
                          _SectionLabel(text: s.notes),
                          const SizedBox(height: 10),
                          _InfoCard(
                            accentColor: c.purpleBright,
                            child: _InfoRow(
                              icon:      Icons.notes_rounded,
                              iconColor: c.purpleBright,
                              label:     s.notes,
                              value:     _r.notes!,
                              isLast:    true,
                            ),
                          ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.06),
                        ],

                        // Prescription link
                        if (_r.prescriptionId != null) ...[
                          const SizedBox(height: 20),
                          _SectionLabel(text: s.linkedPrescription),
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: widget.onPrescriptionTap != null
                                ? () => widget.onPrescriptionTap!(_r.prescriptionId!)
                                : null,
                            child: _InfoCard(
                              accentColor: c.purpleBright,
                              child: _InfoRow(
                                icon:      Icons.link_rounded,
                                iconColor: c.purpleBright,
                                label:     s.linkedPrescription,
                                value:     _r.prescriptionDisplay ??
                                    _r.prescriptionId!.substring(0, 8),
                                isLast:    true,
                                trailing: widget.onPrescriptionTap != null
                                    ? Padding(
                                        padding: const EdgeInsets.only(right: 4),
                                        child: Icon(Icons.arrow_forward_ios_rounded,
                                            size: 14, color: c.purpleBright),
                                      )
                                    : null,
                              ),
                            ),
                          ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.06),
                        ],

                        // Images
                        if (_r.imageUrls.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          _SectionLabel(text: s.viewImage),
                          const SizedBox(height: 10),
                          _ReportGallery(urls: _r.imageUrls)
                              .animate()
                              .fadeIn(delay: 120.ms),
                        ],

                        if (widget.canEdit || widget.canDelete) ...[
                          const SizedBox(height: 28),
                          _ActionRow(
                            onEdit:   widget.canEdit   ? _edit   : null,
                            onDelete: widget.canDelete ? _delete : null,
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeColors c, S s) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.only(
          bottomLeft:  Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        border: Border(bottom: BorderSide(color: c.border, width: 1)),
      ),
      padding: EdgeInsets.only(
          top: topPad + 16, left: 20, right: 20, bottom: 18),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: _SmallIconBtn(icon: Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _r.testName,
                  style: GoogleFonts.poppins(
                    fontSize:   20,
                    fontWeight: FontWeight.w700,
                    color:      c.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _r.testDate != null ? _fmtDate(_r.testDate!) : '—',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: c.textSec),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.05);
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ══════════════════════════════════════════════════════════════════════════════
// Sub-widgets
// ══════════════════════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: GoogleFonts.poppins(
          fontSize:   16,
          fontWeight: FontWeight.w700,
          color:      context.colors.textPrimary,
        ),
      );
}

class _CategoryBadgeLarge extends StatelessWidget {
  final String label;
  const _CategoryBadgeLarge({required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color:        c.cyan.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: c.cyan.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.label_rounded,
              size: 14, color: c.cyan),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize:   13,
              fontWeight: FontWeight.w600,
              color:      c.cyan,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 40.ms);
  }
}

class _InfoCard extends StatelessWidget {
  final Widget child;
  final Color  accentColor;

  const _InfoCard({required this.child, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color:        c.card,
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: c.border, width: 1),
        boxShadow: [
          BoxShadow(
            color:      accentColor.withAlpha(10),
            blurRadius: 12,
            offset:     const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: accentColor),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final String   label;
  final String   value;
  final bool     isLast;
  final Widget?  trailing;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.isLast  = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color:        iconColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: GoogleFonts.poppins(
                            fontSize: 10, color: c.textMuted)),
                    Text(value,
                        style: GoogleFonts.poppins(
                          fontSize:   13,
                          fontWeight: FontWeight.w500,
                          color:      c.textPrimary,
                        )),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
        if (!isLast)
          Divider(height: 1, indent: 16, endIndent: 16,
              color: context.colors.border, thickness: 1),
      ],
    );
  }
}

// ── Image gallery ─────────────────────────────────────────────────────────────

class _ReportGallery extends StatefulWidget {
  final List<String> urls;
  const _ReportGallery({required this.urls});

  @override
  State<_ReportGallery> createState() => _ReportGalleryState();
}

class _ReportGalleryState extends State<_ReportGallery> {
  int _current = 0;
  final _ctrl  = PageController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 220,
            child: PageView.builder(
              controller: _ctrl,
              itemCount:  widget.urls.length,
              onPageChanged: (i) => setState(() => _current = i),
              itemBuilder: (_, i) {
                final url = widget.urls[i];
                // Always try loading as image first; only fall back to doc tile if load fails.
                return GestureDetector(
                  onTap: () => _showFullScreen(context, i),
                  child: Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                      child: _docPageTile(extFromUrl(url), c),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (widget.urls.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.urls.length, (i) {
              final active = i == _current;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin:   const EdgeInsets.symmetric(horizontal: 3),
                width:    active ? 18 : 6,
                height:   6,
                decoration: BoxDecoration(
                  color: active ? c.cyan : c.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
          const SizedBox(height: 4),
          Text(
            '${_current + 1} / ${widget.urls.length}',
            style: GoogleFonts.poppins(
                fontSize: 11, color: c.textMuted),
          ),
        ],
      ],
    );
  }

  Widget _docPageTile(String ext, ThemeColors c) {
    return Container(
      color: c.card,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.insert_drive_file_rounded, color: Colors.orange, size: 64),
          const SizedBox(height: 12),
          Text(ext.toUpperCase(),
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.orange)),
          const SizedBox(height: 8),
          Text('Tap to open', style: GoogleFonts.poppins(fontSize: 12, color: c.textMuted)),
        ],
      ),
    );
  }

  void _showFullScreen(BuildContext context, int initialIndex) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _FullScreenGallery(
        urls:         widget.urls,
        initialIndex: initialIndex,
      ),
    ));
  }
}

class _FullScreenGallery extends StatefulWidget {
  final List<String> urls;
  final int          initialIndex;
  const _FullScreenGallery(
      {required this.urls, required this.initialIndex});

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: widget.urls.length > 1
            ? Text(
                '${_current + 1} / ${widget.urls.length}',
                style: GoogleFonts.poppins(
                    fontSize: 14, color: Colors.white70),
              )
            : null,
      ),
      body: PageView.builder(
        controller: PageController(initialPage: widget.initialIndex),
        itemCount:  widget.urls.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (_, i) {
          final url = widget.urls[i];
          return Center(
            child: InteractiveViewer(
              child: Image.network(
                url,
                errorBuilder: (_, _, _) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.insert_drive_file_rounded, color: Colors.orange, size: 80),
                      const SizedBox(height: 16),
                      Text(
                        extFromUrl(url).isEmpty ? 'FILE' : extFromUrl(url).toUpperCase(),
                        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.orange),
                      ),
                      const SizedBox(height: 8),
                      Text('Tap to open in browser',
                          style: GoogleFonts.poppins(fontSize: 13, color: Colors.white70)),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Action buttons ────────────────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _ActionRow({this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        if (onEdit != null)
          Expanded(
            child: _ActionBtn(
              label: 'Edit',
              icon:  Icons.edit_rounded,
              color: c.cyan,
              onTap: onEdit!,
            ),
          ),
        if (onEdit != null && onDelete != null) const SizedBox(width: 10),
        if (onDelete != null)
          _ActionBtn(
            label:  'Delete',
            icon:   Icons.delete_rounded,
            color:  c.red,
            onTap:  onDelete!,
            square: true,
          ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String       label;
  final IconData     icon;
  final Color        color;
  final VoidCallback onTap;
  final bool         square;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.square = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height:  50,
        width:   square ? 50 : null,
        padding: square
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color:        color.withAlpha(15),
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(color: color.withAlpha(60)),
        ),
        child: square
            ? Center(child: Icon(icon, color: color, size: 20))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 16),
                  const SizedBox(width: 6),
                  Text(label,
                      style: GoogleFonts.poppins(
                        fontSize:   13,
                        fontWeight: FontWeight.w600,
                        color:      color,
                      )),
                ],
              ),
      ),
    );
  }
}

class _SmallIconBtn extends StatelessWidget {
  final IconData icon;

  const _SmallIconBtn({required this.icon});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color:        c.surface,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: c.border, width: 1),
      ),
      child: Icon(icon, color: c.textSec, size: 20),
    );
  }
}
