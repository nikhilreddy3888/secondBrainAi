import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_agent_kit/flutter_local_agent_kit.dart';

import '../../../shared/widgets/section_scaffold.dart';
import '../controller/ai_runtime_controller.dart';
import '../repository/ai_repository.dart';

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key, this.initialPrompt});

  final String? initialPrompt;

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  AssistantMode _mode = AssistantMode.chat;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(aiRuntimeControllerProvider.notifier).bootstrap(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final aiState = ref.watch(aiRuntimeControllerProvider);
    final aiController = ref.read(aiRuntimeControllerProvider.notifier);
    final repository = ref.read(aiRepositoryProvider);
    final cs = Theme.of(context).colorScheme;

    return SectionScaffold(
      title: 'AI Assistant',
      child: Column(
        children: [
          // ── Download banner ──
          if (!aiState.modelDownloaded) ...[
            Material(
              color: cs.surfaceContainerHighest,
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
                        style: TextStyle(color: cs.error),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Mode selector ──
          if (aiState.modelLoaded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: SegmentedButton<AssistantMode>(
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: WidgetStatePropertyAll(
                    Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                segments: const [
                  ButtonSegment(
                    value: AssistantMode.chat,
                    label: Text('Chat'),
                    icon: Icon(Icons.chat_bubble_outline, size: 16),
                  ),
                  ButtonSegment(
                    value: AssistantMode.vault,
                    label: Text('Vault Q&A'),
                    icon: Icon(Icons.search, size: 16),
                  ),
                  ButtonSegment(
                    value: AssistantMode.agent,
                    label: Text('Agent'),
                    icon: Icon(Icons.build_outlined, size: 16),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (selection) {
                  setState(() => _mode = selection.first);
                },
              ),
            ),

          // ── Chat view ──
          Expanded(
            child: aiState.modelLoaded
                ? AgentChatView(
                    onMessage: (content, {imageBytes, onCitations}) {
                      return repository.askStream(
                        content,
                        mode: _mode,
                        onCitations: (results) {
                          onCitations?.call(results.whereType<RetrievalResult>().toList());
                        },
                      );
                    },
                    initialHistory: widget.initialPrompt != null
                        ? [
                            AgentChatMessage(
                              id: 'init',
                              content: widget.initialPrompt!,
                              role: MessageRole.user,
                              timestamp: DateTime.now(),
                            ),
                          ]
                        : null,
                    welcomeMessage: _welcomeForMode(_mode),
                    accentColor: cs.primary,
                  )
                : const Center(
                    child: Text('Model not loaded. Please download or load the model.'),
                  ),
          ),
        ],
      ),
    );
  }

  String _welcomeForMode(AssistantMode mode) {
    switch (mode) {
      case AssistantMode.chat:
        return 'Free chat mode — talk to the on-device AI.\n\nExamples:\n• "Explain quantum computing"\n• "Write a haiku about rain"';
      case AssistantMode.vault:
        return 'Vault Q&A — ask about your stored data.\n\nExamples:\n• "What\'s my HDFC account number?"\n• "When is my passport expiring?"';
      case AssistantMode.agent:
        return 'Agent mode — create & manage vault items.\n\nExamples:\n• "Add a new note titled Groceries"\n• "Schedule a meeting for tomorrow at 3pm"';
    }
  }
}
