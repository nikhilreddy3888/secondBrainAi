import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../models/vault_model.dart';
import '../../../../core/app_colors.dart';

class CustomPasswordDialog extends StatefulWidget {
  final VaultPassword? item;
  const CustomPasswordDialog({super.key, this.item});

  @override
  State<CustomPasswordDialog> createState() => _CustomPasswordDialogState();
}

class _CustomPasswordDialogState extends State<CustomPasswordDialog> {
  late TextEditingController _accountController;
  late TextEditingController _userController;
  late TextEditingController _passController;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _accountController = TextEditingController(text: widget.item?.accountName ?? '');
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
    final colors = AppColors.of(context);

    // Minor overrides specifically for the dialog's glass/pastel feel
    final hintColor = colors.isDark ? Colors.white54 : const Color(0xFFC4B8D1);
    final fieldBg = colors.isDark ? const Color(0xFF2C2533) : const Color(0xFFF6EEFA);
    final iconColor = colors.isDark ? Colors.white70 : const Color(0xFF4A3B69);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: colors.bgColor,
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
                Text(
                  widget.item == null ? 'Save Password' : 'Edit Password',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: colors.textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.item == null
                      ? 'Do you want to save this password for easier sign in next time?'
                      : 'Update your saved password details below.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.subtextColor,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),
                _buildInputField(
                  controller: _accountController,
                  icon: Icons.language,
                  hintText: 'Website or App (e.g. Netflix)',
                  fieldBg: fieldBg,
                  iconColor: iconColor,
                  textColor: colors.textColor,
                  hintColor: hintColor,
                ),
                const SizedBox(height: 16),
                _buildInputField(
                  controller: _userController,
                  icon: Icons.person_outline,
                  hintText: 'Email or Username',
                  fieldBg: fieldBg,
                  iconColor: iconColor,
                  textColor: colors.textColor,
                  hintColor: hintColor,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                          style: TextStyle(fontSize: 15, color: colors.textColor),
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
                          _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          color: colors.isDark ? Colors.white70 : const Color(0xFF6B4BA3),
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
