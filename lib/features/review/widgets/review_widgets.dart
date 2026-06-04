// review_widgets.dart — Shared review UI: star display, compact rating badge,
// an embeddable "Ratings & Reviews" section and the write/edit review sheet.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme_colors.dart';
import '../models/doctor_review.dart';
import '../services/review_service.dart';

// ── Star row (read-only display) ──────────────────────────────────────────────
class StarRow extends StatelessWidget {
  final double rating;
  final double size;
  final Color? color;
  const StarRow({super.key, required this.rating, this.size = 16, this.color});

  @override
  Widget build(BuildContext context) {
    final c   = color ?? context.colors.amber;
    final full = rating.floor();
    final half = (rating - full) >= 0.5;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        IconData icon;
        if (i < full) {
          icon = Icons.star_rounded;
        } else if (i == full && half) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_outline_rounded;
        }
        return Icon(icon, size: size, color: c);
      }),
    );
  }
}

// ── Compact badge for cards: ⭐ 4.5 (2) ───────────────────────────────────────
class RatingBadge extends StatelessWidget {
  final double avg;
  final int    count;
  const RatingBadge({super.key, required this.avg, required this.count});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (count == 0) {
      return Text('No reviews',
          style: GoogleFonts.poppins(fontSize: 11, color: c.textMuted));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, size: 14, color: c.amber),
        const SizedBox(width: 3),
        Text(
          avg.toStringAsFixed(1),
          style: GoogleFonts.poppins(
              fontSize: 12, fontWeight: FontWeight.w700, color: c.textPrimary),
        ),
        const SizedBox(width: 3),
        Text('($count)',
            style: GoogleFonts.poppins(fontSize: 11, color: c.textMuted)),
      ],
    );
  }
}

String _relativeDate(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inDays >= 30) {
    return '${d.day}/${d.month}/${d.year}';
  } else if (diff.inDays >= 1) {
    return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  } else if (diff.inHours >= 1) {
    return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
  } else if (diff.inMinutes >= 1) {
    return '${diff.inMinutes} min ago';
  }
  return 'Just now';
}

// ── Embeddable section for the doctor public profile ──────────────────────────
class DoctorReviewsSection extends StatefulWidget {
  final String doctorId;
  final double initialAvg;
  final int    initialCount;
  // Called after a review change so the parent can refresh aggregate display.
  final VoidCallback? onChanged;

  const DoctorReviewsSection({
    super.key,
    required this.doctorId,
    this.initialAvg = 0,
    this.initialCount = 0,
    this.onChanged,
  });

  @override
  State<DoctorReviewsSection> createState() => _DoctorReviewsSectionState();
}

class _DoctorReviewsSectionState extends State<DoctorReviewsSection> {
  final _svc = ReviewService();

  List<DoctorReview> _reviews = [];
  bool   _loading = true;
  bool   _canReview = false;
  ({int rating, String? comment})? _mine;
  late double _avg   = widget.initialAvg;
  late int    _count = widget.initialCount;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _svc.fetchForDoctor(widget.doctorId),
        _svc.canReview(widget.doctorId),
        _svc.myReview(widget.doctorId),
        _svc.rating(widget.doctorId),
      ]);
      if (!mounted) return;
      setState(() {
        _reviews   = results[0] as List<DoctorReview>;
        _canReview = results[1] as bool;
        _mine      = results[2] as ({int rating, String? comment})?;
        final r    = results[3] as ({double avg, int count});
        _avg       = r.avg;
        _count     = r.count;
        _loading   = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openSheet() async {
    final changed = await showWriteReviewSheet(
      context,
      doctorId: widget.doctorId,
      existingRating: _mine?.rating,
      existingComment: _mine?.comment,
      canDelete: _mine != null,
    );
    if (changed == true) {
      await _load();
      widget.onChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c.amber.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.star_rounded, size: 18, color: c.amber),
              ),
              const SizedBox(width: 12),
              Text('Ratings & Reviews',
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary)),
            ],
          ),
          const SizedBox(height: 14),

          // Average summary
          Row(
            children: [
              Text(
                _count == 0 ? '—' : _avg.toStringAsFixed(1),
                style: GoogleFonts.poppins(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StarRow(rating: _avg, size: 18),
                  const SizedBox(height: 2),
                  Text(
                    _count == 0
                        ? 'No reviews yet'
                        : '$_count review${_count == 1 ? '' : 's'}',
                    style:
                        GoogleFonts.poppins(fontSize: 12, color: c.textSec),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Write / edit / eligibility
          if (_mine != null)
            _reviewBtn(c, 'Edit your review', Icons.edit_rounded, _openSheet)
          else if (_canReview)
            _reviewBtn(c, 'Write a review', Icons.rate_review_rounded, _openSheet)
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.border),
              ),
              child: Text(
                'You can write a review after a completed appointment.',
                style: GoogleFonts.poppins(fontSize: 12, color: c.textMuted),
              ),
            ),

          if (_loading) ...[
            const SizedBox(height: 16),
            Center(
                child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: c.amber))),
          ] else if (_reviews.isNotEmpty) ...[
            const SizedBox(height: 16),
            Divider(height: 1, color: c.border),
            const SizedBox(height: 8),
            ..._reviews.map((r) => _ReviewTile(review: r)),
          ],
        ],
      ),
    );
  }

  Widget _reviewBtn(
      ThemeColors c, String label, IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: c.amber),
        label: Text(label,
            style: GoogleFonts.poppins(
                fontSize: 13, fontWeight: FontWeight.w600, color: c.amber)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: c.amber.withAlpha(110)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final DoctorReview review;
  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StarRow(rating: review.rating.toDouble(), size: 15),
              const Spacer(),
              Text(_relativeDate(review.createdAt),
                  style:
                      GoogleFonts.poppins(fontSize: 11, color: c.textMuted)),
            ],
          ),
          if ((review.comment ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(review.comment!,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: c.textPrimary, height: 1.5)),
          ],
          const SizedBox(height: 4),
          Text('— Anonymous patient',
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: c.textMuted)),
        ],
      ),
    );
  }
}

// ── Post-appointment "Rate your visit" sheet (Submit / Skip) ──────────────────
// Returns true if a review was submitted, false if skipped. Not dismissible by
// barrier/drag so the patient makes a deliberate choice.
Future<bool?> showAppointmentReviewSheet(
  BuildContext context, {
  required String doctorId,
  required String doctorName,
  int? existingRating,
  String? existingComment,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => _AppointmentReviewSheet(
      doctorId: doctorId,
      doctorName: doctorName,
      existingRating: existingRating,
      existingComment: existingComment,
    ),
  );
}

class _AppointmentReviewSheet extends StatefulWidget {
  final String doctorId;
  final String doctorName;
  final int? existingRating;
  final String? existingComment;

  const _AppointmentReviewSheet({
    required this.doctorId,
    required this.doctorName,
    this.existingRating,
    this.existingComment,
  });

  @override
  State<_AppointmentReviewSheet> createState() =>
      _AppointmentReviewSheetState();
}

class _AppointmentReviewSheetState extends State<_AppointmentReviewSheet> {
  final _svc = ReviewService();
  late int _rating = widget.existingRating ?? 0;
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.existingComment ?? '');
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a star rating.')));
      return;
    }
    setState(() => _busy = true);
    try {
      await _svc.upsertReview(widget.doctorId, _rating, _ctrl.text);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ReviewNotAllowedException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: c.amber.withAlpha(20),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(Icons.star_rounded, color: c.amber, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Rate your visit',
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: c.textPrimary)),
                      Text('How was your appointment with Dr. ${widget.doctorName}?',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: c.textSec)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  final filled = i < _rating;
                  return GestureDetector(
                    onTap: () => setState(() => _rating = i + 1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        filled
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 40,
                        color: c.amber,
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _ctrl,
              maxLines: 3,
              maxLength: 500,
              style: GoogleFonts.poppins(fontSize: 13, color: c.textPrimary),
              decoration: InputDecoration(
                hintText: 'Write a short comment (optional)…',
                hintStyle:
                    GoogleFonts.poppins(fontSize: 13, color: c.textMuted),
                filled: true,
                fillColor: c.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.amber),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _busy ? null : () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      side: BorderSide(color: c.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text('Skip',
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: c.textSec)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _busy ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: c.amber,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(
                            widget.existingRating != null ? 'Update' : 'Submit',
                            style: GoogleFonts.poppins(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Write / edit review bottom sheet ──────────────────────────────────────────
Future<bool?> showWriteReviewSheet(
  BuildContext context, {
  required String doctorId,
  int? existingRating,
  String? existingComment,
  bool canDelete = false,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _WriteReviewSheet(
      doctorId: doctorId,
      existingRating: existingRating,
      existingComment: existingComment,
      canDelete: canDelete,
    ),
  );
}

class _WriteReviewSheet extends StatefulWidget {
  final String doctorId;
  final int? existingRating;
  final String? existingComment;
  final bool canDelete;

  const _WriteReviewSheet({
    required this.doctorId,
    this.existingRating,
    this.existingComment,
    required this.canDelete,
  });

  @override
  State<_WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends State<_WriteReviewSheet> {
  final _svc  = ReviewService();
  late int _rating = widget.existingRating ?? 0;
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.existingComment ?? '');
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a star rating.')));
      return;
    }
    setState(() => _busy = true);
    try {
      await _svc.upsertReview(widget.doctorId, _rating, _ctrl.text);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ReviewNotAllowedException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _delete() async {
    setState(() => _busy = true);
    try {
      await _svc.deleteReview(widget.doctorId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              widget.existingRating != null ? 'Edit your review' : 'Write a review',
              style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary),
            ),
            const SizedBox(height: 4),
            Text('Your review is anonymous to the doctor.',
                style: GoogleFonts.poppins(fontSize: 12, color: c.textMuted)),
            const SizedBox(height: 18),

            // Star selector
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  final filled = i < _rating;
                  return GestureDetector(
                    onTap: () => setState(() => _rating = i + 1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        filled ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 40,
                        color: c.amber,
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 18),

            TextField(
              controller: _ctrl,
              maxLines: 4,
              maxLength: 500,
              style: GoogleFonts.poppins(fontSize: 13, color: c.textPrimary),
              decoration: InputDecoration(
                hintText: 'Share your experience (optional)…',
                hintStyle:
                    GoogleFonts.poppins(fontSize: 13, color: c.textMuted),
                filled: true,
                fillColor: c.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.amber),
                ),
              ),
            ),
            const SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _busy ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.amber,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(
                        widget.existingRating != null
                            ? 'Update review'
                            : 'Submit review',
                        style: GoogleFonts.poppins(
                            fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
            if (widget.canDelete) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _busy ? null : _delete,
                  icon: Icon(Icons.delete_outline_rounded,
                      size: 18, color: c.red),
                  label: Text('Delete review',
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: c.red)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
