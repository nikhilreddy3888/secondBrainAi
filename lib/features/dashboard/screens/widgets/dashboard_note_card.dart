import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../models/vault_model.dart';
import '../../../../shared/widgets/confirm_delete_dialog.dart';
import '../../../vault/controller/vault_controller.dart';
import '../../../../core/app_colors.dart';

class DashboardNoteCard extends ConsumerWidget {
  const DashboardNoteCard({
    super.key,
    required this.note,
  });

  final VaultNote note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.borderColor),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    note.title,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colors.textColor,
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () {
                        context.push('/notes/add', extra: note);
                      },
                      child: Icon(
                        Icons.edit,
                        size: 16,
                        color: colors.subtextColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    InkWell(
                      onTap: () async {
                        final confirmed = await showDeleteConfirmation(
                          context,
                          itemType: 'Note',
                          itemName: note.title,
                        );
                        if (confirmed && context.mounted) {
                          ref.read(vaultControllerProvider.notifier).deleteNote(note.id);
                        }
                      },
                      child: Icon(
                        Icons.delete_outline,
                        size: 16,
                        color: colors.subtextColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              note.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.subtextColor,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: colors.subtextColor,
                ),
                const SizedBox(width: 4),
                Text(
                  note.updatedAt.toIso8601String().substring(0, 10),
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.subtextColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
