import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../models/vault_model.dart';
import '../../../../shared/widgets/confirm_delete_dialog.dart';
import '../../../vault/controller/vault_controller.dart';
import '../../../../core/app_colors.dart';

class NoteCard extends ConsumerWidget {
  const NoteCard({
    super.key,
    required this.note,
  });

  final VaultNote note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surfaceColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: colors.borderColor, width: 1.5),
        boxShadow: [
          if (!colors.isDark)
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  note.title,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: colors.textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: colors.subtextColor, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: colors.surfaceColor,
                onSelected: (value) async {
                  if (value == 'edit') {
                    context.push('/notes/add', extra: note);
                  } else if (value == 'delete') {
                    final confirmed = await showDeleteConfirmation(
                      context,
                      itemType: 'Note',
                      itemName: note.title,
                    );
                    if (confirmed && context.mounted) {
                      ref.read(vaultControllerProvider.notifier).deleteNote(note.id);
                    }
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'edit', child: Text('Edit', style: TextStyle(color: colors.textColor))),
                  PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: colors.textColor))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            note.content,
            style: TextStyle(
              fontSize: 15,
              color: colors.subtextColor,
              height: 1.5,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
