import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_agent_kit/flutter_local_agent_kit.dart';
import 'package:runanywhere/runanywhere.dart';
import 'package:runanywhere/native/dart_bridge_model_paths.dart';
import 'package:runanywhere/native/dart_bridge.dart';

import '../../../models/vault_model.dart';
import '../../vault/controller/vault_controller.dart';
import 'assistant_tools.dart';

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  return AiRepository(ref);
});

class AiRepository {
  AiRepository(this.ref);
  final Ref ref;
  final AgentToolTurnLimiter _toolTurnLimiter = AgentToolTurnLimiter();
  static const int _maxAgentVerificationAttempts = 10;

  static const modelId = 'qwen2.5-0.5b-instruct-q4';
  static const modelName = 'Qwen 2.5 0.5B (400 MB)';
  static const modelUrl =
      'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf';
  static const int expectedModelSize = 491400032;
  static const bool localOnly = false;

  final FlutterLocalAgentKit _kit = FlutterLocalAgentKit();
  bool _initialized = false;
  bool _kitInitialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    if (Platform.isAndroid) {
      DartBridge.initialize(SDKEnvironment.development);
      await DartBridge.modelPaths.setBaseDirectory();
    } else {
      await RunAnywhere.initialize(environment: SDKEnvironment.development);
    }

    _initialized = true;
  }

  Future<bool> isModelDownloaded() async {
    await initialize();
    return (await _getExistingModelFilePath()) != null;
  }

  Future<String?> _getExistingModelFilePath() async {
    final modelDir = await DartBridgeModelPaths.instance
        .getModelFolderAndCreate(modelId, InferenceFramework.llamaCpp);
    final filePath = '$modelDir/${Uri.parse(modelUrl).pathSegments.last}';
    final file = File(filePath);
    if (await file.exists()) {
      final size = await file.length();
      if (size == expectedModelSize) {
        return file.path;
      } else {
        // Corrupted or incomplete file, delete it
        await file.delete();
      }
    }
    return null;
  }

  Future<void>? _loadFuture;

  Future<void> loadModel() {
    return _loadFuture ??= _loadModelInternal().catchError((e) {
      _loadFuture = null;
      throw e;
    });
  }

  Future<void> _loadModelInternal() async {
    await initialize();
    final modelPath = await _getExistingModelFilePath();
    if (modelPath == null) {
      throw StateError('Model file not found. Download the model first.');
    }

    // Initialize the Agent Kit with ChatML template (required for Qwen models)
    await _kit.initialize(
      modelPath: modelPath,
      template: ChatMlTemplate(),
      contextSize: 2048,
      gpuLayers: Platform.isAndroid ? 32 : 0,
      customTools: [
        CreateNoteTool(ref, _toolTurnLimiter),
        CreatePasswordTool(ref, _toolTurnLimiter),
        ScheduleEventTool(ref, _toolTurnLimiter),
        CreateDocumentTool(ref, _toolTurnLimiter),
      ],
    );

    _kitInitialized = true;
  }

  Stream<DownloadProgress> downloadModel() async* {
    await initialize();

    final modelDir = await DartBridgeModelPaths.instance
        .getModelFolderAndCreate(modelId, InferenceFramework.llamaCpp);
    final url = Uri.parse(modelUrl);
    final filePath = '$modelDir/${url.pathSegments.last}';
    final file = File(filePath);
    await file.parent.create(recursive: true);

    final client = HttpClient();
    try {
      final request = await client.getUrl(url);
      final response = await request.close();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode}');
      }

      final totalBytes = response.contentLength > 0
          ? response.contentLength
          : 0;
      var downloadedBytes = 0;

      final sink = file.openWrite();
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          downloadedBytes += chunk.length;
          yield DownloadProgress(
            bytesDownloaded: downloadedBytes,
            totalBytes: totalBytes > 0 ? totalBytes : downloadedBytes,
            state: DownloadProgressState.downloading,
          );
        }
      } finally {
        await sink.flush();
        await sink.close();
      }

      yield DownloadProgress(
        bytesDownloaded: downloadedBytes,
        totalBytes: downloadedBytes,
        state: DownloadProgressState.completed,
        stage: DownloadProgressStage.completed,
      );
    } catch (_) {
      if (await file.exists()) {
        await file.delete();
      }
      yield const DownloadProgress(
        bytesDownloaded: 0,
        totalBytes: 1,
        state: DownloadProgressState.failed,
        stage: DownloadProgressStage.failed,
      );
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  /// Builds a string of vault context for injection into prompts.
  Future<String> _buildVaultContext() async {
    final vault = await ref.read(vaultControllerProvider.future);
    final lines = <String>[];

    // Provide current date so the LLM understands relative time
    lines.add(
      'CURRENT DATE AND TIME: ${DateTime.now().toString().split('.')[0]}\n',
    );

    for (final n in vault.notes) {
      lines.add('- Note "${n.title}": ${n.content}');
    }
    for (final p in vault.passwords) {
      lines.add('- Password for "${p.accountName}": username=${p.username}');
    }
    for (final e in vault.events) {
      // Format the date to be easily readable for the LLM
      // e.g. "2024-05-12 14:30:00" -> easier to parse than "2024-05-12T14:30:00.000Z"
      final dateStr = e.startsAt.toString().split('.')[0];
      lines.add(
        '- Event "${e.title}" scheduled for $dateStr: ${e.description}',
      );
    }
    for (final d in vault.documents) {
      lines.add('- Document "${d.title}": ${d.content}');
    }

    return lines.isNotEmpty
        ? lines.join('\n')
        : 'The vault is currently empty.';
  }

  bool _looksLikeCreateIntent(String question) {
    final q = question.toLowerCase();
    final asksCreate =
        q.contains('create') ||
        q.contains('add') ||
        q.contains('save') ||
        q.contains('schedule') ||
        q.contains('new ');
    final targetType =
        q.contains('note') ||
        q.contains('password') ||
        q.contains('event') ||
        q.contains('document');
    return asksCreate && targetType;
  }

  String? _expectedCreateToolForQuestion(String question) {
    final q = question.toLowerCase();

    final asksCreate =
        q.contains('create') ||
        q.contains('add') ||
        q.contains('save') ||
        q.contains('schedule') ||
        q.contains('new ');
    if (!asksCreate) return null;

    bool hasExplicitCreateFor(List<String> nouns) {
      for (final noun in nouns) {
        final pattern = RegExp(
          '\\b(create|add|save|schedule|new)\\s+(an?\\s+)?${RegExp.escape(noun)}\\b',
        );
        if (pattern.hasMatch(q)) {
          return true;
        }
      }
      return false;
    }

    // Prefer explicit user intent phrases first (e.g., "create note", "add event").
    if (hasExplicitCreateFor(['note', 'notes'])) {
      return 'create_note';
    }
    if (hasExplicitCreateFor([
      'password',
      'credential',
      'credentials',
      'login',
    ])) {
      return 'create_password';
    }
    if (hasExplicitCreateFor([
      'event',
      'events',
      'meeting',
      'appointment',
      'calendar reminder',
    ])) {
      return 'create_event';
    }
    if (hasExplicitCreateFor(['document', 'documents', 'doc', 'file'])) {
      return 'create_document';
    }

    final noteSignals = [q.contains('note')].where((e) => e).length;
    final passwordSignals = [
      q.contains('password'),
      q.contains('credential'),
      q.contains('login'),
    ].where((e) => e).length;
    final eventSignals = [
      q.contains('event'),
      q.contains('meeting'),
      q.contains('appointment'),
      q.contains('calendar'),
      q.contains('reminder'),
    ].where((e) => e).length;
    final documentSignals = [
      q.contains('document'),
      q.contains('doc'),
      q.contains('file'),
    ].where((e) => e).length;

    final signaledTypes = [
      noteSignals > 0,
      passwordSignals > 0,
      eventSignals > 0,
      documentSignals > 0,
    ].where((e) => e).length;

    // If multiple categories are present, do not hard-restrict to avoid false blocks.
    if (signaledTypes != 1) {
      return null;
    }

    if (eventSignals > 0) {
      return 'create_event';
    }
    if (passwordSignals > 0) {
      return 'create_password';
    }
    if (documentSignals > 0) {
      return 'create_document';
    }
    if (noteSignals > 0) {
      return 'create_note';
    }

    return null;
  }

  String? _buildVerifiedCreationSummary(VaultData before, VaultData after) {
    final beforeNoteIds = before.notes.map((e) => e.id).toSet();
    final beforePasswordIds = before.passwords.map((e) => e.id).toSet();
    final beforeEventIds = before.events.map((e) => e.id).toSet();
    final beforeDocumentIds = before.documents.map((e) => e.id).toSet();

    final createdNotes = after.notes
        .where((e) => !beforeNoteIds.contains(e.id))
        .toList();
    final createdPasswords = after.passwords
        .where((e) => !beforePasswordIds.contains(e.id))
        .toList();
    final createdEvents = after.events
        .where((e) => !beforeEventIds.contains(e.id))
        .toList();
    final createdDocuments = after.documents
        .where((e) => !beforeDocumentIds.contains(e.id))
        .toList();

    if (createdNotes.isEmpty &&
        createdPasswords.isEmpty &&
        createdEvents.isEmpty &&
        createdDocuments.isEmpty) {
      return null;
    }

    final lines = <String>['Verified vault changes:'];
    for (final n in createdNotes) {
      lines.add('- Note "${n.title}" (id: ${n.id})');
    }
    for (final p in createdPasswords) {
      lines.add('- Password "${p.accountName}" (id: ${p.id})');
    }
    for (final e in createdEvents) {
      lines.add('- Event "${e.title}" (id: ${e.id})');
    }
    for (final d in createdDocuments) {
      lines.add('- Document "${d.title}" (id: ${d.id})');
    }
    return lines.join('\n');
  }

  /// Entry point for AgentChatView. Routes based on [AssistantMode].
  Stream<String> askStream(
    String question, {
    AssistantMode mode = AssistantMode.chat,
    void Function(List<dynamic>)? onCitations,
  }) async* {
    if (!_kitInitialized) await loadModel();

    if (!_kit.isReady) {
      yield "The AI assistant is still starting up or failed to load. Please wait a moment or restart the app.";
      return;
    }

    switch (mode) {
      case AssistantMode.chat:
        // Plain chat — no vault context, no tools
        yield* _kit.askDirectStream(
          question,
          systemPrompt:
              'You are a helpful on-device assistant. Reply clearly and briefly. '
              'If the user greets you, respond with a natural greeting and ask how you can help.',
          maxTokens: 256,
        );

      case AssistantMode.vault:
        // RAG — vault context injected, no tools
        final context = await _buildVaultContext();
        final prompt =
            'You are a helpful vault assistant. NEVER generate code.\n\n'
            'VAULT DATA:\n$context\n\n'
            'Question: $question\n\n'
            'Answer briefly and directly:';
        // Vault mode uses explicitly injected vault context and should not
        // additionally query the RAG index.
        yield* _kit.askDirectStream(
          prompt,
          systemPrompt:
              'You are a precise vault assistant. Use only the provided vault data. '
              'If data is missing, say so clearly.',
          maxTokens: 384,
        );

      case AssistantMode.agent:
        // Agent — ReAct loop with tools + vault context
        final context = await _buildVaultContext();
        final beforeVault = await ref.read(vaultControllerProvider.future);
        final expectedCreateTool = _expectedCreateToolForQuestion(question);
        _toolTurnLimiter.beginTurn(
          maxCreateActions: 1,
          allowedCreateTools: expectedCreateTool == null
              ? null
              : {expectedCreateTool},
        );
        final toolRestriction = expectedCreateTool == null
            ? ''
            : '\n10. For this specific request, you MUST use only the tool "$expectedCreateTool" for any create action. Do not call other create_* tools.';
        final systemPrompt =
          'You are a private vault assistant.\n\n'
          'VAULT DATA:\n$context\n\n'
          'CRITICAL INSTRUCTIONS:\n'
          '1. Agent mode is ONLY for tool calling. You MUST call a tool; never answer directly.\n'
          '2. To perform ANY action, you MUST use the exact format:\n'
          '   Thought: I need to [action]\n'
          '   Action: [tool_name]\n'
          '   Action Input: {"arg1": "value1"}\n'
          '3. DO NOT use python function syntax like tool(args).\n'
          '4. DO NOT use markdown code blocks like ```json.\n'
          '5. NEVER say you have done something (e.g. "I created...") until you see an "Observation: Successfully created..." message.\n'
          '6. If Observation contains "Failed" or any error text, explicitly tell the user the action was NOT completed.\n'
          '7. Once you see the success Observation, use "Final Answer:" to tell the user it is done.\n'
          '8. If you do not use the "Action:" format, no tool will be called and nothing will happen.\n'
          '9. Never claim notes/passwords/events/documents were created without a success Observation containing an item id.\n'
          '10. You are allowed to execute at most one create action for this request. After one successful creation, stop and provide Final Answer.'
          '$toolRestriction';
        try {
          await for (final token in _kit.runAgent(
            question,
            systemPrompt: systemPrompt,
          )) {
            yield token;
          }

          final afterVault = await ref.read(vaultControllerProvider.future);
          final verifiedSummary = _buildVerifiedCreationSummary(
            beforeVault,
            afterVault,
          );
          if (verifiedSummary != null) {
            yield '\n\n$verifiedSummary';
          } else if (_looksLikeCreateIntent(question)) {
            var previousVault = afterVault;
            String? retrySummary;

            for (
              var attempt = 2;
              attempt <= _maxAgentVerificationAttempts && retrySummary == null;
              attempt++
            ) {
              yield '\n\nThinking...';

              _toolTurnLimiter.beginTurn(
                maxCreateActions: 1,
                allowedCreateTools: expectedCreateTool == null
                    ? null
                    : {expectedCreateTool},
              );
              await for (final token in _kit.runAgent(
                question,
                systemPrompt: systemPrompt,
              )) {
                yield token;
              }

              final currentVault = await ref.read(
                vaultControllerProvider.future,
              );
              retrySummary = _buildVerifiedCreationSummary(
                previousVault,
                currentVault,
              );
              previousVault = currentVault;
            }

            if (retrySummary != null) {
              yield '\n\n$retrySummary';
            } else {
              yield '\n\nI could not verify a created item ID after '
                  '$_maxAgentVerificationAttempts attempts. '
                  'Please resend with explicit fields like title and content.';
            }
          }
        } finally {
          _toolTurnLimiter.endTurn();
        }
    }
  }

  bool get isModelLoaded => _kitInitialized;
}

/// The three operating modes for the AI assistant.
enum AssistantMode {
  /// Free chat — no vault context, no tools.
  chat,

  /// Vault Q&A — answers grounded in vault data, no tools.
  vault,

  /// Agent — ReAct loop with tools for creating/modifying vault items.
  agent,
}

enum DownloadProgressState { downloading, completed, failed }

enum DownloadProgressStage { downloading, completed, failed }

class DownloadProgress {
  const DownloadProgress({
    required this.bytesDownloaded,
    required this.totalBytes,
    required this.state,
    this.stage = DownloadProgressStage.downloading,
  });

  final int bytesDownloaded;
  final int totalBytes;
  final DownloadProgressState state;
  final DownloadProgressStage stage;

  double get percentage => totalBytes > 0 ? bytesDownloaded / totalBytes : 0;
}
