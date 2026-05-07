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

  AiModelInfo get selectedModel => _selectedModel;

  String get modelName => _selectedModel.displayName;

  bool get isModelLoaded => RunAnywhere.isModelLoaded;

  bool get _isCurrentModelSmall =>
      _selectedModel.parameterCount.contains('0.6B') ||
      _selectedModel.parameterCount.contains('360M');

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
    for (final model in AiModelRegistry.models) {
      RunAnywhere.registerModel(
        id: model.id,
        name: model.displayName,
        url: Uri.parse(model.downloadUrl),
        framework: InferenceFramework.llamaCpp,
        memoryRequirement: _memoryRequirementFor(model.sizeLabel),
      );
    }
    _modelsRegistered = true;
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

  Future<void>? _loadFuture;

  Future<void> loadModel() {
    return _loadFuture ??= _loadModelInternal().catchError((error) {
      _loadFuture = null;
      throw error;
    });
  }

  ({int contextSize, int gpuLayers}) _androidLoadParams(
    int fileSizeMB,
    int requestedContextSize,
  ) {
    // Tool calling requires at least ~2000 context window, so we never shrink below that.
    final safeContextSize = requestedContextSize < 2048 ? 2048 : requestedContextSize;
    
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
    await initialize();
    final modelPath = await _getExistingModelFilePath();
    if (modelPath == null) {
      throw StateError('Model file not found. Download the model first.');
    }

    final model = _selectedModel;
    int contextSize = model.contextSize;
    int gpuLayers = 0;

    if (Platform.isAndroid) {
      final fileSizeBytes = await File(modelPath).length();
      final fileSizeMB = fileSizeBytes ~/ (1024 * 1024);

      final deviceRamMB = await _getDeviceRamMB();
      if (deviceRamMB > 0 && fileSizeMB > deviceRamMB * 0.4) {
        throw StateError(
          'Not enough device memory to load ${model.displayName} '
          '(${fileSizeMB}MB). Your device has ${deviceRamMB}MB RAM. '
          'Choose a smaller model.',
        );
      }

      final params = _androidLoadParams(fileSizeMB, model.contextSize);
      contextSize = params.contextSize;
      gpuLayers = params.gpuLayers;
    }

    if (RunAnywhere.isModelLoaded) {
      await RunAnywhere.unloadModel();
    }

    await RunAnywhere.loadModel(model.id);

    if (!RunAnywhere.isModelLoaded) {
      throw StateError('Failed to load LLM model: ${model.displayName}');
    }

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
          ra_download.DownloadProgressState.failed => DownloadProgressState.failed,
          ra_download.DownloadProgressState.cancelled =>
            DownloadProgressState.failed,
        },
        stage: switch (progress.stage) {
          ra_download.DownloadProgressStage.completed =>
            DownloadProgressStage.completed,
          ra_download.DownloadProgressStage.failed => DownloadProgressStage.failed,
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
    String? sessionId,
  }) {
    final buffer = StringBuffer();
    final currentDate = DateTime.now().toLocal().toString().split(' ')[0];
    final currentTime = DateTime.now()
        .toLocal()
        .toString()
        .split(' ')[1]
        .split('.')
        .first;

    buffer.writeln('Current Date: $currentDate');
    buffer.writeln('Current Time: $currentTime');
    if (sessionId != null) {
      buffer.writeln('Session Context ID: $sessionId');
    }

    // For small models, avoid sending history in tool-calling modes to keep context small and focused.
    final skipHistory = _isCurrentModelSmall && mode != AssistantMode.chat;

    if (history.isNotEmpty && !skipHistory) {
      for (final message in history) {
        buffer.writeln(message.content);
      }
    }

    buffer.writeln(question);
    return buffer.toString();
  }

  String _systemPromptForMode(AssistantMode mode) {
    final isSmallModel = _isCurrentModelSmall;

    switch (mode) {
      case AssistantMode.chat:
        return isSmallModel
            ? 'You are a helpful assistant. Answer briefly.'
            : 'You are a private, helpful assistant. Answer directly.';
      case AssistantMode.vault:
        return isSmallModel
            ? 'Output ONLY a tool call. Do NOT think or talk.'
            : 'You are a vault assistant. Use tools to inspect the user\'s vault and answer only from the results.';
      case AssistantMode.agent:
        return isSmallModel
            ? 'Output ONLY a tool call. Do NOT think or talk.'
            : 'You are a vault agent. Use tools to create or inspect vault items.';
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
    void Function(List<dynamic>)? onCitations,
    List<ChatMessageEntry> history = const [],
    String? sessionId,
  }) async* {
    final stopwatch = Stopwatch()..start();

    try {
      if (!isModelLoaded) {
        await loadModel();
      }

      if (!RunAnywhere.isModelLoaded) {
        yield 'The AI assistant is still starting up or failed to load. Please wait a moment or restart the app.';
        return;
      }

      final systemPrompt = _systemPromptForMode(mode);
      final prompt = _historyToPrompt(
        question,
        _recentHistory(history),
        mode: mode,
        sessionId: sessionId,
      );

      if (mode == AssistantMode.chat) {
        final streamResult = await RunAnywhere.generateStream(
          prompt,
          options: LLMGenerationOptions(
            maxTokens: _selectedModel.parameterCount.contains('0.6B')
                ? 512
                : 768,
            temperature: 0.7,
            systemPrompt: systemPrompt,
            streamingEnabled: true,
          ),
        );

        await for (final token in streamResult.stream) {
          yield token;
        }
        return;
      }

      final tools = _toolsForMode(mode);
      if (tools.isNotEmpty) {
        RunAnywhereTools.clearTools();
        if (mode == AssistantMode.agent) {
          AssistantTools.registerAgentTools(ref);
        } else if (mode == AssistantMode.vault) {
          AssistantTools.registerVaultQueryTools(ref);
        }
      }

      try {
        final toolResult = await RunAnywhereTools.generateWithTools(
          prompt,
          options: ToolCallingOptions(
            tools: tools,
            maxToolCalls: 5,
            temperature: mode == AssistantMode.chat ? 0.7 : 0.1, // Lower temperature for tools
            maxTokens: _isCurrentModelSmall ? 512 : 1024,
            systemPrompt: systemPrompt,
            formatName: 'chatml', // Use chatml format for Qwen models
            keepToolsAvailable: false,
          ),
        );

        // Strip thinking blocks from the final output before yielding to UI
        String cleanText = toolResult.text;
        
        // Comprehensive stripping of <think> blocks
        cleanText = cleanText.replaceAll(RegExp(r'<think>[\s\S]*?<\/think>'), '').trim();
        cleanText = cleanText.replaceAll(RegExp(r'<think>[\s\S]*'), '').trim(); // Strip unclosed tags
        
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

  List<ChatMessageEntry> _recentHistory(
    List<ChatMessageEntry> history, {
    int maxMessages = 20,
  }) {
    if (history.length <= maxMessages) {
      return List.from(history);
    }
    return history.sublist(history.length - maxMessages);
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
