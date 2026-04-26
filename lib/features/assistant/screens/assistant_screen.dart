import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../models/vault_model.dart';
import '../../../shared/widgets/section_scaffold.dart';
import '../../documents/screens/documents_screen.dart';
import '../../vault/controller/vault_controller.dart';
import '../controller/ai_runtime_controller.dart';
import '../controller/assistant_controller.dart';
import '../repository/ai_repository.dart';

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.citations = const [],
    this.actions = const [],
    this.isLoading = false,
  });

  final String text;
  final bool isUser;
  final List<AiCitation> citations;
  final List<_AssistantAction> actions;
  final bool isLoading;
}

class _AssistantAction {
  const _AssistantAction({
    required this.label,
    required this.type,
    this.id,
  });

  final String label;
  final String type;
  final String? id;
}

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key, this.initialPrompt});

  final String? initialPrompt;

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final TextEditingController _prompt = TextEditingController();
  final List<_ChatMessage> _messages = [
    const _ChatMessage(
      text:
          'Ask about your stored data, or create items with natural language.\n'
          'Examples:\n'
          '- What\'s my HDFC account number?\n'
          '- When is my passport expiring?\n'
          '- Add a new note with title "Meeting with John" and content "Discussed project timeline"',
      isUser: false,
    ),
  ];
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(aiRuntimeControllerProvider.notifier).bootstrap(),
    );
    final initialPrompt = widget.initialPrompt?.trim();
    if (initialPrompt != null && initialPrompt.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _prompt.text = initialPrompt;
        _send();
      });
    }
  }

  Future<void> _send() async {
    final text = _prompt.text.trim();
    if (text.isEmpty || _isSending) return;
    _prompt.clear();
    setState(() {
      _isSending = true;
      _messages
        ..add(_ChatMessage(text: text, isUser: true))
        ..add(
          const _ChatMessage(text: '', isUser: false, isLoading: true),
        );
    });
    try {
      final response = await ref.read(assistantControllerProvider).handle(text);
      final citations = ref.read(aiRepositoryProvider).lastCitations;
      final vault = await ref.read(vaultControllerProvider.future);
      final actions = _actionsFor(text, response, vault);
      if (!mounted) return;
      setState(() {
        _messages.removeLast();
        _messages.add(
          _ChatMessage(
            text: response,
            isUser: false,
            citations: citations,
            actions: actions,
          ),
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.removeLast();
        _messages.add(_ChatMessage(text: error.toString(), isUser: false));
      });
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _showCitation(AiCitation citation) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '[${citation.label}] ${citation.sourceType}: ${citation.title}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                SelectableText(citation.excerpt),
              ],
            ),
          ),
        );
      },
    );
  }

  List<_AssistantAction> _actionsFor(
    String prompt,
    String response,
    VaultData vault,
  ) {
    final text = '$prompt\n$response'.toLowerCase();
    final actions = <_AssistantAction>[];

    void addSection(String label, String type) {
      if (!actions.any((action) => action.type == type && action.id == null)) {
        actions.add(_AssistantAction(label: label, type: type));
      }
    }

    if (text.contains('note')) {
      addSection('Open Notes', 'notes');
      actions.addAll(
        vault.notes.take(3).map(
              (note) => _AssistantAction(
                label: note.title,
                type: 'note',
                id: note.id,
              ),
            ),
      );
    }
    if (text.contains('password') || text.contains('credential')) {
      addSection('Open Passwords', 'passwords');
    }
    if (text.contains('event') || text.contains('schedule')) {
      addSection('Open Events', 'events');
      actions.addAll(
        vault.events.take(3).map(
              (event) => _AssistantAction(
                label: event.title,
                type: 'event',
                id: event.id,
              ),
            ),
      );
    }
    if (text.contains('document') || text.contains('file')) {
      addSection('Open Documents', 'documents');
      actions.addAll(
        vault.documents.take(3).map(
              (doc) => _AssistantAction(
                label: doc.title,
                type: 'document',
                id: doc.id,
              ),
            ),
      );
    }

    for (final result in vault.search(prompt).take(3)) {
      actions.add(
        _AssistantAction(
          label: result.title,
          type: result.type.toLowerCase(),
          id: result.id,
        ),
      );
    }

    final unique = <String, _AssistantAction>{};
    for (final action in actions) {
      unique['${action.type}:${action.id ?? ''}'] = action;
    }
    return unique.values.take(8).toList();
  }

  Future<void> _runAction(_AssistantAction action) async {
    final vault = await ref.read(vaultControllerProvider.future);
    if (!mounted) return;

    switch (action.type) {
      case 'notes':
        context.push('/notes');
        return;
      case 'passwords':
        context.push('/passwords');
        return;
      case 'events':
        context.push('/events');
        return;
      case 'documents':
        context.push('/documents');
        return;
      case 'note':
        final note = vault.notes
            .where((item) => item.id == action.id)
            .firstOrNull;
        if (note != null) {
          context.push('/notes/add', extra: note);
        }
        return;
      case 'document':
        final document = vault.documents
            .where((item) => item.id == action.id)
            .firstOrNull;
        if (document != null) {
          DocumentsScreen.openDocument(context, document);
        }
        return;
      case 'event':
        final event = vault.events
            .where((item) => item.id == action.id)
            .firstOrNull;
        if (event != null) {
          _showEvent(event);
        }
        return;
      case 'password':
        context.push('/passwords');
        return;
    }
  }

  void _showEvent(VaultEvent event) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(event.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat.yMMMd().add_jm().format(event.startsAt)),
            if (event.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              SelectableText(event.description),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final aiState = ref.watch(aiRuntimeControllerProvider);
    final aiController = ref.read(aiRuntimeControllerProvider.notifier);
    return SectionScaffold(
      title: 'AI Assistant',
      child: Column(
        children: [
          if (!aiState.modelDownloaded) ...[
            Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          aiState.modelLoaded
                              ? Icons.memory
                              : Icons.memory_outlined,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(aiState.status)),
                        FilledButton(
                          onPressed: aiState.downloading
                              ? null
                              : aiController.downloadAndLoadModel,
                          child: const Text('Download'),
                        ),
                      ],
                    ),
                    if (aiState.downloading || aiState.progress > 0) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: aiState.progress),
                    ],
                    if (aiState.error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        aiState.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isUser = message.isUser;
                final text = message.text;
                final theme = Theme.of(context);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Align(
                    alignment: isUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: isUser
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: isUser
                                ? const Radius.circular(16)
                                : const Radius.circular(4),
                            bottomRight: isUser
                                ? const Radius.circular(4)
                                : const Radius.circular(16),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                text,
                                style: TextStyle(
                                  color: isUser
                                      ? theme.colorScheme.onPrimaryContainer
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (message.isLoading) const _LoadingBubble(),
                              if (!isUser && message.citations.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: message.citations
                                      .map(
                                        (citation) => ActionChip(
                                          label: Text('[${citation.label}]'),
                                          onPressed: () =>
                                              _showCitation(citation),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],
                              if (!isUser && message.actions.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: message.actions
                                      .map(
                                        (action) => ActionChip(
                                          label: Text(action.label),
                                          onPressed: () => _runAction(action),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _prompt,
                  decoration: const InputDecoration(
                    hintText: 'Ask or create: "Add a new event with title ..."',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filled(
                tooltip: 'Send',
                onPressed: _isSending ? null : _send,
                icon: Icon(_isSending ? Icons.hourglass_top : Icons.send),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoadingBubble extends StatelessWidget {
  const _LoadingBubble();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: color),
        ),
        const SizedBox(width: 10),
        Text('Thinking...', style: TextStyle(color: color)),
      ],
    );
  }
}
