part of '../superadmin_view.dart';

// Extracted verbatim from the original SuperadminView.
extension _SuperadminReports on _SuperadminViewState {
  Widget _reports() => ListView(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 112),
        children: [
          _SectionTitle(
            title: 'Report activity',
            subtitle: 'Completed reports by person or laboratory',
          ),
          const SizedBox(height: 8),
          Text(
            'Ranked from highest to lowest. Archived accounts are retained for accurate totals.',
            style: TextStyle(color: _AdminColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 15),
          _FrostedPanel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('Patient-linked medical reports',style:TextStyle(color:_AdminColors.ink,fontSize:16,fontWeight:FontWeight.w800)),
            const SizedBox(height:6),Text('Search all saved clinical screenings and see their originating laboratory or individual.',
              style:TextStyle(color:_AdminColors.muted,fontSize:12)),
            const SizedBox(height:12),
            _GlassAction(label:'Open all patient reports',icon:Icons.folder_shared_outlined,
              color:_AdminColors.violet,onTap:()=>Get.to(()=>const _AdminClinicalReportsPage())),
          ])),
          const SizedBox(height: 15),
          if (reportAccounts.isEmpty)
            _FrostedPanel(
              padding: EdgeInsets.all(24),
              child: Text('No individual or laboratory accounts yet.'),
            ),
          for (final account in reportAccounts) ...[
            _FrostedPanel(
              padding: const EdgeInsets.all(17),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _AccountAvatar(lab: account['account_type'] == 'lab'),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(account['display_name']?.toString() ?? '',
                                style: TextStyle(
                                    color: _AdminColors.ink,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16)),
                            const SizedBox(height: 3),
                            Text(account['email']?.toString() ?? '',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: _AdminColors.muted, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),
                  Row(
                    children: [
                      _StatusCapsule(
                        account['account_type'] == 'lab'
                            ? 'Laboratory'
                            : 'Individual',
                        color: _AdminColors.violet,
                      ),
                      if (account['is_deleted'] == true) ...[
                        const SizedBox(width: 7),
                        const _StatusCapsule('Archived',
                            color: Color(0xFFB52D52)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '${account['reports_count'] ?? 0}',
                    style: TextStyle(
                      color: _AdminColors.ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 29,
                      letterSpacing: -1,
                    ),
                  ),
                  Text('Reports generated',
                      style: TextStyle(
                          color: _AdminColors.muted, fontSize: 12)),
                  const SizedBox(height: 8),
                  Text(
                    '${account['scans_count'] ?? 0} scanned  ·  ${account['manual_count'] ?? 0} manual',
                    style: TextStyle(
                        color: _AdminColors.ink, fontSize: 12),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Last report: ${account['last_report_at'] == null ? 'Never' : _date(account['last_report_at'])}',
                    style: TextStyle(
                        color: _AdminColors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  _GlassAction(
                    label: 'View history',
                    icon: Icons.arrow_forward_rounded,
                    color: _AdminColors.magenta,
                    onTap: () => _showReportHistory(account),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          Text(
            'Existing usage counters remain unchanged. New patient-linked reports are saved securely in the restricted clinical-record section. Laboratory staff members are not individually identified.',
            style: TextStyle(color: _AdminColors.muted, fontSize: 12),
          ),
        ],
      );

  Future<void> _showReportHistory(Map<String, dynamic> account) async {
    final accountId = Uri.encodeComponent(account['id'].toString());
    final endpoint = '/api/admin/report-usage/$accountId?limit=100';
    Future<Map<String, dynamic>> historyFuture = auth.api('GET', endpoint);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x77261737),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheet) => _LiquidHistorySheet(
          title: account['display_name']?.toString() ?? 'Report history',
          child: FutureBuilder<Map<String, dynamic>>(
            future: historyFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: _AdminColors.violet),
                    SizedBox(height: 15),
                    Text('Loading report history…',
                        style: TextStyle(color: _AdminColors.muted)),
                  ],
                ));
              }
              if (snapshot.hasError || !snapshot.hasData ||
                  snapshot.data!['reports'] is! List) {
                return _HistoryFeedback(
                  icon: Icons.cloud_off_rounded,
                  heading: 'History is unavailable',
                  description: snapshot.hasError
                      ? _friendlyError(snapshot.error!)
                      : 'The server returned an unexpected report list.',
                  actionLabel: 'Try again',
                  onAction: () => setSheet(
                    () => historyFuture = auth.api('GET', endpoint),
                  ),
                );
              }
              final data = snapshot.data!;
              final reports = (data['reports'] as List)
                  .map((r) => Map<String, dynamic>.from(r as Map))
                  .toList();
              final total = (data['total'] as num?)?.toInt() ?? reports.length;
              if (reports.isEmpty) {
                return _HistoryFeedback(
                  icon: Icons.receipt_long_outlined,
                  heading: 'No reports yet',
                  description: 'Completed reports for this account will appear here.',
                );
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  _GlassHistoryCount(total: total),
                  const SizedBox(height: 13),
                  for (final report in reports) ...[
                    _HistoryEntry(
                      scanned: report['mode'] == 'image',
                      date: _date(report['completed_at']),
                    ),
                    const SizedBox(height: 9),
                  ],
                  if (total > reports.length)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        'Showing the 100 most recent reports. Use the web admin '
                        'portal to view older history.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _AdminColors.muted, fontSize: 12),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

}
