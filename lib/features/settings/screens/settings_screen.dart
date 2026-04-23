import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/section_scaffold.dart';
import '../controller/settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    return SectionScaffold(
      title: 'Settings',
      child: ListView(
        children: [
          _buildSettingsCard(
            context,
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.fingerprint),
                  title: const Text('Biometric gate for passwords'),
                  subtitle: const Text('Require authentication before revealing passwords.'),
                  value: settings.biometricEnabled,
                  onChanged: controller.setBiometricEnabled,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.contrast),
                  title: const Text('Theme'),
                  trailing: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                      ButtonSegment(value: ThemeMode.system, label: Text('System')),
                      ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged: (selection) => controller.setThemeMode(selection.single),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSettingsCard(
            context,
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.privacy_tip_outlined),
                  title: Text('Privacy promise'),
                  subtitle: Text(
                    'All data is stored locally on your device with encryption. No servers. No tracking. No third-party sharing. AI runs on-device.',
                  ),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('About Second Brain'),
                  subtitle: Text(
                    'A private digital vault for notes, passwords, documents, events, and local assistant commands.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context, {required Widget child}) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: child,
    );
  }
}
