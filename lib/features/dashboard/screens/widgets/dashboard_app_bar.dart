import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../settings/controller/settings_controller.dart';
import '../../../../core/app_colors.dart';

class DashboardAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const DashboardAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);

    return AppBar(
      backgroundColor: colors.bgColor,
      elevation: 0,
      titleSpacing: 16,
      title: Row(
        children: [
          const Icon(
            Icons.psychology,
            color: Color(0xFFD388FF),
            size: 28,
          ),
          const SizedBox(width: 12),
          Text(
            'Second Brain',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: colors.textColor,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
      actions: [
        PopupMenuButton<String>(
          icon: Icon(
            Icons.settings_outlined,
            color: colors.subtextColor,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          color: theme.colorScheme.surface,
          onSelected: (value) {
            if (value == 'dark_mode') {
              final isCurrentlyDark = theme.brightness == Brightness.dark;
              final newTheme = isCurrentlyDark ? ThemeMode.light : ThemeMode.dark;
              ref.read(settingsControllerProvider.notifier).setThemeMode(newTheme);
            } else if (value == 'about') {
              showDialog(
                context: context,
                builder: (context) => Dialog(
                  backgroundColor: colors.surfaceColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(color: colors.borderColor),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFFE0B0FF), Color(0xFF9D4EDD)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Icon(
                            Icons.psychology,
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Second Brain',
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: colors.textColor,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: colors.passwordsColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Version 1.0.0',
                            style: TextStyle(
                              color: Color(0xFFD388FF),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Your offline, AI-powered personal knowledge vault. Safely store notes, passwords, documents, and events entirely on-device with the power of Local LLMs.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colors.subtextColor,
                            height: 1.5,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              backgroundColor: colors.passwordsColor,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Close',
                              style: TextStyle(
                                color: colors.textColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
          },
          itemBuilder: (context) {
            final isDark = theme.brightness == Brightness.dark;
            return [
              PopupMenuItem(
                value: 'dark_mode',
                child: Row(
                  children: [
                    Icon(
                      isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(isDark ? 'Light Mode' : 'Dark Mode'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'about',
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20),
                    SizedBox(width: 12),
                    Text('About us'),
                  ],
                ),
              ),
            ];
          },
        ),
      ],
    );
  }
}
