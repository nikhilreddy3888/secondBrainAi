import sys

new_code = """import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/vault_model.dart';
import '../../../shared/widgets/confirm_delete_dialog.dart';
import '../../vault/controller/vault_controller.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isDark ? const Color(0xFF1E1A25) : const Color(0xFFF9F5FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : const Color(0xFF5A49D6)),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 24.0),
            child: Center(
              child: Text(
                'Second Brain',
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white : const Color(0xFF5A49D6),
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
            colors: isDark
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
                              color: isDark ? Colors.white : const Color(0xFF3F2A6E),
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Organizing ${vault.notes.length} thoughts and ideas',
                            style: TextStyle(
                              fontSize: 16,
                              color: isDark ? Colors.white70 : const Color(0xFF5A5A5A),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(32),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6366F1).withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: () => context.push('/notes/add'),
                              icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 20),
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
                          ),
                          const SizedBox(height: 24),
                          Container(
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2C2533) : const Color(0xFFFAF7FF),
                              borderRadius: BorderRadius.circular(32),
                            ),
                            child: TextField(
                              controller: _searchController,
                              onChanged: (val) => setState(() => _searchQuery = val),
                              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                              decoration: InputDecoration(
                                hintText: 'Search notes...',
                                hintStyle: TextStyle(
                                  color: isDark ? Colors.white54 : const Color(0xFF9E8DB3),
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                                prefixIcon: Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: Icon(
                                    Icons.search,
                                    color: isDark ? Colors.white54 : const Color(0xFF9E8DB3),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    sliver: filteredNotes.isEmpty
                        ? SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 40.0),
                              child: Center(
                                child: Text(
                                  'No notes found.',
                                  style: TextStyle(
                                    color: isDark ? Colors.white54 : const Color(0xFF6B5A8E),
                                  ),
                                ),
                              ),
                            ),
                          )
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final note = filteredNotes[index];
                                return _buildNoteCard(context, ref, note, isDark);
                              },
                              childCount: filteredNotes.length,
                            ),
                          ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNoteCard(BuildContext context, WidgetRef ref, VaultNote note, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2435).withOpacity(0.8) : Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.white,
          width: 1.5,
        ),
        boxShadow: [
          if (!isDark)
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
                    color: isDark ? Colors.white : const Color(0xFF2D2D2D),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: isDark ? Colors.white54 : const Color(0xFF8C8C8C), size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
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
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            note.content,
            style: TextStyle(
              fontSize: 15,
              color: isDark ? Colors.white70 : const Color(0xFF8C8C8C),
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
"""

with open('lib/features/notes/screens/notes_screen.dart', 'w') as f:
    f.write(new_code)
