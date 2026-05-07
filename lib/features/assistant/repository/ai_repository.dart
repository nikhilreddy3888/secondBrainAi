import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_agent_kit/flutter_local_agent_kit.dart';
import 'package:runanywhere/runanywhere.dart';
import 'package:runanywhere/native/dart_bridge_model_paths.dart';
import 'package:runanywhere/native/dart_bridge.dart';

import '../../../models/vault_model.dart';
import '../../vault/controller/vault_controller.dart';
import 'ai_model_registry.dart';
import 'assistant_tools.dart';

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  return AiRepository(ref);
});

class AiRepository {
  AiRepository(this.ref);
  final Ref ref;
  final AgentToolTurnLimiter _toolTurnLimiter = AgentToolTurnLimiter();
  static const int _maxAgentVerificationAttempts = 10;

  /// The currently selected model (persisted across controller rebuilds).
  AiModelInfo _selectedModel = AiModelRegistry.defaultModel;
  AiModelInfo get selectedModel => _selectedModel;

  /// Human-readable display name for status messages.
  String get modelName => _selectedModel.displayName;

  static const bool localOnly = false;

  final FlutterLocalAgentKit _kit = FlutterLocalAgentKit();
  bool _initialized = false;
  bool _kitInitialized = false;

  /// ── Session conversation history ──
  /// History is now passed directly to askStream by the caller to keep
  /// the repository stateless and allow proper persistence management.

  /// ── Model selection ──

  /// Switches to a different model. Returns `true` if the model changed.
  /// The caller is responsible for re-downloading / re-loading after switching.
  bool selectModel(String modelId) {
    final model = AiModelRegistry.findById(modelId);
    if (model.id == _selectedModel.id) return false;
    _selectedModel = model;
    // Invalidate the loaded state so the runtime controller knows it needs
    // to re-download / re-load.
    _kitInitialized = false;
    _loadFuture = null;
    return true;
  }

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

  Future<bool> isModelDownloaded([String? modelId]) async {
    await initialize();
    return (await _getExistingModelFilePath(modelId)) != null;
  }

  Future<String?> _getExistingModelFilePath([String? modelId]) async {
    final model = modelId != null ? AiModelRegistry.findById(modelId) : _selectedModel;
    final modelDir = await DartBridgeModelPaths.instance
        .getModelFolderAndCreate(model.id, InferenceFramework.llamaCpp);
    final filePath = '$modelDir/${model.fileName}';
    final file = File(filePath);
    if (await file.exists()) {
      final size = await file.length();
      // Sanity check: a valid GGUF model should be at least 1 MB.
      // We no longer require an exact byte count so we can support
      // a large registry of models without hardcoding every file size.
      if (size > 1024 * 1024) {
        return file.path;
      } else {
        // Corrupted or incomplete file, delete it
        await file.delete();
      }
    }
    return null;
  }

  /// Returns the file size of the currently selected model in megabytes,
  /// or 0 if the model file doesn't exist.
  Future<int> getModelFileSizeMB([String? modelId]) async {
    final path = await _getExistingModelFilePath(modelId);
    if (path == null) return 0;
    final bytes = await File(path).length();
    return bytes ~/ (1024 * 1024);
  }

  Future<void> deleteModel(String modelId) async {
    await initialize();
    final model = AiModelRegistry.findById(modelId);
    final modelDir = await DartBridgeModelPaths.instance
        .getModelFolderAndCreate(model.id, InferenceFramework.llamaCpp);
    final filePath = '$modelDir/${model.fileName}';
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
    if (modelId == _selectedModel.id) {
      _kitInitialized = false;
      _loadFuture = null;
    }
  }

  Future<void>? _loadFuture;

  Future<void> loadModel() {
    return _loadFuture ??= _loadModelInternal().catchError((e) {
      _loadFuture = null;
      throw e;
    });
  }

  PromptTemplate _templateForModel(AiModelInfo model) {
    switch (model.templateType) {
      case 'chatml':
        return ChatMlTemplate();
      case 'llama3':
        return Llama3Template();
      case 'gemma':
        return GemmaTemplate();
      default:
        return ChatMlTemplate();
    }
  }

  /// Computes safe loading parameters for Android based on model file size.
  ///
  /// IMPORTANT: On Android, if the native llama.cpp allocation exceeds
  /// available memory, the OS sends SIGKILL which terminates the entire
  /// process instantly. This CANNOT be caught by Dart try/catch. Therefore
  /// we must be very conservative on the first (and only) attempt — there
  /// is no second chance.
  ///
  /// Memory budget for a typical Android device (4-6 GB RAM):
  ///   - OS + background apps: ~2-3 GB
  ///   - App process overhead: ~200 MB
  ///   - Model weights (mmap): ~model file size
  ///   - KV cache: scales with contextSize × model dimensions
  ///   - Available for model: ~1-2 GB
  ({int contextSize, int gpuLayers}) _androidLoadParams(
    int fileSizeMB,
    int requestedContextSize,
  ) {
    if (fileSizeMB < 400) {
      // Tiny models (< 400MB): safe for GPU + full context
      return (contextSize: requestedContextSize, gpuLayers: 32);
    } else if (fileSizeMB < 500) {
      // Small models (400-500MB): CPU only, full context
      return (contextSize: requestedContextSize, gpuLayers: 0);
    } else {
      // Any model ≥ 500MB: CPU only, minimal context (512 tokens).
      // A 1GB model + 512-ctx KV cache ≈ 1.05 GB total native memory.
      // This is the most conservative setting that allows the model to
      // actually function. Going higher risks SIGKILL on most devices.
      return (contextSize: 512, gpuLayers: 0);
    }
  }

  /// Reads total device RAM from /proc/meminfo on Android (in MB).
  /// Returns 0 if the file cannot be read.
  Future<int> _getDeviceRamMB() async {
    try {
      final meminfo = await File('/proc/meminfo').readAsString();
      // First line: "MemTotal:     2048000 kB"
      final match = RegExp(r'MemTotal:\s+(\d+)\s+kB').firstMatch(meminfo);
      if (match != null) {
        final kb = int.parse(match.group(1)!);
        return kb ~/ 1024;
      }
    } catch (_) {}
    return 0;
  }

  Future<void> _loadModelInternal() async {
    await initialize();
    final modelPath = await _getExistingModelFilePath();
    if (modelPath == null) {
      throw StateError('Model file not found. Download the model first.');
    }

    final model = _selectedModel;
    final tools = [
      CreateNoteTool(ref, _toolTurnLimiter),
      CreatePasswordTool(ref, _toolTurnLimiter),
      ScheduleEventTool(ref, _toolTurnLimiter),
      CreateDocumentTool(ref, _toolTurnLimiter),
    ];

    int contextSize = model.contextSize;
    int gpuLayers = 0;

    if (Platform.isAndroid) {
      final fileSizeBytes = await File(modelPath).length();
      final fileSizeMB = fileSizeBytes ~/ (1024 * 1024);

      // Check if the device has enough RAM to safely load this model.
      // The model needs native memory for weights + KV cache + overhead.
      // If the model file is larger than 40% of total RAM, the OS will
      // kill the process shortly after loading (even if the load itself
      // succeeds, there won't be enough RAM left for the rest of the OS).
      final deviceRamMB = await _getDeviceRamMB();

      if (deviceRamMB > 0 && fileSizeMB > deviceRamMB * 0.4) {
        throw StateError(
          'Not enough device memory to load ${model.displayName} '
          '(${fileSizeMB}MB). Your device has ${deviceRamMB}MB RAM. '
          'Models should be under ${(deviceRamMB * 0.4).round()}MB '
          'for your device. Please choose a smaller model.',
        );
      }

      final params = _androidLoadParams(fileSizeMB, model.contextSize);
      contextSize = params.contextSize;
      gpuLayers = params.gpuLayers;
    }

    await _kit.initialize(
      modelPath: modelPath,
      template: _templateForModel(model),
      contextSize: contextSize,
      gpuLayers: gpuLayers,
      customTools: tools,
    );

    _kitInitialized = true;
  }


  Stream<DownloadProgress> downloadModel() async* {
    await initialize();

    final model = _selectedModel;
    final modelDir = await DartBridgeModelPaths.instance
        .getModelFolderAndCreate(model.id, InferenceFramework.llamaCpp);
    final url = Uri.parse(model.downloadUrl);
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

  /// Identifies which vault items are relevant to the user's question.
  /// Uses word-boundary matching on the question text to avoid false positives
  /// from common words appearing in the AI response.
  List<RetrievalResult> _extractVaultSources(
    String question,
    String response,
    VaultData vault,
  ) {
    final questionLower = question.toLowerCase();
    final responseLower = response.toLowerCase();
    final results = <RetrievalResult>[];
    final seenIds = <String>{};

    bool _matches(String title) {
      if (title.length < 3) return false;
      final titleLower = title.toLowerCase();
      // Primary: title words appear in the user's question
      if (questionLower.contains(titleLower)) return true;
      // Secondary: the AI quoted the title exactly (e.g. "Grocery List1")
      if (responseLower.contains('"$titleLower"') ||
          responseLower.contains("'$titleLower'") ||
          responseLower.contains('\"$titleLower\"')) {
        return true;
      }
      return false;
    }

    for (final n in vault.notes) {
      if (_matches(n.title) && seenIds.add(n.id)) {
        results.add(RetrievalResult(
          content: n.content.length > 80
              ? '${n.content.substring(0, 80)}\u2026'
              : n.content,
          source: SourceMetadata(
            title: '\ud83d\udcdd Note: ${n.title}',
            filePath: 'vault://notes/${n.id}',
          ),
          score: 1.0,
        ));
      }
    }

    for (final p in vault.passwords) {
      if (_matches(p.accountName) && seenIds.add(p.id)) {
        results.add(RetrievalResult(
          content: 'Account: ${p.accountName}',
          source: SourceMetadata(
            title: '\ud83d\udd10 Password: ${p.accountName}',
            filePath: 'vault://passwords/${p.id}',
          ),
          score: 1.0,
        ));
      }
    }

    for (final e in vault.events) {
      if (_matches(e.title) && seenIds.add(e.id)) {
        final dateStr = e.startsAt.toString().split('.')[0];
        results.add(RetrievalResult(
          content: '$dateStr \u2014 ${e.description}',
          source: SourceMetadata(
            title: '\ud83d\udcc5 Event: ${e.title}',
            filePath: 'vault://events/${e.id}',
          ),
          score: 1.0,
        ));
      }
    }

    for (final d in vault.documents) {
      if (_matches(d.title) && seenIds.add(d.id)) {
        results.add(RetrievalResult(
          content: d.content.length > 80
              ? '${d.content.substring(0, 80)}\u2026'
              : d.content,
          source: SourceMetadata(
            title: '\ud83d\udcc4 Document: ${d.title}',
            filePath: 'vault://documents/${d.id}',
          ),
          score: 1.0,
        ));
      }
    }

    return results;
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

  /// Trims session history to stay within the model's context window.
  /// Keeps the most recent messages (drops oldest user/assistant pairs first).
  List<AgentChatMessage> _getRecentHistory(List<AgentChatMessage> history, {int maxMessages = 20}) {
    if (history.length <= maxMessages) {
      return List.from(history);
    }
    // Keep only the most recent messages
    return history.sublist(history.length - maxMessages);
  }

  /// Entry point for AgentChatView. Routes based on [AssistantMode].
  Stream<String> askStream(
    String question, {
    AssistantMode mode = AssistantMode.chat,
    void Function(List<dynamic>)? onCitations,
    List<AgentChatMessage> history = const [],
    String? sessionId,
  }) async* {
    final stopwatch = Stopwatch()..start();
    print('[AI] ========== START askStream ==========');
    print('[AI] Question: "$question" (length: ${question.length})');
    print('[AI] Mode: $mode, History length: ${history.length}, SessionId: $sessionId');
    try {
      // Ensure model is loaded
      if (!_kitInitialized) {
        print('[AI] Model not initialized, attempting to load...');
        try {
          await loadModel();
          print('[AI] Model loaded successfully');
        } catch (e) {
          print('[AI] Failed to load model: $e');
          yield "Error loading AI model: $e";
          return;
        }
      }

      // Verify model is ready
      if (!_kit.isReady) {
        print('[AI] Kit not ready, waiting or failed initialization');
        yield "The AI assistant is still starting up or failed to load. Please wait a moment or restart the app.";
        return;
      }
      print('[AI] Model ready, proceeding with inference');
    } catch (e) {
      print('[AI] Unexpected error during initialization: $e');
      yield "Unexpected error during initialization: $e";
      return;
    }

    // History trimming is now applied per-request based on the passed history.

    final responseBuffer = StringBuffer();
    // Unique marker to force context reset between different sessions
    final sessionMarker = sessionId != null ? 'Session Context ID: $sessionId\n' : '';
    
    // Limit tokens for very small models but allow enough for complete responses
    final maxTokens = _selectedModel.parameterCount.contains('0.6B') ? 512 : 768;
    print('[AI] Using max tokens: $maxTokens for model: ${_selectedModel.displayName}');

    try {
      switch (mode) {
        case AssistantMode.chat:
          // Plain chat with session context — pass recent history so the LLM
          // understands prior conversation turns.
          print('[AI] Starting chat mode request');
          final trimmedHistory = _getRecentHistory(history);
          try {
            // For very small models (like Qwen 0.6B), use an extremely concise system prompt
            // Verbose prompts cause the model to output its reasoning instead of answers
            final conciseSystemPrompt = _selectedModel.parameterCount.contains('0.6B')
                ? 'You are a helpful assistant. Answer questions directly and concisely.'
                : '$sessionMarker'
                    'You are a personal, private AI assistant running locally on the user\'s device. '
                    'The user will share personal details (like their name) to help you assist them better. '
                    'You MUST remember and use this information from the conversation history. '
                    'If the user tells you their name, greet them by it and remember it for future questions. '
                    'Never say you don\'t have access to personal information—you have access to what the user tells you in this chat.';
            
            print('[AI] Calling askDirectStream for chat mode');
            final inferenceStart = DateTime.now();
            var tokenCount = 0;
            await for (final token in _kit.askDirectStream(
              question,
              history: trimmedHistory,
              systemPrompt: conciseSystemPrompt,
              maxTokens: maxTokens,
            )) {
              tokenCount++;
              responseBuffer.write(token);
              yield token;
            }
            final inferenceTime = DateTime.now().difference(inferenceStart).inMilliseconds;
            print('[AI] Chat mode inference completed in ${inferenceTime}ms (${tokenCount} tokens, ${(tokenCount*1000/inferenceTime).toStringAsFixed(0)} tokens/sec)');
            print('[AI] Chat mode completed, response length: ${responseBuffer.length}');
          } catch (e) {
            print('[AI] Error in chat stream: $e');
            final errorMsg = 'Error during chat: $e';
            responseBuffer.write(errorMsg);
            yield errorMsg;
          }
          break;

        case AssistantMode.vault:
          // RAG — vault context injected, no tools, with session history
          print('[AI] Starting vault mode request');
          final vaultStart = DateTime.now();
          final context = await _buildVaultContext();
          final vaultTime = DateTime.now().difference(vaultStart).inMilliseconds;
          print('[AI] Vault context built in ${vaultTime}ms (length: ${context.length})');
          final vault = await ref.read(vaultControllerProvider.future);
          final trimmedHistory = _getRecentHistory(history);
          final prompt =
              'You are a helpful vault assistant. NEVER generate code.\n\n'
              'VAULT DATA:\n$context\n\n'
              'Question: $question\n\n'
              'Answer briefly and directly:';
          print('[AI] Vault prompt constructed (length: ${prompt.length})');
          // Vault mode uses explicitly injected vault context and should not
          // additionally query the RAG index.
          try {
            // For very small models, use concise system prompt
            final conciseSystemPrompt = _selectedModel.parameterCount.contains('0.6B')
                ? 'Answer using the vault data provided. Be brief.'
                : '$sessionMarker'
                    'You are a precise vault assistant. Use only the provided vault data. '
                    'If data is missing, say so clearly. '
                    'Remember everything the user tells you during this conversation.';
            
            print('[AI] Calling askDirectStream for vault mode');
            await for (final token in _kit.askDirectStream(
              prompt,
              history: trimmedHistory,
              systemPrompt: conciseSystemPrompt,
              maxTokens: maxTokens,
            )) {
              responseBuffer.write(token);
              yield token;
            }
            print('[AI] Vault mode completed, response length: ${responseBuffer.length}');
          } catch (e) {
            print('[AI] Error in vault stream: $e');
            final errorMsg = 'Error during vault query: $e';
            responseBuffer.write(errorMsg);
            yield errorMsg;
          }
          // After response streaming completes, extract vault sources and
          // emit them as citations so the UI shows reference chips.
          final responseText = responseBuffer.toString();
          print('VaultQA: Response length = ${responseText.length}');
          print('VaultQA: Question = "$question"');
          print('VaultQA: Vault has ${vault.notes.length} notes, ${vault.passwords.length} passwords, ${vault.events.length} events, ${vault.documents.length} documents');
          final vaultSources = _extractVaultSources(question, responseText, vault);
          print('VaultQA: Extracted ${vaultSources.length} sources');
          for (final s in vaultSources) {
            print('VaultQA: Source → ${s.source.title}');
          }
          if (vaultSources.isNotEmpty) {
            onCitations?.call(vaultSources);
            print('VaultQA: onCitations called with ${vaultSources.length} sources');
          } else {
            print('VaultQA: No sources found to cite');
          }
          break;

        case AssistantMode.agent:
          // Agent — ReAct loop with tools + vault context
          print('[AI] Starting agent mode request');
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
          
          // For very small models, simplify system prompt dramatically
          final isSmallModel = _selectedModel.parameterCount.contains('0.6B');
          final systemPrompt = isSmallModel
              ? 'You are a vault assistant. Use tools to create or modify items.\n\n'
                  'VAULT DATA:\n$context'
              : 'You are a private vault assistant.\n\n'
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
              responseBuffer.write(token);
              yield token;
            }
            print('[AI] Agent mode completed, response length: ${responseBuffer.length}');

            final afterVault = await ref.read(vaultControllerProvider.future);
            final verifiedSummary = _buildVerifiedCreationSummary(
              beforeVault,
              afterVault,
            );
            if (verifiedSummary != null) {
              responseBuffer.write('\n\n$verifiedSummary');
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
                  responseBuffer.write(token);
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
                responseBuffer.write('\n\n$retrySummary');
                yield '\n\n$retrySummary';
              } else {
                const msg = '\n\nI could not verify a created item ID after '
                    '$_maxAgentVerificationAttempts attempts. '
                    'Please resend with explicit fields like title and content.';
                responseBuffer.write(msg);
                yield msg;
              }
            }
          } catch (e) {
            print('[AI] Error in agent stream: $e');
            final errorMsg = 'Error during agent action: $e';
            responseBuffer.write(errorMsg);
            yield errorMsg;
          } finally {
            _toolTurnLimiter.endTurn();
          }
          break;
      }
    } catch (e) {
      print('[AI] Unexpected error in askStream: $e');
      yield 'Unexpected error: $e';
    }
    final totalTime = stopwatch.elapsedMilliseconds;
    print('[AI] ========== END askStream (total: ${totalTime}ms), response length: ${responseBuffer.length} ==========');
  }

  bool get isModelLoaded => _kitInitialized;

  /// Helper to tap into a stream without consuming it.
  StreamTransformer<String, String> _tapStream(void Function(String) onData) {
    return StreamTransformer<String, String>.fromHandlers(
      handleData: (data, sink) {
        onData(data);
        sink.add(data);
      },
    );
  }
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
