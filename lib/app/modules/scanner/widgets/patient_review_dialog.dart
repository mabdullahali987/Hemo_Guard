import 'package:flutter/material.dart';
import 'package:hemo_guard/app/modules/home/widgets/user_glass.dart';

/// Patient data is still reviewed before saving; all original fields,
/// validators, and returned keys are preserved.
class PatientReviewDialog extends StatefulWidget {
  const PatientReviewDialog({super.key, required this.initial});
  final Map<String, String> initial;
  @override
  State<PatientReviewDialog> createState() => _PatientReviewDialogState();
}

class _PatientReviewDialogState extends State<PatientReviewDialog> {
  late final Map<String, TextEditingController> fields;
  late String sex;
  final form = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    fields = {
      for (final key in ['name', 'age_at_test', 'public_id',
        'lab_patient_number', 'source_report_number', 'sample_date'])
        key: TextEditingController(text: widget.initial[key] ?? '')
    };
    sex = widget.initial['sex'] ?? 'unknown';
  }

  @override
  void dispose() {
    for (final controller in fields.values) { controller.dispose(); }
    super.dispose();
  }

  Widget entry(String key, String label, {bool required = false, TextInputType? keyboard}) {
    final missing = (widget.initial[key] ?? '').trim().isEmpty;
    return Padding(padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: fields[key], keyboardType: keyboard,
        style: TextStyle(color: UserGlassColors.ink, fontWeight: FontWeight.w600),
        cursorColor: UserGlassColors.violet,
        validator: (value) {
          final text = (value ?? '').trim();
          if (required && text.length < 2) return 'Please enter the patient name';
          if (key == 'age_at_test' && text.isNotEmpty &&
              (int.tryParse(text) == null || int.parse(text) < 0 || int.parse(text) > 125)) {
            return 'Age must be 0–125';
          }
          if (key == 'sample_date' && text.isNotEmpty &&
              !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) return 'Use YYYY-MM-DD';
          return null;
        },
        decoration: InputDecoration(
          filled: true,
          fillColor: UserGlassColors.dark
            ? const Color(0xFF211A25) : const Color(0xFFFFFAFF),
          labelStyle: TextStyle(color: UserGlassColors.muted),
          floatingLabelStyle: const TextStyle(color: UserGlassColors.violet),
          errorStyle: TextStyle(color: UserGlassColors.dark
            ? const Color(0xFFFFAEBE) : const Color(0xFFB3264D)),
          labelText: label,
          helperText: missing ? 'Not detected — enter manually if available' : 'Detected by OCR — editable',
          helperStyle: TextStyle(color: missing
            ? (UserGlassColors.dark ? const Color(0xFFFFD18A) : const Color(0xFF89520C))
            : (UserGlassColors.dark ? const Color(0xFFD9BEFF) : UserGlassColors.violet),
            fontSize: 11),
          prefixIcon: Icon(missing ? Icons.edit_note_rounded : Icons.verified_outlined,
            color: missing
              ? (UserGlassColors.dark ? const Color(0xFFFFD18A) : const Color(0xFF89520C))
              : UserGlassColors.violet),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.all(15),
    child: UserGlassPanel(padding: EdgeInsets.zero, radius: 25,
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 510, maxHeight: 720),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Row(children: [
              const Icon(Icons.manage_accounts_outlined, color: UserGlassColors.violet, size: 29),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Review patient details', style: TextStyle(color: UserGlassColors.ink,
                  fontWeight: FontWeight.w800, fontSize: 19)),
                Text('Correct OCR values before submitting',
                  style: TextStyle(color: UserGlassColors.muted, fontSize: 12)),
              ])),
              IconButton(onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, color: UserGlassColors.ink)),
            ])),
          Flexible(child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Form(key: form, child: Column(children: [
              entry('name', 'Patient name *', required: true),
              entry('age_at_test', 'Age at this test (years)', keyboard: TextInputType.number),
              DropdownButtonFormField<String>(
                value: sex,
                style: TextStyle(color: UserGlassColors.ink, fontWeight: FontWeight.w600),
                dropdownColor: UserGlassColors.dark
                  ? const Color(0xFF29212E) : const Color(0xFFFFF7FF),
                decoration: InputDecoration(
                  labelText: 'Sex',
                  labelStyle: TextStyle(color: UserGlassColors.muted),
                  filled: true,
                  fillColor: UserGlassColors.dark
                    ? const Color(0xFF211A25) : const Color(0xFFFFFAFF)),
                items: const [
                  DropdownMenuItem(value: 'unknown', child: Text('Not recorded')),
                  DropdownMenuItem(value: 'male', child: Text('Male')),
                  DropdownMenuItem(value: 'female', child: Text('Female')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (value) => setState(() => sex = value ?? 'unknown'),
              ),
              const SizedBox(height: 12),
              entry('public_id', 'Existing HemoGuard ID (if printed)'),
              entry('lab_patient_number', 'Laboratory patient number (if stable)'),
              entry('source_report_number', 'Source CBC report / sample number'),
              entry('sample_date', 'Sample date (YYYY-MM-DD)'),
              const SizedBox(height: 4),
              Text('CBC values remain editable on the scanner screen. No patient record is created until you confirm.',
                style: TextStyle(color: UserGlassColors.muted, fontSize: 12)),
              const SizedBox(height: 12),
            ])),
          )),
          Padding(padding: const EdgeInsets.all(16),
            child: SizedBox(width: double.infinity, child: ElevatedButton.icon(
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Confirm and check patient'),
              onPressed: () {
                if (!(form.currentState?.validate() ?? false)) return;
                Navigator.pop(context, {
                  for (final e in fields.entries) e.key: e.value.text.trim(),
                  'sex': sex,
                });
              },
            )),
          ),
        ]),
      ),
    ),
  );
}
