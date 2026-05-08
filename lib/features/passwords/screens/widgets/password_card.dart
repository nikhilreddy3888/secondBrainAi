import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../models/vault_model.dart';
import '../../../../shared/widgets/confirm_delete_dialog.dart';
import '../../../settings/controller/settings_controller.dart';
import '../../../vault/controller/vault_controller.dart';
import '../../../../core/security/biometric_auth.dart';
import '../../../../core/app_colors.dart';

class PasswordCard extends ConsumerWidget {
  const PasswordCard({
    super.key,
    required this.password,
    required this.onEdit,
  });

  final VaultPassword password;
  final VoidCallback onEdit;

  Future<bool> _authorize(BuildContext context, WidgetRef ref, {required String action}) async {
    final settings = ref.read(settingsControllerProvider);
    if (!settings.biometricEnabled) return true;

    final biometricAuth = ref.read(biometricAuthProvider);

    try {
      final didAuthenticate = await biometricAuth.authenticate(
        reason: 'Authenticate to $action',
      );

      if (!didAuthenticate && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication required.')),
        );
      }

      return didAuthenticate;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Authentication failed: $e')),
        );
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: colors.surfaceColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: colors.borderColor, width: 1.5),
        boxShadow: [
          if (!colors.isDark)
            BoxShadow(
              color: const Color(0xFFE2D8F0).withOpacity(0.5),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  password.accountName,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: colors.textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  password.username,
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.subtextColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () async {
              if (!await _authorize(context, ref, action: 'view password') || !context.mounted) {
                return;
              }
              showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: colors.surfaceColor,
                  title: Text(password.accountName, style: TextStyle(color: colors.textColor)),
                  content: SelectableText(password.password, style: TextStyle(color: colors.textColor)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
            icon: Icon(Icons.visibility_outlined, color: colors.subtextColor, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'View password',
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: () async {
              if (!await _authorize(context, ref, action: 'copy password') || !context.mounted) {
                return;
              }
              await Clipboard.setData(ClipboardData(text: password.password));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password copied')));
              }
            },
            icon: Icon(Icons.copy_outlined, color: colors.subtextColor, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Copy password',
          ),
          const SizedBox(width: 16),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: colors.subtextColor, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            color: colors.surfaceColor,
            onSelected: (value) async {
              if (value == 'edit') {
                if (!await _authorize(context, ref, action: 'edit password') || !context.mounted) {
                  return;
                }
                onEdit();
              } else if (value == 'delete') {
                if (!await _authorize(context, ref, action: 'delete password') || !context.mounted) {
                  return;
                }
                final confirmed = await showDeleteConfirmation(
                  context,
                  itemType: 'Password',
                  itemName: password.accountName,
                );
                if (confirmed && context.mounted) {
                  ref.read(vaultControllerProvider.notifier).deletePassword(password.id);
                }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'edit', child: Text('Edit', style: TextStyle(color: colors.textColor))),
              PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: colors.textColor))),
            ],
          ),
        ],
      ),
    );
  }
}
