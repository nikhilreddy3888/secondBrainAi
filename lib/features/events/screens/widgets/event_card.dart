import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../models/vault_model.dart';
import '../../../../shared/widgets/confirm_delete_dialog.dart';
import '../../../vault/controller/vault_controller.dart';
import '../../../../core/app_colors.dart';

class EventCard extends ConsumerWidget {
  const EventCard({
    super.key,
    required this.event,
    required this.badgeColor,
    required this.onEdit,
  });

  final VaultEvent event;
  final Color badgeColor;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final monthFormat = DateFormat('MMM');
    final dayFormat = DateFormat('dd');
    final timeFormat = DateFormat('hh:mm a');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: colors.borderColor),
        boxShadow: [
          if (!colors.isDark)
            BoxShadow(
              color: const Color(0xFFE2D8F0).withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  monthFormat.format(event.startsAt).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  dayFormat.format(event.startsAt),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  event.title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: colors.textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: colors.subtextColor),
                    const SizedBox(width: 6),
                    Text(
                      timeFormat.format(event.startsAt),
                      style: TextStyle(
                        fontSize: 14,
                        color: colors.subtextColor,
                      ),
                    ),
                  ],
                ),
                if (event.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    event.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.subtextColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: colors.subtextColor, size: 20),
            padding: EdgeInsets.zero,
            color: colors.surfaceColor,
            onSelected: (value) async {
              if (value == 'edit') onEdit();
              if (value == 'delete') {
                final confirmed = await showDeleteConfirmation(
                  context,
                  itemType: 'Event',
                  itemName: event.title,
                );
                if (confirmed && context.mounted) {
                  ref.read(vaultControllerProvider.notifier).deleteEvent(event.id);
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
    );
  }
}
