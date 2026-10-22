part of '../superadmin_view.dart';

// Extracted verbatim from the original SuperadminView.
extension _SuperadminAccountActions on _SuperadminViewState {
  Future<void> deleteAccount(Map<String, dynamic> user) async {
    bool deleting = false;
    String? message;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => _LiquidAdminDialog(
          title: 'Delete account?',
          subtitle: 'Review the account before removing access.',
          icon: Icons.delete_outline_rounded,
          danger: true,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DialogAccountSummary(user: user),
              const SizedBox(height: 14),
              const _DialogInfo(
                text: 'Access will be revoked immediately. Past report totals '
                    'and audit events will be retained.',
                icon: Icons.info_outline_rounded,
                danger: true,
              ),
            ],
          ),
          busy: deleting,
          errorMessage: message,
          secondaryLabel: 'Cancel',
          onCancel: () => Navigator.of(dialogContext).pop(),
          actionLabel: 'Delete account',
          onAction: () async {
            if (deleting) return;
            setDialog(() { deleting = true; message = null; });
            try {
              await auth.api('DELETE', '/api/admin/users/${user['id']}');
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              await refresh();
              _show('Account deleted. Report history is preserved.');
            } catch (e) {
              if (dialogContext.mounted) {
                setDialog(() => message = _friendlyError(e));
              }
            } finally {
              if (dialogContext.mounted) setDialog(() => deleting = false);
            }
          },
        ),
      ),
    );
  }

  Future<void> accountDialog({Map<String, dynamic>? existing}) async {
    if (!mounted) return;
    final editing = existing != null;

    // Text controllers belong to the dialog route, not this parent method.
    // A dialog's reverse animation continues after showDialog completes,
    // so disposing controllers here could crash an exiting TextFormField.
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AccountEditorDialog(
        existing: existing,
        onSubmit: (body) async {
          if (editing) {
            await auth.api(
              'PATCH', '/api/admin/users/${existing['id']}', body: body);
          } else {
            await auth.api('POST', '/api/admin/users', body: body);
          }
        },
      ),
    );

    // Only report success once the server has actually confirmed the save.
    if (saved == true && mounted) {
      await refresh();
      if (mounted) {
        _show(editing
            ? 'Account updated successfully.'
            : 'Account created successfully.');
      }
    }
  }

  Future<void> planDialog(Map<String, dynamic> user) async {
    final duration = TextEditingController(text: '30');
    final currentPlan = user['access_plan']?.toString();
    final stopped = user['status'] == 'stopped';
    String action = currentPlan == 'trial'
        ? (stopped ? 'set_trial' : 'extend_trial')
        : currentPlan == 'subscription'
            ? (stopped ? 'set_subscription' : 'extend_subscription')
            : 'set_trial';
    String unit = 'days';
    String? message;
    bool saving = false;
    const actions = <String, String>{
      'set_trial': 'Start/restart trial',
      'extend_trial': 'Extend trial',
      'stop_trial': 'Stop trial',
      'set_subscription': 'Start/switch to subscription',
      'extend_subscription': 'Extend subscription',
      'stop_subscription': 'Stop subscription',
    };
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialog) => _LiquidAdminDialog(
          title: 'Access plan',
          subtitle: 'Manage the access period for this account.',
          icon: Icons.event_available_outlined,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DialogAccountSummary(user: user),
              const SizedBox(height: 13),
              _DialogInfo(
                icon: Icons.schedule_rounded,
                text: 'Current: ${user['access_plan'] ?? 'None'} · ${user['status'] ?? 'Unknown'}\n'
                    'Expires: ${_date(user['plan_expires_at'])}',
              ),
              const SizedBox(height: 17),
              DropdownButtonFormField<String>(
                value: action,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Plan action',
                  prefixIcon: Icon(Icons.tune_rounded, size: 20),
                ),
                items: [
                  for (final item in actions.entries)
                    DropdownMenuItem(value: item.key, child: Text(item.value)),
                ],
                onChanged: saving ? null : (v) => setDialog(() {
                  action = v ?? action;
                  if (action.contains('trial')) unit = 'days';
                  message = null;
                }),
              ),
              if (!action.startsWith('stop')) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: duration,
                  enabled: !saving,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Duration (${action.contains('trial') ? 'days' : unit})',
                    prefixIcon: const Icon(Icons.calendar_month_outlined, size: 20),
                  ),
                ),
                if (action.contains('subscription')) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: unit,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Duration unit'),
                    items: const [
                      DropdownMenuItem(value: 'days', child: Text('Days')),
                      DropdownMenuItem(value: 'months', child: Text('Months')),
                    ],
                    onChanged: saving ? null : (v) => setDialog(() => unit = v ?? unit),
                  ),
                ],
              ] else ...[
                const SizedBox(height: 13),
                const _DialogInfo(
                  icon: Icons.warning_amber_rounded,
                  text: 'Stopping this plan blocks new report access immediately. '
                      'You can restart it later.',
                  danger: true,
                ),
              ],
            ],
          ),
          busy: saving,
          errorMessage: message,
          danger: action.startsWith('stop'),
          secondaryLabel: 'Cancel',
          onCancel: () => Navigator.of(dialogContext).pop(),
          actionLabel: action.startsWith('stop') ? 'Stop plan' : 'Apply plan',
          onAction: () async {
            if (saving) return;
            if (!action.startsWith('stop')) {
              final number = int.tryParse(duration.text.trim());
              final max = action.contains('subscription') && unit == 'months'
                  ? 120 : 3650;
              if (number == null || number < 1 || number > max) {
                setDialog(() => message = 'Enter a duration from 1 to $max.');
                return;
              }
            }
            setDialog(() { saving = true; message = null; });
            try {
              await auth.api('POST', '/api/admin/users/${user['id']}/plan', body: {
                'action': action,
                if (!action.startsWith('stop'))
                  'duration': int.parse(duration.text.trim()),
                'unit': action.contains('trial') ? 'days' : unit,
              });
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              await refresh();
              _show('Access plan updated successfully.');
            } catch (e) {
              if (dialogContext.mounted) {
                setDialog(() => message = _friendlyError(e));
              }
            } finally {
              if (dialogContext.mounted) setDialog(() => saving = false);
            }
          },
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 260));
    duration.dispose();
  }
}
