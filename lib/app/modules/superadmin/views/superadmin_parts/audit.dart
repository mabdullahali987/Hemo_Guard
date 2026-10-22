part of '../superadmin_view.dart';

// Extracted verbatim from the original SuperadminView.
extension _SuperadminAudit on _SuperadminViewState {
  Widget _audit() => ListView(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 112),
        children: [
          _SectionTitle(
            title: 'Audit timeline',
            subtitle: 'Account actions and administrative activity',
          ),
          const SizedBox(height: 15),
          if (events.isEmpty)
            _FrostedPanel(
              padding: EdgeInsets.all(24),
              child: Text('No audit events yet.'),
            ),
          for (final e in events) ...[
            _FrostedPanel(
              padding: const EdgeInsets.all(17),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 41,
                    height: 41,
                    decoration: BoxDecoration(
                      color: _AdminColors.violet.withOpacity(.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.history_rounded,
                        color: _AdminColors.violet, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e['action']?.toString() ?? 'Event',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: _AdminColors.ink)),
                        const SizedBox(height: 5),
                        Text(
                          e['subject_name']?.toString() ??
                              e['subject_email']?.toString() ??
                              'System',
                          style: TextStyle(
                              color: _AdminColors.ink, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text('Actor: ${e['actor_email'] ?? 'System'}',
                            style: TextStyle(
                                color: _AdminColors.muted, fontSize: 11)),
                        const SizedBox(height: 4),
                        Text(_date(e['created_at']),
                            style: TextStyle(
                                color: _AdminColors.muted, fontSize: 11)),
                        const SizedBox(height: 5),
                        Text('${e['details'] ?? {}}',
                            style: TextStyle(
                                color: _AdminColors.muted, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (events.isNotEmpty && events.length % 100 == 0)
            Center(
              child: _GlassAction(
                label: loadingMore ? 'Loading…' : 'Load older audit events',
                icon: Icons.expand_more_rounded,
                color: _AdminColors.violet,
                onTap: loadingMore ? null : loadMore,
              ),
            ),
        ],
      );

}
