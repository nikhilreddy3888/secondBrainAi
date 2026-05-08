import 'package:flutter/material.dart';
import '../../../../core/app_colors.dart';

class ChatWelcomePanel extends StatelessWidget {
  const ChatWelcomePanel({super.key, required this.message, required this.accentColor});
  final String message;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colors.surfaceColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: accentColor.withOpacity(0.2)),
          ),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textColor, fontSize: 15, height: 1.5),
          ),
        ),
      ),
    );
  }
}
