import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hemo_guard/app/data/settings.dart';
import 'package:hemo_guard/app/data/settings_store.dart';
import 'package:hemo_guard/app/routes/app_pages.dart';
import 'package:hemo_guard/app/services/auth_service.dart';
import 'package:hemo_guard/app/services/system_appearance.dart';

/// Design tokens shared by regular-account screens. Scoped deliberately: the
/// login, superadmin, legacy global AppTheme, and all APIs are left untouched.
class UserGlassColors {
  UserGlassColors._();
  static const violet = Color(0xFF7C3AED);
  static const magenta = Color(0xFFC026D3);
  static const rose = Color(0xFFFB7185);
  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [violet, magenta, rose],
  );

  static bool get dark {
    final preference = SettingsStore.shared.current.themeMode;
    if (preference == AppThemeMode.dark) return true;
    if (preference == AppThemeMode.light) return false;
    return HemoGuardSystemAppearance.isDark;
  }

  static Color get ink => dark ? const Color(0xFFF5F0FA) : const Color(0xFF281733);
  static Color get muted => dark ? const Color(0xFFB9AFC1) : const Color(0xFF786780);
  static Color get hint => dark ? const Color(0xFFB7A1C4) : const Color(0xFF8A7A93);
  static Color get border => dark ? const Color(0x42FFFFFF) : const Color(0xC4FFFFFF);
  static Color get surface => dark ? const Color(0xC616121D) : const Color(0xC6FFFFFF);
}

/// Rebuilds the user-only design when Android appearance or the existing
/// settings theme selector changes. Does not alter the global application theme.
class UserGlassScope extends StatefulWidget {
  const UserGlassScope({super.key, required this.child});
  final Widget child;
  @override
  State<UserGlassScope> createState() => _UserGlassScopeState();
}

class _UserGlassScopeState extends State<UserGlassScope> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HemoGuardSystemAppearance.addListener(_changed);
    SettingsStore.shared.appearanceChanges.addListener(_changed);
    HemoGuardSystemAppearance.refresh();
  }

  void _changed() { if (mounted) setState(() {}); }

  @override
  void didChangePlatformBrightness() { HemoGuardSystemAppearance.refresh(); }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) HemoGuardSystemAppearance.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HemoGuardSystemAppearance.removeListener(_changed);
    SettingsStore.shared.appearanceChanges.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = UserGlassColors.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: UserGlassColors.violet,
      brightness: dark ? Brightness.dark : Brightness.light,
      primary: UserGlassColors.violet,
    );
    final base = Theme.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: dark ? const Color(0xFF09080C) : const Color(0xFFF9F3FC),
        systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      ),
      child: Theme(
        data: base.copyWith(
          brightness: dark ? Brightness.dark : Brightness.light,
          colorScheme: scheme,
          scaffoldBackgroundColor: Colors.transparent,
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.transparent,
            foregroundColor: UserGlassColors.ink,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: dark ? const Color(0xC821182C) : const Color(0xC9FFFFFF),
            hintStyle: TextStyle(color: UserGlassColors.hint),
            labelStyle: TextStyle(color: UserGlassColors.muted),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(17)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(17),
              borderSide: BorderSide(color: UserGlassColors.violet.withOpacity(dark ? .48 : .18)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(17),
              borderSide: const BorderSide(color: UserGlassColors.violet, width: 1.6),
            ),
          ),
          cardTheme: CardThemeData(
            color: UserGlassColors.surface,
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: UserGlassColors.border)),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
            backgroundColor: UserGlassColors.violet,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 49),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          )),
          outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
            foregroundColor: UserGlassColors.dark ? const Color(0xFFE0C7FF) : UserGlassColors.violet,
            side: BorderSide(color: UserGlassColors.violet.withOpacity(.50)),
            minimumSize: const Size(0, 49),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          )),
        ),
        child: UserGlassBackdrop(child: widget.child),
      ),
    );
  }
}

/// Identical light/dark lavender-rose canvas language to Login/Superadmin.
class UserGlassBackdrop extends StatelessWidget {
  const UserGlassBackdrop({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: UserGlassColors.dark
          ? const [Color(0xFF030303), Color(0xFF090909), Color(0xFF141018)]
          : const [Color(0xFFFBF9FC), Color(0xFFF5ECFC), Color(0xFFFFF0F6)],
      ))),
      Positioned(top: -130, left: -160, child: _Orb(
        size: 370, color: UserGlassColors.dark ? const Color(0x237C3AED) : const Color(0x497C3AED))),
      Positioned(top: 190, right: -190, child: _Orb(
        size: 420, color: UserGlassColors.dark ? const Color(0x22E14D87) : const Color(0x42FB7185))),
      Positioned(bottom: -200, left: -110, child: _Orb(
        size: 400, color: UserGlassColors.dark ? const Color(0x20C026D3) : const Color(0x36C026D3))),
      child,
    ],
  );
}

class _Orb extends StatelessWidget {
  const _Orb({required this.size, required this.color});
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => IgnorePointer(child: Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color, color.withOpacity(0)])),
  ));
}

class UserGlassPanel extends StatelessWidget {
  const UserGlassPanel({super.key, required this.child,
    this.padding = const EdgeInsets.all(18), this.radius = 24});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [BoxShadow(
        color: UserGlassColors.dark ? const Color(0x4D000000) : const Color(0x25744D8A),
        blurRadius: 27, offset: const Offset(0, 12)),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: UserGlassColors.border),
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: UserGlassColors.dark
                ? const [Color(0xD126202B), Color(0xAE121014)]
                : const [Color(0xDAFFFFFF), Color(0x8AFFFFFF)]),
          ),
          child: Stack(children: [
            Positioned.fill(child: IgnorePointer(child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                gradient: RadialGradient(
                  center: const Alignment(-.85, -1), radius: 1.4,
                  colors: UserGlassColors.dark
                    ? const [Color(0x24FFFFFF), Color(0x00FFFFFF)]
                    : const [Color(0x8CFFFFFF), Color(0x00FFFFFF)],
                ),
              ),
            ))),
            Padding(padding: padding, child: child),
          ]),
        ),
      ),
    ),
  );
}

/// A user-only floating navigation shell. Scanner remains a separate route so
/// the camera and fixed-height CBC editor retain their existing mechanics.
class UserGlassFrame extends StatelessWidget {
  const UserGlassFrame({super.key, required this.title, required this.child,
    required this.selectedIndex, this.subtitle = 'YOUR WORKSPACE',
    this.onRefresh, this.canGoBack = false});
  final String title;
  final String subtitle;
  final Widget child;
  final int selectedIndex;
  final VoidCallback? onRefresh;
  final bool canGoBack;

  @override
  Widget build(BuildContext context) => UserGlassScope(
    child: Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: Stack(children: [
        SafeArea(bottom: false, child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(19, 13, 19, 11),
            child: Row(children: [
              if (canGoBack) ...[
                _GlassIcon(icon: Icons.arrow_back_rounded, tooltip: 'Back', onTap: () => Get.back()),
                const SizedBox(width: 10),
              ] else ...[
                Container(width: 45, height: 45,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [BoxShadow(color: UserGlassColors.violet.withOpacity(.24), blurRadius: 16, offset: const Offset(0, 7))]),
                  child: Image.asset("assets/img.png")),
                const SizedBox(width: 12),
              ],
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(subtitle, style: TextStyle(color: UserGlassColors.muted,
                  fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.8)),
                const SizedBox(height: 2),
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: UserGlassColors.ink, fontSize: 22,
                    fontWeight: FontWeight.w800, letterSpacing: -.65)),
              ])),
              if (onRefresh != null) ...[
                _GlassIcon(icon: Icons.refresh_rounded, tooltip: 'Refresh', onTap: onRefresh!),
                const SizedBox(width: 8),
              ],
              _GlassIcon(icon: Icons.logout_rounded, tooltip: 'Log out',
                onTap: () => Get.find<AuthService>().logout()),
            ]),
          ),
          Expanded(child: Padding(
            padding: const EdgeInsets.only(bottom: 98),
            child: child,
          )),
        ])),
        Positioned(left: 0, right: 0, bottom: 0,
          child: SafeArea(top: false,
            minimum: const EdgeInsets.only(bottom: 15),
            child: Center(child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 324),
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
                child: UserGlassDock(selectedIndex: selectedIndex)),
            )),
          ),
        ),
      ]),
    ),
  );
}

class _GlassIcon extends StatelessWidget {
  const _GlassIcon({required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true, label: tooltip,
    child: Tooltip(message: tooltip,
      child: UserGlassPanel(padding: EdgeInsets.zero, radius: 16,
        child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16),
          child: SizedBox(width: 40, height: 40, child: Icon(icon,
            size: 20, color: UserGlassColors.ink))))),
  );
}

class UserGlassDock extends StatelessWidget {
  const UserGlassDock({super.key, required this.selectedIndex});
  final int selectedIndex;
  @override
  Widget build(BuildContext context) {
    const labels = ['Home', 'Scan', 'Patients', 'Settings'];
    const icons = [Icons.dashboard_rounded, Icons.document_scanner_outlined,
      Icons.folder_shared_outlined, Icons.tune_rounded];
    final dark = UserGlassColors.dark;
    return Container(
      height: 62,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(33),
        boxShadow: [BoxShadow(color: dark ? const Color(0x65000000) : const Color(0x454D224F),
          blurRadius: 27, spreadRadius: -6, offset: const Offset(0, 11))]),
      child: ClipRRect(borderRadius: BorderRadius.circular(33),
        child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 23, sigmaY: 23),
          child: LayoutBuilder(builder: (context, box) {
            final cell = (box.maxWidth - 10) / 4;
            return Stack(children: [
              Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(33),
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: dark
                    ? const [Color(0x50FFFFFF), Color(0x36101010), Color(0x4A231B2C)]
                    : const [Color(0xA6FFFFFF), Color(0x6EAD83B8), Color(0x698C648D)]),
                border: Border.all(color: UserGlassColors.border, width: 1.1)))),
              // The specular lens mirrors the Superadmin's floating dock.
              Positioned(top: 4, bottom: 4,
                left: 5 + cell * selectedIndex + 2,
                width: cell - 4,
                child: Container(decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(29),
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: dark
                      ? const [Color(0x77EABFFF), Color(0x556D3D8D), Color(0x447B3663)]
                      : const [Color(0xEEFFFFFF), Color(0xB8E8C9FA), Color(0xA7F7B5D7)]),
                  border: Border.all(color: Colors.white.withOpacity(dark ? .32 : .82)),
                  boxShadow: [BoxShadow(color: UserGlassColors.violet.withOpacity(.20), blurRadius: 13)]))),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Row(children: [for (var i = 0; i < 4; i++) Expanded(
                  child: Semantics(button: true, selected: selectedIndex == i, label: '${labels[i]} tab',
                    child: Material(color: Colors.transparent,
                      child: InkWell(borderRadius: BorderRadius.circular(30),
                        onTap: () => _select(context, i),
                        child: SizedBox(height: 62, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(icons[i], size: selectedIndex == i ? 23 : 20,
                            color: selectedIndex == i
                              ? (dark ? const Color(0xFFFFD7FC) : UserGlassColors.violet)
                              : (dark ? const Color(0xFFB5AABF) : const Color(0xFF65546A))),
                          const SizedBox(height: 2),
                          Text(labels[i], maxLines: 1, overflow: TextOverflow.fade,
                            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800,
                              color: selectedIndex == i
                                ? (dark ? const Color(0xFFFFD7FC) : UserGlassColors.violet)
                                : (dark ? const Color(0xFFB5AABF) : const Color(0xFF65546A)))),
                        ]))),
                      ),
                    ),
                  ),
                ]),
              ),
            ]);
          }),
        ),
      ),
    );
  }

  void _select(BuildContext context, int index) {
    // Allow reselecting Patients to leave a nested patient-history route.
    switch (index) {
      case 0:
        Get.offAllNamed(Routes.HOME);
        break;
      case 1:
        _scanMenu(context);
        break;
      case 2:
        Get.offAllNamed(Routes.PATIENTS);
        break;
      case 3:
        Get.offAllNamed(Routes.SETTINGS);
        break;
    }
  }

  void _scanMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Padding(padding: const EdgeInsets.all(16),
          child: UserGlassPanel(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Start a screening', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: UserGlassColors.ink)),
            const SizedBox(height: 5),
            Text('Choose how to enter CBC results', style: TextStyle(color: UserGlassColors.muted)),
            const SizedBox(height: 16),
            ListTile(leading: const Icon(Icons.document_scanner_outlined, color: UserGlassColors.violet),
              title: const Text('Scan CBC report'), subtitle: const Text('Camera or gallery'),
              onTap: () { Navigator.of(sheetContext).pop(); Get.toNamed(Routes.SCANNER, arguments: {'type': 'image'}); }),
            ListTile(leading: const Icon(Icons.keyboard_alt_outlined, color: UserGlassColors.violet),
              title: const Text('Enter CBC manually'), subtitle: const Text('Type the seven values'),
              onTap: () { Navigator.of(sheetContext).pop(); Get.toNamed(Routes.SCANNER, arguments: {'type': 'text'}); }),
          ])),
        ),
      ),
    );
  }
}
