import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../repository/ai_repository.dart';
import '../../../../core/app_colors.dart';

class ModernModeSelector extends StatelessWidget {
  const ModernModeSelector({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
  });

  final AssistantMode currentMode;
  final ValueChanged<AssistantMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderColor.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          _ModeItem(
            label: 'Chat',
            icon: Icons.chat_bubble_outline_rounded,
            isSelected: currentMode == AssistantMode.chat,
            onTap: () => onModeChanged(AssistantMode.chat),
          ),
          _ModeItem(
            label: 'Vault',
            icon: Icons.search_rounded,
            isSelected: currentMode == AssistantMode.vault,
            onTap: () => onModeChanged(AssistantMode.vault),
          ),
          _ModeItem(
            label: 'Agent',
            icon: Icons.auto_fix_high_rounded,
            isSelected: currentMode == AssistantMode.agent,
            onTap: () => onModeChanged(AssistantMode.agent),
          ),
        ],
      ),
    );
  }
}

class _ModeItem extends StatelessWidget {
  const _ModeItem({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? (colors.isDark ? Colors.white12 : Colors.white) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected && !colors.isDark
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? (colors.isDark ? Colors.purpleAccent : Colors.purple) : colors.subtextColor,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? colors.textColor : colors.subtextColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
