import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/security/biometric_auth.dart';
import '../../../models/vault_model.dart';
import '../../../shared/widgets/section_scaffold.dart';
import '../../events/screens/events_screen.dart';
import '../../documents/screens/documents_screen.dart';
import '../../settings/controller/settings_controller.dart';
import '../../vault/controller/vault_controller.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery?.trim() ?? '';
    _controller = TextEditingController(text: _query);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
                controller: _controller,
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
                            onTap: () => _openResult(context, ref, vault, result),
                        trailing: result.secret == null
                            ? null
                            : IconButton(
                                tooltip: 'Reveal secret',
                                onPressed: () => _showSecret(
                                  context,
                                  ref,
                                  result.secret!,
                                ),
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

  Future<void> _openResult(
    BuildContext context,
    WidgetRef ref,
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
      case 'Password':
        if (result.secret != null) {
          await _showSecret(context, ref, result.secret!);
        }
        return;
      case 'Event':
        final event =
            vault.events.where((item) => item.id == result.id).firstOrNull;
        if (event != null && context.mounted) {
          _showEvent(context, ref, event);
        }
        return;
    }
  }

  Future<void> _showEvent(BuildContext context, WidgetRef ref, VaultEvent event) async {
    final result = await showDialog<VaultEvent>(
      context: context,
      builder: (context) => EventDialog(event: event),
    );
    if (result == null || result.title.isEmpty) return;
    await ref.read(vaultControllerProvider.notifier).upsertEvent(result);
  }

  Future<void> _showSecret(
    BuildContext context,
    WidgetRef ref,
    String secret,
  ) async {
    final settings = ref.read(settingsControllerProvider);
    if (settings.biometricEnabled) {
      final authorized = await ref.read(biometricAuthProvider).authenticate(
            reason: 'Authenticate to reveal this password',
          );
      if (!authorized || !context.mounted) return;
    }
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
