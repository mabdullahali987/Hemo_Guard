import 'package:flutter/material.dart';
import 'package:hemo_guard/app/modules/home/widgets/user_glass.dart';

/// Returns existing patient UUID, 'new', or 'rescan'. No automated name merge.
class PatientMatchDialog extends StatelessWidget {
  const PatientMatchDialog({super.key, required this.matches, required this.verified});
  final List<Map<String, dynamic>> matches;
  final bool verified;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.all(15),
    child: UserGlassPanel(radius: 24, padding: const EdgeInsets.all(19),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 470),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(verified ? Icons.person_pin_circle_outlined : Icons.manage_search_rounded,
              color: UserGlassColors.violet, size: 29),
            const SizedBox(width: 9),
            Expanded(child: Text(verified ? 'Returning patient detected' : 'Possible existing patient',
              style: TextStyle(color: UserGlassColors.ink, fontWeight: FontWeight.w800, fontSize: 18))),
          ]),
          const SizedBox(height: 10),
          Text(verified
            ? 'A patient record already exists. Select it to append this screening; previous reports stay unchanged.'
            : 'Similar patient details were found. Confirm carefully — name alone is not reliable proof of identity.',
            style: TextStyle(fontSize: 12, color: UserGlassColors.muted)),
          const SizedBox(height: 15),
          for (final patient in matches) ...[
            Card(child: ListTile(
              leading: const Icon(Icons.person_outline, color: UserGlassColors.violet),
              title: Text(patient['name']?.toString() ?? ''),
              subtitle: Text('${patient['public_id']} • age ${patient['age_at_registration'] ?? 'unknown'} • ${patient['sex'] ?? 'unknown'}'),
              trailing: Text('Add test →', style: TextStyle(
                color: UserGlassColors.dark ? const Color(0xFFD9BEFF) : UserGlassColors.violet,
                fontWeight: FontWeight.w700, fontSize: 11)),
              onTap: () => Navigator.pop(context, patient['id'].toString()),
            )),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('This is a new patient'),
            onPressed: () => Navigator.pop(context, 'new'))),
          const SizedBox(height: 4),
          SizedBox(width: double.infinity, child: TextButton(
            onPressed: () => Navigator.pop(context, 'rescan'),
            child: const Text('Scan again'))),
        ]))),
    ),
  );
}
