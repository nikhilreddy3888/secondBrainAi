import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/app_colors.dart';

class AssistantHelpSheet extends StatelessWidget {
  const AssistantHelpSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    
    return Container(
      decoration: BoxDecoration(
        color: colors.bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.subtextColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How to use the Assistant',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: colors.textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose a mode and try these example prompts to get started.',
                  style: TextStyle(color: colors.subtextColor, fontSize: 15),
                ),
                const SizedBox(height: 24),
                _buildModeSection(
                  context,
                  title: 'Chat Mode',
                  icon: Icons.chat_bubble_outline_rounded,
                  color: Colors.blue,
                  prompts: [
                    'Explain the theory of relativity like I\'m five.',
                    'Write an inspiring poem about focus.',
                    'Brainstorm 5 gift ideas for a traveler.',
                  ],
                ),
                const SizedBox(height: 16),
                _buildModeSection(
                  context,
                  title: 'Vault Mode',
                  icon: Icons.search_rounded,
                  color: Colors.amber,
                  prompts: [
                    'What are my notes about Project Alpha?',
                    'When is my next dentist appointment?',
                    'Find the username for my Netflix account.',
                  ],
                ),
                const SizedBox(height: 16),
                _buildModeSection(
                  context,
                  title: 'Agent Mode',
                  icon: Icons.smart_toy_outlined,
                  color: Colors.purple,
                  prompts: [
                    'Create a note called Shopping List with Milk and Bread.',
                    'Save a password for GitHub with my username.',
                    'Schedule an event for Team Lunch this Friday at 1 PM.',
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required List<String> prompts,
  }) {
    final colors = AppColors.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: colors.textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...prompts.map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    p,
                    style: TextStyle(
                      color: colors.textColor.withOpacity(0.8),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
