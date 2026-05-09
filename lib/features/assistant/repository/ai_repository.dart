import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:runanywhere/runanywhere.dart';
import 'package:runanywhere/native/dart_bridge.dart';
import 'package:runanywhere/public/runanywhere_tool_calling.dart';
import 'package:runanywhere/public/types/generation_types.dart';
import 'package:runanywhere/public/types/download_types.dart' as ra_download;
import 'package:runanywhere/public/types/tool_calling_types.dart';
import 'package:runanywhere_llamacpp/runanywhere_llamacpp.dart';

import '../models/chat_session.dart';
import 'ai_model_registry.dart';
import 'assistant_tools.dart';

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  return AiRepository(ref);
});

class AiRepository {
  AiRepository(this.ref);

  final Ref ref;

  AiModelInfo _selectedModel = AiModelRegistry.defaultModel;
  bool _initialized = false;
  bool _modelsRegistered = false;
  String? _cachedDocumentsPath;
  Map<String, String?>? _modelFileCache; // modelId -> file path
  Future<void>? _discoverFuture; // Ensure only one discovery scan at a time
  Future<void>? _loadFuture; // Prevent concurrent model loads
  String? _loadingModelId; // Track which model is currently loading

  AiModelInfo get selectedModel => _selectedModel;

  String get modelName => _selectedModel.displayName;

  bool get isModelLoaded =>
      RunAnywhere.isModelLoaded &&
      RunAnywhere.currentModelId == _selectedModel.id;

  // All local models (max 2.6GB / 4B params) are relatively "small" for tool-calling
  // and need context-saving heuristics (e.g., stripping chat history).
  bool get _isCurrentModelSmall =>
      _selectedModel.id.contains('360m') ||
      _selectedModel.id.contains('0.5b') ||
      _selectedModel.id.contains('0.6b');

  bool selectModel(String modelId) {
    final model = AiModelRegistry.findById(modelId);
    if (model.id == _selectedModel.id) return false;
    _selectedModel = model;
    return true;
  }

  Future<void> initialize() async {
    if (_initialized) return;

    await RunAnywhere.initialize(environment: SDKEnvironment.development);
    await LlamaCpp.register();
    await DartBridge.modelPaths.setBaseDirectory();
    _initialized = true;
  }

  Future<void> ensureModelsRegistered() async {
    if (_modelsRegistered) return;
    print(
      '[AiRepository] Registering ${AiModelRegistry.models.length} models with RunAnywhere...',
    );
    for (final model in AiModelRegistry.models) {
      print('[AiRepository] Registering: ${model.id}');
      RunAnywhere.registerModel(
        id: model.id,
        name: model.displayName,
        url: Uri.parse(model.downloadUrl),
        framework: InferenceFramework.llamaCpp,
        memoryRequirement: _memoryRequirementFor(model.sizeLabel),
      );
    }
    _modelsRegistered = true;
    print('[AiRepository] All models registered with RunAnywhere');
  }

  Future<bool> isModelDownloaded([String? modelId]) async {
    print('[AiRepository] isModelDownloaded called');
    await initialize();
    print('[AiRepository] initialize() done');
    // Only do discovery if we haven't already
    if (_modelFileCache == null) {
      print('[AiRepository] Starting discovery...');
      await _discoverLocalModels();
      print('[AiRepository] Discovery done, cache=$_modelFileCache');
    } else {
      print('[AiRepository] Using cached discovery, cache=$_modelFileCache');
    }
    final id = modelId ?? _selectedModel.id;
    print('[AiRepository] checking model $id in cache');
    return _modelFileCache?.containsKey(id) ?? false;
  }

  Future<void> _discoverLocalModels() async {
    // Only scan once and cache results, ensuring serialization
    if (_modelFileCache != null) return;

    // Ensure only one discovery operation runs at a time
    _discoverFuture ??= performDiscovery();
    await _discoverFuture;
  }

  Future<void> performDiscovery() async {
    _modelFileCache = {};

    try {
      if (_cachedDocumentsPath == null) {
        final documentsDirectory = await getApplicationDocumentsDirectory();
        _cachedDocumentsPath = documentsDirectory.path;
      }

      final modelsRoot = Directory(
        path.join(_cachedDocumentsPath!, 'RunAnywhere', 'Models'),
      );

      if (!await modelsRoot.exists()) return;

      // Single recursive scan to discover all models
      await for (final entity in modelsRoot.list(recursive: true)) {
        if (entity is! File) continue;
        final fileName = entity.path.toLowerCase();

        if (!fileName.endsWith('.gguf') && !fileName.endsWith('.bin')) continue;

        try {
          final size = await entity.length();
          if (size <= 1024 * 1024) continue; // Skip files smaller than 1MB

          // Find which model this file belongs to by checking against all known models
          for (final model in AiModelRegistry.models) {
            if (entity.path.contains(model.id)) {
              _modelFileCache![model.id] = entity.path;
              break;
            }
          }
        } catch (_) {
          // Skip this file if we can't get its size
        }
      }
    } catch (e) {
      debugPrint('[AiRepository] Error discovering local models: $e');
      _modelFileCache = {}; // Return empty cache on error
    }
  }

  Set<String> getDiscoveredModels() {
    return _modelFileCache?.keys.toSet() ?? <String>{};
  }

  Future<void> refreshDiscoveredModels() async {
    invalidateModelCache();
    await _discoverLocalModels();
  }

  void invalidateModelCache() {
    debugPrint('[AiRepository] Invalidating model file cache.');
    _modelFileCache = null;
    _discoverFuture = null;
  }

  Future<String?> _getExistingModelFilePath([String? modelId]) async {
    await _discoverLocalModels();
    final id = modelId ?? _selectedModel.id;
    return _modelFileCache?[id];
  }

  Future<int> getModelFileSizeMB([String? modelId]) async {
    final path = await _getExistingModelFilePath(modelId);
    if (path == null) return 0;
    final bytes = await File(path).length();
    return bytes ~/ (1024 * 1024);
  }

  Future<void> deleteModel(String modelId) async {
    await initialize();
    try {
      final modelPath = await _getExistingModelFilePath(modelId);

      if (modelPath != null) {
        final file = File(modelPath);
        if (await file.exists()) {
          await file.delete();
        }
      }

      // Invalidate the cache so it gets rebuilt on next scan
      _modelFileCache = null;
      _discoverFuture = null;
    } catch (e) {
      debugPrint('[AiRepository] Error deleting model: $e');
    }

    if (modelId == _selectedModel.id && RunAnywhere.isModelLoaded) {
      await RunAnywhere.unloadModel();
    }
  }

  Future<void> loadModel() async {
    final modelId = _selectedModel.id;
    final currentId = RunAnywhere.currentModelId;

    // If we're already loading THIS specific model, return the existing future
    if (_loadingModelId == modelId && _loadFuture != null) {
      debugPrint('[AiRepository] Already loading $modelId, joining future...');
      return _loadFuture!;
    }

    // If a DIFFERENT model is currently loading, wait for it to finish first
    if (_loadFuture != null) {
      debugPrint(
        '[AiRepository] Waiting for previous load (${_loadingModelId}) to complete...',
      );
      await _loadFuture;
    }

    // Now check if the selected model is already loaded (it might have been loaded by the previous future)
    if (isModelLoaded) {
      debugPrint(
        '[AiRepository] Model $modelId is already loaded, skipping load.',
      );
      return;
    }

    debugPrint(
      '[AiRepository] Model mismatch or not loaded. Current: $currentId, Target: $modelId',
    );

    _loadingModelId = modelId;
    try {
      debugPrint('[AiRepository] Initiating load sequence for $modelId...');
      _loadFuture = _loadModelInternal();
      await _loadFuture;
    } catch (e) {
      debugPrint('[AiRepository] Failed to load model $modelId: $e');
      rethrow;
    } finally {
      _loadFuture = null;
      _loadingModelId = null;
    }
  }

  ({int contextSize, int gpuLayers}) _androidLoadParams(
    int fileSizeMB,
    int requestedContextSize,
  ) {
    // Tool calling requires at least ~2000 context window, so we never shrink below that.
    final safeContextSize = requestedContextSize < 2048
        ? 2048
        : requestedContextSize;

    // Use CPU only on Android to avoid stability/VRAM issues on shared-memory mobile devices.
    return (contextSize: safeContextSize, gpuLayers: 0);
  }

  Future<int> _getDeviceRamMB() async {
    try {
      final meminfo = await File('/proc/meminfo').readAsString();
      final match = RegExp(r'MemTotal:\s+(\d+)\s+kB').firstMatch(meminfo);
      if (match != null) {
        final kb = int.parse(match.group(1)!);
        return kb ~/ 1024;
      }
    } catch (_) {}
    return 0;
  }

  Future<void> _loadModelInternal() async {
    print('[AiRepository] Starting _loadModelInternal');
    await initialize();
    print('[AiRepository] Finding existing model file path...');
    final modelPath = await _getExistingModelFilePath();
    if (modelPath == null) {
      print('[AiRepository] ERROR: Model file not found on disk');
      throw StateError('Model file not found. Download the model first.');
    }
    print('[AiRepository] Found model file at: $modelPath');

    final file = File(modelPath);
    if (!await file.exists()) {
      print(
        '[AiRepository] ERROR: Model file path found but file does not exist at that path!',
      );
      throw StateError('Model file found in cache but missing on disk.');
    }
    final size = await file.length();
    print(
      '[AiRepository] Model file size: ${(size / 1024 / 1024).toStringAsFixed(1)} MB',
    );

    final model = _selectedModel;
    int contextSize = model.contextSize;
    int gpuLayers = 0;

    if (Platform.isAndroid) {
      final fileSizeBytes = await File(modelPath).length();
      final fileSizeMB = fileSizeBytes ~/ (1024 * 1024);

      final deviceRamMB = await _getDeviceRamMB();
      final ramThreshold =
          0.75; // Relaxed to 75% to allow Gemma 3 4B on 4GB devices

      if (deviceRamMB > 0) {
        final usageRatio = fileSizeMB / deviceRamMB;
        if (usageRatio > 0.5) {
          print(
            '[AiRepository] WARNING: High memory usage detected (${(usageRatio * 100).toStringAsFixed(1)}% of RAM)',
          );
        }

        if (usageRatio > ramThreshold) {
          throw StateError(
            'Not enough device memory to load ${model.displayName} '
            '(${fileSizeMB}MB). Your device has ${deviceRamMB}MB RAM. '
            'Threshold is ${(ramThreshold * 100).round()}%. Choose a smaller model.',
          );
        }
      }

      final params = _androidLoadParams(fileSizeMB, model.contextSize);
      contextSize = params.contextSize;
      gpuLayers = params.gpuLayers;
    }

    print(
      '[AiRepository] Selected model: ${model.displayName} (ID: ${model.id})',
    );

    if (RunAnywhere.isModelLoaded) {
      print('[AiRepository] Releasing large model memory...');
      await RunAnywhere.unloadModel();
      // Increased delay to 500ms to allow Android OS to reclaim physical RAM pages
      // and prevent thermal/memory-pressure throttling of the CPU.
      await Future.delayed(const Duration(milliseconds: 500));
      print('[AiRepository] Memory reclamation completed');
    }

    // Ensure RunAnywhere knows about the local path if it doesn't already
    // This is a bridge between our manual discovery and RunAnywhere's registry
    print(
      '[AiRepository] Updating RunAnywhere download status for ID ${model.id} with path $modelPath',
    );
    await RunAnywhere.updateModelDownloadStatus(model.id, modelPath);

    print('[AiRepository] Calling RunAnywhere.loadModel(${model.id})...');
    try {
      await RunAnywhere.loadModel(model.id);
      print('[AiRepository] RunAnywhere.loadModel returned');
    } catch (e) {
      print('[AiRepository] ERROR: RunAnywhere.loadModel threw: $e');
      rethrow;
    }

    final isLoaded = RunAnywhere.isModelLoaded;
    print('[AiRepository] RunAnywhere.isModelLoaded: $isLoaded');
    if (!isLoaded) {
      print(
        '[AiRepository] ERROR: Model reported as not loaded after successful call',
      );
      throw StateError('Failed to load LLM model: ${model.displayName}');
    }
    print('[AiRepository] Model loaded successfully');

    debugPrint(
      'Loaded ${model.displayName} (contextSize=$contextSize, gpuLayers=$gpuLayers)',
    );
  }

  Stream<DownloadProgress> downloadModel() async* {
    await initialize();

    await for (final progress in RunAnywhere.downloadModel(_selectedModel.id)) {
      yield DownloadProgress(
        bytesDownloaded: progress.bytesDownloaded,
        totalBytes: progress.totalBytes,
        state: switch (progress.state) {
          ra_download.DownloadProgressState.downloading =>
            DownloadProgressState.downloading,
          ra_download.DownloadProgressState.completed =>
            DownloadProgressState.completed,
          ra_download.DownloadProgressState.failed =>
            DownloadProgressState.failed,
          ra_download.DownloadProgressState.cancelled =>
            DownloadProgressState.failed,
        },
        stage: switch (progress.stage) {
          ra_download.DownloadProgressStage.completed =>
            DownloadProgressStage.completed,
          ra_download.DownloadProgressStage.failed =>
            DownloadProgressStage.failed,
          ra_download.DownloadProgressStage.cancelled =>
            DownloadProgressStage.failed,
          _ => DownloadProgressStage.downloading,
        },
      );
    }
  }

  String _historyToPrompt(
    String question,
    List<ChatMessageEntry> history, {
    required AssistantMode mode,
    String? vaultContext,
  }) {
    final buffer = StringBuffer();
    final template = _selectedModel.templateType;
    final skipHistory = _isCurrentModelSmall && mode != AssistantMode.chat;

    if (!skipHistory) {
      for (final message in history) {
        _appendFormattedMessage(
          buffer,
          message.role,
          message.content,
          template,
        );
      }
    }

    // Prepare the user message content
    String userContent = question;
    if (mode == AssistantMode.vault && vaultContext != null && vaultContext.isNotEmpty) {
      userContent = 'VAULT DATA:\n$vaultContext\n\nQuestion: $question';
    }

    // Add current question as user message
    _appendFormattedMessage(buffer, 'user', userContent, template);

    // Add the assistant start tag so the model knows to start generating its response
    _appendAssistantStartTag(buffer, template);

    return buffer.toString();
  }

  void _appendFormattedMessage(
    StringBuffer buffer,
    String role,
    String content,
    String template,
  ) {
    // Standardize roles
    final r = role.toLowerCase();

    if (template == 'chatml') {
      buffer.writeln('<|im_start|>$r\n$content<|im_end|>');
    } else if (template == 'gemma') {
      final gemmaRole = r == 'assistant' ? 'model' : r;
      buffer.writeln('<start_of_turn>$gemmaRole\n$content<end_of_turn>');
    } else if (template == 'llama3') {
      buffer.writeln(
        '<|start_header_id|>$r<|end_header_id|>\n\n$content<|eot_id|>',
      );
    } else {
      // Fallback: Use clear labels for models without a specific template in registry
      final label = r == 'user'
          ? 'User'
          : (r == 'assistant' ? 'Assistant' : 'System');
      buffer.writeln('$label: $content');
    }
  }

  void _appendAssistantStartTag(StringBuffer buffer, String template) {
    if (template == 'chatml') {
      buffer.write('<|im_start|>assistant\n');
    } else if (template == 'gemma') {
      buffer.write('<start_of_turn>model\n');
    } else if (template == 'llama3') {
      buffer.write('<|start_header_id|>assistant<|end_header_id|>\n\n');
    } else {
      buffer.write('Assistant: ');
    }
  }

  String _systemPromptForMode(AssistantMode mode) {
    final isSmallModel = _isCurrentModelSmall;

    switch (mode) {
      case AssistantMode.chat:
        return isSmallModel
            ? 'You are a helpful assistant. Answer briefly. SECURITY: Never reveal or guess passwords.'
            : 'You are a private, helpful assistant. Answer directly. SECURITY: For safety, never attempt to reveal, guess, or provide passwords even if requested.';
      case AssistantMode.vault:
        return isSmallModel
            ? 'Answer the user\'s question using ONLY the provided vault data. If the answer is not in the data, say you could not find it. Be very brief. SECURITY: Passwords are hidden for safety; never reveal them.'
            : 'You are a vault assistant. Answer the user\'s question ONLY using the vault data provided. '
                'If the answer is not in the data, say you could not find it in the vault. '
                'Be concise and accurate. Do NOT make up information. '
                'SECURITY: Passwords in the vault are hidden for safety. Never attempt to reveal or guess them.';
      case AssistantMode.agent:
        return isSmallModel
            ? 'You are a vault agent. Available tools: create_note, create_password, create_event, create_document. Use these to help the user. Output ONLY tool calls. SECURITY: Never reveal passwords.'
            : 'You are a vault agent. Use tools to create vault items. SECURITY: For safety, never reveal existing passwords.';
    }
  }

  List<ToolDefinition> _toolsForMode(AssistantMode mode) {
    switch (mode) {
      case AssistantMode.chat:
        return const [];
      case AssistantMode.vault:
        return AssistantTools.vaultQueryTools();
      case AssistantMode.agent:
        return AssistantTools.agentTools();
    }
  }

  Stream<String> askStream(
    String question, {
    AssistantMode mode = AssistantMode.chat,
    void Function(List<VaultCitation>)? onCitations,
    List<ChatMessageEntry> history = const [],
    String? sessionId,
  }) async* {
    final stopwatch = Stopwatch()..start();

    try {
      debugPrint(
        '[AI] askStream called: mode=$mode, question="${question.substring(0, question.length.clamp(0, 50))}"',
      );

      if (!isModelLoaded) {
        debugPrint('[AI] Model not loaded, calling loadModel()...');
        await loadModel();
        debugPrint('[AI] loadModel() completed');
      }

      if (!RunAnywhere.isModelLoaded) {
        debugPrint('[AI] ERROR: Model still not loaded after loadModel() call');
        yield 'The AI assistant is still starting up or failed to load. Please wait a moment or restart the app.';
        return;
      }

      debugPrint(
        '[AI] Model loaded, currentModelId=${RunAnywhere.currentModelId}',
      );

      final currentDate = DateTime.now().toLocal().toString().split(' ')[0];
      final currentTime = DateTime.now()
          .toLocal()
          .toString()
          .split(' ')[1]
          .split('.')
          .first;
      final metadata = 'Today is $currentDate, current time is $currentTime.';

      // ── VAULT MODE: Deterministic RAG-style search ──
      if (mode == AssistantMode.vault) {
        debugPrint('[AI] Vault mode: running deterministic search...');
        final vaultResult = await AssistantTools.searchAndBuildContext(
          ref,
          question,
        );
        debugPrint(
          '[AI] Vault search returned ${vaultResult.citations.length} citations',
        );

        // Pass citations to the UI early, before generation
        if (onCitations != null) {
          onCitations(vaultResult.citations);
        }

        final systemPrompt =
            '${_systemPromptForMode(mode)} $metadata';

        final prompt = _historyToPrompt(
          question,
          _recentHistory(history, mode: mode),
          mode: mode,
          vaultContext: vaultResult.context,
        );

        debugPrint(
          '[AI] Vault prompt length: ${prompt.length} chars, systemPrompt: ${systemPrompt.length} chars',
        );

        final streamResult = await RunAnywhere.generateStream(
          prompt,
          options: LLMGenerationOptions(
            maxTokens: _isCurrentModelSmall ? 512 : 768,
            temperature: 0.3,
            systemPrompt: systemPrompt,
            streamingEnabled: true,
          ),
        );

        await for (final token in streamResult.stream) {
          // Strip thinking blocks in real-time
          yield token;
        }

        debugPrint('[AI] Vault stream completed');
        return;
      }

      final systemPrompt = '${_systemPromptForMode(mode)} $metadata';

      // For chat mode, we manage the full template ourselves for precise history handling.
      // For tool modes, we pass the raw question because generateWithTools handles its own templating.
      final prompt = mode == AssistantMode.chat
          ? _historyToPrompt(
              question,
              _recentHistory(history, mode: mode),
              mode: mode,
            )
          : question;

      debugPrint(
        '[AI] Prompt length: ${prompt.length} chars (mode: $mode), systemPrompt: ${systemPrompt.length} chars',
      );

      if (mode == AssistantMode.chat) {
        debugPrint('[AI] Starting generateStream for chat mode...');
        final streamResult = await RunAnywhere.generateStream(
          prompt,
          options: LLMGenerationOptions(
            maxTokens: _isCurrentModelSmall ? 512 : 768,
            temperature: 0.7,
            systemPrompt: systemPrompt,
            streamingEnabled: true,
          ),
        );
        debugPrint('[AI] generateStream returned, listening for tokens...');

        await for (final token in streamResult.stream) {
          yield token;
        }
        debugPrint('[AI] Chat stream completed');
        return;
      }

      final tools = _toolsForMode(mode);
      if (tools.isNotEmpty) {
        RunAnywhereTools.clearTools();
        if (mode == AssistantMode.agent) {
          AssistantTools.registerAgentTools(ref);
          // Register common hallucinations to redirect them to the correct tools
          _registerHallucinationGuards(ref);
        } else if (mode == AssistantMode.vault) {
          AssistantTools.registerVaultQueryTools(ref);
          _registerVaultHallucinationGuards(ref);
        }
      }

      try {
        ToolCallingResult? finalToolResult;
        bool itemCreated = false;
        
        if (mode == AssistantMode.agent && _isCreationIntent(question)) {
          int attempts = 0;
          const maxAttempts = 3;
          String currentPrompt = prompt;

          while (attempts < maxAttempts && !itemCreated) {
            attempts++;
            debugPrint('[AI] Agent creation attempt $attempts of $maxAttempts');
            
            final toolResult = await RunAnywhereTools.generateWithTools(
              currentPrompt,
              options: ToolCallingOptions(
                tools: tools,
                maxToolCalls: 5,
                temperature: 0.1,
                maxTokens: _isCurrentModelSmall ? 512 : 1024,
                systemPrompt: systemPrompt,
                formatName: ToolCallFormatName.defaultFormat,
                keepToolsAvailable: false,
              ),
            );
            
            finalToolResult = toolResult;
            
            final createdId = _detectCreatedItemId(toolResult);
            if (createdId != null) {
              debugPrint('[AI] Agent creation successful! Item ID: $createdId');
              itemCreated = true;
            } else {
              debugPrint('[AI] Agent creation failed on attempt $attempts. No valid item ID returned.');
              if (attempts < maxAttempts) {
                // Add a nudge for the retry
                currentPrompt = prompt + '\n\nIMPORTANT: You MUST call a create tool (create_note, create_password, create_event, or create_document) to complete this request. Do NOT just describe what you would do — actually call the tool. Ensure you provide all required parameters.';
              }
            }
          }
          
          if (!itemCreated) {
            debugPrint('[AI] Agent creation failed after $maxAttempts attempts.');
            yield 'I had trouble creating the item right now. Could you try rephrasing your request?';
            return;
          }
        } else {
          // Standard tool calling (Vault Query or non-creation Agent requests)
          finalToolResult = await RunAnywhereTools.generateWithTools(
            prompt,
            options: ToolCallingOptions(
              tools: tools,
              maxToolCalls: 5,
              temperature: mode == AssistantMode.chat ? 0.7 : 0.1,
              maxTokens: _isCurrentModelSmall ? 512 : 1024,
              systemPrompt: systemPrompt,
              formatName: ToolCallFormatName.defaultFormat,
              keepToolsAvailable: false,
            ),
          );
        }

        // Strip thinking blocks from the final output before yielding to UI
        String cleanText = finalToolResult!.text;

        // Comprehensive stripping of <think> blocks
        cleanText = cleanText
            .replaceAll(RegExp(r'<think>[\s\S]*?<\/think>'), '')
            .trim();
        cleanText = cleanText
            .replaceAll(RegExp(r'<think>[\s\S]*'), '')
            .trim(); // Strip unclosed tags

        if (cleanText.isEmpty && mode == AssistantMode.agent && itemCreated) {
          cleanText = 'Item created successfully!';
        }

        if (cleanText.isNotEmpty) {
          yield cleanText;
        }

        if (onCitations != null) {
          onCitations(const []);
        }
      } finally {
        RunAnywhereTools.clearTools();
      }
    } catch (error) {
      yield 'Unexpected error: $error';
    } finally {
      debugPrint(
        '[AI] askStream completed in ${stopwatch.elapsedMilliseconds}ms for mode $mode',
      );
    }
  }

  void _registerHallucinationGuards(Ref ref) {
    // Some small models (like SmolLM2) hallucinate tool names like 'get_document' or 'add_note'
    // even when they see 'create_document' or 'create_note'.
    RunAnywhereTools.registerTool(
      const ToolDefinition(
        name: 'get_document',
        description: 'Alias for create_document (internal use only)',
        parameters: [
          ToolParameter(
            name: 'title',
            type: ToolParameterType.string,
            description: 'Document title',
          ),
          ToolParameter(
            name: 'content',
            type: ToolParameterType.string,
            description: 'Document content',
          ),
        ],
      ),
      (args) => AssistantTools.handleAlias(ref, 'create_document', args),
    );
    RunAnywhereTools.registerTool(
      const ToolDefinition(
        name: 'add_note',
        description: 'Alias for create_note (internal use only)',
        parameters: [
          ToolParameter(
            name: 'title',
            type: ToolParameterType.string,
            description: 'Note title',
          ),
          ToolParameter(
            name: 'content',
            type: ToolParameterType.string,
            description: 'Note content',
          ),
        ],
      ),
      (args) => AssistantTools.handleAlias(ref, 'create_note', args),
    );
    RunAnywhereTools.registerTool(
      const ToolDefinition(
        name: 'save_password',
        description: 'Alias for create_password (internal use only)',
        parameters: [
          ToolParameter(
            name: 'account_name',
            type: ToolParameterType.string,
            description: 'Account name',
          ),
          ToolParameter(
            name: 'username',
            type: ToolParameterType.string,
            description: 'Username',
          ),
          ToolParameter(
            name: 'password',
            type: ToolParameterType.string,
            description: 'Password',
          ),
        ],
      ),
      (args) => AssistantTools.handleAlias(ref, 'create_password', args),
    );
    RunAnywhereTools.registerTool(
      const ToolDefinition(
        name: 'add_event',
        description: 'Alias for create_event (internal use only)',
        parameters: [
          ToolParameter(
            name: 'title',
            type: ToolParameterType.string,
            description: 'Event title',
          ),
          ToolParameter(
            name: 'date',
            type: ToolParameterType.string,
            description: 'Event date',
          ),
          ToolParameter(
            name: 'time',
            type: ToolParameterType.string,
            description: 'Event time',
          ),
        ],
      ),
      (args) => AssistantTools.handleAlias(ref, 'create_event', args),
    );
    RunAnywhereTools.registerTool(
      const ToolDefinition(
        name: 'add_password',
        description: 'Alias for create_password (internal use only)',
        parameters: [
          ToolParameter(
            name: 'account_name',
            type: ToolParameterType.string,
            description: 'Account name',
          ),
          ToolParameter(
            name: 'username',
            type: ToolParameterType.string,
            description: 'Username',
          ),
          ToolParameter(
            name: 'password',
            type: ToolParameterType.string,
            description: 'Password',
          ),
        ],
      ),
      (args) => AssistantTools.handleAlias(ref, 'create_password', args),
    );
    RunAnywhereTools.registerTool(
      const ToolDefinition(
        name: 'save_note',
        description: 'Alias for create_note (internal use only)',
        parameters: [
          ToolParameter(
            name: 'title',
            type: ToolParameterType.string,
            description: 'Note title',
          ),
          ToolParameter(
            name: 'content',
            type: ToolParameterType.string,
            description: 'Note content',
          ),
        ],
      ),
      (args) => AssistantTools.handleAlias(ref, 'create_note', args),
    );
  }

  void _registerVaultHallucinationGuards(Ref ref) {
    RunAnywhereTools.registerTool(
      const ToolDefinition(
        name: 'query_vault',
        description: 'Alias for search_vault (internal use only)',
        parameters: [
          ToolParameter(
            name: 'query',
            type: ToolParameterType.string,
            description: 'Search query',
          ),
        ],
      ),
      (args) => AssistantTools.handleAlias(ref, 'search_vault', args),
    );
    RunAnywhereTools.registerTool(
      const ToolDefinition(
        name: 'find_in_vault',
        description: 'Alias for search_vault (internal use only)',
        parameters: [
          ToolParameter(
            name: 'query',
            type: ToolParameterType.string,
            description: 'Search query',
          ),
        ],
      ),
      (args) => AssistantTools.handleAlias(ref, 'search_vault', args),
    );
    RunAnywhereTools.registerTool(
      const ToolDefinition(
        name: 'get_grocery', // Specific hallucination seen in logs
        description: 'Alias for search_vault (internal use only)',
        parameters: [
          ToolParameter(
            name: 'query',
            type: ToolParameterType.string,
            description: 'Search query',
          ),
        ],
      ),
      (args) => AssistantTools.handleAlias(ref, 'search_vault', args),
    );
    RunAnywhereTools.registerTool(
      const ToolDefinition(
        name: 'function_name', // Generic hallucination seen in logs
        description: 'Fallback for placeholder tool calls',
        parameters: [
          ToolParameter(
            name: 'query',
            type: ToolParameterType.string,
            description: 'Search query',
          ),
        ],
      ),
      (args) => AssistantTools.handleAlias(ref, 'search_vault', args),
    );
  }

  int? _memoryRequirementFor(String sizeLabel) {
    final normalized = sizeLabel.toLowerCase().replaceAll(' ', '');
    if (normalized.endsWith('mb')) {
      final value = double.tryParse(normalized.replaceAll('mb', ''));
      return value == null ? null : (value * 1024 * 1024).round();
    }
    if (normalized.endsWith('gb')) {
      final value = double.tryParse(normalized.replaceAll('gb', ''));
      return value == null ? null : (value * 1024 * 1024 * 1024).round();
    }
    return null;
  }

  bool _isCreationIntent(String prompt) {
    final lowerPrompt = prompt.toLowerCase();
    final creationKeywords = [
      'create', 'add', 'save', 'store', 'make', 'new', 'remember'
    ];
    final itemTypes = ['note', 'password', 'event', 'document', 'grocery', 'credential', 'appointment'];
    
    bool hasAction = creationKeywords.any((k) => lowerPrompt.contains(k));
    bool hasTarget = itemTypes.any((t) => lowerPrompt.contains(t));
    
    return hasAction || hasTarget;
  }

  String? _detectCreatedItemId(ToolCallingResult toolResult) {
    for (final result in toolResult.toolResults) {
      if (result.success && result.result != null) {
        final toolName = result.toolName.toLowerCase();
        // Check if it's a known creation tool or an alias we registered
        if (toolName.contains('create') || toolName.contains('add') || toolName.contains('save')) {
          final item = result.result!['item']?.objectValue;
          if (item != null) {
            final id = item['id']?.stringValue;
            if (id != null && id.isNotEmpty) {
              return id;
            }
          }
        }
      }
    }
    return null;
  }

  List<ChatMessageEntry> _recentHistory(
    List<ChatMessageEntry> history, {
    AssistantMode mode = AssistantMode.chat,
  }) {
    // Pass full session history for chat mode to maintain conversational context.
    // For tool-calling modes, keep it minimal to save context window for tool JSON.
    if (mode != AssistantMode.chat && history.length > 4) {
      return history.sublist(history.length - 4);
    }
    return List.from(history);
  }
}

enum AssistantMode { chat, vault, agent }

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
