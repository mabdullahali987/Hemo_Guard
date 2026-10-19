import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../services/auth_service.dart';

class AccessView extends StatefulWidget {
  const AccessView({super.key});
  @override
  State<AccessView> createState() => _AccessViewState();
}

class _AccessViewState extends State<AccessView> {
  bool busy = false;
  String? error;
  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Account access'), actions: [
        IconButton(tooltip: 'Log out', onPressed: auth.logout, icon: const Icon(Icons.logout))]),
      body: Center(child: Padding(padding: const EdgeInsets.all(24),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.lock_clock_outlined, size: 58),
            const SizedBox(height: 16),
            Obx(() {
              final plan = auth.user.value?['access_plan']?.toString();
              final planLabel = plan == 'trial' ? 'Trial' :
                  plan == 'subscription' ? 'Subscription' : 'Account';
              final expiry = DateTime.tryParse(
                  auth.user.value?['plan_expires_at']?.toString() ?? '');
              return Column(children: [
                Text('$planLabel access: ${auth.status}',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center),
                if (expiry != null) ...[
                  const SizedBox(height: 8),
                  Text('Plan expiry: ${MaterialLocalizations.of(context).formatMediumDate(expiry.toLocal())}',
                      textAlign: TextAlign.center),
                ],
              ]);
            }),
            const SizedBox(height: 14),
            const Text('Your trial or subscription is not currently active. '
              'Contact the superadmin to extend it or activate a subscription.',
              textAlign: TextAlign.center),
            const SizedBox(height: 18),
            if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
            ElevatedButton(onPressed: busy ? null : () async {
              setState(() { busy = true; error = null; });
              try { await auth.refresh(); Get.offAllNamed(auth.landingRoute); }
              catch (_) { if (mounted) setState(() => error = 'Could not check access. Check your connection.'); }
              finally { if (mounted) setState(() => busy = false); }
            }, child: const Text('Check access again')),
          ]))),
      ),
    );
  }
}
