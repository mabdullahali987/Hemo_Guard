import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../services/auth_service.dart';
import '../../../services/api_client.dart';

/// Native superadmin panel, backed by the exact same API as the web portal.
class SuperadminView extends StatefulWidget {
  const SuperadminView({super.key});
  @override
  State<SuperadminView> createState() => _SuperadminViewState();
}

class _SuperadminViewState extends State<SuperadminView> {
  final auth = Get.find<AuthService>();
  Map<String, dynamic> summary = {};
  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> reportAccounts = [];
  List<Map<String, dynamic>> events = [];
  int auditOffset = 0;
  bool loading = true;
  bool loadingMore = false;
  String? error;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    if (mounted)
      setState(() {
        loading = true;
        error = null;
        auditOffset = 0;
      });
    try {
      final responses = await Future.wait([
        auth.api('GET', '/api/admin/summary'),
        auth.api('GET', '/api/admin/users'),
        auth.api('GET', '/api/admin/audit?limit=100'),
        auth.api('GET', '/api/admin/report-usage'),
      ]);
      if (!mounted) return;
      setState(() {
        summary = responses[0];
        users = (responses[1]['users'] as List)
            .map((v) => Map<String, dynamic>.from(v as Map))
            .toList();
        events = (responses[2]['events'] as List)
            .map((v) => Map<String, dynamic>.from(v as Map))
            .toList();
        reportAccounts = (responses[3]['accounts'] as List)
            .map((v) => Map<String, dynamic>.from(v as Map))
            .toList();
        loading = false;
      });
    } catch (e) {
      if (mounted)
        setState(() {
          error = e.toString();
          loading = false;
        });
    }
  }

  Future<void> loadMore() async {
    if (loadingMore) return;
    setState(() => loadingMore = true);
    try {
      final next = auditOffset + 100;
      final result =
          await auth.api('GET', '/api/admin/audit?limit=100&offset=$next');
      if (!mounted) return;
      final more = (result['events'] as List)
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList();
      setState(() {
        auditOffset = next;
        events.addAll(more);
      });
    } catch (e) {
      _show(e.toString());
    } finally {
      if (mounted) setState(() => loadingMore = false);
    }
  }

  void _show(String message) {
    if (mounted)
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
  }

  String _date(dynamic value) {
    if (value == null) return 'Not set';
    final date = DateTime.tryParse(value.toString());
    return date == null
        ? 'Not set'
        : '${date.toLocal().year}-'
            '${date.toLocal().month.toString().padLeft(2, '0')}-'
            '${date.toLocal().day.toString().padLeft(2, '0')} '
            '${date.toLocal().hour.toString().padLeft(2, '0')}:'
            '${date.toLocal().minute.toString().padLeft(2, '0')} (local)';
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
            title: const Text('Superadmin'),
            actions: [
              IconButton(
                  onPressed: refresh,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh'),
              IconButton(
                  onPressed: auth.logout,
                  icon: const Icon(Icons.logout),
                  tooltip: 'Log out'),
            ],
            bottom: const TabBar(isScrollable: true, tabs: [
              Tab(icon: Icon(Icons.analytics_outlined), text: 'Overview'),
              Tab(icon: Icon(Icons.groups_outlined), text: 'Users'),
              Tab(icon: Icon(Icons.summarize_outlined), text: 'Reports'),
              Tab(icon: Icon(Icons.history_outlined), text: 'Audit'),
            ])),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(error!),
                    TextButton(onPressed: refresh, child: const Text('Retry'))
                  ]))
                : TabBarView(
                    children: [_overview(), _accounts(), _reports(), _audit()]),
        floatingActionButton: loading || error != null
            ? null
            : FloatingActionButton.extended(
                onPressed: () => accountDialog(),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Add user')),
      ));

  Widget _overview() {
    const metrics = <String, String>{
      'total_users': 'Total users',
      'labs': 'Laboratories',
      'persons': 'Individuals',
      'trial_accounts': 'Trial accounts (all)',
      'active_trials': 'Active trials',
      'subscription_accounts': 'Subscription accounts (all)',
      'active_subscriptions': 'Active subscriptions',
      'expired': 'Expired plans',
      'stopped': 'Stopped plans',
      'disabled': 'Disabled accounts',
      'reports_total': 'Reports generated',
      'reports_scanned': 'Scanned reports',
      'reports_manual': 'Manual reports',
    };
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Access & report statistics',
          style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      LayoutBuilder(builder: (context, constraints) {
        final width = (constraints.maxWidth - 12) / 2;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          for (final metric in metrics.entries)
            SizedBox(
                width: width,
                child: Card(
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(metric.value),
                              const SizedBox(height: 8),
                              Text('${summary[metric.key] ?? 0}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium),
                            ])))),
        ]);
      }),
      const SizedBox(height: 20),
      const Text(
          'Report counts include completed analyses only. No CBC values or patient images are sent to the admin backend.'),
    ]);
  }

  Widget _accounts() =>
      ListView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 88), children: [
        Text('${users.length} accounts',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        for (final u in users)
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(u['display_name']?.toString() ?? '',
                            style: Theme.of(context).textTheme.titleMedium),
                        Text(u['email']?.toString() ?? ''),
                        const SizedBox(height: 7),
                        Text(
                            '${u['account_type']} • ${u['access_plan']} • ${u['status']}'),
                        Text('Expires: ${_date(u['plan_expires_at'])}'),
                        Text('Reports: ${u['reports_count'] ?? 0} '
                            '(scan ${u['scans_count'] ?? 0}, manual ${u['manual_count'] ?? 0})'),
                        Wrap(spacing: 8, children: [
                          TextButton.icon(
                              onPressed: () => accountDialog(existing: u),
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Edit')),
                          TextButton.icon(
                              onPressed: () => planDialog(u),
                              icon: const Icon(Icons.event_available_outlined),
                              label: const Text('Plan')),
                          TextButton.icon(
                              onPressed: () => deleteAccount(u),
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Delete')),
                        ]),
                      ]))),
      ]);

  Widget _reports() => ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 88),
        children: [
          Text('Reports by user / laboratory',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          const Text('Completed reports only. Ranked from highest to lowest. '
              'Archived accounts are retained for accurate totals.'),
          const SizedBox(height: 12),
          if (reportAccounts.isEmpty)
            const Card(
                child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No individual or laboratory accounts yet.'))),
          for (final account in reportAccounts)
            Card(
                child: InkWell(
              onTap: () => _showReportHistory(account),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(account['account_type'] == 'lab'
                            ? Icons.science_outlined
                            : Icons.person_outline),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(
                                account['display_name']?.toString() ?? '',
                                style:
                                    Theme.of(context).textTheme.titleMedium)),
                        const Icon(Icons.chevron_right),
                      ]),
                      Text(account['email']?.toString() ?? ''),
                      Text(account['account_type'] == 'lab'
                          ? 'Laboratory'
                          : 'Individual'),
                      if (account['is_deleted'] == true)
                        const Text('Archived account',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Text('${account['reports_count'] ?? 0} reports generated',
                          style: Theme.of(context).textTheme.titleMedium),
                      Text('${account['scans_count'] ?? 0} scanned  ·  '
                          '${account['manual_count'] ?? 0} manual'),
                      Text(
                          'Last report: ${account['last_report_at'] == null ? 'Never' : _date(account['last_report_at'])}'),
                      const SizedBox(height: 6),
                      const Text('Tap to see report history'),
                    ]),
              ),
            )),
          const Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                  'A lab account records combined activity for that lab login; '
                  'staff members are not individually identified. '
                  'Patient CBC data and images are not sent to the audit server.')),
        ],
      );

  Future<void> _showReportHistory(Map<String, dynamic> account) async {
    final accountId = Uri.encodeComponent(account['id'].toString());
    final future =
        auth.api('GET', '/api/admin/report-usage/$accountId?limit=100');
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
          child: SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * 0.78,
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                      child: Text(account['display_name']?.toString() ?? '',
                          style: Theme.of(sheetContext).textTheme.titleLarge)),
                  IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(sheetContext)),
                ]),
                const Text(
                    'Completed report history (times shown in local time)'),
                const SizedBox(height: 10),
                Expanded(
                    child: FutureBuilder<Map<String, dynamic>>(
                  future: future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                          child: Text(
                              'Could not load reports: ${snapshot.error}'));
                    }
                    final data = snapshot.data!;
                    final reports = (data['reports'] as List)
                        .map((r) => Map<String, dynamic>.from(r as Map))
                        .toList();
                    return ListView(children: [
                      Text('${data['total']} reports generated',
                          style: Theme.of(context).textTheme.titleMedium),
                      if (reports.isEmpty)
                        const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child:
                                Text('No completed reports for this account.')),
                      for (final report in reports)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(report['mode'] == 'image'
                              ? Icons.document_scanner_outlined
                              : Icons.edit_note),
                          title: Text(report['mode'] == 'image'
                              ? 'Scanned report'
                              : 'Manual report'),
                          subtitle: Text(_date(report['completed_at'])),
                        ),
                      if ((data['total'] as num) > reports.length)
                        const Text('Showing the most recent 100 reports. '
                            'Open the web superadmin portal to view older reports.'),
                    ]);
                  },
                )),
              ],
            )),
      )),
    );
  }

  Widget _audit() =>
      ListView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 80), children: [
        Text('Activity / audit log',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        for (final e in events)
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e['action']?.toString() ?? 'Event',
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 5),
                        Text(e['subject_name']?.toString() ??
                            e['subject_email']?.toString() ??
                            'System'),
                        Text('Actor: ${e['actor_email'] ?? 'System'}'),
                        Text(_date(e['created_at'])),
                        Text('${e['details'] ?? {}}'),
                      ]))),
        if (events.isNotEmpty && events.length % 100 == 0)
          TextButton(
              onPressed: loadingMore ? null : loadMore,
              child:
                  Text(loadingMore ? 'Loading…' : 'Load older audit events')),
      ]);

  Future<void> deleteAccount(Map<String, dynamic> user) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Delete account?'),
                content: Text(
                    'Delete ${user['display_name']}? Access will be revoked, '
                    'and past audit/report counts will be retained.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel')),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete'))
                ]));
    if (confirmed != true) return;
    try {
      await auth.api('DELETE', '/api/admin/users/${user['id']}');
      await refresh();
      _show('Account deleted');
    } catch (e) {
      _show(e.toString());
    }
  }

  Future<void> accountDialog({Map<String, dynamic>? existing}) async {
    final editing = existing != null;
    final name = TextEditingController(
        text: existing?['display_name']?.toString() ?? '');
    final email =
        TextEditingController(text: existing?['email']?.toString() ?? '');
    final password = TextEditingController();
    final duration = TextEditingController(text: '14');
    String type = existing?['account_type']?.toString() ?? 'person';
    String plan = 'trial';
    String unit = 'days';
    bool active = existing?['is_active'] == true;
    bool saving = false;
    String? message;
    final key = GlobalKey<FormState>();
    await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialog) => AlertDialog(
                  title: Text(editing ? 'Edit user' : 'Create user'),
                  content: SizedBox(
                      width: 440,
                      child: SingleChildScrollView(
                          child: Form(
                              key: key,
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextFormField(
                                        controller: name,
                                        decoration: const InputDecoration(
                                            labelText: 'Name / laboratory'),
                                        validator: (v) =>
                                            v == null || v.trim().length < 2
                                                ? 'Enter a name'
                                                : null),
                                    TextFormField(
                                        controller: email,
                                        decoration: const InputDecoration(
                                            labelText: 'Login email'),
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        validator: (v) =>
                                            v == null || !v.contains('@')
                                                ? 'Enter an email'
                                                : null),
                                    DropdownButtonFormField<String>(
                                        value: type,
                                        decoration: const InputDecoration(
                                            labelText: 'Account type'),
                                        items: const [
                                          DropdownMenuItem(
                                              value: 'person',
                                              child: Text('Individual')),
                                          DropdownMenuItem(
                                              value: 'lab',
                                              child: Text('Laboratory'))
                                        ],
                                        onChanged: (v) =>
                                            setDialog(() => type = v ?? type)),
                                    TextFormField(
                                        controller: password,
                                        obscureText: true,
                                        decoration: InputDecoration(
                                            labelText: editing
                                                ? 'New password (optional)'
                                                : 'Initial password'),
                                        validator: (v) => (!editing ||
                                                    (v?.isNotEmpty ?? false)) &&
                                                (v?.length ?? 0) < 12
                                            ? 'At least 12 characters'
                                            : null),
                                    if (editing)
                                      SwitchListTile(
                                          title: const Text('Account enabled'),
                                          value: active,
                                          onChanged: (v) =>
                                              setDialog(() => active = v))
                                    else ...[
                                      DropdownButtonFormField<String>(
                                          value: plan,
                                          decoration: const InputDecoration(
                                              labelText: 'Access type'),
                                          items: const [
                                            DropdownMenuItem(
                                                value: 'trial',
                                                child: Text('Trial')),
                                            DropdownMenuItem(
                                                value: 'subscription',
                                                child: Text('Subscription'))
                                          ],
                                          onChanged: (v) => setDialog(() {
                                                plan = v ?? plan;
                                                if (plan == 'trial')
                                                  unit = 'days';
                                              })),
                                      TextFormField(
                                          controller: duration,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                              labelText: 'Duration'),
                                          validator: (v) =>
                                              (int.tryParse(v ?? '') ?? 0) < 1
                                                  ? 'Enter valid duration'
                                                  : null),
                                      if (plan == 'subscription')
                                        DropdownButtonFormField<String>(
                                            value: unit,
                                            items: const [
                                              DropdownMenuItem(
                                                  value: 'days',
                                                  child: Text('Days')),
                                              DropdownMenuItem(
                                                  value: 'months',
                                                  child: Text('Months'))
                                            ],
                                            onChanged: (v) => setDialog(
                                                () => unit = v ?? unit)),
                                    ],
                                    if (message != null)
                                      Padding(
                                          padding:
                                              const EdgeInsets.only(top: 10),
                                          child: Text(message!,
                                              style: const TextStyle(
                                                  color: Colors.red))),
                                  ])))),
                  actions: [
                    TextButton(
                        onPressed:
                            saving ? null : () => Navigator.pop(dialogContext),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: saving
                            ? null
                            : () async {
                                if (!key.currentState!.validate()) return;
                                setDialog(() {
                                  saving = true;
                                  message = null;
                                });
                                try {
                                  if (editing) {
                                    await auth.api('PATCH',
                                        '/api/admin/users/${existing['id']}',
                                        body: {
                                          'display_name': name.text,
                                          'email': email.text,
                                          'account_type': type,
                                          'is_active': active,
                                          if (password.text.isNotEmpty)
                                            'password': password.text,
                                        });
                                  } else {
                                    await auth
                                        .api('POST', '/api/admin/users', body: {
                                      'display_name': name.text,
                                      'email': email.text,
                                      'account_type': type,
                                      'password': password.text,
                                      'access_plan': plan,
                                      'duration': int.parse(duration.text),
                                      'unit': plan == 'trial' ? 'days' : unit,
                                    });
                                  }
                                  if (dialogContext.mounted)
                                    Navigator.pop(dialogContext);
                                  await refresh();
                                } on ApiException catch (e) {
                                  if (dialogContext.mounted)
                                    setDialog(() => message = e.message);
                                } catch (e) {
                                  if (dialogContext.mounted)
                                    setDialog(() => message = e.toString());
                                } finally {
                                  if (dialogContext.mounted)
                                    setDialog(() => saving = false);
                                }
                              },
                        child: Text(editing ? 'Save' : 'Create')),
                  ],
                )));
    name.dispose();
    email.dispose();
    password.dispose();
    duration.dispose();
  }

  Future<void> planDialog(Map<String, dynamic> user) async {
    final duration = TextEditingController(text: '30');
    String action =
        user['access_plan'] == 'trial' ? 'extend_trial' : 'extend_subscription';
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
        builder: (dialogContext) => StatefulBuilder(
            builder: (ctx, setDialog) => AlertDialog(
                  title: Text('Access plan: ${user['display_name']}'),
                  content: SizedBox(
                      width: 420,
                      child: SingleChildScrollView(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(
                            'Current: ${user['access_plan']} / ${user['status']}\n'
                            'Expires: ${_date(user['plan_expires_at'])}'),
                        DropdownButtonFormField<String>(
                            value: action,
                            isExpanded: true,
                            decoration:
                                const InputDecoration(labelText: 'Action'),
                            items: [
                              for (final item in actions.entries)
                                DropdownMenuItem(
                                    value: item.key, child: Text(item.value))
                            ],
                            onChanged: saving
                                ? null
                                : (v) => setDialog(() {
                                      action = v ?? action;
                                      if (action.contains('trial'))
                                        unit = 'days';
                                    })),
                        if (!action.startsWith('stop')) ...[
                          TextField(
                              controller: duration,
                              keyboardType: TextInputType.number,
                              decoration:
                                  const InputDecoration(labelText: 'Duration')),
                          if (action.contains('subscription'))
                            DropdownButtonFormField<String>(
                                value: unit,
                                items: const [
                                  DropdownMenuItem(
                                      value: 'days', child: Text('Days')),
                                  DropdownMenuItem(
                                      value: 'months', child: Text('Months'))
                                ],
                                onChanged: saving
                                    ? null
                                    : (v) => setDialog(() => unit = v ?? unit)),
                        ],
                        if (message != null)
                          Text(message!,
                              style: const TextStyle(color: Colors.red)),
                      ]))),
                  actions: [
                    TextButton(
                        onPressed:
                            saving ? null : () => Navigator.pop(dialogContext),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: saving
                            ? null
                            : () async {
                                if (!action.startsWith('stop') &&
                                    (int.tryParse(duration.text) ?? 0) < 1) {
                                  setDialog(() =>
                                      message = 'Enter a positive duration');
                                  return;
                                }
                                setDialog(() {
                                  saving = true;
                                  message = null;
                                });
                                try {
                                  await auth.api('POST',
                                      '/api/admin/users/${user['id']}/plan',
                                      body: {
                                        'action': action,
                                        if (!action.startsWith('stop'))
                                          'duration': int.parse(duration.text),
                                        'unit': action.contains('trial')
                                            ? 'days'
                                            : unit,
                                      });
                                  if (dialogContext.mounted)
                                    Navigator.pop(dialogContext);
                                  await refresh();
                                } on ApiException catch (e) {
                                  if (dialogContext.mounted)
                                    setDialog(() => message = e.message);
                                } catch (e) {
                                  if (dialogContext.mounted)
                                    setDialog(() => message = e.toString());
                                } finally {
                                  if (dialogContext.mounted)
                                    setDialog(() => saving = false);
                                }
                              },
                        child: const Text('Apply')),
                  ],
                )));
    duration.dispose();
  }
}
