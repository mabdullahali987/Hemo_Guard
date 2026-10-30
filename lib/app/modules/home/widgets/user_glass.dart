import 'dart:ui';
import 'dart:math' as math;

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

  static Color get ink => dark ? const Color(0xFFF4F4F4) : const Color(0xFF281733);
  static Color get muted => dark ? const Color(0xFFB0B0B0) : const Color(0xFF77687F);
  static Color get hint => dark ? const Color(0xFFB59DBB) : const Color(0xFF9C8CA3);
  static Color get border => dark ? const Color(0x30FFFFFF) : const Color(0xDEFFFFFF);
  static Color get surface => dark ? const Color(0xD1171717) : const Color(0xBCFFFFFF);
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
        systemNavigationBarColor: dark ? const Color(0xFF090909) : const Color(0xFFF7EFFC),
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
            fillColor: dark ? const Color(0xB8111111) : const Color(0xB8FFFFFF),
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
          ? const [Color(0xFF030303), Color(0xFF090909), Color(0xFF111111)]
          : const [Color(0xFFFBF9FC), Color(0xFFF7EFFC), Color(0xFFFFF1F5)],
      ))),
      Positioned(top: -210, left: -175, child: _Orb(
        size: 430, color: UserGlassColors.dark ? const Color(0x14FFFFFF) : const Color(0x557C3AED))),
      Positioned(top: 185, right: -190, child: _Orb(
        size: 440, color: UserGlassColors.dark ? const Color(0x16FF8EA7) : const Color(0x44E11D48))),
      Positioned(bottom: -260, left: -50, child: _Orb(
        size: 460, color: UserGlassColors.dark ? const Color(0x10FFFFFF) : const Color(0x35C026D3))),
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
        color: UserGlassColors.dark ? const Color(0x54000000) : const Color(0x1B744D8A),
        blurRadius: 34, offset: const Offset(0, 13)),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: UserGlassColors.border),
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: UserGlassColors.dark
                ? const [Color(0xD1171717), Color(0x9E0E0E0E)]
                : const [Color(0xBAFFFFFF), Color(0x64FFFFFF)]),
          ),
          child: Stack(children: [
            Positioned.fill(child: IgnorePointer(child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                gradient: RadialGradient(
                  center: const Alignment(-.85, -1), radius: 1.4,
                  colors: UserGlassColors.dark
                    ? const [Color(0x24FFFFFF), Color(0x00FFFFFF)]
                    : const [Color(0xABFFFFFF), Color(0x00FFFFFF)],
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


/// Allows dashboard shortcuts to select a nearby workspace tab without
/// changing GetX routes, rebuilding the whole page or flashing the route canvas.
class UserWorkspaceNavigation extends InheritedWidget {
  const UserWorkspaceNavigation({super.key, required this.selectTab, required super.child});
  final ValueChanged<int> selectTab;

  static UserWorkspaceNavigation? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<UserWorkspaceNavigation>();

  @override
  bool updateShouldNotify(UserWorkspaceNavigation oldWidget) =>
      selectTab != oldWidget.selectTab;
}

/// Shared background and header for the regular account workspace.
/// Its persistent dock and content use the same animation when hosted by
/// UserWorkspaceView; patient detail pages can continue using it standalone.
class UserGlassFrame extends StatelessWidget {
  const UserGlassFrame({super.key, required this.title, required this.child,
    required this.selectedIndex, this.subtitle = 'YOUR WORKSPACE',
    this.onRefresh, this.canGoBack = false, this.dockAnimation,
    this.onTabSelected, this.tabTitles, this.tabSubtitles});

  final String title;
  final String subtitle;
  final Widget child;
  final int selectedIndex;
  final VoidCallback? onRefresh;
  final bool canGoBack;
  final Animation<double>? dockAnimation;
  final ValueChanged<int>? onTabSelected;
  final List<String>? tabTitles;
  final List<String>? tabSubtitles;

  @override
  Widget build(BuildContext context) => UserGlassScope(
    child: Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: Stack(children: [
        SafeArea(bottom: false, child: Column(children: [
          AnimatedBuilder(
            animation: dockAnimation ?? const AlwaysStoppedAnimation<double>(0),
            builder: (context, _) {
              final pageIndex = dockAnimation == null ? 0
                  : dockAnimation!.value.round().clamp(0, 2).toInt();
              final activeTitle = tabTitles == null ? title : tabTitles![pageIndex];
              final activeSubtitle = tabSubtitles == null ? subtitle : tabSubtitles![pageIndex];
              final showRefresh = onRefresh != null &&
                  (dockAnimation == null || pageIndex == 1);
              return Padding(
                padding: const EdgeInsets.fromLTRB(19, 13, 19, 11),
                child: Row(children: [
                  if (canGoBack) ...[
                    _GlassIcon(icon: Icons.arrow_back_rounded, tooltip: 'Back',
                        onTap: () => Get.back()),
                    const SizedBox(width: 10),
                  ] else ...[
                    Container(width: 45, height: 45,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [BoxShadow(
                          color: UserGlassColors.magenta.withOpacity(.19),
                          blurRadius: 15, offset: const Offset(0, 7))]),
                      child: Image.asset('assets/img.png', fit: BoxFit.fill)),
                    const SizedBox(width: 12),
                  ],
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(activeSubtitle, style: TextStyle(color: UserGlassColors.muted,
                      fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.8)),
                    const SizedBox(height: 2),
                    Text(activeTitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: UserGlassColors.ink, fontSize: 22,
                        fontWeight: FontWeight.w800, letterSpacing: -.65)),
                  ])),
                  if (showRefresh) ...[
                    _GlassIcon(icon: Icons.refresh_rounded,
                      tooltip: 'Refresh', onTap: onRefresh!),
                    const SizedBox(width: 8),
                  ],
                  _GlassIcon(icon: Icons.logout_rounded, tooltip: 'Log out',
                    onTap: () => Get.find<AuthService>().logout()),
                ]),
              );
            },
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
                child: UserGlassDock(selectedIndex: selectedIndex,
                  animation: dockAnimation, onSelect: onTabSelected)),
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
        child: Material(color: Colors.transparent,
          child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16),
            child: SizedBox(width: 40, height: 40, child: Icon(icon,
              size: 20, color: UserGlassColors.ink)))))),
  );
}

/// Identical navigation principle to Superadmin: the same animation drives
/// horizontal page motion, selected icon colors and the liquid highlight.
class UserGlassDock extends StatelessWidget {
  const UserGlassDock({super.key, required this.selectedIndex,
    this.animation, this.onSelect});
  final int selectedIndex;
  final Animation<double>? animation;
  final ValueChanged<int>? onSelect;

  static const _labels = ['Home', 'Scan', 'Patients', 'Settings'];
  static const _icons = [Icons.dashboard_rounded, Icons.document_scanner_outlined,
    Icons.folder_shared_outlined, Icons.tune_rounded];

  @override
  Widget build(BuildContext context) {
    final dark = UserGlassColors.dark;
    final reduced = MediaQuery.of(context).disableAnimations;
    return LayoutBuilder(builder: (context, constraints) {
      const height = 59.0;
      final cell = (constraints.maxWidth - 10) / 4;
      return Container(
        height: height,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(31),
          boxShadow: [
            BoxShadow(color: (dark ? Colors.black : const Color(0xFF4D224F))
              .withOpacity(dark ? .34 : .18), blurRadius: 26,
              spreadRadius: -6, offset: const Offset(0, 11)),
            BoxShadow(color: (dark ? const Color(0x22FFFFFF) : UserGlassColors.rose)
              .withOpacity(dark ? .04 : .08), blurRadius: 20,
              offset: const Offset(0, -3)),
          ]),
        child: ClipRRect(borderRadius: BorderRadius.circular(31),
          child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: AnimatedBuilder(
              animation: animation ?? AlwaysStoppedAnimation<double>(selectedIndex.toDouble()),
              builder: (context, _) {
                final raw = animation?.value.clamp(0.0, 2.0).toDouble();
                // The Scan button is a camera action, not a fourth page.
                // Across Home->Patients, the lens travels THROUGH Scan
                // without opening the camera unintentionally.
                final position = raw == null ? selectedIndex.toDouble()
                    : (raw <= 1 ? raw * 2 : raw + 1);
                final progress = raw == null ? 0.0 : raw - raw.floorToDouble();
                final morph = reduced ? 0.0 :
                    math.sin(math.pi * progress).clamp(0.0, 1.0).toDouble();
                final lensWidth = cell - 5 + morph * 26;
                final center = 5 + cell * (position + .5);
                final lensLeft = (center - lensWidth / 2)
                    .clamp(2.0, constraints.maxWidth - lensWidth - 2).toDouble();
                return Stack(clipBehavior: Clip.hardEdge, children: [
                  Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(31),
                    gradient: LinearGradient(begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: dark
                        ? const [Color(0x2AFFFFFF), Color(0x14000000), Color(0x20101010)]
                        : const [Color(0x4DFFFFFF), Color(0x269D71AA), Color(0x337D547D)],
                      stops: const [0, .51, 1]),
                    border: Border.all(color: dark ? const Color(0x30FFFFFF)
                        : const Color(0xB7FFFFFF), width: 1.05)))),
                  Positioned.fill(child: IgnorePointer(child: DecoratedBox(
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(31),
                      gradient: LinearGradient(begin: Alignment.topCenter,
                        end: Alignment.bottomCenter, colors: dark
                          ? const [Color(0x22FFFFFF), Color(0x05000000), Color(0x08000000)]
                          : const [Color(0x60FFFFFF), Color(0x06FFFFFF), Color(0x15EB68A8)],
                        stops: const [0, .39, 1]))))),
                  if (!reduced && morph > .001)
                    Positioned.fill(child: IgnorePointer(child: CustomPaint(
                      painter: _UserDockTrail(position: position, cell: cell, strength: morph)))),
                  Positioned(top: 3, bottom: 3, left: lensLeft, width: lensWidth,
                    child: _UserLiquidLens(morph: morph)),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Row(children: [
                      for (var i = 0; i < 4; i++)
                        Expanded(child: Semantics(
                          button: true,
                          selected: animation == null ? selectedIndex == i :
                              ((raw! < .5 && i == 0) ||
                               (raw >= .5 && raw < 1.5 && i == 2) ||
                               (raw >= 1.5 && i == 3)),
                          label: '${_labels[i]} tab',
                          child: Material(color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(29),
                              splashColor: (dark ? Colors.white : UserGlassColors.violet)
                                  .withOpacity(dark ? .05 : .09),
                              highlightColor: Colors.transparent,
                              onTap: () => _select(context, i),
                              child: SizedBox(height: height,
                                child: Column(mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Transform.scale(
                                      scale: 1.0 + .14 * (1 - (position - i).abs())
                                          .clamp(0.0, 1.0).toDouble(),
                                      child: Icon(_icons[i], size: 20,
                                        color: Color.lerp(
                                          dark ? const Color(0xFFA7A7A7) : const Color(0xFF5D4166),
                                          dark ? const Color(0xFFFFD3DE) : UserGlassColors.violet,
                                          (1 - (position - i).abs()).clamp(0.0, 1.0).toDouble()))),
                                    const SizedBox(height: 2),
                                    FittedBox(fit: BoxFit.scaleDown,
                                      child: Text(_labels[i], maxLines: 1,
                                        style: TextStyle(fontSize: 9.3,
                                          fontWeight: FontWeight.w800,
                                          color: Color.lerp(
                                            dark ? const Color(0xFF979797) : const Color(0xFF695473),
                                            dark ? const Color(0xFFFFD3DE) : UserGlassColors.violet,
                                            (1 - (position - i).abs()).clamp(0.0, 1.0).toDouble())))),
                                  ])),
                            )),
                        )),
                    ])),
                ]);
              },
            ),
          ),
        ),
      );
    });
  }

  void _select(BuildContext context, int index) {
    if (index == 1) { _scanMenu(context); return; }
    if (onSelect != null) { onSelect!(index); return; }
    // Standalone patient-detail pages still support the same destinations.
    switch (index) {
      case 0: Get.offAllNamed(Routes.HOME); break;
      case 2: Get.offAllNamed(Routes.PATIENTS); break;
      case 3: Get.offAllNamed(Routes.SETTINGS); break;
    }
  }

  void _scanMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Padding(padding: const EdgeInsets.all(16),
          child: UserGlassPanel(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Start a screening', style: TextStyle(fontSize: 19,
              fontWeight: FontWeight.w800, color: UserGlassColors.ink)),
            const SizedBox(height: 5),
            Text('Choose how to enter CBC results',
              style: TextStyle(color: UserGlassColors.muted)),
            const SizedBox(height: 16),
            ListTile(leading: const Icon(Icons.document_scanner_outlined,
                color: UserGlassColors.violet),
              title: const Text('Scan CBC report'),
              subtitle: const Text('Camera or gallery'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                Get.toNamed(Routes.SCANNER, arguments: {'type': 'image'});
              }),
            ListTile(leading: const Icon(Icons.keyboard_alt_outlined,
                color: UserGlassColors.violet),
              title: const Text('Enter CBC manually'),
              subtitle: const Text('Type the seven values'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                Get.toNamed(Routes.SCANNER, arguments: {'type': 'text'});
              }),
          ])),
        ),
      ),
    );
  }
}

class _UserLiquidLens extends StatelessWidget {
  const _UserLiquidLens({required this.morph});
  final double morph;

  @override
  Widget build(BuildContext context) {
    final dark = UserGlassColors.dark;
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(
          color: (dark ? const Color(0xFFFFA7B9) : const Color(0xFFAC55C4))
            .withOpacity(dark ? .05 + morph * .05 : .10 + morph * .11),
          blurRadius: 12 + morph * 8, spreadRadius: -2)]),
      child: ClipPath(clipper: _UserLensClipper(morph),
        child: Stack(fit: StackFit.expand, children: [
          BackdropFilter(filter: ImageFilter.blur(sigmaX: 11, sigmaY: 11),
            child: DecoratedBox(decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dark
                  ? const [Color(0x66FFFFFF), Color(0x406D3D8D), Color(0x337B3663)]
                  : const [Color(0xDFFFFFFF), Color(0xB2E8C9FA), Color(0xA0F7B5D7)])))),
          IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(
            gradient: RadialGradient(center: const Alignment(-.73, -.95),
              radius: 1.28, colors: dark
                ? const [Color(0x44FFFFFF), Color(0x08FFFFFF), Color(0x00FFFFFF)]
                : const [Color(0xABFFFFFF), Color(0x28FFFFFF), Color(0x00FFFFFF)])))),
          IgnorePointer(child: CustomPaint(painter: _UserLensRim(morph))),
        ])),
    );
  }
}

class _UserLensClipper extends CustomClipper<Path> {
  const _UserLensClipper(this.morph);
  final double morph;
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final r = h * .47;
    final pull = morph * 4.0;
    return Path()
      ..moveTo(r, 1)
      ..cubicTo(w * .34, 1 - pull * .22, w * .69, 1 + pull * .26, w - r, 1)
      ..cubicTo(w - r * .20, 1 - pull * .45,
        w + pull * .55, h * .24, w - 1, h / 2)
      ..cubicTo(w + pull * .55, h * .76,
        w - r * .15, h + pull * .20, w - r, h - 1)
      ..cubicTo(w * .68, h - 1 - pull * .25,
        w * .35, h - 1 + pull * .25, r, h - 1)
      ..cubicTo(r * .18, h + pull * .25,
        -pull * .40, h * .76, 1, h / 2)
      ..cubicTo(-pull * .40, h * .24,
        r * .18, 1 - pull * .24, r, 1)
      ..close();
  }
  @override
  bool shouldReclip(covariant _UserLensClipper oldClipper) =>
      oldClipper.morph != morph;
}

class _UserLensRim extends CustomPainter {
  const _UserLensRim(this.morph);
  final double morph;
  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 22 || size.height < 22) return;
    final w = size.width, h = size.height;
    final top = Path()
      ..moveTo(8, h * .44)
      ..cubicTo(7, h * .13, w * .21, 3, w * .43, 3)
      ..cubicTo(w * .72, 3 - morph, w * .85, 7, w - 8, h * .30);
    canvas.drawPath(top, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7 + morph * .7
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(colors: [
        Color(0x12FFFFFF), Color(0xEEFFFFFF), Color(0x33FFFFFF),
      ]).createShader(Rect.fromLTWH(0, 0, w, h)));
    final bottom = Path()
      ..moveTo(10, h * .73)
      ..cubicTo(w * .25, h - 3, w * .76, h - 3, w - 10, h * .73);
    canvas.drawPath(bottom, Paint()
      ..color = const Color(0x9AFFFFFF)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke);
  }
  @override
  bool shouldRepaint(covariant _UserLensRim old) => old.morph != morph;
}

class _UserDockTrail extends CustomPainter {
  const _UserDockTrail({required this.position,
    required this.cell, required this.strength});
  final double position;
  final double cell;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    if (strength < .001) return;
    final anchored = position.roundToDouble();
    final x1 = 5 + cell * (anchored + .5);
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
    final dark = UserGlassColors.dark;
    canvas.drawPath(path, Paint()
      ..shader = LinearGradient(colors: [
        (dark ? Colors.white : const Color(0xFFB979D4))
            .withOpacity((dark ? .05 : .10) * strength),
        (dark ? const Color(0xFFFFE1E8) : const Color(0xFFFFE4FD))
            .withOpacity((dark ? .34 : .58) * strength),
        (dark ? const Color(0xFFFFB7C6) : const Color(0xFFBF72D2))
            .withOpacity((dark ? .10 : .21) * strength),
      ]).createShader(Rect.fromLTWH(
        math.min(x1, x2), y - 14, math.max(1.0, (x2 - x1).abs()), 28)));
  }
  @override
  bool shouldRepaint(covariant _UserDockTrail old) =>
      old.position != position || old.cell != cell || old.strength != strength;
}
