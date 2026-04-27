import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_agent_kit/flutter_local_agent_kit.dart';
import 'package:runanywhere/runanywhere.dart';
import 'package:runanywhere/native/dart_bridge_model_paths.dart';
import 'package:runanywhere/native/dart_bridge.dart';

import '../../vault/controller/vault_controller.dart';
import 'assistant_tools.dart';

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  return AiRepository(ref);
});

class AiRepository {
  AiRepository(this.ref);
  final Ref ref;

  static const modelId = 'qwen2.5-0.5b-instruct-q4';
  static const modelName = 'Qwen 2.5 0.5B (400 MB)';
  static const modelUrl =
      'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf';

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
    return await file.exists() ? file.path : null;
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
      gpuLayers: Platform.isAndroid || Platform.isIOS ? 32 : 0,
      customTools: [
        CreateNoteTool(ref),
        CreatePasswordTool(ref),
        ScheduleEventTool(ref),
        CreateDocumentTool(ref),
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

      final totalBytes = response.contentLength > 0 ? response.contentLength : 0;
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
    lines.add('CURRENT DATE AND TIME: ${DateTime.now().toString().split('.')[0]}\n');

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
      lines.add('- Event "${e.title}" scheduled for $dateStr: ${e.description}');
    }
    for (final d in vault.documents) {
      lines.add('- Document "${d.title}": ${d.content}');
    }

    return lines.isNotEmpty ? lines.join('\n') : 'The vault is currently empty.';
  }

  /// Entry point for AgentChatView. Routes based on [AssistantMode].
  Stream<String> askStream(String question, {
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
        yield* _kit.askStream(question);

      case AssistantMode.vault:
        // RAG — vault context injected, no tools
        final context = await _buildVaultContext();
        final prompt =
            'You are a helpful vault assistant. NEVER generate code.\n\n'
            'VAULT DATA:\n$context\n\n'
            'Question: $question\n\n'
            'Answer briefly and directly:';
        yield* _kit.askStream(prompt, onCitations: onCitations);

      case AssistantMode.agent:
        // Agent — ReAct loop with tools + vault context
        final context = await _buildVaultContext();
        final systemPrompt =
            'You are a private vault assistant.\n\n'
            'VAULT DATA:\n$context\n\n'
            'CRITICAL INSTRUCTIONS:\n'
            '1. To perform ANY action, you MUST use the exact format:\n'
            '   Thought: I need to [action]\n'
            '   Action: [tool_name]\n'
            '   Action Input: {"arg1": "value1"}\n'
            '2. DO NOT use python function syntax like tool(args).\n'
            '3. DO NOT use markdown code blocks like ```json.\n'
            '4. NEVER say you have done something (e.g. "I created...") until you see an "Observation: Successfully created..." message.\n'
            '5. Once you see the success Observation, use "Final Answer:" to tell the user it is done.\n'
            '6. If you do not use the "Action:" format, no tool will be called and nothing will happen.';
        yield* _kit.runAgent(question, systemPrompt: systemPrompt);
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
