import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/app_colors.dart';

class DashboardBottomInput extends StatelessWidget {
  const DashboardBottomInput({
    super.key,
    required this.controller,
  });

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: mediaQuery.padding.bottom + 12,
        ),
        color: colors.bgColor,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: colors.surfaceColor,
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: colors.borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFE0B0FF), Color(0xFF9D4EDD)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  style: TextStyle(color: colors.textColor),
                  decoration: InputDecoration(
                    hintText: 'Ask your second brain...',
                    hintStyle: TextStyle(
                      color: colors.subtextColor,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: () {
                  final prompt = controller.text.trim();
                  if (prompt.isNotEmpty) {
                    context.push('/assistant', extra: prompt);
                    controller.clear();
                  }
                },
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.passwordsColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.send, color: colors.textColor, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
