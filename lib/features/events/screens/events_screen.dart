import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../models/vault_model.dart';
import '../../../shared/widgets/confirm_delete_dialog.dart';
import '../../../shared/widgets/section_scaffold.dart';
import '../../vault/controller/vault_controller.dart';

class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vault = ref.watch(vaultControllerProvider);
    return vault.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text(error.toString())),
      data: (vault) {
        final events = [...vault.events]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
        return SectionScaffold(
          title: 'Events',
          action: FilledButton.icon(
            onPressed: () => _showEventDialog(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('New event'),
          ),
          child: EmptyAwareList(
            isEmpty: events.isEmpty,
            emptyText: 'No events scheduled.',
            child: ListView.separated(
              itemCount: events.length,
              separatorBuilder: (_, index) => const SizedBox.shrink(),
              itemBuilder: (context, index) {
                final event = events[index];
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
                        child: Icon(Icons.event_outlined, color: theme.colorScheme.onSurfaceVariant),
                      ),
                      title: Text(
                        event.title,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          '${DateFormat.yMMMd().add_jm().format(event.startsAt)} - ${event.description}',
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                      trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') _showEventDialog(context, ref, event);
                      if (value == 'delete') {
                        final confirmed = await showDeleteConfirmation(
                          context,
                          itemType: 'Event',
                          itemName: event.title,
                        );
                        if (confirmed) {
                          ref.read(vaultControllerProvider.notifier).deleteEvent(event.id);
                        }
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                    ),
                  ),
                ),
              );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _showEventDialog(
    BuildContext context,
    WidgetRef ref, [
    VaultEvent? event,
  ]) async {
    final title = TextEditingController(text: event?.title ?? '');
    final description = TextEditingController(text: event?.description ?? '');
    DateTime selected = event?.startsAt ?? DateTime.now().add(const Duration(hours: 1));
    final result = await showDialog<VaultEvent>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => EditDialog(
          title: event == null ? 'New event' : 'Edit event',
          fields: [
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: Text(DateFormat.yMMMd().add_jm().format(selected)),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: selected,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (date == null || !context.mounted) return;
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(selected),
                );
                if (time == null) return;
                setDialogState(() {
                  selected = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                });
              },
            ),
            TextField(
              controller: description,
              decoration: const InputDecoration(labelText: 'Description'),
              minLines: 3,
              maxLines: 6,
            ),
          ],
          onSave: () => VaultEvent(
            id: event?.id ?? uuid.v4(),
            title: title.text.trim(),
            startsAt: selected,
            description: description.text.trim(),
          ),
        ),
      ),
    );
    if (result == null || result.title.isEmpty) return;
    await ref.read(vaultControllerProvider.notifier).upsertEvent(result);
  }
}
