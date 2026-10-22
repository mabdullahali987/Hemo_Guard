import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

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

class _SuperadminViewState extends State<SuperadminView> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final auth = Get.find<AuthService>();
  Map<String, dynamic> summary = {};
  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> reportAccounts = [];
  List<Map<String, dynamic>> events = [];
  int auditOffset = 0;
  bool loading = true;
  bool loadingMore = false;
  String? error;
  // Screen-local glass feedback. An overlay avoids ScaffoldMessenger moving
  // notifications above the floating action button and bottom dock.
  OverlayEntry? _feedbackEntry;
  Timer? _feedbackTimer;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    refresh();
  }

  @override
  void dispose() {
    _clearFeedback();
    _tabs.dispose();
    super.dispose();
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
          error = _friendlyError(e);
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
      _show(_friendlyError(e), isError: true);
    } finally {
      if (mounted) setState(() => loadingMore = false);
    }
  }

  String _friendlyError(Object failure) => failure is ApiException
      ? failure.message
      : 'Something went wrong. Please try again.';

  void _clearFeedback() {
    _feedbackTimer?.cancel();
    _feedbackTimer = null;
    _feedbackEntry?.remove();
    _feedbackEntry?.dispose();
    _feedbackEntry = null;
  }

  void _show(String message, {bool isError = false}) {
    if (!mounted) return;
    _clearFeedback();
    final overlay = Overlay.of(context);
    _feedbackEntry = OverlayEntry(
      builder: (overlayContext) {
        final bottomInset = MediaQuery.of(overlayContext).viewPadding.bottom;
        return Positioned(
          left: 18,
          right: 18,
          // Fixed just above the dock, regardless of the Add User button.
          bottom: bottomInset + 17 + 59 + 12,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 370),
              child: Semantics(
                liveRegion: true,
                child: _GlassFeedbackNotice(
                  message: message,
                  isError: isError,
                ),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(_feedbackEntry!);
    _feedbackTimer = Timer(const Duration(milliseconds: 3100), () {
      if (mounted) _clearFeedback();
    });
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

  // These colors and overrides apply only to the mobile superadmin screen.
  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final localTheme = base.copyWith(
      colorScheme: ColorScheme.fromSeed(seedColor: _AdminColors.violet),
      scaffoldBackgroundColor: Colors.transparent,
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFFFDF7FD),
        surfaceTintColor: Colors.transparent,
        elevation: 14,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(27),
          side: const BorderSide(color: Colors.white, width: 1.2),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xB8FFFFFF),
        labelStyle: const TextStyle(color: _AdminColors.muted, fontWeight: FontWeight.w600),
        floatingLabelStyle: const TextStyle(color: _AdminColors.violet, fontWeight: FontWeight.w800),
        hintStyle: const TextStyle(color: Color(0xFF9C8CA3)),
        errorStyle: const TextStyle(color: Color(0xFFB52258), fontWeight: FontWeight.w600),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 15,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _AdminColors.violet.withOpacity(.16)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _AdminColors.violet, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFC72D5C)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFC72D5C), width: 1.5),
        ),
      ),
    );
    return Theme(
      data: localTheme,
      child: _AdminCanvas(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          // Render the page behind the floating dock, so glass can actually
          // refract the underlying violet/rose canvas instead of empty space.
          extendBody: true,
          body: Stack(
            children: [
              SafeArea(
                child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 15, 18, 14),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: _AdminColors.accent,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: _AdminColors.magenta.withOpacity(.19),
                              blurRadius: 15,
                              offset: const Offset(0, 7),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.monitor_heart_outlined,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'HEMOGUARD',
                              style: TextStyle(
                                color: _AdminColors.muted,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2.0,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Superadmin',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _AdminColors.ink,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _TopGlassIcon(
                        icon: Icons.refresh_rounded,
                        tooltip: 'Refresh',
                        onTap: refresh,
                      ),
                      const SizedBox(width: 9),
                      _TopGlassIcon(
                        icon: Icons.logout_rounded,
                        tooltip: 'Log out',
                        onTap: auth.logout,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: loading
                      ? Center(
                          child: _FrostedPanel(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 36, vertical: 28),
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(
                                    color: _AdminColors.violet),
                                SizedBox(height: 16),
                                Text('Loading your workspace…'),
                              ],
                            ),
                          ),
                        )
                      : error != null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: _FrostedPanel(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.wifi_off_rounded,
                                          color: _AdminColors.rose, size: 34),
                                      const SizedBox(height: 13),
                                      Text(error!, textAlign: TextAlign.center),
                                      const SizedBox(height: 12),
                                      FilledButton.icon(
                                        onPressed: refresh,
                                        icon: const Icon(Icons.refresh_rounded),
                                        label: const Text('Try again'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          : TabBarView(
                              controller: _tabs,
                              physics: const BouncingScrollPhysics(),
                              children: [
                                _fadeTab(0, _overview()),
                                _fadeTab(1, _accounts()),
                                _fadeTab(2, _reports()),
                                _fadeTab(3, _audit()),
                              ],
                            ),
                ),
              ],
                ),
              ),
              // The dock floats over the actual page canvas. Unlike placing it
              // in Scaffold.bottomNavigationBar, this creates no full-width
              // light-colored strip underneath. _navigation() is unchanged.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  minimum: const EdgeInsets.only(bottom: 17),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 304),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: _navigation(),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: loading || error != null
              ? null
              : Padding(
                  // Keep the action above the overlaid dock (as before).
                  padding: const EdgeInsets.only(bottom: 72),
                  child: _GlassCreateUserButton(
                    onPressed: () => accountDialog(),
                  ),
                ),
        ),
      ),
    );
  }

  // Translucent compact dock with an elastic glass lens. The custom shape
  // stretches at tab boundaries and leaves a fading fluid ribbon in its wake.
  // One TabController drives both page movement and the dock; no duplicate
  // navigation, requests, timers, or additional dependencies are introduced.
  Widget _navigation() => LayoutBuilder(
        builder: (context, constraints) {
          const labels = ['Overview', 'Accounts', 'Reports', 'Audit'];
          const icons = [
            Icons.dashboard_rounded,
            Icons.people_alt_rounded,
            Icons.description_rounded,
            Icons.history_rounded,
          ];
          const dockHeight = 59.0;
          final cell = (constraints.maxWidth - 10) / 4;
          final reduceMotion = MediaQuery.of(context).disableAnimations;
          return Container(
            height: dockHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(31),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4D224F).withOpacity(.18),
                  blurRadius: 26,
                  spreadRadius: -6,
                  offset: const Offset(0, 11),
                ),
                BoxShadow(
                  color: _AdminColors.rose.withOpacity(.08),
                  blurRadius: 20,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(31),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: AnimatedBuilder(
                  animation: _tabs.animation!,
                  builder: (context, _) {
                    final position = _tabs.animation!.value
                        .clamp(0.0, 3.0)
                        .toDouble();
                    final phase = position - position.floorToDouble();
                    final liquid = reduceMotion ? 0.0 :
                        math.sin(math.pi * phase).clamp(0.0, 1.0).toDouble();
                    final lensWidth = cell - 5 + liquid * 26;
                    final lensCenter = 5 + cell * (position + .5);
                    final lensLeft = (lensCenter - lensWidth / 2)
                        .clamp(2.0, constraints.maxWidth - lensWidth - 2.0)
                        .toDouble();
                    return Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        // Translucent, not opaque charcoal: moving page colors
                        // remain visible through the blurred material.
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(31),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0x4DFFFFFF),
                                  Color(0x269D71AA),
                                  Color(0x337D547D),
                                ],
                                stops: [0, .51, 1],
                              ),
                              border: Border.all(
                                color: const Color(0xB7FFFFFF),
                                width: 1.05,
                              ),
                            ),
                          ),
                        ),
                        // Upper glint and lower rosy reflection trace the
                        // capsule's curvature while preserving transparency.
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(31),
                                gradient: const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0x60FFFFFF),
                                    Color(0x06FFFFFF),
                                    Color(0x15EB68A8),
                                  ],
                                  stops: [0, .39, 1],
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (!reduceMotion && liquid > .001)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: _DockFluidTrailPainter(
                                  position: position,
                                  cell: cell,
                                  strength: liquid,
                                ),
                              ),
                            ),
                          ),
                        // One morphing lens. Travel widens its belly, pinches
                        // its rim and paints a connecting glossy fluid trail.
                        Positioned(
                          top: 3,
                          bottom: 3,
                          left: lensLeft,
                          width: lensWidth,
                          child: _LiquidGlassLens(morph: liquid),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Row(
                            children: [
                              for (var i = 0; i < labels.length; i++)
                                Expanded(
                                  child: Semantics(
                                    button: true,
                                    selected: _tabs.index == i,
                                    label: '${labels[i]} tab',
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(29),
                                        splashColor: _AdminColors.violet
                                            .withOpacity(.09),
                                        highlightColor: Colors.transparent,
                                        onTap: () {
                                          if (_tabs.index == i &&
                                              !_tabs.indexIsChanging) return;
                                          _tabs.animateTo(
                                            i,
                                            duration: reduceMotion
                                                ? Duration.zero
                                                : const Duration(
                                                    milliseconds: 550),
                                            curve: Curves.easeInOutCubic,
                                          );
                                        },
                                        child: SizedBox(
                                          height: dockHeight,
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Transform.scale(
                                                scale: 1.0 + .14 *
                                                    (1 - (position - i).abs())
                                                        .clamp(0.0, 1.0)
                                                        .toDouble(),
                                                child: Icon(
                                                  icons[i],
                                                  size: 20,
                                                  color: Color.lerp(
                                                    const Color(0xFF5D4166),
                                                    _AdminColors.violet,
                                                    (1 - (position - i).abs())
                                                        .clamp(0.0, 1.0)
                                                        .toDouble(),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                  labels[i],
                                                  maxLines: 1,
                                                  style: TextStyle(
                                                    fontSize: 9.3,
                                                    fontWeight: FontWeight.w800,
                                                    color: Color.lerp(
                                                      const Color(0xFF695473),
                                                      _AdminColors.violet,
                                                      (1 - (position - i).abs())
                                                          .clamp(0.0, 1.0)
                                                          .toDouble(),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        },
      );

  // TabBarView handles the single horizontal page movement; opacity supplies
  // a gentle liquid fade without a second outgoing-page animation.
  Widget _fadeTab(int index, Widget child) => AnimatedBuilder(
        animation: _tabs.animation!,
        child: child,
        builder: (context, child) {
          final reduced = MediaQuery.of(context).disableAnimations;
          final distance = (_tabs.animation!.value - index).abs()
              .clamp(0.0, 1.0).toDouble();
          return Opacity(
            opacity: reduced ? 1 : 1 - distance * .17,
            child: child,
          );
        },
      );

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
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('WORKSPACE OVERVIEW',
                        style: TextStyle(
                          letterSpacing: 1.6,
                          color: _AdminColors.violet,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        )),
                    SizedBox(height: 7),
                    Text('Every account, in focus.',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: _AdminColors.ink,
                          fontSize: 23,
                          letterSpacing: -.65,
                        )),
                    SizedBox(height: 6),
                    Text('Access plans and reporting activity at a glance.',
                        style: TextStyle(
                            fontSize: 12, color: _AdminColors.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  gradient: _AdminColors.accent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.insights_rounded,
                    color: Colors.white, size: 28),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const _SectionTitle(
            title: 'At a glance', subtitle: 'Live account and report totals'),
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
          child: const Row(
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

  Widget _accounts() => ListView(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 112),
        children: [
          _SectionTitle(
            title: 'Account directory',
            subtitle: '${users.length} individual / laboratory accounts',
          ),
          const SizedBox(height: 15),
          if (users.isEmpty)
            const _FrostedPanel(
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
                                style: const TextStyle(
                                  color: _AdminColors.ink,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                )),
                            const SizedBox(height: 3),
                            Text(u['email']?.toString() ?? '',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
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
                      style: const TextStyle(
                          color: _AdminColors.muted, fontSize: 12)),
                  const SizedBox(height: 5),
                  Text(
                    'Reports: ${u['reports_count'] ?? 0} · Scan ${u['scans_count'] ?? 0} · Manual ${u['manual_count'] ?? 0}',
                    style: const TextStyle(
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

  Widget _reports() => ListView(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 112),
        children: [
          const _SectionTitle(
            title: 'Report activity',
            subtitle: 'Completed reports by person or laboratory',
          ),
          const SizedBox(height: 8),
          const Text(
            'Ranked from highest to lowest. Archived accounts are retained for accurate totals.',
            style: TextStyle(color: _AdminColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 15),
          if (reportAccounts.isEmpty)
            const _FrostedPanel(
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
                                style: const TextStyle(
                                    color: _AdminColors.ink,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16)),
                            const SizedBox(height: 3),
                            Text(account['email']?.toString() ?? '',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
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
                    style: const TextStyle(
                      color: _AdminColors.ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 29,
                      letterSpacing: -1,
                    ),
                  ),
                  const Text('Reports generated',
                      style: TextStyle(
                          color: _AdminColors.muted, fontSize: 12)),
                  const SizedBox(height: 8),
                  Text(
                    '${account['scans_count'] ?? 0} scanned  ·  ${account['manual_count'] ?? 0} manual',
                    style: const TextStyle(
                        color: _AdminColors.ink, fontSize: 12),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Last report: ${account['last_report_at'] == null ? 'Never' : _date(account['last_report_at'])}',
                    style: const TextStyle(
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
          const Text(
            'A lab account records combined activity for that lab login; staff members are not individually identified. Patient CBC data and images are not sent to the audit server.',
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
                return const Center(child: Column(
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
                return const _HistoryFeedback(
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
                    const Padding(
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

  Widget _audit() => ListView(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 112),
        children: [
          const _SectionTitle(
            title: 'Audit timeline',
            subtitle: 'Account actions and administrative activity',
          ),
          const SizedBox(height: 15),
          if (events.isEmpty)
            const _FrostedPanel(
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
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: _AdminColors.ink)),
                        const SizedBox(height: 5),
                        Text(
                          e['subject_name']?.toString() ??
                              e['subject_email']?.toString() ??
                              'System',
                          style: const TextStyle(
                              color: _AdminColors.ink, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text('Actor: ${e['actor_email'] ?? 'System'}',
                            style: const TextStyle(
                                color: _AdminColors.muted, fontSize: 11)),
                        const SizedBox(height: 4),
                        Text(_date(e['created_at']),
                            style: const TextStyle(
                                color: _AdminColors.muted, fontSize: 11)),
                        const SizedBox(height: 5),
                        Text('${e['details'] ?? {}}',
                            style: const TextStyle(
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

// Dialog and report history presentation is scoped to this screen only.
// Flutter blur + translucent highlights approximate (but don't replicate)
// Apple's native Liquid Glass compositing.
class _DialogGlassSurface extends StatelessWidget {
  const _DialogGlassSurface({required this.child, this.radius = 30});
  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xC8FFFCFF), Color(0xA6F9F0FC), Color(0xC2FCECF5)],
          ),
          border: Border.all(color: const Color(0xF5FFFFFF), width: 1.25),
          boxShadow: const [
            BoxShadow(color: Color(0x289158B4), blurRadius: 28, offset: Offset(0, 12)),
          ],
        ),
        child: Stack(
          children: [
            const Positioned(
              top: -100, right: -65,
              child: _AdminOrb(size: 210, color: Color(0x28C026D3)),
            ),
            const Positioned(
              bottom: -125, left: -90,
              child: _AdminOrb(size: 210, color: Color(0x20FB7185)),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    gradient: const RadialGradient(
                      center: Alignment(-.85, -1.0), radius: 1.5,
                      colors: [Color(0x88FFFFFF), Color(0x00FFFFFF)],
                    ),
                  ),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    ),
  );
}

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

class _LiquidAdminDialog extends StatelessWidget {
  const _LiquidAdminDialog({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.content,
    required this.onCancel,
    required this.onAction,
    required this.actionLabel,
    required this.secondaryLabel,
    this.busy = false,
    this.danger = false,
    this.errorMessage,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget content;
  final VoidCallback onCancel;
  final VoidCallback onAction;
  final String actionLabel;
  final String secondaryLabel;
  final bool busy;
  final bool danger;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 22),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 450, maxHeight: height * .85),
        child: _DialogGlassSurface(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(23, 23, 23, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 47,
                      width: 47,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: danger
                            ? const LinearGradient(colors: [Color(0xFFE11D48), Color(0xFFFB7185)])
                            : _AdminColors.accent,
                        boxShadow: [
                          BoxShadow(
                            color: (danger ? _AdminColors.rose : _AdminColors.violet)
                                .withOpacity(.19),
                            blurRadius: 16, offset: const Offset(0, 7),
                          ),
                        ],
                      ),
                      child: Icon(icon, color: Colors.white, size: 23),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(
                            color: _AdminColors.ink,
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            letterSpacing: -.5,
                          )),
                          const SizedBox(height: 5),
                          Text(subtitle, style: const TextStyle(
                            color: _AdminColors.muted, fontSize: 12,
                            height: 1.35,
                          )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(23, 0, 23, 8),
                  child: _DialogFeedback(message: errorMessage!),
                ),
              Flexible(
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(23, 7, 23, 13),
                  child: content,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(21, 10, 21, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: busy ? null : onCancel,
                      style: TextButton.styleFrom(
                        foregroundColor: _AdminColors.violet,
                        minimumSize: const Size(65, 45),
                      ),
                      child: Text(secondaryLabel),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: _LiquidPrimaryAction(
                        title: actionLabel,
                        danger: danger,
                        busy: busy,
                        onPressed: busy ? null : onAction,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiquidPrimaryAction extends StatelessWidget {
  const _LiquidPrimaryAction({
    required this.title,
    required this.onPressed,
    this.danger = false,
    this.busy = false,
  });
  final String title;
  final VoidCallback? onPressed;
  final bool danger;
  final bool busy;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onPressed == null ? .65 : 1,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(15),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 45),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: danger
                ? const LinearGradient(colors: [Color(0xFFD9275B), Color(0xFFEF6488)])
                : _AdminColors.accent,
            boxShadow: [BoxShadow(
              color: (danger ? _AdminColors.rose : _AdminColors.violet)
                  .withOpacity(.23), blurRadius: 13, offset: const Offset(0, 5),
            )],
            border: Border.all(color: const Color(0xAAFFFFFF)),
          ),
          child: Center(
            child: busy
                ? const SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white,
                    ),
                  )
                : Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800,
                      fontSize: 13,
                    )),
            ),
          ),
        ),
      ),
    ),
  );
}

class _DialogAccountSummary extends StatelessWidget {
  const _DialogAccountSummary({required this.user});
  final Map<String, dynamic> user;
  @override
  Widget build(BuildContext context) => _FrostedPanel(
    padding: const EdgeInsets.all(13),
    radius: 17,
    child: Row(children: [
      _AccountAvatar(lab: user['account_type'] == 'lab'),
      const SizedBox(width: 11),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(user['display_name']?.toString() ?? 'Account',
              style: const TextStyle(color: _AdminColors.ink,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(user['email']?.toString() ?? '',
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _AdminColors.muted, fontSize: 11)),
        ],
      )),
    ]),
  );
}

class _DialogInfo extends StatelessWidget {
  const _DialogInfo({required this.text, required this.icon, this.danger = false});
  final String text;
  final IconData icon;
  final bool danger;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(15),
      color: (danger ? const Color(0xFFFFDFE8) : const Color(0xFFF0E6FF))
          .withOpacity(.75),
      border: Border.all(
        color: (danger ? _AdminColors.rose : _AdminColors.violet).withOpacity(.20),
      ),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 20,
          color: danger ? const Color(0xFFAF2153) : _AdminColors.violet),
      const SizedBox(width: 9),
      Expanded(child: Text(text, style: const TextStyle(
          color: _AdminColors.ink, fontSize: 12, height: 1.4))),
    ]),
  );
}

class _DialogFeedback extends StatelessWidget {
  const _DialogFeedback({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFFFFE8F0).withOpacity(.88),
        border: Border.all(color: const Color(0x77DF4778)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.error_outline_rounded,
            color: Color(0xFFB52258), size: 20),
        const SizedBox(width: 9),
        Expanded(child: Text(message, style: const TextStyle(
          color: Color(0xFF9D1B50), fontSize: 12,
          fontWeight: FontWeight.w600, height: 1.35,
        ))),
      ]),
    ),
  );
}

class _DialogSwitch extends StatelessWidget {
  const _DialogSwitch({
    required this.label, required this.description,
    required this.value, required this.onChanged,
  });
  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(15),
      color: const Color(0xAAFFFFFF),
      border: Border.all(color: const Color(0x66FFFFFF)),
    ),
    child: Row(children: [
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: _AdminColors.ink,
              fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 3),
          Text(description, style: const TextStyle(
              color: _AdminColors.muted, fontSize: 11)),
        ],
      )),
      Switch.adaptive(value: value, onChanged: onChanged,
          activeColor: _AdminColors.violet),
    ]),
  );
}

class _LiquidHistorySheet extends StatelessWidget {
  const _LiquidHistorySheet({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 35, 12, 9),
      child: SizedBox(
        height: height * .79,
        child: _DialogGlassSurface(
          radius: 29,
          child: Column(children: [
            const SizedBox(height: 11),
            Container(width: 42, height: 5,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                color: const Color(0x557C3AED),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 14, 12),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: _AdminColors.accent,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.receipt_long_rounded,
                      color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _AdminColors.ink,
                        fontWeight: FontWeight.w800, fontSize: 19)),
                    const Text('Completed report history',
                      style: TextStyle(color: _AdminColors.muted, fontSize: 12)),
                  ],
                )),
                IconButton(
                  tooltip: 'Close history',
                  icon: const Icon(Icons.close_rounded, color: _AdminColors.ink),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ]),
            ),
            Expanded(child: child),
          ]),
        ),
      ),
    );
  }
}

class _HistoryFeedback extends StatelessWidget {
  const _HistoryFeedback({
    required this.icon, required this.heading,
    required this.description, this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final String heading;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 42, color: _AdminColors.violet),
        const SizedBox(height: 13),
        Text(heading, textAlign: TextAlign.center,
            style: const TextStyle(color: _AdminColors.ink,
                fontWeight: FontWeight.w800, fontSize: 17)),
        const SizedBox(height: 7),
        Text(description, textAlign: TextAlign.center,
            style: const TextStyle(color: _AdminColors.muted, fontSize: 12)),
        if (onAction != null) ...[
          const SizedBox(height: 20),
          _LiquidPrimaryAction(title: actionLabel ?? 'Retry',
              onPressed: onAction),
        ],
      ]),
    ),
  );
}

class _GlassHistoryCount extends StatelessWidget {
  const _GlassHistoryCount({required this.total});
  final int total;
  @override
  Widget build(BuildContext context) => _FrostedPanel(
    radius: 17,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(children: [
      const Icon(Icons.auto_graph_rounded, color: _AdminColors.violet),
      const SizedBox(width: 11),
      Text('$total reports generated',
          style: const TextStyle(color: _AdminColors.ink,
              fontWeight: FontWeight.w800, fontSize: 14)),
    ]),
  );
}

class _HistoryEntry extends StatelessWidget {
  const _HistoryEntry({required this.scanned, required this.date});
  final bool scanned;
  final String date;
  @override
  Widget build(BuildContext context) => _FrostedPanel(
    radius: 17,
    padding: const EdgeInsets.all(13),
    child: Row(children: [
      Container(
        width: 43, height: 43,
        decoration: BoxDecoration(
          color: (scanned ? _AdminColors.violet : _AdminColors.magenta).withOpacity(.11),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(scanned ? Icons.document_scanner_outlined : Icons.edit_note_outlined,
            color: scanned ? _AdminColors.violet : _AdminColors.magenta),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(scanned ? 'Scanned report' : 'Manual report',
            style: const TextStyle(color: _AdminColors.ink,
                fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 4),
          Text(date, style: const TextStyle(color: _AdminColors.muted, fontSize: 11)),
        ],
      )),
    ]),
  );
}

/// Translucent violet-to-rose create button. Only the appearance differs;
/// tapping it still opens the original accountDialog() route.
class _GlassCreateUserButton extends StatelessWidget {
  const _GlassCreateUserButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          boxShadow: [
            BoxShadow(
              color: _AdminColors.magenta.withOpacity(.19),
              blurRadius: 21,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(17),
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(17),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xB4C69AF8),
                        Color(0xAAB977F0),
                        Color(0xB6F49ABB),
                      ],
                    ),
                    border: Border.all(
                      color: const Color(0xDDFFFFFF),
                      width: 1.2,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 13),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.person_add_alt_1_rounded,
                            color: Color(0xFF4C176E), size: 19),
                        SizedBox(width: 9),
                        Text('Add user',
                            style: TextStyle(
                              color: Color(0xFF4C176E),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            )),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

/// Compact screen-local feedback placed immediately above the floating dock.
/// Draws a check stroke after a successful request instead of showing a
/// hard blue/purple Snackbar in an unpredictable ScaffoldMessenger position.
class _GlassFeedbackNotice extends StatelessWidget {
  const _GlassFeedbackNotice({
    required this.message,
    required this.isError,
  });
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 16),
          child: child,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(21),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7D4385).withOpacity(.19),
                blurRadius: 22,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(21),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(21),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isError
                        ? const [Color(0xD5FFF5F7), Color(0xC5FFD3E3)]
                        : const [
                            Color(0xC9FFFFFF),
                            Color(0xBEEFD9FD),
                            Color(0xC5FBE0EE),
                          ],
                  ),
                  border: Border.all(
                    color: const Color(0xEFFFFFFF),
                    width: 1.2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isError)
                        const Icon(Icons.error_outline_rounded,
                            color: Color(0xFFB62756), size: 26)
                      else
                        _AnimatedGlassTick(reduceMotion: reduceMotion),
                      const SizedBox(width: 11),
                      Flexible(
                        child: Text(message,
                          style: TextStyle(
                            color: isError
                                ? const Color(0xFF90264A)
                                : _AdminColors.ink,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedGlassTick extends StatelessWidget {
  const _AnimatedGlassTick({required this.reduceMotion});
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => Transform.scale(
          scale: .86 + .14 * value,
          child: CustomPaint(
            size: const Size(26, 26),
            painter: _GlassTickPainter(progress: value),
          ),
        ),
      );
}

class _GlassTickPainter extends CustomPainter {
  const _GlassTickPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawCircle(
      outer.center,
      size.width / 2,
      Paint()
        ..shader = _AdminColors.accent.createShader(outer),
    );
    final tick = Path()
      ..moveTo(size.width * .25, size.height * .52)
      ..lineTo(size.width * .43, size.height * .69)
      ..lineTo(size.width * .77, size.height * .33);
    final pathMetric = tick.computeMetrics().first;
    canvas.drawPath(
      pathMetric.extractPath(0, pathMetric.length * progress),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2.7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _GlassTickPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// Private widgets below are local to SuperadminView; no global app theming,
// shared services, routing, or data handling is modified by this design.
class _AdminColors {
  static const violet = Color(0xFF7C3AED);
  static const magenta = Color(0xFFC026D3);
  static const rose = Color(0xFFFB7185);
  static const ink = Color(0xFF281733);
  static const muted = Color(0xFF77687F);
  static const accent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [violet, magenta, rose],
  );
}

class _AdminCanvas extends StatelessWidget {
  const _AdminCanvas({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFBF9FC),
                  Color(0xFFF7EFFC),
                  Color(0xFFFFF1F5),
                ],
              ),
            ),
          ),
          const Positioned(
            top: -210,
            left: -175,
            child: _AdminOrb(
              size: 430,
              color: Color(0x557C3AED),
            ),
          ),
          const Positioned(
            top: 185,
            right: -190,
            child: _AdminOrb(
              size: 440,
              color: Color(0x44E11D48),
            ),
          ),
          const Positioned(
            bottom: -260,
            left: -50,
            child: _AdminOrb(
              size: 460,
              color: Color(0x35C026D3),
            ),
          ),
          child,
        ],
      );
}

class _AdminOrb extends StatelessWidget {
  const _AdminOrb({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color, color.withOpacity(0)],
            ),
          ),
        ),
      );
}

class _FrostedPanel extends StatelessWidget {
  const _FrostedPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF744982).withOpacity(.105),
              offset: const Offset(0, 13),
              blurRadius: 34,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(.73),
                    Colors.white.withOpacity(.39),
                  ],
                ),
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: Colors.white.withOpacity(.87)),
              ),
              child: Stack(
                children: [
                  // A specular highlight along the upper surface gives the
                  // card a curved, refractive-looking illuminated edge.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(radius),
                          gradient: RadialGradient(
                            center: const Alignment(-.88, -1),
                            radius: 1.32,
                            colors: [
                              Colors.white.withOpacity(.48),
                              Colors.white.withOpacity(.08),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(padding: padding, child: child),
                ],
              ),
            ),
          ),
        ),
      );
}

/// Morphing glass droplet, inspired by optical highlights and the stretched
/// lens behavior in iOS dock references. This remains a Flutter approximation.
class _LiquidGlassLens extends StatelessWidget {
  const _LiquidGlassLens({required this.morph});
  final double morph;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFAC55C4).withOpacity(.10 + morph * .11),
              blurRadius: 12 + morph * 8,
              spreadRadius: -2,
            ),
            BoxShadow(
              color: const Color(0xFF5A315C).withOpacity(.10),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipPath(
          clipper: _FluidLensClipper(morph),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 19, sigmaY: 19),
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xADFFFFFF),
                        Color(0x64FFE8FF),
                        Color(0x4FD2AFE5),
                        Color(0x9BFFFFFF),
                      ],
                      stops: [0, .30, .71, 1],
                    ),
                  ),
                ),
                const IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(-.73, -.95),
                        radius: 1.28,
                        colors: [
                          Color(0xABFFFFFF),
                          Color(0x28FFFFFF),
                          Color(0x00FFFFFF),
                        ],
                      ),
                    ),
                  ),
                ),
                IgnorePointer(
                  child: CustomPaint(
                    painter: _LiquidLensRim(morph: morph),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

// A slightly asymmetric, elastic capsule instead of a sliding rectangle.
class _FluidLensClipper extends CustomClipper<Path> {
  const _FluidLensClipper(this.morph);
  final double morph;

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final r = h * .47;
    final pull = morph * 4.0;
    return Path()
      ..moveTo(r, 1)
      ..cubicTo(w * .34, 1 - pull * .22, w * .69, 1 + pull * .26,
          w - r, 1)
      ..cubicTo(w - r * .20, 1 - pull * .45,
          w + pull * .55, h * .24, w - 1, h / 2)
      ..cubicTo(w + pull * .55, h * .76,
          w - r * .15, h + pull * .20, w - r, h - 1)
      ..cubicTo(w * .68, h - 1 - pull * .25,
          w * .35, h - 1 + pull * .25, r, h - 1)
      ..cubicTo(r * .18, h + pull * .25,
          -pull * .40, h * .76, 1, h / 2)
      ..cubicTo(-pull * .40, h * .24, r * .18, 1 - pull * .24, r, 1)
      ..close();
  }

  @override
  bool shouldReclip(covariant _FluidLensClipper oldClipper) =>
      oldClipper.morph != morph;
}

/// A thin fading fluid bridge, visible only mid-movement between tab centers.
class _DockFluidTrailPainter extends CustomPainter {
  const _DockFluidTrailPainter({
    required this.position,
    required this.cell,
    required this.strength,
  });
  final double position;
  final double cell;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    if (strength < .001) return;
    // Use the nearest anchored tab as the tail. This keeps the fluid
    // connection natural when swiping either left or right.
    final from = position.roundToDouble();
    final x1 = 5 + cell * (from + .5);
    final x2 = 5 + cell * (position + .5);
    final y = size.height / 2;
    final bend = 5 + 5 * strength;
    final path = Path()
      ..moveTo(x1, y - 2.5)
      ..cubicTo(x1 + (x2 - x1) * .35, y - bend,
          x1 + (x2 - x1) * .65, y - bend, x2, y - 6)
      ..quadraticBezierTo(x2 + 5, y, x2, y + 6)
      ..cubicTo(x1 + (x2 - x1) * .65, y + bend,
          x1 + (x2 - x1) * .35, y + bend, x1, y + 2.5)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFFB979D4).withOpacity(.10 * strength),
            const Color(0xFFFFE4FD).withOpacity(.58 * strength),
            const Color(0xFFBF72D2).withOpacity(.21 * strength),
          ],
        ).createShader(Rect.fromLTWH(
            math.min(x1, x2), y - 14, math.max(1.0, (x2 - x1).abs()), 28)),
    );
  }

  @override
  bool shouldRepaint(covariant _DockFluidTrailPainter oldDelegate) =>
      oldDelegate.position != position ||
      oldDelegate.cell != cell ||
      oldDelegate.strength != strength;
}

class _LiquidLensRim extends CustomPainter {
  const _LiquidLensRim({required this.morph});
  final double morph;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 22 || size.height < 22) return;
    final w = size.width;
    final h = size.height;
    final top = Path()
      ..moveTo(8, h * .44)
      ..cubicTo(7, h * .13, w * .21, 3, w * .43, 3)
      ..cubicTo(w * .72, 3 - morph, w * .85, 7, w - 8, h * .30);
    canvas.drawPath(
      top,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7 + morph * .7
        ..strokeCap = StrokeCap.round
        ..shader = const LinearGradient(
          colors: [Color(0x12FFFFFF), Color(0xEEFFFFFF), Color(0x33FFFFFF)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
    final bottom = Path()
      ..moveTo(10, h * .73)
      ..cubicTo(w * .25, h - 3, w * .76, h - 3, w - 10, h * .73);
    canvas.drawPath(
      bottom,
      Paint()
        ..color = const Color(0x9AFFFFFF)
        ..strokeWidth = 1.1
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _LiquidLensRim oldDelegate) =>
      oldDelegate.morph != morph;
}

class _TopGlassIcon extends StatelessWidget {
  const _TopGlassIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: SizedBox(
          width: 43,
          height: 43,
          child: _FrostedPanel(
            radius: 14,
            padding: EdgeInsets.zero,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: onTap,
                child: Icon(icon, color: _AdminColors.ink, size: 20),
              ),
            ),
          ),
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _AdminColors.ink,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: -.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: _AdminColors.muted,
              fontSize: 12,
            ),
          ),
        ],
      );
}

class _MetricGlass extends StatelessWidget {
  const _MetricGlass({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => _FrostedPanel(
        padding: const EdgeInsets.all(15),
        radius: 20,
        child: SizedBox(
          height: 110,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _AdminColors.violet.withOpacity(.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: _AdminColors.violet, size: 19),
              ),
              const Spacer(),
              Text(
                value,
                style: const TextStyle(
                  color: _AdminColors.ink,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: _AdminColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
}

class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({required this.lab});
  final bool lab;

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            colors: lab
                ? const [Color(0xFFFB7185), Color(0xFFC026D3)]
                : const [Color(0xFF7C3AED), Color(0xFFB45CF0)],
          ),
        ),
        child: Icon(
          lab ? Icons.science_outlined : Icons.person_outline_rounded,
          color: Colors.white,
          size: 24,
        ),
      );
}

class _StatusCapsule extends StatelessWidget {
  const _StatusCapsule(this.label, {required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(.095),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: color.withOpacity(.17)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 10.5,
          ),
        ),
      );
}

class _GlassAction extends StatelessWidget {
  const _GlassAction({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.color,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(13),
              child: Container(
                constraints: const BoxConstraints(minHeight: 42),
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withOpacity(.19),
                      color.withOpacity(.09),
                    ],
                  ),
                  border: Border.all(color: color.withOpacity(.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: 7),
                    Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
