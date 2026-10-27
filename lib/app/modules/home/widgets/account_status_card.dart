import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../services/auth_service.dart';
import 'user_glass.dart';

/// Original access data and refresh behavior retained; glass presentation only.
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
      if (!auth.hasAccess) Get.offAllNamed(auth.landingRoute);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not update your plan. Check your connection.');
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

      return UserGlassPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 42, height: 42,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
              color: UserGlassColors.violet.withOpacity(UserGlassColors.dark ? .20 : .09)),
            child: Icon(isTrial ? Icons.hourglass_bottom_rounded : Icons.verified_outlined,
              color: UserGlassColors.dark ? const Color(0xFFDCC5FF) : UserGlassColors.violet, size: 24)),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ACCOUNT STATUS', style: TextStyle(color: UserGlassColors.muted,
              fontSize: 9.5, letterSpacing: 1.4, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(planName, style: TextStyle(color: UserGlassColors.ink,
              fontSize: 16, fontWeight: FontWeight.w800)),
            Text(data['display_name']?.toString() ?? '', maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: UserGlassColors.muted, fontSize: 11)),
          ])),
          IconButton(
            tooltip: 'Refresh account access',
            onPressed: _refreshing ? null : _checkAccess,
            icon: _refreshing
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(Icons.refresh_rounded, color: UserGlassColors.muted)),
        ]),
        const SizedBox(height: 15),
        Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: active
              ? UserGlassColors.violet.withOpacity(UserGlassColors.dark ? .17 : .07)
              : Theme.of(context).colorScheme.error.withOpacity(.10)),
          child: Row(children: [
            Icon(active ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
              color: active ? (UserGlassColors.dark ? const Color(0xFFDCC5FF) : UserGlassColors.violet)
                : Theme.of(context).colorScheme.error),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(remaining, style: TextStyle(color: UserGlassColors.ink,
                fontWeight: FontWeight.w800, fontSize: 14)),
              const SizedBox(height: 3),
              Text(dateText, style: TextStyle(color: UserGlassColors.muted, fontSize: 11.5)),
            ])),
          ])),
        if (isTrial && active) ...[
          const SizedBox(height: 11),
          Text('You are using your free trial. Contact your administrator to activate a subscription.',
            style: TextStyle(color: UserGlassColors.muted, fontSize: 11)),
        ],
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
        ],
      ]));
    });
  }
}
