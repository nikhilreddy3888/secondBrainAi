import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import 'package:google_fonts/google_fonts.dart';

import '../../../models/vault_model.dart';
import '../../../shared/widgets/section_scaffold.dart';
import '../../settings/controller/settings_controller.dart';
import '../../vault/controller/vault_controller.dart';

class PasswordsScreen extends ConsumerWidget {
  const PasswordsScreen({super.key});

  static final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vault = ref.watch(vaultControllerProvider);
    return vault.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text(error.toString())),
      data: (vault) => SectionScaffold(
        title: 'Passwords',
        action: FilledButton.icon(
          onPressed: () => _showPasswordDialog(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('New password'),
        ),
        child: EmptyAwareList(
          isEmpty: vault.passwords.isEmpty,
          emptyText: 'No passwords saved.',
          child: ListView.separated(
            itemCount: vault.passwords.length,
            separatorBuilder: (_, index) => const SizedBox.shrink(),
            itemBuilder: (context, index) {
              final password = vault.passwords[index];
              final theme = Theme.of(context);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.outline),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.lock_outline, color: theme.colorScheme.onSurfaceVariant),
                    ),
                    title: Text(
                      password.accountName,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      password.username,
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    trailing: Wrap(
                      children: [
                    IconButton(
                      tooltip: 'Copy password',
                      onPressed: () async {
                        if (!await _authorize(context, ref) || !context.mounted) {
                          return;
                        }
                        await Clipboard.setData(ClipboardData(text: password.password));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Password copied')),
                        );
                      },
                      icon: const Icon(Icons.copy),
                    ),
                    IconButton(
                      tooltip: 'View password',
                      onPressed: () async {
                        if (!await _authorize(context, ref) || !context.mounted) {
                          return;
                        }
                        showDialog<void>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(password.accountName),
                            content: SelectableText(password.password),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.visibility_outlined),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') _showPasswordDialog(context, ref, password);
                        if (value == 'delete') {
                          ref
                              .read(vaultControllerProvider.notifier)
                              .deletePassword(password.id);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
          ),
        ),
      ),
    );
  }

  Future<bool> _authorize(BuildContext context, WidgetRef ref) async {
    final settings = ref.read(settingsControllerProvider);
    if (!settings.biometricEnabled) return true;

    try {
      final canAuthenticate = await _localAuth.canCheckBiometrics;
      final deviceSupported = await _localAuth.isDeviceSupported();
      if (!canAuthenticate || !deviceSupported) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Biometric authentication is not available on this device.'),
            ),
          );
        }
        return false;
      }

      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Authenticate to access saved passwords',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          sensitiveTransaction: true,
        ),
      );

      if (!didAuthenticate && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication cancelled.')),
        );
      }

      return didAuthenticate;
    } on PlatformException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Authentication failed: ${error.message ?? error.code}')),
        );
      }
      return false;
    }
  }

  Future<void> _showPasswordDialog(
    BuildContext context,
    WidgetRef ref, [
    VaultPassword? item,
  ]) async {
    final accountName = TextEditingController(text: item?.accountName ?? '');
    final username = TextEditingController(text: item?.username ?? '');
    final password = TextEditingController(text: item?.password ?? '');
    final result = await showDialog<VaultPassword>(
      context: context,
      builder: (context) => EditDialog(
        title: item == null ? 'New password' : 'Edit password',
        fields: [
          TextField(
            controller: accountName,
            decoration: const InputDecoration(labelText: 'Account name'),
          ),
          TextField(controller: username, decoration: const InputDecoration(labelText: 'Username')),
          TextField(
            controller: password,
            decoration: const InputDecoration(labelText: 'Password'),
            obscureText: true,
          ),
        ],
        onSave: () => VaultPassword(
          id: item?.id ?? uuid.v4(),
          accountName: accountName.text.trim(),
          username: username.text.trim(),
          password: password.text,
        ),
      ),
    );
    if (result == null || result.accountName.isEmpty) return;
    await ref.read(vaultControllerProvider.notifier).upsertPassword(result);
  }
}
