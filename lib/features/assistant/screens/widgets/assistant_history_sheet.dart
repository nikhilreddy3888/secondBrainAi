import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../shared/widgets/confirm_delete_dialog.dart';
import '../../controller/chat_session_controller.dart';
import '../../../../core/app_colors.dart';

class AssistantHistorySheet extends ConsumerWidget {
  const AssistantHistorySheet({
    super.key,
    required this.onSessionSelected,
  });

  final Function(String sessionId) onSessionSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatSessionControllerProvider);
    final controller = ref.read(chatSessionControllerProvider.notifier);
    final sessions = state.sessions;
    final colors = AppColors.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colors.bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.subtextColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Row(
                  children: [
                    Icon(Icons.history, color: colors.textColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Chat History',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: colors.textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              if (sessions.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      'No chat history yet.',
                      style: TextStyle(color: colors.subtextColor),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      final isSelected = session.id == state.activeSessionId;

                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: colors.surfaceColor,
                        title: Text(
                          session.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textColor,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          session.lastMessagePreview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: colors.subtextColor),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          color: colors.subtextColor,
                          onPressed: () async {
                            final confirmed = await showDeleteConfirmation(
                              context,
                              itemType: 'Chat Session',
                              itemName: session.title,
                            );
                            if (confirmed == true) {
                              await controller.deleteSession(session.id);
                            }
                          },
                        ),
                        onTap: () async {
                          onSessionSelected(session.id);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
