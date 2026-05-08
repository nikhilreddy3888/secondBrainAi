import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../models/vault_model.dart';
import '../../vault/controller/vault_controller.dart';
import '../../../core/app_colors.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note saved')));
      context.go('/notes');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors.isDark
                ? [const Color(0xFF1E1A25), const Color(0xFF120E15)]
                : [const Color(0xFFFDF8FF), const Color(0xFFF2E6F7)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(colors),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      _buildTitleField(colors),
                      const SizedBox(height: 12),
                      _buildMetadataChips(colors),
                      const SizedBox(height: 24),
                      Expanded(
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            _buildEditorCard(colors),
                            Positioned(
                              right: -15,
                              bottom: -15,
                              child: _buildSaveButton(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(AppColors colors) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surfaceColor.withOpacity(0.8),
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
            icon: Icon(Icons.arrow_back, color: colors.textColor),
            onPressed: () => context.canPop() ? context.pop() : context.go('/notes'),
          ),
          Text(
            'Edit Note',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: colors.textColor),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildTitleField(AppColors colors) {
    return TextField(
      controller: _titleController,
      style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: colors.textColor, height: 1.2),
      maxLines: null,
      decoration: InputDecoration(
        hintText: 'Note Title',
        hintStyle: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: colors.subtextColor.withOpacity(0.5)),
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildMetadataChips(AppColors colors) {
    final now = widget.note?.updatedAt ?? DateTime.now();
    final timeString = 'Last updated: ${DateFormat('h:mm a').format(now)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.borderColor),
      ),
      child: Text(
        timeString,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.subtextColor),
      ),
    );
  }

  Widget _buildEditorCard(AppColors colors) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surfaceColor.withOpacity(0.7),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: colors.borderColor, width: 2),
      ),
      child: TextField(
        controller: _contentController,
        style: TextStyle(fontSize: 16, color: colors.textColor, height: 1.6),
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        decoration: InputDecoration(
          hintText: 'Start typing...',
          hintStyle: TextStyle(fontSize: 16, color: colors.subtextColor),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
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
