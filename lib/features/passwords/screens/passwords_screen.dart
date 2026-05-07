import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:second_brain_app/core/security/biometric_auth.dart';
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
      backgroundColor: isDark
          ? const Color(0xFF1E1A25)
          : const Color(0xFFF9F5FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : const Color(0xFF5A49D6),
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 24.0),
            child: Center(
              child: Text(
                'Second Brain',
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white : const Color(0xFF5A49D6),
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
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
                : [const Color(0xFFF9F5FF), const Color(0xFFEBE0FA)],
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
                          const SizedBox(height: 8),
                          Text(
                            'Passwords',
                            style: GoogleFonts.inter(
                              fontSize: 48,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF3F2A6E),
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Securely managing ${vault.passwords.length} access credentials',
                            style: TextStyle(
                              fontSize: 16,
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xFF5A5A5A),
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
                                  color: const Color(
                                    0xFF6366F1,
                                  ).withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  _showPasswordDialog(context, ref),
                              icon: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 20,
                              ),
                              label: const Text(
                                'Add Password',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(32),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF2C2533)
                                  : const Color(0xFFF3EDFD),
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white12
                                    : const Color(0xFFD1C5E4).withOpacity(0.5),
                              ),
                            ),
                            child: TextField(
                              controller: _searchController,
                              onChanged: (val) =>
                                  setState(() => _searchQuery = val),
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Search passwords...',
                                hintStyle: TextStyle(
                                  color: isDark
                                      ? Colors.white54
                                      : const Color(0xFF9E8DB3),
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 18,
                                ),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 32),
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
                                    color: isDark
                                        ? Colors.white54
                                        : const Color(0xFF6B5A8E),
                                  ),
                                ),
                              ),
                            ),
                          )
                        : SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final password = filteredPasswords[index];
                              return _buildPasswordCard(
                                context,
                                ref,
                                password,
                                isDark,
                              );
                            }, childCount: filteredPasswords.length),
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

  Widget _buildPasswordCard(
    BuildContext context,
    WidgetRef ref,
    VaultPassword password,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF2A2435).withOpacity(0.8)
            : Colors.white.withOpacity(0.8),
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
                    color: isDark ? Colors.white : const Color(0xFF2D2D2D),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  password.username,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : const Color(0xFF5A5A5A),
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
              if (!await _authorize(context, ref, action: 'view password') ||
                  !context.mounted) {
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
            icon: Icon(
              Icons.visibility_outlined,
              color: isDark ? Colors.white54 : const Color(0xFF8C8C8C),
              size: 20,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'View password',
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: () async {
              if (!await _authorize(context, ref, action: 'copy password') ||
                  !context.mounted) {
                return;
              }
              await Clipboard.setData(ClipboardData(text: password.password));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Password copied')));
            },
            icon: Icon(
              Icons.copy_outlined,
              color: isDark ? Colors.white54 : const Color(0xFF8C8C8C),
              size: 20,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Copy password',
          ),
          const SizedBox(width: 16),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: isDark ? Colors.white54 : const Color(0xFF8C8C8C),
              size: 20,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onSelected: (value) async {
              if (value == 'edit') {
                if (!await _authorize(context, ref, action: 'edit password') ||
                    !context.mounted) {
                  return;
                }
                _showPasswordDialog(context, ref, password);
              } else if (value == 'delete') {
                if (!await _authorize(context, ref, action: 'delete password') ||
                    !context.mounted) {
                  return;
                }
                final confirmed = await showDeleteConfirmation(
                  context,
                  itemType: 'Password',
                  itemName: password.accountName,
                );
                if (confirmed && context.mounted) {
                  ref
                      .read(vaultControllerProvider.notifier)
                      .deletePassword(password.id);
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
    );
  }

  Future<bool> _authorize(
    BuildContext context,
    WidgetRef ref, {
    required String action,
  }) async {
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

class _CustomPasswordDialog extends StatefulWidget {
  final VaultPassword? item;
  const _CustomPasswordDialog({this.item});

  @override
  State<_CustomPasswordDialog> createState() => _CustomPasswordDialogState();
}

class _CustomPasswordDialogState extends State<_CustomPasswordDialog> {
  late TextEditingController _accountController;
  late TextEditingController _userController;
  late TextEditingController _passController;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _accountController = TextEditingController(
      text: widget.item?.accountName ?? '',
    );
    _userController = TextEditingController(text: widget.item?.username ?? '');
    _passController = TextEditingController(text: widget.item?.password ?? '');
  }

  @override
  void dispose() {
    _accountController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1A25) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? Colors.white54 : const Color(0xFFC4B8D1);
    final fieldBg = isDark ? const Color(0xFF2C2533) : const Color(0xFFF6EEFA);
    final iconColor = isDark ? Colors.white70 : const Color(0xFF4A3B69);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFFB55CF0), Color(0xFFD672A1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 16),
                // Title
                Text(
                  widget.item == null ? 'Save Password' : 'Edit Password',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                // Subtitle
                Text(
                  widget.item == null
                      ? 'Do you want to save this password for easier sign in next time?'
                      : 'Update your saved password details below.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white54 : Colors.black54,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),

                // Account Name Input
                _buildInputField(
                  controller: _accountController,
                  icon: Icons.language,
                  hintText: 'Website or App (e.g. Netflix)',
                  fieldBg: fieldBg,
                  iconColor: iconColor,
                  textColor: textColor,
                  hintColor: hintColor,
                ),
                const SizedBox(height: 16),

                // Username Input
                _buildInputField(
                  controller: _userController,
                  icon: Icons.person_outline,
                  hintText: 'Email or Username',
                  fieldBg: fieldBg,
                  iconColor: iconColor,
                  textColor: textColor,
                  hintColor: hintColor,
                ),
                const SizedBox(height: 16),

                // Password Input
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: fieldBg,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.vpn_key_outlined, color: iconColor, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _passController,
                          obscureText: _obscurePassword,
                          style: TextStyle(fontSize: 15, color: textColor),
                          decoration: InputDecoration(
                            hintText: 'Password',
                            hintStyle: TextStyle(
                              fontSize: 15,
                              color: hintColor,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: iconColor,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark
                              ? Colors.white70
                              : const Color(0xFF6B4BA3),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7E42EB), Color(0xFF6887F7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7E42EB).withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          final account = _accountController.text.trim();
                          if (account.isEmpty) return;
                          Navigator.pop(
                            context,
                            VaultPassword(
                              id: widget.item?.id ?? const Uuid().v4(),
                              accountName: account,
                              username: _userController.text.trim(),
                              password: _passController.text,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                        ),
                        child: Text(
                          widget.item == null ? 'Save Password' : 'Update',
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required IconData icon,
    required String hintText,
    required Color fieldBg,
    required Color iconColor,
    required Color textColor,
    required Color hintColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: fieldBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              style: TextStyle(fontSize: 15, color: textColor),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(fontSize: 15, color: hintColor),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
