import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/vault_model.dart';
import '../../vault/controller/vault_controller.dart';
import '../../../core/app_colors.dart';
import 'widgets/event_card.dart';
import 'widgets/event_dialog.dart';

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<Color> _badgeColors = const [
    Color(0xFF2C0B5E),
    Color(0xFF6B5A8E),
    Color(0xFFC19B44),
    Color(0xFF4A3B69),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showEventDialog(BuildContext context, WidgetRef ref, [VaultEvent? event]) async {
    final result = await showDialog<VaultEvent>(
      context: context,
      builder: (context) => EventDialog(event: event),
    );
    if (result == null || result.title.isEmpty) return;
    await ref.read(vaultControllerProvider.notifier).upsertEvent(result);
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
          icon: Icon(Icons.arrow_back, color: colors.isDark ? Colors.white : const Color(0xFF5A49D6)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 24.0),
            child: Center(
              child: Text(
                'Second Brain',
                style: GoogleFonts.inter(
                  color: colors.isDark ? Colors.white : const Color(0xFF9E47FF),
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
            final events = [...vault.events]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
            final filteredEvents = events.where((e) {
              final query = _searchQuery.toLowerCase();
              return e.title.toLowerCase().contains(query) || e.description.toLowerCase().contains(query);
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
                              color: colors.textColor,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Organizing ${events.length} upcoming events',
                            style: TextStyle(fontSize: 16, color: colors.subtextColor),
                          ),
                          const SizedBox(height: 24),
                          _buildAddButton(context, ref),
                          const SizedBox(height: 24),
                          _buildSearchField(colors),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                  _buildEventsList(filteredEvents, colors),
                  _buildProductivityCard(colors),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAddButton(BuildContext context, WidgetRef ref) {
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
        onPressed: () => _showEventDialog(context, ref),
        icon: const Icon(Icons.add, color: Colors.white, size: 20),
        label: const Text('Add Event', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        ),
      ),
    );
  }

  Widget _buildSearchField(AppColors colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.isDark ? const Color(0xFF2C2533) : const Color(0xFFF3EDFD),
        borderRadius: BorderRadius.circular(32),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        style: TextStyle(color: colors.textColor),
        decoration: InputDecoration(
          hintText: 'Search events...',
          hintStyle: TextStyle(color: colors.subtextColor),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        ),
      ),
    );
  }

  Widget _buildEventsList(List<VaultEvent> filteredEvents, AppColors colors) {
    if (filteredEvents.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 40.0),
          child: Center(child: Text('No events found.', style: TextStyle(color: colors.subtextColor))),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final event = filteredEvents[index];
            final badgeColor = _badgeColors[index % _badgeColors.length];
            return EventCard(
              event: event,
              badgeColor: badgeColor,
              onEdit: () => _showEventDialog(context, ref, event),
            );
          },
          childCount: filteredEvents.length,
        ),
      ),
    );
  }

  Widget _buildProductivityCard(AppColors colors) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colors.isDark ? const Color(0xFF2A2435).withOpacity(0.8) : const Color(0xFFFAF7FF),
            borderRadius: BorderRadius.circular(32),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Maximize Productivity',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF6B4BA3)),
              ),
              const SizedBox(height: 8),
              Text(
                'Sync your calendar to automatically organize all your meetings and notes in one place.',
                style: TextStyle(fontSize: 14, color: colors.subtextColor, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
