import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/section_scaffold.dart';
import '../controller/ai_runtime_controller.dart';
import '../controller/chat_session_controller.dart';
import '../repository/ai_model_registry.dart';
import '../repository/ai_repository.dart';
import '../repository/assistant_tools.dart';
import '../../../core/app_colors.dart';
import 'widgets/assistant_history_sheet.dart';
import 'widgets/assistant_model_selector.dart';
import 'widgets/assistant_mode_selector.dart';
import 'widgets/assistant_chat_view.dart';
import 'widgets/assistant_status_banners.dart';
import 'widgets/assistant_help_sheet.dart';

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
      chatController.startNewSession();
      if (mounted) setState(() => _isInitializing = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final aiState = ref.watch(aiRuntimeControllerProvider);
    final chatState = ref.watch(chatSessionControllerProvider);
    final colors = AppColors.of(context);

    return SectionScaffold(
      title: 'AI Assistant',
      actions: [
        IconButton(
          tooltip: 'New Chat',
          icon: const Icon(Icons.add_comment_outlined),
          onPressed: () {
            ref.read(chatSessionControllerProvider.notifier).startNewSession();
            setState(() => _chatViewKey = UniqueKey());
          },
        ),
        IconButton(
          tooltip: 'Chat History',
          icon: const Icon(Icons.history_rounded),
          onPressed: () => _showHistory(context),
        ),
        IconButton(
          tooltip: 'Help',
          icon: const Icon(Icons.help_outline_rounded),
          onPressed: () => _showHelp(context),
        ),
      ],
      bodyPadding: EdgeInsets.zero,
      child: Column(
        children: [
          if (!aiState.initialized)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else ...[
            AssistantModelSelectorTile(
              selectedModelId: aiState.selectedModelId ?? AiModelRegistry.defaultModel.id,
              isModelLoaded: aiState.modelLoaded,
              onModelChanged: (id) => ref.read(aiRuntimeControllerProvider.notifier).selectModel(id),
            ),
            if (!aiState.modelDownloaded)
              AssistantStatusBanner(
                title: 'Model Download Required',
                status: aiState.status,
                buttonLabel: 'Download',
                onPressed: aiState.downloading ? null : ref.read(aiRuntimeControllerProvider.notifier).downloadAndLoadModel,
                progress: aiState.progress,
                error: aiState.error,
              )
            else if (!aiState.modelLoaded)
              AssistantStatusBanner(
                title: 'Model Ready',
                status: aiState.status,
                buttonLabel: 'Load',
                onPressed: ref.read(aiRuntimeControllerProvider.notifier).loadDownloadedModel,
                icon: Icons.memory_outlined,
              ),
            if (aiState.modelLoaded)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ModernModeSelector(currentMode: _mode, onModeChanged: (m) => setState(() => _mode = m)),
              ),
            Expanded(
              child: _isInitializing
                  ? const Center(child: CircularProgressIndicator())
                  : aiState.modelLoaded
                      ? AssistantChatView(
                          key: _chatViewKey,
                          initialHistory: chatState.activeSession != null ? ref.read(chatSessionControllerProvider.notifier).getHistoryForLLM(chatState.activeSession!) : null,
                          onMessage: _handleMessage,
                          initialPromptToSend: _initialPromptProcessed ? null : widget.initialPrompt,
                          welcomeMessage: chatState.activeSessionId == null ? _welcomeForMode(_mode) : null,
                          accentColor: colors.isDark ? Colors.purpleAccent : const Color(0xFF6366F1),
                        )
                      : const Center(child: Text('Model not loaded.')),
            ),
          ],
        ],
      ),
    );
  }

  Stream<String> _handleMessage(String content, {Uint8List? imageBytes, void Function(List<VaultCitation>)? onCitations}) async* {
    if (!_initialPromptProcessed) _initialPromptProcessed = true;
    final chatController = ref.read(chatSessionControllerProvider.notifier);
    final repository = ref.read(aiRepositoryProvider);

    String? sessionId = ref.read(chatSessionControllerProvider).activeSessionId;
    if (sessionId == null) {
      final session = await chatController.createSession(modelId: ref.read(aiRuntimeControllerProvider).selectedModelId ?? AiModelRegistry.defaultModel.id, mode: _mode.name);
      sessionId = session.id;
    }

    final history = await chatController.getFullHistory(sessionId);
    await chatController.addUserMessage(content, sessionId: sessionId);

    final responseBuffer = StringBuffer();
    List<VaultCitation> collectedCitations = [];
    try {
      final stream = repository.askStream(
        content,
        mode: _mode,
        history: history,
        sessionId: sessionId,
        onCitations: (citations) {
          collectedCitations = citations;
          onCitations?.call(citations);
        },
      );
      await for (final token in stream.timeout(const Duration(seconds: 120))) {
        responseBuffer.write(token);
        yield token;
      }
    } catch (e) {
      yield 'Error: $e';
    } finally {
      await chatController.addAssistantMessage(
        responseBuffer.toString(),
        sessionId: sessionId,
        citations: collectedCitations,
      );
      await chatController.refreshSessions();
    }
  }

  String _welcomeForMode(AssistantMode mode) {
    return switch (mode) {
      AssistantMode.chat => 'Free chat mode — talk to the on-device AI.',
      AssistantMode.vault => 'Vault Q&A — ask about your stored data.',
      AssistantMode.agent => 'Agent mode — create & manage vault items.',
    };
  }

  void _showHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AssistantHistorySheet(
        onSessionSelected: (id) async {
          await ref.read(chatSessionControllerProvider.notifier).switchToSession(id);
          if (context.mounted) {
            setState(() => _chatViewKey = UniqueKey());
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  void _showHelp(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AssistantHelpSheet(),
    );
  }
}
