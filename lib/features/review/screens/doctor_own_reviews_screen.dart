// doctor_own_reviews_screen.dart — A doctor's read-only view of the anonymous
// reviews patients left for them.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme_colors.dart';
import '../models/doctor_review_model.dart';
import '../services/review_service.dart';
import '../widgets/review_widgets.dart';

class DoctorOwnReviewsScreen extends StatefulWidget {
  final String doctorId;
  const DoctorOwnReviewsScreen({super.key, required this.doctorId});

  @override
  State<DoctorOwnReviewsScreen> createState() => _DoctorOwnReviewsScreenState();
}

class _DoctorOwnReviewsScreenState extends State<DoctorOwnReviewsScreen> {
  final _svc = ReviewService();
  List<DoctorReview> _reviews = [];
  double _avg = 0;
  int _count = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _svc.fetchForDoctor(widget.doctorId),
        _svc.rating(widget.doctorId),
      ]);
      if (!mounted) return;
      setState(() {
        _reviews = results[0] as List<DoctorReview>;
        final r  = results[1] as ({double avg, int count});
        _avg     = r.avg;
        _count   = r.count;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _relative(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inDays >= 30) return '${d.day}/${d.month}/${d.year}';
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.card,
        elevation: 0,
        title: Text('My Reviews',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700, color: c.textPrimary)),
        iconTheme: IconThemeData(color: c.textSec),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: c.amber))
          : RefreshIndicator(
              color: c.amber,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
                children: [
                  // Summary
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: c.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: c.border),
                    ),
                    child: Row(
                      children: [
                        Text(
                          _count == 0 ? '—' : _avg.toStringAsFixed(1),
                          style: GoogleFonts.poppins(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: c.textPrimary),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            StarRow(rating: _avg, size: 20),
                            const SizedBox(height: 4),
                            Text(
                              _count == 0
                                  ? 'No reviews yet'
                                  : 'Based on $_count review${_count == 1 ? '' : 's'}',
                              style: GoogleFonts.poppins(
                                  fontSize: 12, color: c.textSec),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (_reviews.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.reviews_outlined,
                                size: 56, color: c.textMuted),
                            const SizedBox(height: 12),
                            Text('No reviews yet',
                                style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: c.textSec)),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._reviews.map((r) => Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: c.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: c.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  StarRow(rating: r.rating.toDouble(), size: 15),
                                  const Spacer(),
                                  Text(_relative(r.createdAt),
                                      style: GoogleFonts.poppins(
                                          fontSize: 11, color: c.textMuted)),
                                ],
                              ),
                              if ((r.comment ?? '').isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(r.comment!,
                                    style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: c.textPrimary,
                                        height: 1.5)),
                              ],
                              const SizedBox(height: 6),
                              Text('— Anonymous patient',
                                  style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                      color: c.textMuted)),
                            ],
                          ),
                        )),
                ],
              ),
            ),
    );
  }
}
