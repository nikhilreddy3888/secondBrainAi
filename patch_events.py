import sys

new_code = """import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../models/vault_model.dart';
import '../../../shared/widgets/confirm_delete_dialog.dart';
import '../../vault/controller/vault_controller.dart';

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<Color> _badgeColors = const [
    Color(0xFF2C0B5E), // dark purple
    Color(0xFF6B5A8E), // grayish purple
    Color(0xFFC19B44), // gold
    Color(0xFF4A3B69), // standard purple
  ];

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
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 24.0),
            child: Center(
              child: Text(
                'Second Brain',
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white : const Color(0xFF9E47FF),
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
            final events = [...vault.events]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
            final filteredEvents = events.where((e) {
              final query = _searchQuery.toLowerCase();
              return e.title.toLowerCase().contains(query) ||
                  e.description.toLowerCase().contains(query);
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
                            'Events',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 48,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Organizing ${events.length} upcoming events',
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
                              onPressed: () => _showEventDialog(context, ref),
                              icon: const Icon(Icons.add, color: Colors.white, size: 20),
                              label: const Text(
                                'Add Event',
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
                              color: isDark ? const Color(0xFF2C2533) : const Color(0xFFF3EDFD),
                              borderRadius: BorderRadius.circular(32),
                            ),
                            child: TextField(
                              controller: _searchController,
                              onChanged: (val) => setState(() => _searchQuery = val),
                              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                              decoration: InputDecoration(
                                hintText: 'Search events...',
                                hintStyle: TextStyle(
                                  color: isDark ? Colors.white54 : const Color(0xFF9E8DB3),
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
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
                    sliver: filteredEvents.isEmpty
                        ? SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 40.0),
                              child: Center(
                                child: Text(
                                  'No events found.',
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
                                final event = filteredEvents[index];
                                final badgeColor = _badgeColors[index % _badgeColors.length];
                                return _buildEventCard(context, ref, event, isDark, badgeColor);
                              },
                              childCount: filteredEvents.length,
                            ),
                          ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2A2435).withOpacity(0.8) : const Color(0xFFFAF7FF),
                          borderRadius: BorderRadius.circular(32),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Maximize Productivity',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF6B4BA3),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Sync your calendar to automatically organize all your meetings and notes in one place.',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white70 : const Color(0xFF5A5A5A),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, WidgetRef ref, VaultEvent event, bool isDark, Color badgeColor) {
    final monthFormat = DateFormat('MMM');
    final dayFormat = DateFormat('dd');
    final timeFormat = DateFormat('hh:mm a');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2435).withOpacity(0.8) : Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          if (!isDark)
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
                    color: isDark ? Colors.white : const Color(0xFF2D2D2D),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: isDark ? Colors.white54 : const Color(0xFF5A5A5A)),
                    const SizedBox(width: 6),
                    Text(
                      timeFormat.format(event.startsAt),
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white54 : const Color(0xFF5A5A5A),
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
                      color: isDark ? Colors.white54 : const Color(0xFF8C8C8C),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: isDark ? Colors.white54 : const Color(0xFF8C8C8C), size: 20),
            padding: EdgeInsets.zero,
            onSelected: (value) async {
              if (value == 'edit') _showEventDialog(context, ref, event);
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
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showEventDialog(
    BuildContext context,
    WidgetRef ref, [
    VaultEvent? event,
  ]) async {
    final result = await showDialog<VaultEvent>(
      context: context,
      builder: (context) => EventDialog(event: event),
    );
    if (result == null || result.title.isEmpty) return;
    await ref.read(vaultControllerProvider.notifier).upsertEvent(result);
  }
}
"""

with open('lib/features/events/screens/events_screen.dart', 'r') as f:
    lines = f.readlines()

bottom_part = "".join(lines[116:])

with open('lib/features/events/screens/events_screen.dart', 'w') as f:
    f.write(new_code + "\n" + bottom_part)

