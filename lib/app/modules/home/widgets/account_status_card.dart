import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../services/auth_service.dart';

/// Shows the authenticated account's current access plan. Dates are provided
/// by the server and displayed in the device's local time zone.
class AccountStatusCard extends StatefulWidget {
  const AccountStatusCard({super.key});

  @override
  State<AccountStatusCard> createState() => _AccountStatusCardState();
}

class _AccountStatusCardState extends State<AccountStatusCard> {
  bool _refreshing = false;
  String? _error;

  Future<void> _checkAccess() async {
    if (_refreshing) return;
    setState(() { _refreshing = true; _error = null; });
    final auth = Get.find<AuthService>();
    try {
      await auth.refresh();
      if (!mounted) return;
      if (!auth.hasAccess) {
        Get.offAllNamed(auth.landingRoute);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not update your plan. Check your connection.');
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthService>();
    return Obx(() {
      final data = auth.user.value;
      if (data == null || auth.isSuperadmin) return const SizedBox.shrink();

      final plan = data['access_plan']?.toString();
      final isTrial = plan == 'trial';
      final planName = isTrial ? 'Trial account' :
          plan == 'subscription' ? 'Subscription account' : 'Account access';
      final status = data['status']?.toString() ?? 'unassigned';
      final expiry = DateTime.tryParse(data['plan_expires_at']?.toString() ?? '');
      final millisecondsLeft = expiry?.difference(DateTime.now()).inMilliseconds ?? 0;
      final locallyExpired = millisecondsLeft <= 0;
      final active = status == 'active' && !locallyExpired;
      final days = active ? (millisecondsLeft / Duration.millisecondsPerDay).ceil() : 0;
      final remaining = !active ? 'Access ${locallyExpired && status == 'active' ? 'expired' : status}' :
          days == 1 ? '1 day remaining (under 24 hours)' : '$days days remaining';

      final dateText = expiry == null ? 'Expiry not set' :
          'Expires ${MaterialLocalizations.of(context).formatMediumDate(expiry.toLocal())}'
          ' at ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(expiry.toLocal()))}';

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(isTrial ? Icons.hourglass_bottom_outlined : Icons.verified_outlined,
                  size: 26, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(planName, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(data['display_name']?.toString() ?? '',
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ])),
              IconButton(onPressed: _refreshing ? null : _checkAccess,
                tooltip: 'Refresh account access', icon: _refreshing
                    ? const SizedBox(width: 19, height: 19,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh)),
            ]),
            const SizedBox(height: 12),
            Text(remaining, style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: active ? Theme.of(context).colorScheme.primary :
                    Theme.of(context).colorScheme.error)),
            const SizedBox(height: 4),
            Text(dateText, style: Theme.of(context).textTheme.bodySmall),
            if (isTrial && active) ...[
              const SizedBox(height: 8),
              const Text('You are using your free trial. Contact your administrator to activate a subscription.'),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ]),
        ),
      );
    });
  }
}
