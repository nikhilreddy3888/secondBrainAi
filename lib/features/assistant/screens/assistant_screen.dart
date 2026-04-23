import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/section_scaffold.dart';
import '../controller/ai_runtime_controller.dart';
import '../controller/assistant_controller.dart';
import '../repository/ai_repository.dart';

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.citations = const [],
  });

  final String text;
  final bool isUser;
  final List<AiCitation> citations;
}

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(aiRuntimeControllerProvider.notifier).bootstrap(),
    );
  }

  Future<void> _send() async {
    final text = _prompt.text.trim();
    if (text.isEmpty) return;
    _prompt.clear();
    setState(() => _messages.add(_ChatMessage(text: text, isUser: true)));
    try {
      final response = await ref.read(assistantControllerProvider).handle(text);
      final citations = ref.read(aiRepositoryProvider).lastCitations;
      setState(
        () => _messages.add(
          _ChatMessage(text: response, isUser: false, citations: citations),
        ),
      );
    } catch (error) {
      setState(
        () =>
            _messages.add(_ChatMessage(text: error.toString(), isUser: false)),
      );
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
                onPressed: _send,
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
