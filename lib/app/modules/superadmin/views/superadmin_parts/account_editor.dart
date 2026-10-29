part of '../superadmin_view.dart';

// The dialog owns and disposes its controllers with its own widget lifecycle.
// This is important: showDialog's Future completes at Navigator.pop, before
// Flutter finishes the closing animation and unmounts the text fields.
class _AccountEditorDialog extends StatefulWidget {
  const _AccountEditorDialog({required this.onSubmit, this.existing});

  final Map<String, dynamic>? existing;
  final Future<void> Function(Map<String, dynamic> body) onSubmit;

  @override
  State<_AccountEditorDialog> createState() => _AccountEditorDialogState();
}

class _AccountEditorDialogState extends State<_AccountEditorDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController name;
  late final TextEditingController email;
  late final TextEditingController password;
  late final TextEditingController duration;
  late String type;
  String plan = 'trial';
  String unit = 'days';
  late bool active;
  late bool canViewResults;
  bool saving = false;
  bool showPassword = false;
  String? message;

  bool get editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    name = TextEditingController(
        text: existing?['display_name']?.toString() ?? '');
    email = TextEditingController(
        text: existing?['email']?.toString() ?? '');
    password = TextEditingController();
    duration = TextEditingController(text: '14');
    type = existing?['account_type']?.toString() ?? 'person';
    active = existing?['is_active'] == true;
    canViewResults = existing?['can_view_results'] == true;
  }

  @override
  void dispose() {
    // Called only after the closing route has finished unmounting its fields.
    name.dispose();
    email.dispose();
    password.dispose();
    duration.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (saving || !(formKey.currentState?.validate() ?? false)) return;
    setState(() { saving = true; message = null; });
    var saved = false;
    try {
      final body = <String, dynamic>{
        'display_name': name.text.trim(),
        'email': email.text.trim(),
        'account_type': type,
        'can_view_results': canViewResults,
        if (editing) ...{
          'is_active': active,
          if (password.text.isNotEmpty) 'password': password.text,
        } else ...{
          'password': password.text,
          'access_plan': plan,
          'duration': int.parse(duration.text.trim()),
          'unit': plan == 'trial' ? 'days' : unit,
        },
      };
      await widget.onSubmit(body);
      saved = true;
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => message = e is ApiException
            ? e.message
            : 'Something went wrong. Please try again.');
      }
    } finally {
      // Never rebuild an exiting dialog after a successful Navigator.pop.
      if (!saved && mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => _LiquidAdminDialog(
    title: editing ? 'Edit account' : 'Create user',
    subtitle: editing
        ? 'Update login details and account access.'
        : 'Set up a user or laboratory with a secure login.',
    icon: editing ? Icons.edit_note_rounded : Icons.person_add_alt_1_rounded,
    busy: saving,
    errorMessage: message,
      content: Form(
        key: formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: name,
              enabled: !saving,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: 'Name / laboratory',
                prefixIcon: Icon(Icons.badge_outlined, size: 20),
              ),
              validator: (v) => (v?.trim().length ?? 0) < 2
                  ? 'Enter a name of at least 2 characters.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: email,
              enabled: !saving,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              maxLength: 254,
              decoration: const InputDecoration(
                labelText: 'Login email',
                prefixIcon: Icon(Icons.alternate_email_rounded, size: 20),
              ),
              validator: (v) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                      .hasMatch(v?.trim() ?? '')
                  ? null : 'Enter a valid email address.',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: type,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Account type',
                prefixIcon: Icon(Icons.groups_outlined, size: 20),
              ),
              items: const [
                DropdownMenuItem(value: 'person', child: Text('Individual')),
                DropdownMenuItem(value: 'lab', child: Text('Laboratory')),
              ],
              onChanged: saving ? null : (v) => setState(() => type = v ?? type),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: password,
              enabled: !saving,
              obscureText: !showPassword,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: editing ? 'New password (optional)' : 'Initial password',
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                suffixIcon: IconButton(
                  tooltip: showPassword ? 'Hide password' : 'Show password',
                  icon: Icon(showPassword
                      ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: saving ? null : () => setState(
                    () => showPassword = !showPassword),
                ),
              ),
              validator: (v) {
                final value = v ?? '';
                if (editing && value.isEmpty) return null;
                if (value.length < 12) return 'Use at least 12 characters.';
                if (utf8.encode(value).length > 72) {
                  return 'Password is too long (maximum 72 UTF-8 bytes).';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _DialogSwitch(
              label: 'Allow result viewing',
              description: canViewResults
                  ? 'This account can view its saved screening predictions.'
                  : 'Screenings save, but only superadmin can view results.',
              value: canViewResults,
              onChanged: saving ? null : (v) => setState(() => canViewResults = v),
            ),
            const SizedBox(height: 12),
            if (editing)
              _DialogSwitch(
                label: 'Account enabled',
                description: active ? 'This account may sign in.'
                    : 'Sign-in is disabled for this account.',
                value: active,
                onChanged: saving ? null : (v) => setState(() => active = v),
              )
            else ...[
              DropdownButtonFormField<String>(
                value: plan,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Access type',
                  prefixIcon: Icon(Icons.workspace_premium_outlined, size: 20),
                ),
                items: const [
                  DropdownMenuItem(value: 'trial', child: Text('Trial')),
                  DropdownMenuItem(value: 'subscription', child: Text('Subscription')),
                ],
                onChanged: saving ? null : (v) => setState(() {
                  plan = v ?? plan;
                  if (plan == 'trial') unit = 'days';
                }),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: duration,
                enabled: !saving,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Duration (${plan == 'trial' ? 'days' : unit})',
                  prefixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
                ),
                validator: (v) {
                  final n = int.tryParse(v?.trim() ?? '');
                  final max = unit == 'months' && plan == 'subscription'
                      ? 120 : 3650;
                  return n != null && n >= 1 && n <= max
                      ? null : 'Enter 1–$max ${plan == 'trial' ? 'days' : unit}.';
                },
              ),
              if (plan == 'subscription') ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: unit,
                  decoration: const InputDecoration(labelText: 'Duration unit'),
                  items: const [
                    DropdownMenuItem(value: 'days', child: Text('Days')),
                    DropdownMenuItem(value: 'months', child: Text('Months')),
                  ],
                  onChanged: saving ? null : (v) => setState(() => unit = v ?? unit),
                ),
              ],
            ],
          ],
        ),
      ),
    secondaryLabel: 'Cancel',
    onCancel: () => Navigator.of(context).pop(false),
    actionLabel: editing ? 'Save changes' : 'Create account',
    onAction: submit,
  );
}

