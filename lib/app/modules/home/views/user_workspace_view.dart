import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../home/views/home_view.dart';
import '../../home/widgets/user_glass.dart';
import '../../patients/views/patients_view.dart';
import '../../settings/views/settings_view.dart';

/// One persistent, swipeable workspace: the page motion and glass dock are
/// controlled by the SAME TabController (as on the superadmin screen).
/// Scan remains a separate camera route, opened from the central dock action.
class UserWorkspaceView extends StatefulWidget {
  const UserWorkspaceView({super.key, this.initialTab = 0});
  final int initialTab; // 0 Home, 1 Patients, 2 Settings.

  @override
  State<UserWorkspaceView> createState() => _UserWorkspaceViewState();
}

class _UserWorkspaceViewState extends State<UserWorkspaceView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final GlobalKey<PatientsViewState> _patientsKey = GlobalKey<PatientsViewState>();
  late int _previousTab;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 3,
      initialIndex: widget.initialTab.clamp(0, 2).toInt(),
      vsync: this,
    );
    _previousTab = _tabs.index;
    _tabs.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    // Refresh the existing patient list on return from a new CBC screening.
    // Keeping pages alive preserves search and scroll state while navigating.
    if (_tabs.index == _previousTab) return;
    _previousTab = _tabs.index;
    if (_tabs.index == 1) _patientsKey.currentState?.refresh();
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    if (index < 0 || index > 2) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    _tabs.animateTo(index,
      duration: reducedMotion ? Duration.zero : const Duration(milliseconds: 540),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const _KeepAliveTab(child: HomeView(embedded: true)),
      _KeepAliveTab(child: PatientsView(key: _patientsKey, embedded: true)),
      const _KeepAliveTab(child: SettingsView(embedded: true)),
    ];
    return UserWorkspaceNavigation(
      selectTab: _selectTab,
      child: UserGlassFrame(
        title: 'Dashboard',
        subtitle: 'HEMOGUARD',
        selectedIndex: widget.initialTab == 0 ? 0 : widget.initialTab + 1,
        dockAnimation: _tabs.animation,
        tabTitles: const ['Dashboard', 'Patient reports', 'Settings'],
        tabSubtitles: const [
          'HEMOGUARD', 'HEMOGUARD  /  HISTORY', 'HEMOGUARD  /  PREFERENCES',
        ],
        onTabSelected: (dockIndex) {
          switch (dockIndex) {
            case 0: _selectTab(0); break;
            case 2: _selectTab(1); break;
            case 3: _selectTab(2); break;
          }
        },
        onRefresh: () => _patientsKey.currentState?.refresh(),
        child: TabBarView(
          controller: _tabs,
          physics: const BouncingScrollPhysics(),
          children: [
            for (var i = 0; i < pages.length; i++)
              _GlassPageFade(animation: _tabs.animation!, tab: i, child: pages[i]),
          ],
        ),
      ),
    );
  }
}

class _KeepAliveTab extends StatefulWidget {
  const _KeepAliveTab({required this.child});
  final Widget child;
  @override
  State<_KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<_KeepAliveTab>
    with AutomaticKeepAliveClientMixin<_KeepAliveTab> {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _GlassPageFade extends StatelessWidget {
  const _GlassPageFade({required this.animation, required this.tab, required this.child});
  final Animation<double> animation;
  final int tab;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    child: child,
    builder: (context, child) {
      final distance = (animation.value - tab).abs().clamp(0.0, 1.0).toDouble();
      return Opacity(
        opacity: MediaQuery.of(context).disableAnimations ? 1 : 1 - distance * .13,
        child: child,
      );
    },
  );
}
