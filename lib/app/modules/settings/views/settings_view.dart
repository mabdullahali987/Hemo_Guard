import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/settings.dart';
import '../controllers/settings_controller.dart';

/// Settings screen: local-storage toggle + app theme selection.
class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Obx(() {
        final s = controller.settings.value;
        return ListView(
          children: [
            SwitchListTile(
              title: const Text('Save scans on device'),
              subtitle: const Text('Keep captured reports in local storage'),
              value: s.saveScansLocally,
              onChanged: controller.setSaveScansLocally,
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text('Theme'),
            ),
            ...AppThemeMode.values.map(
              (mode) => RadioListTile<AppThemeMode>(
                title: Text(mode.name),
                value: mode,
                groupValue: s.themeMode,
                onChanged: (value) =>
                    value == null ? null : controller.setThemeMode(value),
              ),
            ),
          ],
        );
      }),
    );
  }
}
