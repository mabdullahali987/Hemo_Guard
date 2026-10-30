import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hemo_guard/app/routes/app_pages.dart';
import 'package:hemo_guard/app/services/auth_service.dart';
import '../controllers/home_controller.dart';
import '../widgets/account_status_card.dart';
import '../widgets/user_glass.dart';

/// Existing user actions and routes, presented in the same glass vocabulary as
/// Login and Superadmin. No prediction, authorization or report logic changed.
class HomeView extends GetView<HomeController> {
  const HomeView({super.key, this.embedded = false});
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final content = LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth > 680;
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 9, 20, 24),
        child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _Welcome(wide: wide),
            const SizedBox(height: 17),
            if (wide) Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Expanded(child: AccountStatusCard()),
              const SizedBox(width: 16),
              Expanded(child: _PrimaryAction(onTap: _scan)),
            ]) else ...[
              const AccountStatusCard(),
              const SizedBox(height: 15),
              _PrimaryAction(onTap: _scan),
            ],
            const SizedBox(height: 15),
            Row(children: [
              Expanded(child: _QuickAction(
                icon: Icons.keyboard_alt_outlined, title: 'Manual entry',
                description: 'Enter CBC values', onTap: _manual)),
              const SizedBox(width: 12),
              Expanded(child: _QuickAction(
                icon: Icons.folder_shared_outlined, title: 'Patient reports',
                description: 'View saved history', onTap: () => _patients(context))),
            ]),
            const SizedBox(height: 22),
            const _About(),
          ]),
        )),
      );
    });
    return embedded ? content : UserGlassFrame(
      title: 'Dashboard', subtitle: 'HEMOGUARD', selectedIndex: 0, child: content);
  }

  static void _scan() { Get.toNamed(Routes.SCANNER, arguments: {'type': 'image'}); }
  static void _manual() { Get.toNamed(Routes.SCANNER, arguments: {'type': 'text'}); }
  static void _patients(BuildContext context) {
    final workspace = UserWorkspaceNavigation.maybeOf(context);
    if (workspace != null) { workspace.selectTab(1); }
    else { Get.toNamed(Routes.PATIENTS); }
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.wide});
  final bool wide;
  @override
  Widget build(BuildContext context) => UserGlassPanel(
    padding: const EdgeInsets.fromLTRB(21, 22, 20, 20),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 7, height: 7, decoration: const BoxDecoration(
            shape: BoxShape.circle, color: UserGlassColors.rose)),
          const SizedBox(width: 8),
          Text('YOUR SCREENING WORKSPACE', style: TextStyle(
            color: UserGlassColors.muted, fontSize: 10,
            fontWeight: FontWeight.w800, letterSpacing: 1.25)),
        ]),
        const SizedBox(height: 13),
        Obx(() {
          final name = Get.find<AuthService>().user.value?['display_name']?.toString();
          return Text((name == null || name.trim().isEmpty) ? 'Welcome back' : 'Welcome, $name',
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: UserGlassColors.ink, fontSize: wide ? 27 : 23,
              fontWeight: FontWeight.w800, letterSpacing: -.8));
        }),
        const SizedBox(height: 7),
        Text('Analyze CBC reports and manage your patients in one place.',
          style: TextStyle(color: UserGlassColors.muted, fontSize: 12.5, height: 1.5)),
      ])),
      const SizedBox(width: 13),
      Container(
        width: wide ? 77 : 62, height: wide ? 77 : 62,
        decoration: BoxDecoration(
          gradient: UserGlassColors.gradient,
          borderRadius: BorderRadius.circular(21),
          boxShadow: [BoxShadow(
            color: UserGlassColors.magenta.withOpacity(.20),
            blurRadius: 22, offset: const Offset(0, 9)),
          ],
        ),
        child: Icon(Icons.health_and_safety_outlined,
          color: Colors.white, size: wide ? 37 : 31),
      ),
    ]),
  );
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => UserGlassPanel(
    padding: const EdgeInsets.all(15),
    child: Material(color: Colors.transparent,
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 20),
          decoration: BoxDecoration(gradient: UserGlassColors.gradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: UserGlassColors.violet.withOpacity(.20), blurRadius: 14)]),
          child: Row(children: [
            Container(width: 47, height: 47,
              decoration: BoxDecoration(color: Colors.white.withOpacity(.19), borderRadius: BorderRadius.circular(15)),
              child: const Icon(Icons.document_scanner_outlined, size: 26, color: Colors.white)),
            const SizedBox(width: 13),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Scan CBC report', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
              SizedBox(height: 4),
              Text('Camera or gallery • AI screening',
                style: TextStyle(color: Color(0xFFEBDFF4), fontSize: 11)),
            ])),
            const Icon(Icons.arrow_forward_rounded, color: Colors.white),
          ]),
        ),
      ),
    ),
  );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.title,
    required this.description, required this.onTap});
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => UserGlassPanel(
    padding: EdgeInsets.zero,
    child: Material(color: Colors.transparent,
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(24),
        child: Padding(padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 44, height: 44,
              decoration: BoxDecoration(
                color: UserGlassColors.violet.withOpacity(UserGlassColors.dark ? .20 : .09),
                borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, size: 23, color: UserGlassColors.dark
                ? const Color(0xFFDBBFFF) : UserGlassColors.violet)),
            const SizedBox(height: 14),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: UserGlassColors.ink, fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 4),
            Text(description, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: UserGlassColors.muted, fontSize: 11.5)),
          ])),
      ),
    ),
  );
}

class _About extends StatelessWidget {
  const _About();
  @override
  Widget build(BuildContext context) => Column(children: [
    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.info_outline_rounded, size: 15, color: UserGlassColors.muted),
      const SizedBox(width: 7),
      Flexible(child: Text('A screening aid, not a diagnosis. Consult a doctor.',
        textAlign: TextAlign.center, style: TextStyle(color: UserGlassColors.muted, fontSize: 11.5))),
    ]),
    const SizedBox(height: 11),
    Text('Developed by CoE-AI', style: TextStyle(fontSize: 11,
      fontWeight: FontWeight.w700, color: UserGlassColors.muted)),
  ]);
}
