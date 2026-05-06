import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../models/vault_model.dart';
import '../../vault/controller/vault_controller.dart';

class AddNoteScreen extends ConsumerStatefulWidget {
  final VaultNote? note;

  const AddNoteScreen({super.key, this.note});

  @override
  ConsumerState<AddNoteScreen> createState() => _AddNoteScreenState();
}

class _AddNoteScreenState extends ConsumerState<AddNoteScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(text: widget.note?.content ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      if (mounted) context.pop();
      return;
    }

    final note = VaultNote(
      id: widget.note?.id ?? const Uuid().v4(),
      title: title.isEmpty ? 'Untitled' : title,
      content: content,
      updatedAt: DateTime.now(),
    );

    await ref.read(vaultControllerProvider.notifier).upsertNote(note);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note saved')),
      );
      context.go('/notes');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final primaryPurple = isDark ? const Color(0xFF9B7BF0) : const Color(0xFF6B4BA3);
    final bgGradientTop = isDark ? const Color(0xFF1E1A25) : const Color(0xFFFDF8FF);
    final bgGradientBottom = isDark ? const Color(0xFF120E15) : const Color(0xFFF2E6F7);
    final appBarBg = isDark ? const Color(0xFF2C2533).withOpacity(0.8) : const Color(0xFFFBF4FA).withOpacity(0.8);
    final textColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? Colors.white54 : Colors.black54;
    final cardBg = isDark ? const Color(0xFF241E2B).withOpacity(0.8) : Colors.white.withOpacity(0.6);
    final cardBorder = isDark ? Colors.white12 : Colors.white;
    final chipBg = isDark ? Colors.white12 : Colors.white.withOpacity(0.7);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [bgGradientTop, bgGradientBottom],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildFloatingAppBar(primaryPurple, appBarBg, textColor),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          _buildTitleField(primaryPurple),
                          const SizedBox(height: 12),
                          _buildMetadataChips(primaryPurple, chipBg),
                          const SizedBox(height: 24),
                          Expanded(
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                _buildEditorCard(primaryPurple, cardBg, cardBorder, textColor, hintColor),
                                Positioned(
                                  right: -15,
                                  bottom: -15,
                                  child: _buildElegantSaveButton(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20), // padding for bottom toolbars
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingAppBar(Color primaryPurple, Color appBarBg, Color textColor) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: appBarBg,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: primaryPurple),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/notes');
              }
            },
          ),
          Text(
            'AI Notes',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildTitleField(Color primaryPurple) {
    return TextField(
      controller: _titleController,
      style: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: primaryPurple,
        height: 1.2,
      ),
      maxLines: null,
      decoration: InputDecoration(
        hintText: 'Note Title',
        hintStyle: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: primaryPurple.withOpacity(0.5),
        ),
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildMetadataChips(Color primaryPurple, Color chipBg) {
    final now = widget.note?.updatedAt ?? DateTime.now();
    final timeString = 'Today, ${DateFormat('h:mm a').format(now)}';

    return Row(
      children: [
        _buildChip(timeString, primaryPurple, chipBg),
      ],
    );
  }

  Widget _buildChip(String text, Color color, Color bg, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorCard(Color primaryPurple, Color cardBg, Color cardBorder, Color textColor, Color hintColor) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: cardBorder, width: 2),
        boxShadow: [
          BoxShadow(
            color: primaryPurple.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          TextField(
            controller: _contentController,
            style: TextStyle(
              fontSize: 16,
              color: textColor,
              height: 1.6,
            ),
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            decoration: InputDecoration(
              hintText: 'Start typing your thoughts...',
              hintStyle: TextStyle(
                fontSize: 16,
                color: hintColor,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildElegantSaveButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFB55CF0), Color(0xFF7E42EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7E42EB).withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: _saveNote,
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: const Icon(Icons.save_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}
