part of '../superadmin_view.dart';

// Extracted verbatim from the original SuperadminView.
extension _SuperadminOverview on _SuperadminViewState {
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
    const metricIcons = <IconData>[
      Icons.groups_outlined,
      Icons.science_outlined,
      Icons.person_outline_rounded,
      Icons.hourglass_top_rounded,
      Icons.timelapse_rounded,
      Icons.workspace_premium_outlined,
      Icons.verified_outlined,
      Icons.event_busy_outlined,
      Icons.pause_circle_outline,
      Icons.block_outlined,
      Icons.description_outlined,
      Icons.document_scanner_outlined,
      Icons.edit_note_outlined,
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 112),
      children: [
        _FrostedPanel(
          radius: 26,
          padding: const EdgeInsets.all(23),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Create and manage user or laboratory accounts, control trials and subscriptions, and review report activity from one place.',
                        style: TextStyle(
                            fontSize: 15, color: _AdminColors.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 55,
                height: 55,
                decoration: BoxDecoration(
                  gradient: _AdminColors.accent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.integration_instructions_outlined,
                    color: Colors.white, size: 28),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _FrostedPanel(
          padding: EdgeInsets.symmetric(horizontal: 10,vertical: 5),
          child: Row(
            children: [
              Icon(Icons.radio_button_checked, color: Colors.red,size: 20,),
              SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Live Overview',
                  style: TextStyle(fontSize: 12, color: _AdminColors.muted,fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900
                ? 4
                : constraints.maxWidth >= 620
                    ? 3
                    : constraints.maxWidth >= 320
                        ? 2
                        : 1;
            const gap = 11.0;
            final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
            var i = 0;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final metric in metrics.entries)
                  SizedBox(
                    width: width,
                    child: _MetricGlass(
                      icon: metricIcons[i++],
                      label: metric.value,
                      value: '${summary[metric.key] ?? 0}',
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        _FrostedPanel(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.verified_user_outlined, color: _AdminColors.violet),
              SizedBox(width: 11),
              Expanded(
                child: Text(
                  'Report counts include completed analyses only. No CBC values or patient images are sent to the admin backend.',
                  style: TextStyle(fontSize: 12, color: _AdminColors.muted),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

}
