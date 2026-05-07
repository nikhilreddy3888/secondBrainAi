import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../shared/widgets/section_scaffold.dart';
import '../../../shared/widgets/confirm_delete_dialog.dart';
import '../models/chat_session.dart';
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
              selectedModelId:
                  aiState.selectedModelId ?? AiModelRegistry.defaultModel.id,
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
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.cloud_download_outlined,
                                color: cs.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Model Download Required',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    aiState.status,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: aiState.downloading
                                  ? null
                                  : aiController.downloadAndLoadModel,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text('Download'),
                            ),
                          ],
                        ),
                        if (aiState.downloading || aiState.progress > 0) ...[
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: aiState.progress,
                              minHeight: 8,
                              backgroundColor: cs.primary.withValues(alpha: 0.1),
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
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.memory_outlined, color: cs.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Model Ready',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                aiState.status,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: aiController.loadDownloadedModel,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Load'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            const SizedBox(height: 8),

            // ── Mode selector ──
            if (aiState.modelLoaded)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: _ModernModeSelector(
                  currentMode: _mode,
                  onModeChanged: (mode) => setState(() => _mode = mode),
                ),
              ),

            const SizedBox(height: 12),

            // ── Chat view ──
            Expanded(
              child: _isInitializing
                  ? const Center(child: CircularProgressIndicator())
                  : aiState.modelLoaded
                  ? AgentChatView(
                      key: _chatViewKey,
                      initialHistory: chatState.activeSession != null
                          ? chatController.getHistoryForLLM(
                              chatState.activeSession!,
                            )
                          : null,
                      onMessage: (content, {imageBytes, onCitations}) async* {
                        final screenStopwatch = Stopwatch()..start();
                        print(
                          '[Screen] ========== MESSAGE RECEIVED ==========',
                        );
                        print(
                          '[Screen] Content: "$content" (length: ${content.length})',
                        );
                        print('[Screen] ImageBytes: ${imageBytes != null}');

                        if (!_initialPromptProcessed) {
                          _initialPromptProcessed = true;
                        }

                        final currentAiState = ref.read(
                          aiRuntimeControllerProvider,
                        );
                        String? currentSessionId = ref
                            .read(chatSessionControllerProvider)
                            .activeSessionId;

                        if (currentSessionId == null) {
                          print('[Screen] No active session, creating new one');
                          final newSession = await chatController.createSession(
                            modelId:
                                currentAiState.selectedModelId ??
                                AiModelRegistry.defaultModel.id,
                            mode: _mode.name,
                          );
                          currentSessionId = newSession.id;
                          print('[Screen] Created session: $currentSessionId');
                        }

                        // Get history for the SPECIFIC session we are interacting with
                        // This now loads from DB if needed to ensure we never lose context.
                        final history = await chatController.getFullHistory(
                          currentSessionId,
                        );
                        print(
                          '[Screen] Loaded history: ${history.length} messages',
                        );

                        print('[Screen] Saving user message to DB');
                        await chatController.addUserMessage(
                          content,
                          sessionId: currentSessionId,
                        );

                        print('[Screen] Calling repository.askStream');
                        final stream = repository.askStream(
                          content,
                          mode: _mode,
                          history: history,
                          sessionId: currentSessionId,
                          onCitations: (results) {
                            onCitations?.call(const []);
                          },
                        );

                        final responseBuffer = StringBuffer();
                        var hasReceivedTokens = false;
                        try {
                          print('[Screen] Starting to read stream');
                          final streamTimeout = _mode == AssistantMode.chat
                              ? const Duration(seconds: 120)
                              : const Duration(seconds: 90);
                          await for (final token in stream.timeout(
                            streamTimeout,
                          )) {
                            hasReceivedTokens = true;
                            responseBuffer.write(token);
                            yield token;
                          }
                          print('[Screen] Stream completed successfully');
                        } on TimeoutException {
                          print(
                            '[AI] Timeout error: Response generation took longer than the allowed stream timeout',
                          );
                          final timeoutMessage = hasReceivedTokens
                              ? '\n\n[Response truncated due to timeout]'
                              : 'I am taking longer than expected and did not complete this response. Please try again.';
                          responseBuffer.write(timeoutMessage);
                          yield timeoutMessage;
                        } catch (e) {
                          print('[Screen] Stream error: $e');
                          if (!hasReceivedTokens) {
                            final errorMessage =
                                'Error generating response: $e';
                            responseBuffer.write(errorMessage);
                            yield errorMessage;
                          }
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
                        final totalTime = screenStopwatch.elapsedMilliseconds;
                        print(
                          '[Screen] ========== MESSAGE COMPLETE (total: ${totalTime}ms) ==========',
                        );
                      },
                      initialPromptToSend: _initialPromptProcessed
                          ? null
                          : widget.initialPrompt,
                      welcomeMessage: chatState.activeSessionId == null
                          ? _welcomeForMode(_mode)
                          : null,
                      accentColor: cs.primary,
                      enableImagePicker: false,
                    )
                  : const Center(
                      child: Text(
                        'Model not loaded. Please download or load the model.',
                      ),
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
                            final isSelected =
                                session.id == state.activeSessionId;

                            return ListTile(
                              selected: isSelected,
                              selectedTileColor: cs.primaryContainer.withValues(
                                alpha: 0.3,
                              ),
                              title: Text(
                                session.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              subtitle: Text(
                                session.lastMessagePreview,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12),
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                ),
                                onPressed: () async {
                                  final confirmed =
                                      await showDeleteConfirmation(
                                        context,
                                        itemType: 'Chat Session',
                                        itemName: session.title,
                                      );
                                  if (confirmed == true) {
                                    await controller.deleteSession(session.id);
                                    if (context.mounted &&
                                        sessions.length <= 1) {
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
            Icon(
              Icons.unfold_more_rounded,
              size: 20,
              color: cs.onSurfaceVariant,
            ),
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
  Map<String, List<AiModelInfo>> _getGroupedModels(
    Set<String> downloadedModels,
  ) {
    final groups = <String, List<AiModelInfo>>{};

    // Special group for already downloaded models
    final downloaded = _filteredModels
        .where((m) => downloadedModels.contains(m.id))
        .toList();
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
    final downloadedModels = ref
        .watch(aiRuntimeControllerProvider)
        .downloadedModels;
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
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: cs.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: cs.outline.withValues(alpha: 0.3),
                    ),
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
                      itemCount: groups.entries.fold<int>(
                        0,
                        (sum, e) => sum + 1 + e.value.length,
                      ),
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
                            final isSelected =
                                model.id == widget.selectedModelId;
                            final isDownloaded = downloadedModels.contains(
                              model.id,
                            );
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
                                  ref
                                      .read(
                                        aiRuntimeControllerProvider.notifier,
                                      )
                                      .deleteModel(model.id);
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
          Expanded(child: Divider(color: cs.outline.withValues(alpha: 0.3))),
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
                    color: isSelected ? cs.primary : Colors.transparent,
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
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
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
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDownloaded
                            ? Colors.green.withValues(alpha: 0.1)
                            : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isDownloaded) ...[
                            const Icon(
                              Icons.check_circle_outline,
                              size: 12,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            isDownloaded ? 'Ready' : model.sizeLabel,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDownloaded
                                  ? Colors.green
                                  : cs.onSurfaceVariant,
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
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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

class AgentChatView extends StatefulWidget {
  const AgentChatView({
    super.key,
    this.initialHistory,
    required this.onMessage,
    this.initialPromptToSend,
    this.welcomeMessage,
    this.accentColor,
    this.enableImagePicker = false,
  });

  final List<ChatMessageEntry>? initialHistory;
  final Stream<String> Function(
    String content, {
    Uint8List? imageBytes,
    void Function(List<dynamic>)? onCitations,
  })
  onMessage;
  final String? initialPromptToSend;
  final String? welcomeMessage;
  final Color? accentColor;
  final bool enableImagePicker;

  @override
  State<AgentChatView> createState() => _AgentChatViewState();
}

class _AgentChatViewState extends State<AgentChatView> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatBubble> _messages = [];
  bool _isSending = false;
  bool _sentInitialPrompt = false;

  @override
  void initState() {
    super.initState();
    _syncHistory(widget.initialHistory);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeSendInitialPrompt();
    });
  }

  @override
  void didUpdateWidget(covariant AgentChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialHistory != widget.initialHistory) {
      _syncHistory(widget.initialHistory);
      _sentInitialPrompt = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeSendInitialPrompt();
      });
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _syncHistory(List<ChatMessageEntry>? history) {
    _messages
      ..clear()
      ..addAll(
        (history ?? const []).map((entry) {
          return _ChatBubble(role: entry.role, content: entry.content);
        }),
      );
  }

  void _maybeSendInitialPrompt() {
    if (_sentInitialPrompt || widget.initialPromptToSend == null) return;
    if (_messages.isNotEmpty) return;
    _sentInitialPrompt = true;
    _inputController.text = widget.initialPromptToSend!;
    _submitMessage();
  }

  Future<void> _submitMessage() async {
    if (_isSending) return;
    final message = _inputController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _messages.add(_ChatBubble(role: 'user', content: message));
      _inputController.clear();
      _isSending = true;
    });
    _scrollToBottom();

    final assistantBuffer = StringBuffer();
    try {
      await for (final token in widget.onMessage(message)) {
        assistantBuffer.write(token);
        if (_messages.isNotEmpty && _messages.last.role == 'assistant-stream') {
          _messages.removeLast();
        }
        setState(() {
          _messages.add(
            _ChatBubble(
              role: 'assistant-stream',
              content: assistantBuffer.toString(),
            ),
          );
        });
        _scrollToBottom();
      }
    } finally {
      if (_messages.isNotEmpty && _messages.last.role == 'assistant-stream') {
        final finalText = _messages.last.content.trim();
        _messages.removeLast();
        if (finalText.isNotEmpty) {
          _messages.add(_ChatBubble(role: 'assistant', content: finalText));
        }
      }
      if (assistantBuffer.isEmpty) {
        _messages.add(
          const _ChatBubble(
            role: 'assistant',
            content: 'I could not generate a response for that request.',
          ),
        );
      }
      setState(() {
        _isSending = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = widget.accentColor ?? cs.primary;

    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? _WelcomePanel(
                  message: widget.welcomeMessage ?? 'Start a conversation.',
                  accentColor: accent,
                )
              : ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  itemCount: _messages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    return _ChatBubbleTile(
                      message: message,
                      accentColor: accent,
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Container(
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: cs.shadow.withValues(alpha: 0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
              border: Border.all(
                color: cs.outline.withValues(alpha: 0.1),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        minLines: 1,
                        maxLines: 5,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _submitMessage(),
                        style: GoogleFonts.inter(fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'Ask anything...',
                          hintStyle: TextStyle(
                            color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _AnimatedSendButton(
                      isSending: _isSending,
                      onPressed: _submitMessage,
                      accentColor: accent,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AnimatedSendButton extends StatelessWidget {
  const _AnimatedSendButton({
    required this.isSending,
    required this.onPressed,
    required this.accentColor,
  });

  final bool isSending;
  final VoidCallback onPressed;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Material(
        color: isSending ? accentColor.withValues(alpha: 0.2) : accentColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isSending ? null : onPressed,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: isSending
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                    ),
                  )
                : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

class _ChatBubble {
  const _ChatBubble({required this.role, required this.content});

  final String role;
  final String content;
}

class _ChatBubbleTile extends StatelessWidget {
  const _ChatBubbleTile({required this.message, required this.accentColor});

  final _ChatBubble message;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isUser = message.role == 'user';
    final isStreaming = message.role == 'assistant-stream';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        constraints: const BoxConstraints(maxWidth: 300),
        margin: EdgeInsets.only(
          left: isUser ? 50 : 0,
          right: isUser ? 0 : 50,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: isUser
              ? LinearGradient(
                  colors: [accentColor, accentColor.withValues(alpha: 0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [
                    cs.surfaceContainerHighest,
                    cs.surfaceContainerHighest.withValues(alpha: 0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 20),
          ),
          boxShadow: [
            BoxShadow(
              color: (isUser ? accentColor : cs.shadow).withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          message.content.isEmpty && isStreaming
              ? 'Generating...'
              : message.content,
          style: GoogleFonts.inter(
            color: isUser ? Colors.white : cs.onSurface,
            fontSize: 15,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _ModernModeSelector extends StatelessWidget {
  const _ModernModeSelector({
    required this.currentMode,
    required this.onModeChanged,
  });

  final AssistantMode currentMode;
  final ValueChanged<AssistantMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _ModeItem(
            label: 'Chat',
            icon: Icons.chat_bubble_outline_rounded,
            isSelected: currentMode == AssistantMode.chat,
            onTap: () => onModeChanged(AssistantMode.chat),
          ),
          _ModeItem(
            label: 'Vault',
            icon: Icons.search_rounded,
            isSelected: currentMode == AssistantMode.vault,
            onTap: () => onModeChanged(AssistantMode.vault),
          ),
          _ModeItem(
            label: 'Agent',
            icon: Icons.auto_fix_high_rounded,
            isSelected: currentMode == AssistantMode.agent,
            onTap: () => onModeChanged(AssistantMode.agent),
          ),
        ],
      ),
    );
  }
}

class _ModeItem extends StatelessWidget {
  const _ModeItem({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? cs.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: cs.shadow.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? cs.primary : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel({required this.message, required this.accentColor});

  final String message;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                accentColor.withValues(alpha: 0.12),
                cs.surfaceContainerHighest,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accentColor.withValues(alpha: 0.18)),
          ),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }
}
