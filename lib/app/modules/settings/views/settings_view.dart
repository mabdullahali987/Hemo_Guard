import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hemo_guard/app/modules/home/widgets/user_glass.dart';
import '../../../data/settings.dart';
import '../controllers/settings_controller.dart';

/// Settings behavior preserved; controls now follow the user glass workspace.
class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});
  @override
  Widget build(BuildContext context) => UserGlassFrame(
    title: 'Settings', subtitle: 'HEMOGUARD  /  PREFERENCES', selectedIndex: 3,
    child: Obx(() {
      final s = controller.settings.value;
      return ListView(padding: const EdgeInsets.fromLTRB(20, 10, 20, 24), children: [
        UserGlassPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.palette_outlined, color: UserGlassColors.dark
              ? const Color(0xFFD9BEFF) : UserGlassColors.violet),
            const SizedBox(width: 10),
            Text('Appearance', style: TextStyle(color: UserGlassColors.ink,
              fontSize: 18, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 8),
          Text('Choose the appearance of your user workspace.',
            style: TextStyle(color: UserGlassColors.muted, fontSize: 12)),
          const SizedBox(height: 12),
          for (final mode in AppThemeMode.values)
            RadioListTile<AppThemeMode>(
              contentPadding: EdgeInsets.zero,
              title: Text(mode == AppThemeMode.system ? 'Follow device' :
                mode == AppThemeMode.light ? 'Light' : 'Dark'),
              subtitle: Text(mode == AppThemeMode.system ? 'Match your phone setting' :
                mode == AppThemeMode.light ? 'Pearl & lavender glass' : 'Midnight liquid glass',
                style: TextStyle(color: UserGlassColors.muted, fontSize: 11)),
              value: mode, groupValue: s.themeMode,
              activeColor: UserGlassColors.violet,
              onChanged: (value) => value == null ? null : controller.setThemeMode(value),
            ),
        ])),
        const SizedBox(height: 15),
        UserGlassPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.storage_rounded, color: UserGlassColors.dark
              ? const Color(0xFFD9BEFF) : UserGlassColors.violet),
            const SizedBox(width: 10),
            Text('Device storage', style: TextStyle(color: UserGlassColors.ink,
              fontSize: 18, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 9),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Save scans on device'),
            subtitle: Text('Keep captured reports in local storage',
              style: TextStyle(color: UserGlassColors.muted, fontSize: 11)),
            value: s.saveScansLocally,
            activeColor: UserGlassColors.violet,
            onChanged: controller.setSaveScansLocally,
          ),
        ])),
        const SizedBox(height: 22),
        Center(child: Text('HemoGuard • Developed by CoE-AI',
          style: TextStyle(color: UserGlassColors.muted, fontSize: 11))),
      ]);
    }),
  );
}
