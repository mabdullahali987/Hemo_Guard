import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hemo_guard/app/data/hemoguard_pdf_generator.dart';
import 'package:hemo_guard/app/modules/home/widgets/user_glass.dart';
import 'package:hemo_guard/app/services/auth_service.dart';

/// Same account-isolated patient API, with a user-scoped liquid-glass UI.
class PatientsView extends StatefulWidget {
  const PatientsView({super.key});
  @override
  State<PatientsView> createState() => _PatientsViewState();
}

class _PatientsViewState extends State<PatientsView> {
  final search = TextEditingController();
  late Future<Map<String, dynamic>> result;

  @override
  void initState() { super.initState(); _refresh(); }
  @override
  void dispose() { search.dispose(); super.dispose(); }

  void _refresh() {
    result = Get.find<AuthService>().api('GET',
      '/api/patients?search=${Uri.encodeQueryComponent(search.text)}');
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => UserGlassFrame(
    title: 'Patient reports', subtitle: 'HEMOGUARD  /  HISTORY',
    selectedIndex: 2, onRefresh: _refresh,
    child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(19, 8, 19, 14),
        child: UserGlassPanel(padding: const EdgeInsets.fromLTRB(17, 17, 17, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Find a patient', style: TextStyle(color: UserGlassColors.ink,
              fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 5),
            Text('Your own saved CBC screenings, all in one place.',
              style: TextStyle(color: UserGlassColors.muted, fontSize: 11.5)),
            const SizedBox(height: 14),
            TextField(controller: search, onSubmitted: (_) => _refresh(),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded),
                hintText: 'Name or HG-P patient ID',
                suffixIcon: IconButton(tooltip: 'Search',
                  icon: const Icon(Icons.arrow_forward_rounded), onPressed: _refresh))),
          ]))),
      Expanded(child: FutureBuilder<Map<String, dynamic>>(
        future: result, builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) return _StatePanel(
              icon: Icons.wifi_off_rounded, title: 'Unable to load patients',
              message: 'Check your connection and try again.', onRetry: _refresh);
            return const Center(child: CircularProgressIndicator(color: UserGlassColors.violet));
          }
          final patients = (snapshot.data!['patients'] as List)
            .map((p) => Map<String, dynamic>.from(p as Map)).toList();
          if (patients.isEmpty) return const _StatePanel(
            icon: Icons.folder_open_rounded, title: 'No reports found',
            message: 'Scan a CBC report to start a patient history.');
          return RefreshIndicator(
            onRefresh: () async { _refresh(); await result; },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(19, 0, 19, 15),
              itemCount: patients.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) return Padding(padding: const EdgeInsets.only(bottom: 13, top: 1),
                  child: Text('${patients.length} patient${patients.length == 1 ? '' : 's'} found',
                    style: TextStyle(color: UserGlassColors.muted, fontWeight: FontWeight.w700, fontSize: 11)));
                final patient = patients[i - 1];
                return Padding(padding: const EdgeInsets.only(bottom: 12),
                  child: UserGlassPanel(padding: EdgeInsets.zero, radius: 22,
                    child: Material(color: Colors.transparent,
                      child: InkWell(borderRadius: BorderRadius.circular(22),
                        onTap: () => Get.to(() => PatientHistoryView(patient: patient)),
                        child: Padding(padding: const EdgeInsets.all(16),
                          child: Row(children: [
                            Container(width: 49, height: 49,
                              decoration: BoxDecoration(
                                color: UserGlassColors.violet.withOpacity(UserGlassColors.dark ? .19 : .10),
                                borderRadius: BorderRadius.circular(16)),
                              child: Icon(Icons.person_outline_rounded, color: UserGlassColors.dark
                                ? const Color(0xFFE1CBFF) : UserGlassColors.violet, size: 26)),
                            const SizedBox(width: 13),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(patient['name']?.toString() ?? 'Unknown patient',
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: UserGlassColors.ink,
                                  fontWeight: FontWeight.w800, fontSize: 15)),
                              const SizedBox(height: 3),
                              Text(patient['public_id']?.toString() ?? '',
                                style: TextStyle(color: UserGlassColors.muted, fontSize: 11)),
                              const SizedBox(height: 7),
                              Text('${patient['reports_count'] ?? 0} saved screenings',
                                style: TextStyle(color: UserGlassColors.dark
                                  ? const Color(0xFFD9BDFF) : UserGlassColors.violet,
                                  fontSize: 11.5, fontWeight: FontWeight.w700)),
                            ])),
                            Icon(Icons.chevron_right_rounded, color: UserGlassColors.muted),
                          ])),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      )),
    ]),
  );
}

class PatientHistoryView extends StatefulWidget {
  const PatientHistoryView({super.key, required this.patient});
  final Map<String, dynamic> patient;
  @override
  State<PatientHistoryView> createState() => _PatientHistoryViewState();
}

class _PatientHistoryViewState extends State<PatientHistoryView> {
  late Future<Map<String, dynamic>> history;
  @override
  void initState() { super.initState(); _load(); }
  void _load() {
    history = Get.find<AuthService>().api('GET',
      '/api/patients/${Uri.encodeComponent(widget.patient['id'].toString())}/reports');
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => UserGlassFrame(
    title: 'Patient history', subtitle: 'HEMOGUARD  /  REPORTS',
    selectedIndex: 2, onRefresh: _load, canGoBack: true,
    child: FutureBuilder<Map<String, dynamic>>(
      future: history, builder: (context, snap) {
        if (!snap.hasData) {
          if (snap.hasError) return _StatePanel(icon: Icons.wifi_off_rounded,
            title: 'Unable to load history', message: 'Check your connection and retry.', onRetry: _load);
          return const Center(child: CircularProgressIndicator(color: UserGlassColors.violet));
        }
        final reports = (snap.data!['reports'] as List)
          .map((r) => Map<String, dynamic>.from(r as Map)).toList();
        return ListView(padding: const EdgeInsets.fromLTRB(19, 10, 19, 22), children: [
          UserGlassPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 53, height: 53,
                decoration: BoxDecoration(gradient: UserGlassColors.gradient,
                  borderRadius: BorderRadius.circular(18)),
                child: const Icon(Icons.person_outline_rounded, color: Colors.white, size: 28)),
              const SizedBox(width: 13),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.patient['name']?.toString() ?? 'Unknown patient',
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: UserGlassColors.ink, fontWeight: FontWeight.w800, fontSize: 20)),
                const SizedBox(height: 3),
                Text(widget.patient['public_id']?.toString() ?? '',
                  style: TextStyle(color: UserGlassColors.muted, fontSize: 12)),
              ])),
            ]),
            const SizedBox(height: 17),
            Container(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
              decoration: BoxDecoration(color: UserGlassColors.violet.withOpacity(UserGlassColors.dark ? .17 : .08),
                borderRadius: BorderRadius.circular(15)),
              child: Row(children: [
                const Icon(Icons.history_rounded, size: 21, color: UserGlassColors.violet),
                const SizedBox(width: 9),
                Text('${reports.length} saved screening${reports.length == 1 ? '' : 's'}',
                  style: TextStyle(color: UserGlassColors.ink, fontWeight: FontWeight.w700)),
              ])),
          ])),
          const SizedBox(height: 20),
          Text('SCREENING TIMELINE', style: TextStyle(color: UserGlassColors.muted,
            fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 1.7)),
          const SizedBox(height: 12),
          if (reports.isEmpty) const _StatePanel(icon: Icons.description_outlined,
            title: 'No screenings yet', message: 'Reports will appear here after testing.'),
          for (var i = 0; i < reports.length; i++) ...[
            _ReportTile(report: reports[i], newest: i == 0,
              onTap: () => _showReport(context, reports[i])),
            const SizedBox(height: 12),
          ],
        ]);
      },
    ),
  );

  Future<void> _showReport(BuildContext context, Map<String, dynamic> report) async {
    final cbc = Map<String, dynamic>.from(report['cbc'] as Map);
    final model = Map<String, dynamic>.from(report['prediction'] as Map);
    await showModalBottomSheet<void>(
      context: context, isScrollControlled: true, useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(13),
        child: UserGlassPanel(padding: EdgeInsets.zero,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Clinical screening report',
                style: TextStyle(color: UserGlassColors.ink, fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('Patient: ${widget.patient['name']}  ·  ${widget.patient['public_id']}',
                style: TextStyle(color: UserGlassColors.muted)),
              Text('Recorded: ${report['created_at']}', style: TextStyle(color: UserGlassColors.muted)),
              const SizedBox(height: 13),
              Divider(color: UserGlassColors.border),
              for (final e in cbc.entries) Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  Expanded(child: Text(e.key.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(color: UserGlassColors.muted, fontSize: 12))),
                  Text('${e.value}', style: TextStyle(color: UserGlassColors.ink,
                    fontWeight: FontWeight.w800)),
                ])),
              Divider(color: UserGlassColors.border),
              Text(model['is_thalassemia'] == true
                ? 'Thalassemia indicators detected' : 'No thalassemia indicators',
                style: TextStyle(color: UserGlassColors.ink, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('Consent: operator attestation • ${report['consent_id']}',
                style: TextStyle(color: UserGlassColors.muted, fontSize: 11.5)),
              const SizedBox(height: 18),
              SizedBox(width: double.infinity, child: ElevatedButton.icon(
                icon: const Icon(Icons.picture_as_pdf_outlined), label: const Text('Save PDF'),
                onPressed: () async {
                  try {
                    final f = await HemoGuardPdfGenerator.generate(report,
                      patientPublicId: widget.patient['public_id']?.toString());
                    if (sheetContext.mounted) ScaffoldMessenger.of(sheetContext).showSnackBar(
                      SnackBar(content: Text('PDF saved to ${f.path}')));
                  } catch (e) {
                    if (sheetContext.mounted) ScaffoldMessenger.of(sheetContext).showSnackBar(
                      SnackBar(content: Text('PDF failed: $e')));
                  }
                },
              )),
              const SizedBox(height: 13),
              Text('Screening aid only — not a diagnosis.',
                style: TextStyle(color: UserGlassColors.muted, fontSize: 11)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.report, required this.onTap, required this.newest});
  final Map<String, dynamic> report;
  final VoidCallback onTap;
  final bool newest;
  @override
  Widget build(BuildContext context) {
    final cbc = Map<String, dynamic>.from(report['cbc'] as Map);
    final prediction = Map<String, dynamic>.from(report['prediction'] as Map);
    final date = report['sample_date']?.toString() ??
      report['created_at']?.toString().split('T').first ?? 'Unknown date';
    return UserGlassPanel(padding: EdgeInsets.zero, radius: 21,
      child: Material(color: Colors.transparent,
        child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(21),
          child: Padding(padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(width: 44, height: 48,
                decoration: BoxDecoration(
                  color: UserGlassColors.violet.withOpacity(UserGlassColors.dark ? .18 : .08),
                  borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.description_outlined, color: UserGlassColors.violet)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(date, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: UserGlassColors.ink, fontWeight: FontWeight.w800, fontSize: 14))),
                  if (newest) ...[
                    const SizedBox(width: 8),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(color: UserGlassColors.violet.withOpacity(.15),
                        borderRadius: BorderRadius.circular(9)),
                      child: const Text('LATEST', style: TextStyle(color: UserGlassColors.violet,
                        fontSize: 9, fontWeight: FontWeight.w800))),
                  ],
                ]),
                const SizedBox(height: 5),
                Text('Hb ${cbc['hemoglobin']} g/dL  ·  MCV ${cbc['mcv']} fL',
                  style: TextStyle(color: UserGlassColors.muted, fontSize: 11.5)),
                const SizedBox(height: 3),
                Text(prediction['is_thalassemia'] == true
                  ? 'Indicators detected' : 'No indicators detected',
                  style: TextStyle(color: UserGlassColors.ink, fontSize: 11,
                    fontWeight: FontWeight.w600)),
              ])),
              Icon(Icons.chevron_right_rounded, color: UserGlassColors.muted),
            ])),
        ),
      ),
    );
  }
}

class _StatePanel extends StatelessWidget {
  const _StatePanel({required this.icon, required this.title,
    required this.message, this.onRetry});
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(19),
    child: UserGlassPanel(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: UserGlassColors.violet, size: 36),
      const SizedBox(height: 13),
      Text(title, textAlign: TextAlign.center,
        style: TextStyle(color: UserGlassColors.ink, fontSize: 17, fontWeight: FontWeight.w800)),
      const SizedBox(height: 7),
      Text(message, textAlign: TextAlign.center,
        style: TextStyle(color: UserGlassColors.muted, fontSize: 12)),
      if (onRetry != null) ...[
        const SizedBox(height: 13),
        TextButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry')),
      ],
    ])),
  ));
}
