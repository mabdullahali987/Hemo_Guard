//home_view.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hemo_guard/app/routes/app_pages.dart';
import 'package:hemo_guard/app/theme/app_theme.dart';
import 'package:hemo_guard/app/services/auth_service.dart';

import '../controllers/home_controller.dart';
import '../widgets/account_status_card.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final landscape = constraints.maxWidth > constraints.maxHeight;
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: landscape
                      ? _landscape(context)
                      : _portrait(context),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _portrait(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Align(alignment: Alignment.centerRight, child: IconButton(
          tooltip: 'Log out', onPressed: () => Get.find<AuthService>().logout(),
          icon: const Icon(Icons.logout))),
        const AccountStatusCard(),
        const SizedBox(height: 12),
        const _Brand(),
        const SizedBox(height: 40),
        _actions(),
        const SizedBox(height: 28),
        const _Footer(),
      ],
    );
  }

  Widget _landscape(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Expanded(child: Center(child: _Brand())),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Align(alignment: Alignment.centerRight, child: IconButton(
                tooltip: 'Log out', onPressed: () => Get.find<AuthService>().logout(),
                icon: const Icon(Icons.logout))),
              const AccountStatusCard(),
              const SizedBox(height: 16),
              _actions(),
              const SizedBox(height: 20),
              const _Footer(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _actions() {
    return Column(
      children: [
        _ActionCard(
          icon: Icons.document_scanner_outlined,
          title: 'Scan Report',
          subtitle: 'Capture or pick a CBC report photo',
          onTap: () =>
              Get.toNamed(Routes.SCANNER, arguments: {'type': 'image'}),
        ),
        const SizedBox(height: 16),
        _ActionCard(
          icon: Icons.keyboard_alt_outlined,
          title: 'Enter Manually',
          subtitle: 'Type CBC values yourself',
          onTap: () =>
              Get.toNamed(Routes.SCANNER, arguments: {'type': 'text'}),
        ),
        const SizedBox(height:16),
        _ActionCard(icon:Icons.folder_shared_outlined,title:'Patient Reports',
          subtitle:'View your patients and previous CBC screenings',
          onTap:()=>Get.toNamed(Routes.PATIENTS)),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _Disclaimer(),
        SizedBox(height: 12),
        Text(
          'Developed by CoE-AI',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.brand,
          ),
        ),
      ],
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/logo.png',
          width: 280,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.medical_services,
              size: 80,
              color: AppColors.brand,
            );
          },
        ),
        const SizedBox(height: 18),
        const Text(
          'Thalassemia screening from your blood report',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.muted,
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.dangerBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.brand, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.muted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.info_outline, size: 15, color: AppColors.muted),
        const SizedBox(width: 6),
        const Flexible(
          child: Text(
            'A screening aid, not a diagnosis. Consult a doctor.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ),
      ],
    );
  }
}
