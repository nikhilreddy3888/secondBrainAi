import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/app_colors.dart';

class AssistantStatusBanner extends StatelessWidget {
  const AssistantStatusBanner({
    super.key,
    required this.title,
    required this.status,
    required this.buttonLabel,
    required this.onPressed,
    this.progress,
    this.error,
    this.icon = Icons.cloud_download_outlined,
  });

  final String title;
  final String status;
  final String buttonLabel;
  final VoidCallback? onPressed;
  final double? progress;
  final String? error;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: colors.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: colors.textColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: colors.textColor),
                        ),
                        Text(
                          status,
                          style: TextStyle(fontSize: 12, color: colors.subtextColor),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: onPressed,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      backgroundColor: colors.isDark ? Colors.purpleAccent : cs.primary,
                    ),
                    child: Text(buttonLabel),
                  ),
                ],
              ),
              if (progress != null && progress! > 0) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: colors.borderColor,
                    valueColor: AlwaysStoppedAnimation<Color>(colors.isDark ? Colors.purpleAccent : cs.primary),
                  ),
                ),
              ],
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
