// ─────────────────────────────────────────────────────────────────────────────
// medical_header.dart
//
// The top curved header section shared by Login and Sign-up screens.
// Displays the TreatTrace logo, cross icon, and a welcoming subtitle.
// The wavy clip gives it a modern, healthcare-app feel.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';

class MedicalHeader extends StatelessWidget {
  /// The subtitle shown below the app name (e.g. "Welcome back!" or "Create Account").
  final String subtitle;

  const MedicalHeader({super.key, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      // The custom clipper creates the wavy bottom edge.
      clipper: _WaveClipper(),
      child: Container(
        height: 240,
        decoration: const BoxDecoration(gradient: AppColors.headerGradient),
        child: Stack(
          children: [
            // ── Decorative background circles ──────────────────────────────
            Positioned(
              top: -30,
              right: -40,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(15),
                ),
              ),
            ),
            Positioned(
              top: 20,
              left: -60,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(10),
                ),
              ),
            ),

            // ── Content ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 56, 28, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App logo row: medical cross + name
                  Row(
                    children: [
                      // App logo
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'Logo/treattrace_icon_1024.png',
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // App name
                      Text(
                        'TreatTrace',
                        style: GoogleFonts.poppins(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  )
                      .animate()
                      .fadeIn(duration: 600.ms)
                      .slideX(begin: -0.2, end: 0),

                  const SizedBox(height: 14),

                  // Subtitle text (changes per screen)
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withAlpha(220),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 200.ms, duration: 500.ms)
                      .slideY(begin: 0.2, end: 0),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _WaveClipper
// Creates the characteristic wave cut at the bottom of the header.
// ─────────────────────────────────────────────────────────────────────────────
class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 40); // Start at bottom-left

    // First wave curve
    path.quadraticBezierTo(
      size.width * 0.25, size.height,       // control point
      size.width * 0.5, size.height - 20,   // end point
    );

    // Second wave curve
    path.quadraticBezierTo(
      size.width * 0.75, size.height - 40,  // control point
      size.width, size.height,               // end point
    );

    path.lineTo(size.width, 0); // Top-right corner
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
