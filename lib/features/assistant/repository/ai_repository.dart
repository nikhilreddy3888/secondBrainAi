import 'dart:io';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:runanywhere/runanywhere.dart';
import 'package:runanywhere_llamacpp/runanywhere_llamacpp.dart';
import 'package:runanywhere/native/dart_bridge_model_paths.dart';
import 'package:runanywhere/native/dart_bridge.dart';

import 'package:uuid/uuid.dart';

import '../../../models/vault_model.dart';
import '../../vault/controller/vault_controller.dart';
import 'rag_engine.dart';

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  return AiRepository(ref);
});

class AiCitation {
  const AiCitation({
    required this.label,
    required this.sourceId,
    required this.sourceType,
    required this.title,
    required this.excerpt,
    required this.score,
  });

  final String label;
  final String sourceId;
  final String sourceType;
  final String title;
  final String excerpt;
  final double score;
}

class AiRepository {
  AiRepository(this.ref);
  final Ref ref;

  static const modelId = 'qwen2.5-0.5b-instruct-q4';
  static const modelName = 'Qwen 2.5 0.5B (400 MB)';
  static const modelUrl =
      'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf';

  final VaultRagEngine _ragEngine = VaultRagEngine();
  List<AiCitation> _lastCitations = const [];
  bool _initialized = false;
  bool _registered = false;
  bool _isAndroidBackendRegistered = false;

  List<AiCitation> get lastCitations => _lastCitations;

  void clearCitations() {
    _lastCitations = const [];
  }

  /// Initialize the SDK without triggering the native model registry save
  /// that causes SIGSEGV on Android. On Android we use DartBridge.initialize()
  /// directly (matching flutterconnectllm pattern) and defer LlamaCpp.register()
  /// until loadModel() time.
  Future<void> initialize() async {
    if (_initialized) return;

    if (Platform.isAndroid) {
      // Android-safe init: skip RunAnywhere.initialize() which calls
      // LlamaCpp.addModel() -> _saveToCppRegistry() -> native SIGSEGV.
      DartBridge.initialize(SDKEnvironment.development);
      await DartBridge.modelPaths.setBaseDirectory();
    } else {
      await RunAnywhere.initialize(environment: SDKEnvironment.development);
      await LlamaCpp.register();
    }

    if (!_registered) {
      _registerTools();
      _registered = true;
    }

    _initialized = true;
  }

  /// Register LlamaCpp backend on Android only when needed (deferred).
  Future<void> _ensureAndroidBackendRegistered() async {
    if (!Platform.isAndroid || _isAndroidBackendRegistered) return;
    await LlamaCpp.register();
    _isAndroidBackendRegistered = true;
  }

  bool _isLoaded = false;

  bool get isModelLoaded => _isLoaded;

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

  Future<void> loadModel() async {
    await initialize();
    await _ensureAndroidBackendRegistered();

    final modelPath = await _getExistingModelFilePath();
    if (modelPath == null) {
      throw StateError('Model file not found. Download the model first.');
    }

    if (DartBridge.llm.isLoaded) {
      DartBridge.llm.unload();
    }

    await DartBridge.llm.loadModel(
      modelPath,
      modelId,
      modelName,
    );
    
    _isLoaded = DartBridge.llm.isLoaded;
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

  /// The main entry point for the AI Assistant. Uses the on-device LLM
  /// with tool calling to handle ALL commands: search, create note,
  /// create password, schedule event, and create document.
  Future<String> answer({
    required VaultData vault,
    required String question,
  }) async {
    await initialize();
    await _ensureAndroidBackendRegistered();

    if (!isModelLoaded) {
      throw StateError('AI model is not loaded.');
    }

    clearCitations();

    // Build RAG context so the LLM has vault data for search queries
    final ragResults = _ragEngine.retrieve(vault, question, topK: 5);
    String ragContext = '';
    if (ragResults.isNotEmpty) {
      _lastCitations = ragResults
          .map((r) => AiCitation(
                label: 'S',
                sourceId: r.sourceId,
                sourceType: r.sourceType,
                title: r.title,
                excerpt: r.text,
                score: r.score,
              ))
          .toList();
      final contextLines = ragResults
          .map((r) =>
              '[${r.sourceType}: ${r.title}] ${_truncate(r.text, max: 250)}')
          .join('\n');
      ragContext = '\n\nVault data matching the query:\n$contextLines';
    }

    // Build the tool-calling system prompt
    final prompt = '''You are a helpful AI assistant for a private, encrypted vault app running on-device.
You can perform actions using tools. To call a tool, respond with ONLY a JSON object like:
{"tool": "tool_name", "args": {"param1": "value1", "param2": "value2"}}

Available tools:
1. search_documents(query) - Search the vault for notes, passwords, events, documents.
2. list_items(type) - List saved items. type must be one of: notes, passwords, events, documents.
3. create_note(title, content) - Create a new note.
4. create_password(account_name, username, password) - Save a new password.
5. schedule_event(title, date, time, description) - Schedule a new event. Date format: YYYY-MM-DD, Time format: HH:MM.
6. create_document(title, content) - Create a new document.

If the user asks a question and vault data is provided below, answer using that data directly.
If the user asks to show/list/count/check whether they have notes, passwords, events, or documents, use list_items.
If the user asks to create/add something, use the appropriate tool.
Be concise.$ragContext

User: $question
Assistant:''';

    if (Platform.isAndroid) {
      return _generateWithToolsOnAndroid(prompt, vault);
    }

    // Non-Android: use RunAnywhereTools
    final result = await RunAnywhereTools.generateWithTools(
      prompt,
      options: ToolCallingOptions(
        autoExecute: true,
        maxTokens: 400,
        temperature: 0.2,
      ),
    );

    final response = result.text.trim();
    if (response.isEmpty) {
      return 'I could not generate a response.';
    }
    return response;
  }

  /// Android LLM generation with tool-calling support.
  /// Generates a response, detects tool call JSON, executes the tool,
  /// and returns a user-friendly result.
  Future<String> _generateWithToolsOnAndroid(
      String prompt, VaultData vault) async {
    final buffer = StringBuffer();
    final tokenStream = DartBridge.llm.generateStream(
      prompt,
      maxTokens: 400,
      temperature: 0.2,
    );

    await for (final token in tokenStream) {
      buffer.write(token);
    }

    final rawResponse = buffer.toString().trim();
    if (rawResponse.isEmpty) {
      return 'I could not generate a response.';
    }

    // Try to parse a tool call from the LLM output
    final toolCall = _parseToolCall(rawResponse);
    if (toolCall != null) {
      return _executeToolCall(toolCall, vault);
    }

    // No tool call detected. Return the LLM's natural language response.
    return rawResponse;
  }

  /// Parse a JSON tool call from LLM output.
  /// Expects format: {"tool": "name", "args": {...}}
  Map<String, dynamic>? _parseToolCall(String text) {
    try {
      // Find JSON object in the response
      final jsonStart = text.indexOf('{');
      final jsonEnd = text.lastIndexOf('}');
      if (jsonStart == -1 || jsonEnd == -1 || jsonEnd <= jsonStart) return null;

      final jsonStr = text.substring(jsonStart, jsonEnd + 1);
      final parsed = Map<String, dynamic>.from(
        jsonDecode(jsonStr) as Map,
      );

      if (parsed.containsKey('tool')) {
        return parsed;
      }
    } catch (_) {
      // Not valid JSON — LLM gave a natural language response
    }
    return null;
  }

  /// Execute a parsed tool call against the vault and return a result string.
  Future<String> _executeToolCall(
      Map<String, dynamic> toolCall, VaultData vault) async {
    final toolName = toolCall['tool'] as String? ?? '';
    final args = toolCall['args'] as Map<String, dynamic>? ?? {};

    switch (toolName) {
      case 'search_documents':
        final query = args['query']?.toString() ?? '';
        final results = _ragEngine.retrieve(vault, query, topK: 3);
        if (results.isEmpty) return 'No matching data found in your vault.';
        _lastCitations = results
            .map((r) => AiCitation(
                  label: 'S',
                  sourceId: r.sourceId,
                  sourceType: r.sourceType,
                  title: r.title,
                  excerpt: r.text,
                  score: r.score,
                ))
            .toList();
        return results
            .map((r) => '${r.sourceType}: ${r.title}\n${_truncate(r.text)}')
            .join('\n\n');

      case 'list_items':
      case 'list_notes':
      case 'show_notes':
      case 'list_passwords':
      case 'list_events':
      case 'list_documents':
        final requestedType = args['type']?.toString().toLowerCase() ??
            _typeFromAlias(toolName);
        return _listItems(vault, requestedType);

      case 'create_note':
        final title = args['title']?.toString() ?? 'Untitled Note';
        final content = args['content']?.toString() ?? '';
        final newNote = VaultNote(
          id: const Uuid().v4(),
          title: title,
          content: content,
          updatedAt: DateTime.now(),
        );
        final updated = vault.copyWith(notes: [...vault.notes, newNote]);
        await ref
            .read(vaultControllerProvider.notifier)
            .replaceVault(updated);
        return 'Created note "$title".';

      case 'create_password':
        final account = args['account_name']?.toString() ?? 'Unknown';
        final username = args['username']?.toString() ?? '';
        final password = args['password']?.toString() ?? '';
        final newPw = VaultPassword(
          id: const Uuid().v4(),
          accountName: account,
          username: username,
          password: password,
        );
        final updated =
            vault.copyWith(passwords: [...vault.passwords, newPw]);
        await ref
            .read(vaultControllerProvider.notifier)
            .replaceVault(updated);
        return 'Saved password for "$account".';

      case 'schedule_event':
      case 'create_event':
        final title = args['title']?.toString() ?? 'Untitled Event';
        final date = args['date']?.toString() ?? '';
        final time = args['time']?.toString() ?? '00:00';
        final desc = args['description']?.toString() ?? '';
        final dateTime =
            DateTime.tryParse('${date}T$time:00') ?? DateTime.now();
        final newEvent = VaultEvent(
          id: const Uuid().v4(),
          title: title,
          startsAt: dateTime,
          description: desc,
        );
        final updated = vault.copyWith(events: [...vault.events, newEvent]);
        await ref
            .read(vaultControllerProvider.notifier)
            .replaceVault(updated);
        return 'Scheduled event "$title" for $date at $time.';

      case 'create_document':
        final title = args['title']?.toString() ?? 'Untitled Document';
        final content = args['content']?.toString() ?? '';
        final newDoc = VaultDocument(
          id: const Uuid().v4(),
          title: title,
          fileName: '$title.txt',
          path: '',
          content: content,
          addedAt: DateTime.now(),
        );
        final updated =
            vault.copyWith(documents: [...vault.documents, newDoc]);
        await ref
            .read(vaultControllerProvider.notifier)
            .replaceVault(updated);
        return 'Created document "$title".';

      default:
        return rawResponse(toolCall);
    }
  }

  String rawResponse(Map<String, dynamic> toolCall) {
    return 'Unknown tool: ${toolCall['tool']}';
  }

  String _typeFromAlias(String toolName) {
    if (toolName.contains('note')) return 'notes';
    if (toolName.contains('password')) return 'passwords';
    if (toolName.contains('event')) return 'events';
    if (toolName.contains('document')) return 'documents';
    return 'all';
  }

  String _listItems(VaultData vault, String requestedType) {
    switch (requestedType) {
      case 'note':
      case 'notes':
        if (vault.notes.isEmpty) return 'You do not have any notes yet.';
        return 'You have ${vault.notes.length} note(s):\n${vault.notes.map((note) => 'Note: ${note.title} - ${_truncate(note.content)}').join('\n')}';
      case 'password':
      case 'passwords':
      case 'credentials':
        if (vault.passwords.isEmpty) {
          return 'You do not have any passwords yet.';
        }
        return 'You have ${vault.passwords.length} password item(s):\n${vault.passwords.map((item) => 'Password: ${item.accountName} - ${item.username}').join('\n')}';
      case 'event':
      case 'events':
        if (vault.events.isEmpty) return 'You do not have any events yet.';
        final events = [...vault.events]
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
        return 'You have ${events.length} event(s):\n${events.map((event) => 'Event: ${event.title} - ${event.startsAt} ${_truncate(event.description)}').join('\n')}';
      case 'document':
      case 'documents':
      case 'files':
        if (vault.documents.isEmpty) {
          return 'You do not have any documents yet.';
        }
        return 'You have ${vault.documents.length} document(s):\n${vault.documents.map((doc) => 'Document: ${doc.title} - ${doc.fileName}').join('\n')}';
      default:
        final total = vault.notes.length +
            vault.passwords.length +
            vault.events.length +
            vault.documents.length;
        return 'You have $total saved item(s): ${vault.notes.length} notes, ${vault.passwords.length} passwords, ${vault.events.length} events, and ${vault.documents.length} documents.';
    }
  }

  void _registerTools() {
    // 1. Search Documents
    RunAnywhereTools.registerTool(
      ToolDefinition(
        name: 'search_documents',
        description: 'Search the encrypted vault for notes, passwords, events, or documents matching a query.',
        parameters: [
          ToolParameter(
            name: 'query',
            type: ToolParameterType.string,
            description: 'The search query to look for in the vault.',
          ),
        ],
      ),
      (args) async {
        final query = args['query']?.stringValue ?? '';
        final vault = await ref.read(vaultControllerProvider.future);
        final results = _ragEngine.retrieve(vault, query, topK: 3);
        
        if (results.isEmpty) {
          return {'result': ToolValue.from('No matching data found.')};
        }

        final lines = <String>[];
        for (var i = 0; i < results.length; i++) {
          final chunk = results[i];
          lines.add('[Source: ${chunk.sourceType} - ${chunk.title}] ${_truncate(chunk.text)}');
        }

        _lastCitations = results.map((r) => AiCitation(
          label: 'S',
          sourceId: r.sourceId,
          sourceType: r.sourceType,
          title: r.title,
          excerpt: r.text,
          score: r.score,
        )).toList();

        return {'result': ToolValue.from(lines.join('\n\n'))};
      },
    );

    // 2. List Items
    RunAnywhereTools.registerTool(
      ToolDefinition(
        name: 'list_items',
        description:
            'List saved notes, passwords, events, or documents from the encrypted vault.',
        parameters: [
          ToolParameter(
            name: 'type',
            type: ToolParameterType.string,
            description:
                'The item type to list: notes, passwords, events, or documents.',
          ),
        ],
      ),
      (args) async {
        final type = args['type']?.stringValue ?? 'all';
        final vault = await ref.read(vaultControllerProvider.future);
        return {'result': ToolValue.from(_listItems(vault, type))};
      },
    );

    // 3. Create Note
    RunAnywhereTools.registerTool(
      ToolDefinition(
        name: 'create_note',
        description: 'Create a new note in the encrypted vault.',
        parameters: [
          ToolParameter(
            name: 'title',
            type: ToolParameterType.string,
            description: 'The title of the note.',
          ),
          ToolParameter(
            name: 'content',
            type: ToolParameterType.string,
            description: 'The content or body of the note.',
          ),
        ],
      ),
      (args) async {
        final title = args['title']?.stringValue ?? 'Untitled Note';
        final content = args['content']?.stringValue ?? '';
        
        final vault = await ref.read(vaultControllerProvider.future);
        final newNote = VaultNote(
          id: const Uuid().v4(),
          title: title,
          content: content,
          updatedAt: DateTime.now(),
        );

        final updatedVault = vault.copyWith(notes: [...vault.notes, newNote]);
        await ref.read(vaultControllerProvider.notifier).replaceVault(updatedVault);
        
        return {'status': ToolValue.from('success'), 'message': ToolValue.from('Note "$title" created.')};
      },
    );

    // 3. Schedule Event
    RunAnywhereTools.registerTool(
      ToolDefinition(
        name: 'schedule_event',
        description: 'Schedule a new calendar event in the encrypted vault.',
        parameters: [
          ToolParameter(
            name: 'title',
            type: ToolParameterType.string,
            description: 'The title of the event.',
          ),
          ToolParameter(
            name: 'date',
            type: ToolParameterType.string,
            description: 'The event date in YYYY-MM-DD format.',
          ),
          ToolParameter(
            name: 'time',
            type: ToolParameterType.string,
            description: 'The event time in HH:MM format.',
          ),
          ToolParameter(
            name: 'description',
            type: ToolParameterType.string,
            description: 'Optional description of the event.',
            required: false,
          ),
        ],
      ),
      (args) async {
        final title = args['title']?.stringValue ?? 'Untitled Event';
        final date = args['date']?.stringValue ?? '';
        final time = args['time']?.stringValue ?? '00:00';
        final desc = args['description']?.stringValue ?? '';
        
        final vault = await ref.read(vaultControllerProvider.future);
        final newEvent = VaultEvent(
          id: const Uuid().v4(),
          title: title,
          startsAt: DateTime.tryParse('${date}T$time:00') ?? DateTime.now(),
          description: desc,
        );

        final updatedVault = vault.copyWith(events: [...vault.events, newEvent]);
        await ref.read(vaultControllerProvider.notifier).replaceVault(updatedVault);
        
        return {'status': ToolValue.from('success'), 'message': ToolValue.from('Event "$title" scheduled.')};
      },
    );

    // 4. Save Password
    RunAnywhereTools.registerTool(
      ToolDefinition(
        name: 'create_password',
        description: 'Save a new password or credential to the encrypted vault.',
        parameters: [
          ToolParameter(
            name: 'account_name',
            type: ToolParameterType.string,
            description: 'The website, service, or account name (e.g., Facebook, Google).',
          ),
          ToolParameter(
            name: 'username',
            type: ToolParameterType.string,
            description: 'The username or email for the account.',
          ),
          ToolParameter(
            name: 'password',
            type: ToolParameterType.string,
            description: 'The password for the account.',
          ),
        ],
      ),
      (args) async {
        final account = args['account_name']?.stringValue ?? 'Unknown Account';
        final user = args['username']?.stringValue ?? '';
        final pass = args['password']?.stringValue ?? '';
        
        final vault = await ref.read(vaultControllerProvider.future);
        final newPw = VaultPassword(
          id: const Uuid().v4(),
          accountName: account,
          username: user,
          password: pass,
        );

        final updatedVault = vault.copyWith(passwords: [...vault.passwords, newPw]);
        await ref.read(vaultControllerProvider.notifier).replaceVault(updatedVault);
        
        return {'status': ToolValue.from('success'), 'message': ToolValue.from('Password for "$account" saved securely.')};
      },
    );

    // 5. Create Document
    RunAnywhereTools.registerTool(
      ToolDefinition(
        name: 'create_document',
        description: 'Create a new text document in the encrypted vault.',
        parameters: [
          ToolParameter(
            name: 'title',
            type: ToolParameterType.string,
            description: 'The title of the document.',
          ),
          ToolParameter(
            name: 'content',
            type: ToolParameterType.string,
            description: 'The content or body of the document.',
          ),
        ],
      ),
      (args) async {
        final title = args['title']?.stringValue ?? 'Untitled Document';
        final content = args['content']?.stringValue ?? '';

        final vault = await ref.read(vaultControllerProvider.future);
        final newDoc = VaultDocument(
          id: const Uuid().v4(),
          title: title,
          fileName: '$title.txt',
          path: '',
          content: content,
          addedAt: DateTime.now(),
        );

        final updatedVault =
            vault.copyWith(documents: [...vault.documents, newDoc]);
        await ref
            .read(vaultControllerProvider.notifier)
            .replaceVault(updatedVault);

        return {
          'status': ToolValue.from('success'),
          'message': ToolValue.from('Document "$title" created.'),
        };
      },
    );
  }

  String _truncate(String text, {int max = 180}) {
    final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length <= max) return clean;
    return '${clean.substring(0, max - 3)}...';
  }
}
