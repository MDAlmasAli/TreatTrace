// searchable_picker_field.dart — A tap-to-open searchable dropdown.
//
// The user MUST pick from the provided list (free text is not accepted as a
// value). Optionally, a "can't find it? add manually" affordance lets the user
// submit a new entry (used for hospitals — the typed name is returned with
// isManual = true so the caller can route it through admin approval).

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/theme_colors.dart';

class PickerOption {
  final String id;
  final String label;
  final String? subtitle;
  // Extra strings to match against (e.g. a Bengali name) beyond [label].
  final List<String> searchTerms;

  const PickerOption({
    required this.id,
    required this.label,
    this.subtitle,
    this.searchTerms = const [],
  });

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (label.toLowerCase().contains(q)) return true;
    return searchTerms.any((t) => t.toLowerCase().contains(q));
  }
}

class PickerResult {
  final String id;      // selected option id; '' when a manual value
  final String label;   // display text
  final bool isManual;  // true when the user typed a brand-new value

  const PickerResult({required this.id, required this.label, this.isManual = false});
}

// ── The display field (tap to open the picker) ────────────────────────────────

class SearchablePickerField extends StatelessWidget {
  final String label;
  final IconData icon;
  final String hint;
  final String? value;     // currently-selected display text (null = none)
  final String? errorText;
  final bool enabled;
  final VoidCallback onTap;

  const SearchablePickerField({
    super.key,
    required this.label,
    required this.icon,
    required this.hint,
    required this.value,
    required this.onTap,
    this.errorText,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasValue = value != null && value!.trim().isNotEmpty;
    final hasError = errorText != null && errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 12, fontWeight: FontWeight.w600, color: c.textPrimary)),
        const SizedBox(height: 6),
        InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: hasError ? c.red : c.border),
            ),
            child: Row(
              children: [
                Icon(icon, color: c.textMuted, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hasValue ? value! : hint,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: hasValue ? c.textPrimary : c.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.arrow_drop_down_rounded, color: c.textMuted, size: 24),
              ],
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Text(errorText!, style: GoogleFonts.poppins(fontSize: 12, color: c.red)),
        ],
      ],
    );
  }
}

// ── The picker bottom sheet ───────────────────────────────────────────────────

// Returns the chosen option, or — when [manualAddLabel] is provided and the
// user opts to add their typed text — a manual PickerResult. Returns null if
// dismissed.
Future<PickerResult?> showSearchablePicker({
  required BuildContext context,
  required String title,
  required String searchHint,
  required List<PickerOption> options,
  String? selectedId,
  String? manualAddLabel, // e.g. 'Add "{q}" as a new hospital' enables manual entry
}) {
  return showModalBottomSheet<PickerResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PickerSheet(
      title: title,
      searchHint: searchHint,
      options: options,
      selectedId: selectedId,
      manualAddLabel: manualAddLabel,
    ),
  );
}

class _PickerSheet extends StatefulWidget {
  final String title;
  final String searchHint;
  final List<PickerOption> options;
  final String? selectedId;
  final String? manualAddLabel;

  const _PickerSheet({
    required this.title,
    required this.searchHint,
    required this.options,
    required this.selectedId,
    required this.manualAddLabel,
  });

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final q = _query.trim();
    final filtered =
        widget.options.where((o) => o.matches(q)).toList();
    final exactExists = widget.options.any(
        (o) => o.label.toLowerCase() == q.toLowerCase());
    final showManual = widget.manualAddLabel != null && q.isNotEmpty && !exactExists;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: c.border, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: Row(
                children: [
                  Text(widget.title,
                      style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary)),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: c.textSec, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Search box
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                style: GoogleFonts.poppins(fontSize: 14, color: c.textPrimary),
                decoration: InputDecoration(
                  hintText: widget.searchHint,
                  hintStyle: GoogleFonts.poppins(fontSize: 13, color: c.textMuted),
                  prefixIcon: Icon(Icons.search_rounded, color: c.textMuted, size: 20),
                  filled: true,
                  fillColor: c.surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: c.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: c.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: c.accent, width: 1.5)),
                ),
              ),
            ),
            Divider(height: 1, color: c.border),
            Expanded(
              child: (filtered.isEmpty && !showManual)
                  ? Center(
                      child: Text('No matches',
                          style: GoogleFonts.poppins(
                              fontSize: 13, color: c.textMuted)),
                    )
                  : ListView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        ...filtered.map((o) {
                          final sel = o.id == widget.selectedId;
                          return ListTile(
                            onTap: () => Navigator.pop(
                                context,
                                PickerResult(id: o.id, label: o.label)),
                            title: Text(o.label,
                                style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight:
                                        sel ? FontWeight.w700 : FontWeight.w500,
                                    color: sel ? c.accent : c.textPrimary)),
                            subtitle: o.subtitle == null
                                ? null
                                : Text(o.subtitle!,
                                    style: GoogleFonts.poppins(
                                        fontSize: 12, color: c.textMuted)),
                            trailing: sel
                                ? Icon(Icons.check_rounded, color: c.accent, size: 20)
                                : null,
                          );
                        }),
                        if (showManual)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.pop(
                                  context,
                                  PickerResult(
                                      id: '', label: q, isManual: true)),
                              icon: Icon(Icons.add_rounded, size: 18, color: c.accent),
                              label: Text(
                                widget.manualAddLabel!.replaceAll('{q}', q),
                                style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: c.accent),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: c.accent.withAlpha(120)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
