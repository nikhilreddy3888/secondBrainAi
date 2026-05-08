import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:second_brain_app/models/vault_model.dart';

import '../../vault/controller/vault_controller.dart';
import '../../../core/app_colors.dart';
import 'widgets/note_card.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vaultAsync = ref.watch(vaultControllerProvider);
    final colors = AppColors.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: colors.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: colors.isDark ? Colors.white : const Color(0xFF5A49D6),
          ),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 24.0),
            child: Center(
              child: Text(
                'Second Brain',
                style: GoogleFonts.inter(
                  color: colors.isDark ? Colors.white : const Color(0xFF5A49D6),
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors.isDark
                ? [const Color(0xFF1E1A25), const Color(0xFF120F16)]
                : [const Color(0xFFF9F5FF), const Color(0xFFEBE0FA)],
          ),
        ),
        child: vaultAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text(error.toString())),
          data: (vault) {
            final filteredNotes = vault.notes.where((note) {
              final query = _searchQuery.toLowerCase();
              return note.title.toLowerCase().contains(query) ||
                  note.content.toLowerCase().contains(query);
            }).toList();

            return SafeArea(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Text(
                            'Notes',
                            style: GoogleFonts.inter(
                              fontSize: 48,
                              fontWeight: FontWeight.w400,
                              color: colors.textColor,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Organizing ${vault.notes.length} thoughts and ideas',
                            style: TextStyle(
                              fontSize: 16,
                              color: colors.subtextColor,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildAddButton(context),
                          const SizedBox(height: 24),
                          _buildSearchField(colors),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                  _buildNotesList(filteredNotes, colors),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: ElevatedButton.icon(
        onPressed: () => context.push('/notes/add'),
        icon: const Icon(
          Icons.add_circle_outline,
          color: Colors.white,
          size: 20,
        ),
        label: const Text(
          'New Note',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField(AppColors colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.isDark
            ? const Color(0xFF2C2533)
            : const Color(0xFFFAF7FF),
        borderRadius: BorderRadius.circular(32),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        style: TextStyle(color: colors.textColor),
        decoration: InputDecoration(
          hintText: 'Search notes...',
          hintStyle: TextStyle(color: colors.subtextColor),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 18,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Icon(Icons.search, color: colors.subtextColor),
          ),
        ),
      ),
    );
  }

  Widget _buildNotesList(List<VaultNote> notes, AppColors colors) {
    if (notes.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 40.0),
          child: Center(
            child: Text(
              'No notes found.',
              style: TextStyle(color: colors.subtextColor),
            ),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => NoteCard(note: notes[index]),
          childCount: notes.length,
        ),
      ),
    );
  }
}
