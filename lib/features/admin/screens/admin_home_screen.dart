import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme_colors.dart';
import '../../../core/services/doctor_verification_service.dart';
import '../../../core/services/auth_service.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen>
    with SingleTickerProviderStateMixin {
  final _service     = DoctorVerificationService();
  final _authService = AuthService();
  late final TabController _tabs;

  List<Map<String, dynamic>> _all      = [];
  List<Map<String, dynamic>> _edits    = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _service.fetchAllVerifications().onError((e, s) => []),
      _service.fetchPendingEdits().onError((e, s) => []),
    ]);
    if (mounted) {
      setState(() {
        _all   = results[0];
        _edits = results[1];
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _pending  => _all.where((v) => v['status'] == 'pending').toList();
  List<Map<String, dynamic>> get _approved => _all.where((v) => v['status'] == 'approved').toList();
  List<Map<String, dynamic>> get _rejected => _all.where((v) => v['status'] == 'rejected').toList();

  Future<void> _approve(String id) async {
    await _service.approveVerification(id);
    await _load();
  }

  Future<void> _showRejectDialog(String id) async {
    final c = context.colors;
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Reject Verification',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: c.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Provide a reason for rejection:',
                style: GoogleFonts.poppins(fontSize: 13, color: c.textSec)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 3,
              style: GoogleFonts.poppins(fontSize: 13, color: c.textPrimary),
              decoration: InputDecoration(
                hintText: 'e.g. BMDC number not valid',
                hintStyle: GoogleFonts.poppins(fontSize: 12, color: c.textMuted),
                filled: true, fillColor: c.surface,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: c.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: c.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: c.red, width: 1.5)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: c.textSec)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: c.red, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: Text('Reject', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed == true && ctrl.text.trim().isNotEmpty) {
      await _service.rejectVerification(id, ctrl.text.trim());
      await _load();
    }
    ctrl.dispose();
  }

  Future<void> _showRejectEditDialog(String id) async {
    final c = context.colors;
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Reject Edit',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: c.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Provide a reason for rejection:',
                style: GoogleFonts.poppins(fontSize: 13, color: c.textSec)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 3,
              style: GoogleFonts.poppins(fontSize: 13, color: c.textPrimary),
              decoration: InputDecoration(
                hintText: 'e.g. BMDC number mismatch',
                hintStyle: GoogleFonts.poppins(fontSize: 12, color: c.textMuted),
                filled: true, fillColor: c.surface,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: c.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: c.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: c.red, width: 1.5)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: c.textSec)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: c.red, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: Text('Reject', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed == true && ctrl.text.trim().isNotEmpty) {
      await _service.rejectEdit(id, ctrl.text.trim());
      await _load();
    }
    ctrl.dispose();
  }

  Future<void> _approveEdit(String id) async {
    await _service.approveEdit(id);
    await _load();
  }

  Future<void> _signOut() async {
    await _authService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.card,
        elevation: 0,
        title: Text('Admin Panel',
            style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: c.textSec),
            onPressed: _load,
          ),
          IconButton(
            icon: Icon(Icons.logout_rounded, color: c.textSec),
            onPressed: _signOut,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: c.accent,
          unselectedLabelColor: c.textSec,
          indicatorColor: c.accent,
          labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13),
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: 'Pending (${_pending.length})'),
            Tab(text: 'Approved (${_approved.length})'),
            Tab(text: 'Rejected (${_rejected.length})'),
            Tab(text: 'Edits (${_edits.length})'),
          ],
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: c.accent, strokeWidth: 2.5))
          : TabBarView(
              controller: _tabs,
              children: [
                _VerificationList(
                  items: _pending,
                  onApprove: _approve,
                  onReject: _showRejectDialog,
                  emptyMessage: 'No pending verifications',
                ),
                _VerificationList(
                  items: _approved,
                  emptyMessage: 'No approved doctors yet',
                ),
                _VerificationList(
                  items: _rejected,
                  emptyMessage: 'No rejected verifications',
                ),
                _EditsList(
                  items: _edits,
                  onApprove: _approveEdit,
                  onReject: _showRejectEditDialog,
                ),
              ],
            ),
    );
  }
}

class _VerificationList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final Future<void> Function(String)? onApprove;
  final Future<void> Function(String)? onReject;
  final String emptyMessage;

  const _VerificationList({
    required this.items,
    this.onApprove,
    this.onReject,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (items.isEmpty) {
      return Center(
        child: Text(emptyMessage,
            style: GoogleFonts.poppins(fontSize: 14, color: c.textMuted)),
      );
    }
    return RefreshIndicator(
      color: c.accent,
      onRefresh: () async {},
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _VerificationCard(
          data: items[i],
          onApprove: onApprove,
          onReject: onReject,
        ),
      ),
    );
  }
}

class _VerificationCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final Future<void> Function(String)? onApprove;
  final Future<void> Function(String)? onReject;

  const _VerificationCard({required this.data, this.onApprove, this.onReject});

  @override
  State<_VerificationCard> createState() => _VerificationCardState();
}

class _VerificationCardState extends State<_VerificationCard> {
  bool _acting = false;

  @override
  Widget build(BuildContext context) {
    final c    = context.colors;
    final d    = widget.data;
    final prof = d['profiles'] as Map<String, dynamic>? ?? {};
    final id   = d['id'] as String;
    final status = d['status'] as String;

    Color statusColor = switch (status) {
      'approved' => c.green,
      'rejected' => c.red,
      _          => c.amber,
    };

    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name + status badge
          Row(
            children: [
              Expanded(
                child: Text(
                  prof['full_name'] as String? ?? 'Unknown Doctor',
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w700, color: c.textPrimary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withAlpha(60)),
                ),
                child: Text(status.toUpperCase(),
                    style: GoogleFonts.poppins(
                        fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(prof['email'] as String? ?? '',
              style: GoogleFonts.poppins(fontSize: 12, color: c.textSec)),

          const SizedBox(height: 14),
          _InfoRow(icon: Icons.badge_rounded,           label: 'BMDC No.',  value: d['bmdc_number'] ?? '-'),
          _InfoRow(icon: Icons.medical_services_rounded, label: 'Specialty', value: d['specialty'] ?? '-'),
          _InfoRow(icon: Icons.local_hospital_rounded,  label: 'Hospital',  value: d['hospital'] ?? '-'),
          _InfoRow(icon: Icons.perm_identity_rounded,   label: 'NID/Pass.', value: d['nid_passport'] ?? '-'),
          if ((d['degree'] as String?)?.isNotEmpty == true)
            _InfoRow(icon: Icons.school_rounded, label: 'Degree', value: d['degree']!),
          if (d['visiting_fee'] != null)
            _InfoRow(icon: Icons.payments_rounded, label: 'Visiting Fee', value: 'BDT ${d['visiting_fee']}'),
          if ((d['about'] as String?)?.isNotEmpty == true)
            _InfoRow(icon: Icons.person_outline_rounded, label: 'About', value: d['about']!),
          if ((d['additional_info'] as String?)?.isNotEmpty == true)
            _InfoRow(icon: Icons.notes_rounded, label: 'Other', value: d['additional_info']!),

          if (status == 'rejected' && (d['rejection_reason'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: c.red.withAlpha(12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: c.red.withAlpha(40)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: c.red, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Reason: ${d['rejection_reason']}',
                        style: GoogleFonts.poppins(fontSize: 12, color: c.red, height: 1.4)),
                  ),
                ],
              ),
            ),
          ],

          if (status == 'pending') ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _acting ? null : () async {
                      setState(() => _acting = true);
                      await widget.onReject?.call(id);
                      if (mounted) setState(() => _acting = false);
                    },
                    icon: Icon(Icons.cancel_rounded, size: 16, color: c.red),
                    label: Text('Reject',
                        style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w600, color: c.red)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: c.red.withAlpha(80)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _acting ? null : () async {
                      setState(() => _acting = true);
                      await widget.onApprove?.call(id);
                      if (mounted) setState(() => _acting = false);
                    },
                    icon: _acting
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check_circle_rounded, size: 16),
                    label: Text(_acting ? 'Processing...' : 'Approve',
                        style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.green,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: c.textMuted),
          const SizedBox(width: 6),
          Text('$label: ',
              style: GoogleFonts.poppins(fontSize: 12, color: c.textMuted)),
          Expanded(
            child: Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.w600, color: c.textPrimary)),
          ),
        ],
      ),
    );
  }
}

// ── Pending-edits tab ─────────────────────────────────────────────────────────

class _EditsList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final Future<void> Function(String) onApprove;
  final Future<void> Function(String) onReject;

  const _EditsList({
    required this.items,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (items.isEmpty) {
      return Center(
        child: Text('No pending edits',
            style: GoogleFonts.poppins(fontSize: 14, color: c.textMuted)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _EditCard(
        data: items[i],
        onApprove: onApprove,
        onReject: onReject,
      ),
    );
  }
}

class _EditCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final Future<void> Function(String) onApprove;
  final Future<void> Function(String) onReject;

  const _EditCard({required this.data, required this.onApprove, required this.onReject});

  @override
  State<_EditCard> createState() => _EditCardState();
}

class _EditCardState extends State<_EditCard> {
  bool _acting = false;

  @override
  Widget build(BuildContext context) {
    final c    = context.colors;
    final d    = widget.data;
    final prof = d['profiles'] as Map<String, dynamic>? ?? {};
    final id   = d['id'] as String;

    String? feeStr(dynamic v) => v == null ? null : 'BDT $v';
    // pairs of (label, icon, approved value, pending value)
    final fields = [
      ('BMDC No.',     Icons.badge_rounded,             d['bmdc_number'],                  d['pending_bmdc']),
      ('Specialty',    Icons.medical_services_rounded,  d['specialty'],                    d['pending_specialty']),
      ('Hospital',     Icons.local_hospital_rounded,    d['hospital'],                     d['pending_hospital']),
      ('NID/Pass.',    Icons.perm_identity_rounded,     d['nid_passport'],                 d['pending_nid_passport']),
      ('Degree',       Icons.school_rounded,            d['degree'],                       d['pending_degree']),
      ('Visiting Fee', Icons.payments_rounded,          feeStr(d['visiting_fee']),         feeStr(d['pending_visiting_fee'])),
      ('About',        Icons.person_outline_rounded,    d['about'],                        d['pending_about']),
      ('Other',        Icons.notes_rounded,             d['additional_info'],              d['pending_additional']),
    ];

    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // header
          Row(
            children: [
              Expanded(
                child: Text(
                  prof['full_name'] as String? ?? 'Unknown Doctor',
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w700, color: c.textPrimary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: c.amber.withAlpha(20),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: c.amber.withAlpha(60)),
                ),
                child: Text('EDIT PENDING',
                    style: GoogleFonts.poppins(
                        fontSize: 10, fontWeight: FontWeight.w700, color: c.amber)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(prof['email'] as String? ?? '',
              style: GoogleFonts.poppins(fontSize: 12, color: c.textSec)),
          const SizedBox(height: 14),

          // field-by-field diff
          for (final (label, icon, approved, pending) in fields)
            if (approved != null || pending != null)
              _EditFieldRow(
                icon: icon,
                label: label,
                approvedValue: approved as String? ?? '-',
                pendingValue: pending as String?,
              ),

          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _acting ? null : () async {
                    setState(() => _acting = true);
                    await widget.onReject(id);
                    if (mounted) setState(() => _acting = false);
                  },
                  icon: Icon(Icons.cancel_rounded, size: 16, color: c.red),
                  label: Text('Reject',
                      style: GoogleFonts.poppins(
                          fontSize: 13, fontWeight: FontWeight.w600, color: c.red)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: c.red.withAlpha(80)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _acting ? null : () async {
                    setState(() => _acting = true);
                    await widget.onApprove(id);
                    if (mounted) setState(() => _acting = false);
                  },
                  icon: _acting
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check_circle_rounded, size: 16),
                  label: Text(_acting ? 'Processing...' : 'Approve',
                      style: GoogleFonts.poppins(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditFieldRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String approvedValue;
  final String? pendingValue;

  const _EditFieldRow({
    required this.icon,
    required this.label,
    required this.approvedValue,
    this.pendingValue,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final changed = pendingValue != null && pendingValue != approvedValue;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: c.textMuted),
          const SizedBox(width: 6),
          SizedBox(
            width: 68,
            child: Text('$label: ',
                style: GoogleFonts.poppins(fontSize: 12, color: c.textMuted)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  approvedValue,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: changed ? c.textSec : c.textPrimary,
                    decoration: changed ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (changed) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.arrow_forward_rounded, size: 11, color: c.amber),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          pendingValue!,
                          style: GoogleFonts.poppins(
                              fontSize: 12, fontWeight: FontWeight.w700, color: c.amber),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
