import 'package:flutter/material.dart';
import 'package:hemo_guard/app/modules/home/widgets/user_glass.dart';
import '../controllers/scanner_controller.dart';

/// Same server-backed operator attestation, now in the shared user glass UI.
class ConsentGate extends StatefulWidget {
  const ConsentGate({super.key, required this.controller});
  final ScannerController controller;
  @override
  State<ConsentGate> createState() => _ConsentGateState();
}

class _ConsentGateState extends State<ConsentGate> {
  bool agreed = false;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 510),
        child: UserGlassPanel(padding: const EdgeInsets.all(24), radius: 27,
          child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 54, height: 54,
              decoration: BoxDecoration(gradient: UserGlassColors.gradient,
                borderRadius: BorderRadius.circular(17)),
              child: const Icon(Icons.shield_outlined, size: 29, color: Colors.white)),
            const SizedBox(height: 15),
            Text('Patient consent', style: TextStyle(color: UserGlassColors.ink,
              fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 7),
            Text('Confirm permission before scanning a CBC report or entering patient medical data.',
              style: TextStyle(color: UserGlassColors.muted, fontSize: 12.5)),
            const SizedBox(height: 17),
            if (widget.controller.consentLoading.value)
              const LinearProgressIndicator(color: UserGlassColors.violet),
            if (!widget.controller.consentLoading.value &&
                widget.controller.consentVersion.value.isEmpty)
              TextButton.icon(onPressed: widget.controller.retryConsent,
                icon: const Icon(Icons.refresh), label: const Text('Retry loading consent')),
            Text(widget.controller.consentText.value.isEmpty
              ? 'Loading consent information…' : widget.controller.consentText.value,
              style: TextStyle(height: 1.5, fontSize: 13, color: UserGlassColors.ink)),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: agreed,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: UserGlassColors.violet,
              title: const Text('I confirm that the patient or authorized representative has agreed.',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Text('Operator attestation only — not a patient signature.',
                style: TextStyle(color: UserGlassColors.muted, fontSize: 11)),
              onChanged: (value) => setState(() => agreed = value ?? false),
            ),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              onPressed: agreed && !widget.controller.consentLoading.value &&
                    widget.controller.consentVersion.value.isNotEmpty
                  ? widget.controller.confirmConsent : null,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Agree & continue')),
            ),
          ])),
      ),
    ),
  );
}
