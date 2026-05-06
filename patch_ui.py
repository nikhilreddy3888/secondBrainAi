import sys

new_code = """import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:uuid/uuid.dart';

import 'package:google_fonts/google_fonts.dart';

import '../../../models/vault_model.dart';
import '../../../shared/widgets/confirm_delete_dialog.dart';
import '../../settings/controller/settings_controller.dart';
import '../../vault/controller/vault_controller.dart';

class PasswordsScreen extends ConsumerStatefulWidget {
  const PasswordsScreen({super.key});

  @override
  ConsumerState<PasswordsScreen> createState() => _PasswordsScreenState();
}

class _PasswordsScreenState extends ConsumerState<PasswordsScreen> {
  static final LocalAuthentication _localAuth = LocalAuthentication();
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vaultAsync = ref.watch(vaultControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isDark ? const Color(0xFF1E1A25) : const Color(0xFFF5EFFF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.menu, color: isDark ? Colors.white : const Color(0xFF4A3BE8)),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: Text(
          'Second Brain',
          style: GoogleFonts.inter(
            color: isDark ? Colors.white : const Color(0xFF4A3BE8),
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: isDark ? Colors.white24 : const Color(0xFFD1C5E4),
              child: Icon(
                Icons.person,
                size: 20,
                color: isDark ? Colors.white : const Color(0xFF4A3B69),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF1E1A25), const Color(0xFF120F16)]
                : [const Color(0xFFF5EFFF), const Color(0xFFE9E0F8)],
          ),
        ),
        child: vaultAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text(error.toString())),
          data: (vault) {
            final filteredPasswords = vault.passwords.where((p) {
              final query = _searchQuery.toLowerCase();
              return p.accountName.toLowerCase().contains(query) ||
                  p.username.toLowerCase().contains(query);
            }).toList();

            return SafeArea(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          Text(
                            'Passwords',
                            style: GoogleFonts.inter(
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF3F2A6E),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            f'Securely managing {vault.passwords.length} access credentials',
                            style: TextStyle(
                              fontSize: 15,
                              color: isDark ? Colors.white70 : const Color(0xFF6B5A8E),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(32),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6366F1).withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: () => _showPasswordDialog(context, ref),
                              icon: const Icon(Icons.add, color: Colors.white),
                              label: const Text(
                                'Add Password',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(32),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2C2533) : Colors.transparent,
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                color: isDark ? Colors.white12 : const Color(0xFFD1C5E4),
                              ),
                            ),
                            child: TextField(
                              controller: _searchController,
                              onChanged: (val) => setState(() => _searchQuery = val),
                              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                              decoration: InputDecoration(
                                hintText: 'Search passwords...',
                                hintStyle: TextStyle(
                                  color: isDark ? Colors.white54 : const Color(0xFFA193B5),
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    sliver: filteredPasswords.isEmpty
                        ? SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 40.0),
                              child: Center(
                                child: Text(
                                  'No passwords found.',
                                  style: TextStyle(
                                    color: isDark ? Colors.white54 : const Color(0xFF6B5A8E),
                                  ),
                                ),
                              ),
                            ),
                          )
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final password = filteredPasswords[index];
                                return _buildPasswordCard(context, ref, password, isDark);
                              },
                              childCount: filteredPasswords.length,
                            ),
                          ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPasswordCard(BuildContext context, WidgetRef ref, VaultPassword password, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2435).withOpacity(0.8) : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.white,
          width: 1.5,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: const Color(0xFFE2D8F0).withOpacity(0.5),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? Colors.white12 : const Color(0xFFF0EAF8),
                    width: 1,
                  ),
                  boxShadow: [
                    if (!isDark)
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
                child: Center(
                  child: Text(
                    password.accountName.isNotEmpty ? password.accountName[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF4A3B69),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      password.accountName,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1E1A25),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      password.username,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white70 : const Color(0xFF6B5A8E),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                onPressed: () async {
                  if (!await _authorize(context, ref) || !context.mounted) return;
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
                icon: Icon(Icons.visibility_outlined, color: isDark ? Colors.white54 : const Color(0xFF6B5A8E)),
                tooltip: 'View password',
              ),
              IconButton(
                onPressed: () async {
                  if (!await _authorize(context, ref) || !context.mounted) return;
                  await Clipboard.setData(ClipboardData(text: password.password));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password copied')),
                  );
                },
                icon: Icon(Icons.copy_outlined, color: isDark ? Colors.white54 : const Color(0xFF6B5A8E)),
                tooltip: 'Copy password',
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: isDark ? Colors.white54 : const Color(0xFF6B5A8E)),
                onSelected: (value) async {
                  if (!await _authorize(context, ref) || !context.mounted) return;
                  if (value == 'edit') {
                    _showPasswordDialog(context, ref, password);
                  } else if (value == 'delete') {
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
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ],
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
    final result = await showDialog<VaultPassword>(
      context: context,
      builder: (context) => _CustomPasswordDialog(item: item),
    );
    if (result == null || result.accountName.isEmpty) return;
    await ref.read(vaultControllerProvider.notifier).upsertPassword(result);
  }
}
"""

with open('lib/features/passwords/screens/passwords_screen.dart', 'r') as f:
    lines = f.readlines()

bottom_part = "".join(lines[204:])

# Correct f-string replacement
new_code = new_code.replace("f'Securely managing {vault.passwords.length} access credentials'", "'Securely managing ${vault.passwords.length} access credentials'")

with open('lib/features/passwords/screens/passwords_screen.dart', 'w') as f:
    f.write(new_code + "\n" + bottom_part)

