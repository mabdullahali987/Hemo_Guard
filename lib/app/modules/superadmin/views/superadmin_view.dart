import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../services/auth_service.dart';
import '../../../services/api_client.dart';
import '../../../services/system_appearance.dart';


part 'superadmin_parts/dock.dart';
part 'superadmin_parts/overview.dart';
part 'superadmin_parts/accounts.dart';
part 'superadmin_parts/reports.dart';
part 'superadmin_parts/clinical_reports.dart';
part 'superadmin_parts/audit.dart';
part 'superadmin_parts/account_actions.dart';
part 'superadmin_parts/dialog_surface.dart';
part 'superadmin_parts/account_editor.dart';
part 'superadmin_parts/dialog_controls.dart';
part 'superadmin_parts/history_widgets.dart';
part 'superadmin_parts/feedback_widgets.dart';
part 'superadmin_parts/glass_primitives.dart';
part 'superadmin_parts/liquid_lens.dart';
part 'superadmin_parts/common_widgets.dart';

/// Native superadmin panel, backed by the exact same API as the web portal.
class SuperadminView extends StatefulWidget {
  const SuperadminView({super.key});
  @override
  State<SuperadminView> createState() => _SuperadminViewState();
}

class _SuperadminViewState extends State<SuperadminView> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
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
    WidgetsBinding.instance.addObserver(this);
    HemoGuardSystemAppearance.addListener(_onSystemAppearanceChanged);
    _refreshSystemAppearance();
    _tabs = TabController(length: 4, vsync: this);
    refresh();
  }

  void _onSystemAppearanceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refreshSystemAppearance() async {
    await HemoGuardSystemAppearance.refresh();
    if (mounted) setState(() {});
  }

  // Refresh screen-local glass colors after OS appearance changes.
  @override
  void didChangePlatformBrightness() {
    _refreshSystemAppearance();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _refreshSystemAppearance();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HemoGuardSystemAppearance.removeListener(_onSystemAppearanceChanged);
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
    // Listen to OS light/dark mode while leaving HemoGuard's other pages alone.
    final dark = HemoGuardSystemAppearance.isDark;
    final base = Theme.of(context);
    final localTheme = base.copyWith(
      brightness: dark ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme.fromSeed(
          seedColor: _AdminColors.violet,
          brightness: dark ? Brightness.dark : Brightness.light),
      scaffoldBackgroundColor: Colors.transparent,
      dialogTheme: DialogThemeData(
        backgroundColor: dark ? const Color(0xFF23162B) : const Color(0xFFFDF7FD),
        surfaceTintColor: Colors.transparent,
        elevation: 14,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(27),
          side: BorderSide(color: dark ? const Color(0x55FFFFFF) : Colors.white, width: 1.2),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xB820142B) : const Color(0xB8FFFFFF),
        labelStyle: TextStyle(color: _AdminColors.muted, fontWeight: FontWeight.w600),
        floatingLabelStyle: const TextStyle(color: _AdminColors.violet, fontWeight: FontWeight.w800),
        hintStyle: TextStyle(color: dark ? const Color(0xFFB59DBB) : const Color(0xFF9C8CA3)),
        errorStyle: TextStyle(color: dark ? const Color(0xFFFF9AB8) : const Color(0xFFB52258), fontWeight: FontWeight.w600),
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      ),
      child: Theme(
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
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: _AdminColors.magenta.withOpacity(.19),
                              blurRadius: 15,
                              offset: const Offset(0, 7),
                            ),
                          ],
                        ), // Adds a nice breathing room inside the gradient box
                          child: Image.asset(
                            "assets/img.png",
                            fit: BoxFit.fill,
                        )
                      ),
                      const SizedBox(width: 12),
                      Expanded(
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
    ),
    );
  }

  // Forward existing behavior to the original implementations, organized
  // by screen concern. No UI or business logic is changed by these delegates.
  Widget _navigation() => _SuperadminDock(this)._navigation();
  Widget _fadeTab(int index, Widget child) =>
      _SuperadminDock(this)._fadeTab(index, child);
  Widget _overview() => _SuperadminOverview(this)._overview();
  Widget _accounts() => _SuperadminAccounts(this)._accounts();
  Widget _reports() => _SuperadminReports(this)._reports();
  Future<void> _showReportHistory(Map<String, dynamic> account) =>
      _SuperadminReports(this)._showReportHistory(account);
  Widget _audit() => _SuperadminAudit(this)._audit();
  Future<void> deleteAccount(Map<String, dynamic> user) =>
      _SuperadminAccountActions(this).deleteAccount(user);
  Future<void> accountDialog({Map<String, dynamic>? existing}) =>
      _SuperadminAccountActions(this).accountDialog(existing: existing);
  Future<void> planDialog(Map<String, dynamic> user) =>
      _SuperadminAccountActions(this).planDialog(user);
}
