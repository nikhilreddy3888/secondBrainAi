import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme.dart';
import '../../../models/vault_model.dart';
import '../../../shared/widgets/confirm_delete_dialog.dart';
import '../../events/screens/events_screen.dart';
import '../../documents/screens/documents_screen.dart';
import '../../settings/controller/settings_controller.dart';
import '../../vault/controller/vault_controller.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _aiController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _aiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: _buildAppBar(context),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSearchBar(theme),
                  const SizedBox(height: 16),
                  _buildActionButtons(context),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Notes',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          // Add new note logic
                          context.push('/notes/add');
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(
                            Icons.note_add,
                            size: 24,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          _buildNotesList(context, ref, theme),
        ],
      ),
      bottomNavigationBar: _buildBottomInput(context, theme),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final theme = Theme.of(context);
    return AppBar(
      centerTitle: true,
      title: Text(
        'Second Brain',
        style: GoogleFonts.playfairDisplay(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: theme.appBarTheme.foregroundColor,
        ),
      ),
      actions: [
        PopupMenuButton<String>(
          icon: Icon(Icons.settings_outlined, color: theme.colorScheme.onSurface),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          color: theme.colorScheme.surface,
          onSelected: (value) {
            if (value == 'dark_mode') {
              final currentTheme = ref.read(settingsControllerProvider).themeMode;
              final newTheme = currentTheme == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
              ref.read(settingsControllerProvider.notifier).setThemeMode(newTheme);
            } else if (value == 'about') {
              showAboutDialog(
                context: context,
                applicationName: 'Second Brain',
                applicationVersion: '1.0.0',
                applicationIcon: Icon(Icons.psychology, size: 48, color: theme.appBarTheme.foregroundColor),
                children: [
                  const Text('Your AI-powered personal knowledge vault. Safely store notes, passwords, documents, and events.'),
                ],
              );
            }
          },
          itemBuilder: (context) {
            final isDark = ref.watch(settingsControllerProvider).themeMode == ThemeMode.dark;
            return [
              PopupMenuItem(
                value: 'dark_mode',
                child: Row(
                  children: [
                    Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, size: 20),
                    const SizedBox(width: 12),
                    Text(isDark ? 'Light Mode' : 'Dark Mode'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'about',
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20),
                    SizedBox(width: 12),
                    Text('About us'),
                  ],
                ),
              ),
            ];
          },
        ),
      ],
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: theme.colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: 'Search notes, passwords, events, documents...',
          hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
        textInputAction: TextInputAction.search,
        onSubmitted: (value) {
          final query = value.trim();
          if (query.isNotEmpty) {
            context.push('/search', extra: query);
          }
        },
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () => context.push('/passwords'),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.actionButtonColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Passwords',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                Icon(Icons.visibility_off_outlined, color: Colors.white),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => context.push('/events'),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.actionButtonColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Events',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      Icon(Icons.arrow_right, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () => context.push('/documents'),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.actionButtonColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.description_outlined, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Documents',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      Icon(Icons.arrow_right, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNotesList(BuildContext context, WidgetRef ref, ThemeData theme) {
    final vault = ref.watch(vaultControllerProvider);
    return vault.when(
      loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
      error: (error, stack) => SliverFillRemaining(child: Center(child: Text(error.toString()))),
      data: (vault) {
        if (_searchQuery.trim().isNotEmpty) {
          final results = vault.search(_searchQuery);
          if (results.isEmpty) {
            return SliverFillRemaining(
              child: Center(
                child: Text(
                  'No vault items match your search.',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            );
          }
          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final result = results[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.colorScheme.outline),
                      ),
                      child: ListTile(
                        leading: Icon(result.icon),
                        title: Text(result.title),
                        subtitle: Text(
                          '${result.type} - ${result.subtitle}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _openSearchResult(context, vault, result),
                        trailing: result.secret == null
                            ? null
                            : const Icon(Icons.lock_outline),
                      ),
                    ),
                  );
                },
                childCount: results.length,
              ),
            ),
          );
        }
        final notes = vault.notes;
        
        if (notes.isEmpty) {
          return SliverFillRemaining(
            child: Center(
              child: Text(
                'No notes found.',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final note = notes[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.surface,
                          theme.colorScheme.surfaceContainerHighest,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
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
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
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
                                    size: 20,
                                    color: theme.colorScheme.onSurfaceVariant,
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
                                    size: 20,
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          note.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              note.updatedAt.toIso8601String().substring(0, 10),
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
              childCount: notes.length,
            ),
          ),
        );
      },
    );
  }

  Future<void> _openSearchResult(
    BuildContext context,
    VaultData vault,
    SearchResult result,
  ) async {
    switch (result.type) {
      case 'Note':
        final note = vault.notes.where((item) => item.id == result.id).firstOrNull;
        if (note != null) {
          context.push('/notes/add', extra: note);
        }
        return;
      case 'Document':
        final document =
            vault.documents.where((item) => item.id == result.id).firstOrNull;
        if (document != null) {
          DocumentsScreen.openDocument(context, document);
        }
        return;
      case 'Event':
        final event = vault.events.where((item) => item.id == result.id).firstOrNull;
        if (event != null && context.mounted) {
          await showDialog<VaultEvent>(
            context: context,
            builder: (context) => EventDialog(event: event),
          );
        }
        return;
      case 'Password':
        context.push('/passwords');
        return;
    }
  }

  Widget _buildBottomInput(BuildContext context, ThemeData theme) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: mediaQuery.padding.bottom + 12,
        ),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(color: theme.colorScheme.outline),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.actionButtonColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _aiController,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        decoration: InputDecoration(
                          hintText: 'Ask your second brain...',
                          hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: () {
                final prompt = _aiController.text.trim();
                if (prompt.isNotEmpty) {
                  context.push('/assistant', extra: prompt);
                  _aiController.clear();
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.actionButtonColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.send,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
