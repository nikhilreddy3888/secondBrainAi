import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../shared/widgets/section_scaffold.dart';
import '../../vault/controller/vault_controller.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final vault = ref.watch(vaultControllerProvider);
    return vault.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text(error.toString())),
      data: (vault) {
        final results = vault.search(_query);
        return SectionScaffold(
          title: 'Global Search',
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search notes, passwords, events, and documents',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: EmptyAwareList(
                  isEmpty: _query.isEmpty || results.isEmpty,
                  emptyText: _query.isEmpty ? 'Start typing to search.' : 'No results found.',
                  child: ListView.separated(
                    itemCount: results.length,
                    separatorBuilder: (_, index) => const SizedBox.shrink(),
                    itemBuilder: (context, index) {
                      final result = results[index];
                      final theme = Theme.of(context);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.colorScheme.outline),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(result.icon, color: theme.colorScheme.onSurfaceVariant),
                            ),
                            title: Text(
                              result.title,
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            subtitle: Text(
                              result.subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                            ),
                        trailing: result.secret == null
                            ? null
                            : IconButton(
                                tooltip: 'Reveal secret',
                                onPressed: () => _showSecret(context, result.secret!),
                                icon: const Icon(Icons.visibility_outlined),
                              ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSecret(BuildContext context, String secret) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Protected secret'),
        content: SelectableText(secret),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }
}
