import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../models/vault_model.dart';
import '../../../../shared/widgets/confirm_delete_dialog.dart';
import '../../../vault/controller/vault_controller.dart';
import '../../../../core/app_colors.dart';
import 'document_viewer.dart';

class DocumentCard extends ConsumerWidget {
  const DocumentCard({
    super.key,
    required this.doc,
  });

  final VaultDocument doc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final ext = doc.fileName.split('.').last.toLowerCase();
    
    IconData iconData;
    Color iconColor;
    Color iconBgColor;

    if (ext == 'pdf') {
      iconData = Icons.picture_as_pdf_outlined;
      iconColor = const Color(0xFFE53935);
      iconBgColor = const Color(0xFFFFEBEE);
    } else if (['png', 'jpg', 'jpeg'].contains(ext)) {
      iconData = Icons.image_outlined;
      iconColor = const Color(0xFF1E88E5);
      iconBgColor = const Color(0xFFE3F2FD);
    } else if (['txt', 'doc', 'docx'].contains(ext)) {
      iconData = Icons.article_outlined;
      iconColor = const Color(0xFF5E35B1);
      iconBgColor = const Color(0xFFEDE7F6);
    } else if (['zip', 'rar', 'tar'].contains(ext)) {
      iconData = Icons.folder_zip_outlined;
      iconColor = const Color(0xFFF57C00);
      iconBgColor = const Color(0xFFFFF3E0);
    } else {
      iconData = Icons.description_outlined;
      iconColor = const Color(0xFF5A5A5A);
      iconBgColor = const Color(0xFFEEEEEE);
    }

    if (colors.isDark) {
      iconBgColor = iconColor.withOpacity(0.2);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(iconData, color: iconColor, size: 24),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  doc.title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: colors.textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  doc.fileName,
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.subtextColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => DocumentViewer.openDocument(context, doc),
            icon: Icon(Icons.visibility_outlined, color: colors.subtextColor, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'View document',
          ),
          const SizedBox(width: 16),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: colors.subtextColor, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            color: colors.surfaceColor,
            onSelected: (value) async {
              if (value == 'delete') {
                final confirmed = await showDeleteConfirmation(
                  context,
                  itemType: 'Document',
                  itemName: doc.title,
                );
                if (confirmed && context.mounted) {
                  ref.read(vaultControllerProvider.notifier).deleteDocument(doc.id);
                }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: colors.textColor))),
            ],
          ),
        ],
      ),
    );
  }
}
