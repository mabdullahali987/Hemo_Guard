part of '../superadmin_view.dart';

// Extracted verbatim from the original SuperadminView.
extension _SuperadminAccounts on _SuperadminViewState {
  Widget _accounts() => ListView(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 112),
        children: [
          _SectionTitle(
            title: 'Account directory',
            subtitle: '${users.length} individual / laboratory accounts',
          ),
          const SizedBox(height: 15),
          if (users.isEmpty)
            _FrostedPanel(
              padding: EdgeInsets.all(24),
              child: Text('No accounts yet. Tap Add user to get started.'),
            ),
          for (final u in users) ...[
            _FrostedPanel(
              padding: const EdgeInsets.all(17),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _AccountAvatar(lab: u['account_type'] == 'lab'),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(u['display_name']?.toString() ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _AdminColors.ink,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                )),
                            const SizedBox(height: 3),
                            Text(u['email']?.toString() ?? '',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _AdminColors.muted,
                                  fontSize: 12,
                                )),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _StatusCapsule(
                        '${u['account_type'] == 'lab' ? 'Laboratory' : 'Individual'}',
                        color: _AdminColors.violet,
                      ),
                      _StatusCapsule(
                        '${u['access_plan'] ?? 'None'}',
                        color: _AdminColors.magenta,
                      ),
                      _StatusCapsule(
                        '${u['status'] ?? 'Unknown'}',
                        color: u['status'] == 'active'
                            ? const Color(0xFF14866A)
                            : const Color(0xFFB52D52),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Expires: ${_date(u['plan_expires_at'])}',
                      style: TextStyle(
                          color: _AdminColors.muted, fontSize: 12)),
                  const SizedBox(height: 5),
                  Text(
                    'Reports: ${u['reports_count'] ?? 0} · Scan ${u['scans_count'] ?? 0} · Manual ${u['manual_count'] ?? 0}',
                    style: TextStyle(
                      color: _AdminColors.ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _GlassAction(
                        label: 'Edit',
                        icon: Icons.edit_outlined,
                        onTap: () => accountDialog(existing: u),
                        color: _AdminColors.violet,
                      ),
                      _GlassAction(
                        label: 'Plan',
                        icon: Icons.event_available_outlined,
                        onTap: () => planDialog(u),
                        color: _AdminColors.magenta,
                      ),
                      _GlassAction(
                        label: 'Delete',
                        icon: Icons.delete_outline_rounded,
                        onTap: () => deleteAccount(u),
                        color: const Color(0xFFC42A58),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      );

}
