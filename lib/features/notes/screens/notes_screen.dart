import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/vault_model.dart';
import '../../../shared/widgets/confirm_delete_dialog.dart';
import '../../../shared/widgets/section_scaffold.dart';
import '../../vault/controller/vault_controller.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final vault = ref.watch(vaultControllerProvider);
    return vault.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text(error.toString())),
      data: (vault) {
        final notes = vault.notes.where((note) {
          return '${note.title} ${note.content}'
              .toLowerCase()
              .contains(_query.toLowerCase());
        }).toList();
        return SectionScaffold(
          title: 'Notes',
          action: FilledButton.icon(
            onPressed: () => _showNoteDialog(),
            icon: const Icon(Icons.add),
            label: const Text('New note'),
          ),
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search notes',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: EmptyAwareList(
                  isEmpty: notes.isEmpty,
                  emptyText: 'No notes found.',
                  child: ListView.separated(
                    itemCount: notes.length,
                    separatorBuilder: (_, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final note = notes[index];
                      return ListTile(
                        leading: const Icon(Icons.sticky_note_2_outlined),
                        title: Text(note.title),
                        subtitle: Text(
                          note.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'edit') _showNoteDialog(note);
                            if (value == 'delete') {
                              final confirmed = await showDeleteConfirmation(
                                context,
                                itemType: 'Note',
                                itemName: note.title,
                              );
                              if (confirmed) {
                                ref
                                    .read(vaultControllerProvider.notifier)
                                    .deleteNote(note.id);
                              }
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
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

  Future<void> _showNoteDialog([VaultNote? note]) async {
    final title = TextEditingController(text: note?.title ?? '');
    final content = TextEditingController(text: note?.content ?? '');
    final result = await showDialog<VaultNote>(
      context: context,
      builder: (context) => EditDialog(
        title: note == null ? 'New note' : 'Edit note',
        fields: [
          TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
          TextField(
            controller: content,
            decoration: const InputDecoration(labelText: 'Content'),
            minLines: 4,
            maxLines: 8,
          ),
        ],
        onSave: () => VaultNote(
          id: note?.id ?? uuid.v4(),
          title: title.text.trim(),
          content: content.text.trim(),
          updatedAt: DateTime.now(),
        ),
      ),
    );
    if (result == null || result.title.isEmpty) return;
    await ref.read(vaultControllerProvider.notifier).upsertNote(result);
  }
}
