import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme_colors.dart';
import '../../../core/services/auth_service.dart';

class RoleSelectionScreen extends StatefulWidget {
  final VoidCallback onRoleSelected;

  const RoleSelectionScreen({super.key, required this.onRoleSelected});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  final _authService = AuthService();
  String? _selectedRole;
  bool _isLoading = false;

  Future<void> _selectRole(String role) async {
    if (_isLoading) return;
    setState(() {
      _selectedRole = role;
      _isLoading = true;
    });
    try {
      await _authService.updateRole(role);
      if (mounted) widget.onRoleSelected();
    } catch (_) {
      if (mounted) {
        setState(() {
          _selectedRole = null;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save role. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: c.bg,
        body: Container(
          decoration: BoxDecoration(gradient: c.bgGradient),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 48),

                  _LogoSection().animate().fadeIn(duration: 400.ms).scale(
                        begin: const Offset(0.9, 0.9),
                        curve: Curves.easeOut,
                      ),

                  const SizedBox(height: 36),

                  Text(
                    'Who are you?',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 100.ms),

                  const SizedBox(height: 8),

                  Text(
                    'Choose your role to personalize\nyour TreatTrace experience.',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: c.textSec,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 150.ms),

                  const SizedBox(height: 36),

                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: _RoleCard(
                            icon: Icons.personal_injury_rounded,
                            title: "I'm a Patient",
                            subtitle:
                                'Track prescriptions, test reports\n& appointments',
                            isSelected: _selectedRole == 'patient',
                            isLoading: _isLoading && _selectedRole == 'patient',
                            accentColor: c.accent,
                            onTap:
                                _isLoading ? null : () => _selectRole('patient'),
                          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: _RoleCard(
                            icon: Icons.medical_services_rounded,
                            title: "I'm a Doctor",
                            subtitle:
                                'Manage patients, appointments\n& write prescriptions',
                            isSelected: _selectedRole == 'doctor',
                            isLoading: _isLoading && _selectedRole == 'doctor',
                            accentColor: c.green,
                            onTap:
                                _isLoading ? null : () => _selectRole('doctor'),
                          ).animate().fadeIn(delay: 280.ms).slideY(begin: 0.1),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: c.accent,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: c.accent.withAlpha(50),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.local_hospital_rounded,
              color: Colors.white, size: 34),
        ),
        const SizedBox(height: 12),
        Text(
          'TreatTrace',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: c.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final bool isLoading;
  final Color accentColor;
  final VoidCallback? onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.isLoading,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.card,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        splashColor: accentColor.withAlpha(15),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? accentColor : c.border,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? accentColor.withAlpha(25)
                    : Colors.black.withAlpha(8),
                blurRadius: isSelected ? 20 : 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(isSelected ? 30 : 15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: accentColor.withAlpha(isSelected ? 60 : 30),
                    width: 1,
                  ),
                ),
                child: isLoading
                    ? Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: accentColor,
                            strokeWidth: 2.5,
                          ),
                        ),
                      )
                    : Icon(icon, color: accentColor, size: 34),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: c.textSec,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? accentColor : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? accentColor : c.border,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 16)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
