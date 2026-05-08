import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../repository/assistant_tools.dart';
import '../../../../core/app_colors.dart';

class ChatBubble {
  const ChatBubble({required this.role, required this.content, this.citations = const []});
  final String role;
  final String content;
  final List<VaultCitation> citations;
}

class ChatBubbleTile extends StatelessWidget {
  const ChatBubbleTile({super.key, required this.message, required this.accentColor});
  final ChatBubble message;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isUser = message.role == 'user';
    final isStreaming = message.role == 'assistant-stream';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 300),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isUser ? accentColor : colors.surfaceColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isUser ? 20 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 20),
              ),
              border: isUser ? null : Border.all(color: colors.borderColor),
            ),
            child: Text(
              message.content.isEmpty && isStreaming ? 'Generating...' : message.content,
              style: GoogleFonts.inter(color: isUser ? Colors.white : colors.textColor, fontSize: 15, height: 1.4),
            ),
          ),
          if (!isUser && message.citations.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: message.citations.map((c) => _CitationChip(citation: c)).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _CitationChip extends StatelessWidget {
  const _CitationChip({required this.citation});
  final VaultCitation citation;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final chipColor = switch (citation.type) {
      'note' => Colors.amber,
      'password' => Colors.redAccent,
      'event' => Colors.teal,
      'document' => Colors.indigo,
      _ => Colors.purple,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: chipColor.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(citation.icon, size: 14, color: chipColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              citation.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textColor),
            ),
          ),
        ],
      ),
    );
  }
}
