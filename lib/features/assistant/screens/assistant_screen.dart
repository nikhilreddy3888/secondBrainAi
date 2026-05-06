import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_agent_kit/flutter_local_agent_kit.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../shared/widgets/section_scaffold.dart';
import '../../../shared/widgets/confirm_delete_dialog.dart';
import '../controller/ai_runtime_controller.dart';
import '../controller/chat_session_controller.dart';
import '../repository/ai_model_registry.dart';
import '../repository/ai_repository.dart';

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key, this.initialPrompt});

  final String? initialPrompt;

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  AssistantMode _mode = AssistantMode.chat;
  Key _chatViewKey = UniqueKey();
  bool _initialPromptProcessed = false;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      ref.read(aiRuntimeControllerProvider.notifier).bootstrap();
      final chatController = ref.read(chatSessionControllerProvider.notifier);
      await chatController.loadSessions();
      // Always start fresh when entering the assistant screen from dashboard/elsewhere
      chatController.startNewSession();
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final aiState = ref.watch(aiRuntimeControllerProvider);
    final aiController = ref.read(aiRuntimeControllerProvider.notifier);
    final repository = ref.read(aiRepositoryProvider);
    final chatState = ref.watch(chatSessionControllerProvider);
    final chatController = ref.read(chatSessionControllerProvider.notifier);
    final cs = Theme.of(context).colorScheme;

    return SectionScaffold(
      title: 'AI Assistant',
      actions: [
        IconButton(
          tooltip: 'New Chat',
          icon: const Icon(Icons.add_comment_outlined),
          onPressed: () {
            chatController.startNewSession();
            setState(() {
              _chatViewKey = UniqueKey();
            });
          },
        ),
        IconButton(
          tooltip: 'Chat History',
          icon: const Icon(Icons.history_rounded),
          onPressed: () => _showHistorySheet(context),
        ),
      ],
      bodyPadding: EdgeInsets.zero,
      child: Column(
        children: [
          if (!aiState.initialized)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(aiState.status),
                  ],
                ),
              ),
            )
          else ...[
          // ── Model selector ──
          _ModelSelectorTile(
            selectedModelId: aiState.selectedModelId ?? AiModelRegistry.defaultModel.id,
            isModelLoaded: aiState.modelLoaded,
            onModelChanged: (modelId) {
              aiController.selectModel(modelId);
            },
          ),

          // ── Download banner ──
          if (!aiState.modelDownloaded) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Material(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.cloud_download_outlined, color: cs.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              aiState.status,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          FilledButton(
                            onPressed: aiState.downloading
                                ? null
                                : aiController.downloadAndLoadModel,
                            child: const Text('Download'),
                          ),
                        ],
                      ),
                      if (aiState.downloading || aiState.progress > 0) ...[
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: aiState.progress,
                            minHeight: 6,
                          ),
                        ),
                      ],
                      if (aiState.error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          aiState.error!,
                          style: TextStyle(color: cs.error, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          if (aiState.modelDownloaded && !aiState.modelLoaded) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Material(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(Icons.memory_outlined, color: cs.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          aiState.status,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      FilledButton(
                        onPressed: aiController.loadDownloadedModel,
                        child: const Text('Load'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // ── Mode selector + New chat button ──
          if (aiState.modelLoaded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
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
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    tooltip: 'New chat',
                    onPressed: () {
                      chatController.startNewSession();
                      setState(() {
                        _chatViewKey = UniqueKey();
                      });
                    },
                    icon: const Icon(Icons.add_comment_outlined, size: 20),
                  ),
                ],
              ),
            ),

          // ── Chat view ──
          Expanded(
            child: _isInitializing
                ? const Center(child: CircularProgressIndicator())
                : aiState.modelLoaded
                    ? AgentChatView(
                        key: _chatViewKey,
                    initialHistory: chatState.activeSession != null
                        ? chatController.getHistoryForLLM(chatState.activeSession!)
                        : null,
                    onMessage: (content, {imageBytes, onCitations}) async* {
                      if (!_initialPromptProcessed) {
                        _initialPromptProcessed = true;
                      }

                      final currentAiState = ref.read(aiRuntimeControllerProvider);
                      String? currentSessionId = ref.read(chatSessionControllerProvider).activeSessionId;

                      if (currentSessionId == null) {
                        final newSession = await chatController.createSession(
                          modelId: currentAiState.selectedModelId ?? AiModelRegistry.defaultModel.id,
                          mode: _mode.name,
                        );
                        currentSessionId = newSession.id;
                      }

                      // Get history for the SPECIFIC session we are interacting with
                      // This now loads from DB if needed to ensure we never lose context.
                      final history = await chatController.getFullHistory(currentSessionId);

                      await chatController.addUserMessage(content, sessionId: currentSessionId);

                      final stream = repository.askStream(
                        content,
                        mode: _mode,
                        history: history,
                        sessionId: currentSessionId,
                        onCitations: (results) {
                          onCitations?.call(
                            results.whereType<RetrievalResult>().toList(),
                          );
                        },
                      );

                      final responseBuffer = StringBuffer();
                      try {
                        await for (final token in stream.timeout(const Duration(seconds: 90))) {
                          responseBuffer.write(token);
                          yield token;
                        }
                      } on TimeoutException {
                        const timeoutMessage =
                            'I am taking longer than expected and did not complete this response. Please try again.';
                        responseBuffer.write(timeoutMessage);
                        yield timeoutMessage;
                      }

                      if (responseBuffer.toString().trim().isEmpty) {
                        const emptyMessage =
                            'I could not generate a response for that request. Please try rephrasing and send again.';
                        responseBuffer.write(emptyMessage);
                        yield emptyMessage;
                      }

                      await chatController.addAssistantMessage(
                        responseBuffer.toString(),
                        sessionId: currentSessionId,
                      );
                      await chatController.refreshSessions();
                    },
                    initialPromptToSend: _initialPromptProcessed ? null : widget.initialPrompt,
                    welcomeMessage: chatState.activeSessionId == null
                        ? _welcomeForMode(_mode)
                        : null,
                    accentColor: cs.primary,
                    enableImagePicker: false,
                  )
                : const Center(
                    child: Text('Model not loaded. Please download or load the model.'),
                  ),
          ),
          ],
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

  void _showHistorySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final state = ref.watch(chatSessionControllerProvider);
            final controller = ref.read(chatSessionControllerProvider.notifier);
            final sessions = state.sessions;
            final cs = Theme.of(context).colorScheme;

            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    // Handle
                    Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 4),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                      child: Row(
                        children: [
                          Icon(Icons.history, color: cs.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Chat History',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    if (sessions.isEmpty)
                      Expanded(
                        child: Center(
                          child: Text(
                            'No chat history yet.',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: sessions.length,
                          itemBuilder: (context, index) {
                            final session = sessions[index];
                            final isSelected = session.id == state.activeSessionId;
                            
                            return ListTile(
                              selected: isSelected,
                              selectedTileColor: cs.primaryContainer.withValues(alpha: 0.3),
                              title: Text(
                                session.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              subtitle: Text(
                                session.lastMessagePreview,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20),
                                onPressed: () async {
                                  final confirmed = await showDeleteConfirmation(
                                    context,
                                    itemType: 'Chat Session',
                                    itemName: session.title,
                                  );
                                  if (confirmed == true) {
                                    await controller.deleteSession(session.id);
                                    if (context.mounted && sessions.length <= 1) {
                                      Navigator.pop(context);
                                    }
                                  }
                                },
                              ),
                              onTap: () async {
                                await controller.switchToSession(session.id);
                                if (context.mounted) {
                                  setState(() {
                                    _chatViewKey = UniqueKey();
                                  });
                                  Navigator.pop(context);
                                }
                              },
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Model selector tile — tapping opens a full bottom-sheet model picker
// ─────────────────────────────────────────────────────────────────────────────

class _ModelSelectorTile extends StatelessWidget {
  const _ModelSelectorTile({
    required this.selectedModelId,
    required this.isModelLoaded,
    required this.onModelChanged,
  });

  final String selectedModelId;
  final bool isModelLoaded;
  final ValueChanged<String> onModelChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selected = AiModelRegistry.findById(selectedModelId);

    return GestureDetector(
      onTap: () => _showModelPicker(context),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            // Model icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.smart_toy_rounded, size: 20, color: cs.primary),
            ),
            const SizedBox(width: 12),
            // Model info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          selected.displayName,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (selected.id == AiModelRegistry.defaultModel.id) ...[
                        const SizedBox(width: 6),
                        _Badge(label: 'Default', color: cs.primary),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${selected.family} · ${selected.parameterCount} · ${selected.sizeLabel}',
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            // Active badge or change chevron
            if (isModelLoaded) ...[
              _StatusBadge(label: 'Active', color: Colors.green),
              const SizedBox(width: 4),
            ],
            Icon(Icons.unfold_more_rounded, size: 20, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  void _showModelPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ModelPickerSheet(
        selectedModelId: selectedModelId,
        onModelSelected: (id) {
          onModelChanged(id);
          Navigator.pop(context);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Full model picker bottom sheet — grouped by family
// ─────────────────────────────────────────────────────────────────────────────

class _ModelPickerSheet extends ConsumerStatefulWidget {
  const _ModelPickerSheet({
    required this.selectedModelId,
    required this.onModelSelected,
  });

  final String selectedModelId;
  final ValueChanged<String> onModelSelected;

  @override
  ConsumerState<_ModelPickerSheet> createState() => _ModelPickerSheetState();
}

class _ModelPickerSheetState extends ConsumerState<_ModelPickerSheet> {
  String _search = '';

  List<AiModelInfo> get _filteredModels {
    if (_search.isEmpty) return AiModelRegistry.models;
    final q = _search.toLowerCase();
    return AiModelRegistry.models.where((m) {
      return m.displayName.toLowerCase().contains(q) ||
          m.family.toLowerCase().contains(q) ||
          m.description.toLowerCase().contains(q) ||
          m.parameterCount.toLowerCase().contains(q);
    }).toList();
  }

  /// Groups filtered models by family, preserving insertion order.
  /// Downloaded models are extracted and placed at the very top.
  Map<String, List<AiModelInfo>> _getGroupedModels(Set<String> downloadedModels) {
    final groups = <String, List<AiModelInfo>>{};
    
    // Special group for already downloaded models
    final downloaded = _filteredModels.where((m) => downloadedModels.contains(m.id)).toList();
    if (downloaded.isNotEmpty) {
      groups['Downloaded'] = downloaded;
    }

    // Then group the rest by family
    for (final m in _filteredModels) {
      if (downloadedModels.contains(m.id)) continue;
      groups.putIfAbsent(m.family, () => []).add(m);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final downloadedModels = ref.watch(aiRuntimeControllerProvider).downloadedModels;
    final groups = _getGroupedModels(downloadedModels);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // ── Handle ──
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // ── Title ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(
                children: [
                  Icon(Icons.smart_toy_rounded, color: cs.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Choose a Model',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    '${AiModelRegistry.models.length} models',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            // ── Search ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search models…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.3)),
                  ),
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            const Divider(height: 1),
            // ── Model list ──
            Expanded(
              child: groups.isEmpty
                  ? Center(
                      child: Text(
                        'No models match "$_search"',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: groups.entries
                          .fold<int>(0, (sum, e) => sum + 1 + e.value.length),
                      itemBuilder: (context, index) {
                        // Flatten groups into a single list with headers
                        var cursor = 0;
                        for (final entry in groups.entries) {
                          if (index == cursor) {
                            // Family header
                            return _FamilyHeader(
                              family: entry.key,
                              count: entry.value.length,
                            );
                          }
                          cursor++;
                          final modelIndex = index - cursor;
                          if (modelIndex < entry.value.length) {
                            final model = entry.value[modelIndex];
                            final isSelected = model.id == widget.selectedModelId;
                            final isDownloaded = downloadedModels.contains(model.id);
                            return _ModelTile(
                              model: model,
                              isSelected: isSelected,
                              isDownloaded: isDownloaded,
                              onTap: () => widget.onModelSelected(model.id),
                              onDelete: () async {
                                final confirmed = await showDeleteConfirmation(
                                  context,
                                  itemType: 'AI Model',
                                  itemName: model.displayName,
                                );
                                if (confirmed == true) {
                                  ref.read(aiRuntimeControllerProvider.notifier).deleteModel(model.id);
                                }
                              },
                            );
                          }
                          cursor += entry.value.length;
                        }
                        return const SizedBox.shrink();
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual widgets for the model picker
// ─────────────────────────────────────────────────────────────────────────────

class _FamilyHeader extends StatelessWidget {
  const _FamilyHeader({required this.family, required this.count});
  final String family;
  final int count;

  IconData get _familyIcon {
    if (family == 'Downloaded') return Icons.download_done_rounded;
    switch (family) {
      case 'Qwen':
        return Icons.auto_awesome;
      case 'Gemma':
        return Icons.diamond_outlined;
      case 'Llama':
        return Icons.pets;
      case 'Phi':
        return Icons.science_outlined;
      case 'Mistral':
        return Icons.air;
      case 'SmolLM':
        return Icons.emoji_nature;
      case 'TinyLlama':
        return Icons.pest_control;
      case 'StableLM':
        return Icons.balance;
      case 'DeepSeek':
        return Icons.psychology;
      default:
        return Icons.memory;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Icon(_familyIcon, size: 16, color: cs.primary),
          const SizedBox(width: 6),
          Text(
            family,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: cs.primary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '($count)',
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(color: cs.outline.withValues(alpha: 0.3)),
          ),
        ],
      ),
    );
  }
}

class _ModelTile extends StatelessWidget {
  const _ModelTile({
    required this.model,
    required this.isSelected,
    required this.isDownloaded,
    required this.onTap,
    required this.onDelete,
  });

  final AiModelInfo model;
  final bool isSelected;
  final bool isDownloaded;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: isSelected
            ? cs.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Selection indicator
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? cs.primary : cs.outline,
                      width: isSelected ? 2 : 1.5,
                    ),
                    color: isSelected
                        ? cs.primary
                        : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 14),
                // Model info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              model.displayName,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? cs.primary : cs.onSurface,
                              ),
                            ),
                          ),
                          if (model.id == AiModelRegistry.defaultModel.id) ...[
                            const SizedBox(width: 8),
                            _Badge(label: 'Recommended', color: cs.primary),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        model.description,
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Downloaded badge or size badge
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDownloaded ? Colors.green.withValues(alpha: 0.1) : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isDownloaded) ...[
                            const Icon(Icons.check_circle_outline, size: 12, color: Colors.green),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            isDownloaded ? 'Ready' : model.sizeLabel,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDownloaded ? Colors.green : cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isDownloaded) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        color: cs.error,
                        tooltip: 'Delete Model',
                        onPressed: onDelete,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
