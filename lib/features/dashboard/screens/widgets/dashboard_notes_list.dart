import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../models/vault_model.dart';
import '../../../documents/screens/documents_screen.dart';
import '../../../events/screens/widgets/event_dialog.dart';
import '../../../vault/controller/vault_controller.dart';
import '../../../../core/app_colors.dart';
import 'dashboard_note_card.dart';

class DashboardNotesList extends ConsumerWidget {
  const DashboardNotesList({
    super.key,
    required this.searchQuery,
  });

  final String searchQuery;

  Future<void> _openSearchResult(
    BuildContext context,
    WidgetRef ref,
    VaultData vault,
    SearchResult result,
  ) async {
    switch (result.type) {
      case 'Note':
        final note = vault.notes.where((item) => item.id == result.id).firstOrNull;
        if (note != null && context.mounted) {
          context.push('/notes/add', extra: note);
        }
        return;
      case 'Document':
        final document = vault.documents.where((item) => item.id == result.id).firstOrNull;
        if (document != null && context.mounted) {
          DocumentsScreen.openDocument(context, document);
        }
        return;
      case 'Event':
        final event = vault.events.where((item) => item.id == result.id).firstOrNull;
        if (event != null && context.mounted) {
          final dialogResult = await showDialog<VaultEvent>(
            context: context,
            builder: (context) => EventDialog(event: event),
          );
          if (dialogResult != null && dialogResult.title.isNotEmpty) {
            await ref.read(vaultControllerProvider.notifier).upsertEvent(dialogResult);
          }
        }
        return;
      case 'Password':
        if (context.mounted) {
          context.push('/passwords');
        }
        return;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vault = ref.watch(vaultControllerProvider);
    final theme = Theme.of(context);
    final colors = AppColors.of(context);

    return vault.when(
      loading: () => const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => SliverFillRemaining(child: Center(child: Text(error.toString()))),
      data: (vaultData) {
        if (searchQuery.trim().isNotEmpty) {
          final results = vaultData.search(searchQuery);
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
              delegate: SliverChildBuilderDelegate((context, index) {
                final result = results[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: colors.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.borderColor),
                    ),
                    child: ListTile(
                      leading: Icon(result.icon, color: colors.textColor),
                      title: Text(result.title, style: TextStyle(color: colors.textColor)),
                      subtitle: Text(
                        '${result.type} - ${result.subtitle}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.subtextColor),
                      ),
                      onTap: () => _openSearchResult(context, ref, vaultData, result),
                      trailing: result.secret == null ? null : Icon(Icons.lock_outline, color: colors.subtextColor),
                    ),
                  ),
                );
              }, childCount: results.length),
            ),
          );
        }
        final notes = vaultData.notes;

        if (notes.isEmpty) {
          return SliverFillRemaining(
            child: Center(
              child: Text(
                'No notes found.',
                style: TextStyle(color: colors.subtextColor),
              ),
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final note = notes[index];
              return DashboardNoteCard(note: note);
            }, childCount: notes.length),
          ),
        );
      },
    );
  }
}
