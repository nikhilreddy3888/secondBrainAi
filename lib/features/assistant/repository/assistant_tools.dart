import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:runanywhere/public/runanywhere_tool_calling.dart';
import 'package:runanywhere/public/types/tool_calling_types.dart';
import 'package:uuid/uuid.dart';

import '../../../models/vault_model.dart';
import '../../vault/controller/vault_controller.dart';

class AssistantTools {
  AssistantTools._();

  static List<ToolDefinition> vaultQueryTools() => const [
    ToolDefinition(
      name: 'search_vault',
      description:
          'Search the user\'s vault for notes, passwords, events, and documents.',
      parameters: [
        ToolParameter(
          name: 'query',
          type: ToolParameterType.string,
          description: 'Search keywords or a natural language question.',
        ),
        ToolParameter(
          name: 'item_type',
          type: ToolParameterType.string,
          description:
              'Optional filter: note, password, event, document, or all.',
          required: false,
          enumValues: ['note', 'password', 'event', 'document', 'all'],
        ),
      ],
    ),
    ToolDefinition(
      name: 'get_item_by_id',
      description:
          'Fetch a single vault item by ID and return its full stored details.',
      parameters: [
        ToolParameter(
          name: 'id',
          type: ToolParameterType.string,
          description: 'Exact vault item ID.',
        ),
      ],
    ),
    ToolDefinition(
      name: 'list_vault_items',
      description:
          'List vault items by type or return a compact overview of the vault.',
      parameters: [
        ToolParameter(
          name: 'item_type',
          type: ToolParameterType.string,
          description:
              'Optional filter: note, password, event, document, or all.',
          required: false,
          enumValues: ['note', 'password', 'event', 'document', 'all'],
        ),
      ],
    ),
  ];

  static List<ToolDefinition> agentTools() => const [
    ToolDefinition(
      name: 'create_note',
      description: 'Create a new note in the vault.',
      parameters: [
        ToolParameter(
          name: 'title',
          type: ToolParameterType.string,
          description: 'Title of the note.',
        ),
        ToolParameter(
          name: 'content',
          type: ToolParameterType.string,
          description: 'Body text of the note.',
        ),
      ],
    ),
    ToolDefinition(
      name: 'create_password',
      description: 'Store a password or credential in the vault.',
      parameters: [
        ToolParameter(
          name: 'account_name',
          type: ToolParameterType.string,
          description: 'Service or account name.',
        ),
        ToolParameter(
          name: 'username',
          type: ToolParameterType.string,
          description: 'Username or email.',
        ),
        ToolParameter(
          name: 'password',
          type: ToolParameterType.string,
          description: 'Password value.',
        ),
      ],
    ),
    ToolDefinition(
      name: 'create_event',
      description: 'Create an event in the vault.',
      parameters: [
        ToolParameter(
          name: 'title',
          type: ToolParameterType.string,
          description: 'Event title.',
        ),
        ToolParameter(
          name: 'date',
          type: ToolParameterType.string,
          description: 'Event date in YYYY-MM-DD format.',
        ),
        ToolParameter(
          name: 'time',
          type: ToolParameterType.string,
          description: 'Event time in HH:MM format.',
        ),
        ToolParameter(
          name: 'description',
          type: ToolParameterType.string,
          description: 'Optional event description.',
          required: false,
        ),
      ],
    ),
    ToolDefinition(
      name: 'create_document',
      description: 'Create a text document in the vault.',
      parameters: [
        ToolParameter(
          name: 'title',
          type: ToolParameterType.string,
          description: 'Document title.',
        ),
        ToolParameter(
          name: 'content',
          type: ToolParameterType.string,
          description: 'Document body text.',
        ),
      ],
    ),
  ];

  static void registerVaultQueryTools(Ref ref) {
    _registerTool(vaultQueryTools()[0], (args) => _searchVault(ref, args));
    _registerTool(vaultQueryTools()[1], (args) => _getItemById(ref, args));
    _registerTool(vaultQueryTools()[2], (args) => _listVaultItems(ref, args));
  }

  static void registerAgentTools(Ref ref) {
    _registerTool(agentTools()[0], (args) => _createNote(ref, args));
    _registerTool(agentTools()[1], (args) => _createPassword(ref, args));
    _registerTool(agentTools()[2], (args) => _createEvent(ref, args));
    _registerTool(agentTools()[3], (args) => _createDocument(ref, args));
  }

  static void _registerTool(ToolDefinition definition, ToolExecutor executor) {
    RunAnywhereTools.registerTool(definition, executor);
  }

  static Future<Map<String, ToolValue>> _searchVault(
    Ref ref,
    Map<String, ToolValue> args,
  ) async {
    final vault = await ref.read(vaultControllerProvider.future);
    final query = (args['query']?.stringValue ?? '').trim();
    final requestedType = (args['item_type']?.stringValue ?? 'all')
        .trim()
        .toLowerCase();
    final results = vault.search(query);

    final filtered = results.where((result) {
      if (requestedType == 'all' || requestedType.isEmpty) return true;
      return result.type.toLowerCase() == requestedType;
    }).toList();

    return {
      'count': NumberToolValue(filtered.length.toDouble()),
      'results': ArrayToolValue(
        filtered
            .map((result) => ObjectToolValue(_searchResultToToolValue(result)))
            .toList(),
      ),
    };
  }

  static Future<Map<String, ToolValue>> _getItemById(
    Ref ref,
    Map<String, ToolValue> args,
  ) async {
    final vault = await ref.read(vaultControllerProvider.future);
    final id = (args['id']?.stringValue ?? '').trim();

    final item = _findById(vault, id);
    if (item == null) {
      return {
        'found': const BoolToolValue(false),
        'item': const NullToolValue(),
      };
    }

    return {'found': const BoolToolValue(true), 'item': ObjectToolValue(item)};
  }

  static Future<Map<String, ToolValue>> _listVaultItems(
    Ref ref,
    Map<String, ToolValue> args,
  ) async {
    final vault = await ref.read(vaultControllerProvider.future);
    final requestedType = (args['item_type']?.stringValue ?? 'all')
        .trim()
        .toLowerCase();
    final items = _vaultItems(vault).where((item) {
      if (requestedType == 'all' || requestedType.isEmpty) return true;
      return item['type']?.stringValue?.toLowerCase() == requestedType;
    }).toList();

    return {
      'count': NumberToolValue(items.length.toDouble()),
      'results': ArrayToolValue(
        items.map((item) => ObjectToolValue(item)).toList(),
      ),
    };
  }

  static Future<Map<String, ToolValue>> _createNote(
    Ref ref,
    Map<String, ToolValue> args,
  ) async {
    final title = (args['title']?.stringValue ?? 'Untitled Note').trim();
    final content = (args['content']?.stringValue ?? '').trim();
    final note = VaultNote(
      id: const Uuid().v4(),
      title: title.isEmpty ? 'Untitled Note' : title,
      content: content,
      updatedAt: DateTime.now(),
    );
    await ref.read(vaultControllerProvider.notifier).upsertNote(note);
    return {
      'success': const BoolToolValue(true),
      'item': ObjectToolValue(_noteToMap(note)),
    };
  }

  static Future<Map<String, ToolValue>> _createPassword(
    Ref ref,
    Map<String, ToolValue> args,
  ) async {
    final accountName = (args['account_name']?.stringValue ?? 'Unknown Account')
        .trim();
    final username = (args['username']?.stringValue ?? '').trim();
    final password = (args['password']?.stringValue ?? '').trim();
    final entry = VaultPassword(
      id: const Uuid().v4(),
      accountName: accountName.isEmpty ? 'Unknown Account' : accountName,
      username: username,
      password: password,
    );
    await ref.read(vaultControllerProvider.notifier).upsertPassword(entry);
    return {
      'success': const BoolToolValue(true),
      'item': ObjectToolValue(_passwordToMap(entry)),
    };
  }

  static Future<Map<String, ToolValue>> _createEvent(
    Ref ref,
    Map<String, ToolValue> args,
  ) async {
    final title = (args['title']?.stringValue ?? 'Untitled Event').trim();
    final date = (args['date']?.stringValue ?? '').trim();
    final time = (args['time']?.stringValue ?? '00:00').trim();
    final description = (args['description']?.stringValue ?? '').trim();
    final event = VaultEvent(
      id: const Uuid().v4(),
      title: title.isEmpty ? 'Untitled Event' : title,
      startsAt: DateTime.tryParse('${date}T$time:00') ?? DateTime.now(),
      description: description,
    );
    await ref.read(vaultControllerProvider.notifier).upsertEvent(event);
    return {
      'success': const BoolToolValue(true),
      'item': ObjectToolValue(_eventToMap(event)),
    };
  }

  static Future<Map<String, ToolValue>> _createDocument(
    Ref ref,
    Map<String, ToolValue> args,
  ) async {
    final title = (args['title']?.stringValue ?? 'Untitled Document').trim();
    final content = (args['content']?.stringValue ?? '').trim();
    final document = VaultDocument(
      id: const Uuid().v4(),
      title: title.isEmpty ? 'Untitled Document' : title,
      fileName: '${title.isEmpty ? 'Untitled Document' : title}.txt',
      path: '',
      content: content,
      addedAt: DateTime.now(),
    );
    await ref.read(vaultControllerProvider.notifier).addDocument(document);
    return {
      'success': const BoolToolValue(true),
      'item': ObjectToolValue(_documentToMap(document)),
    };
  }

  static Map<String, ToolValue>? _findById(VaultData vault, String id) {
    for (final item in _vaultItems(vault)) {
      if (item['id']?.stringValue == id) {
        return item;
      }
    }
    return null;
  }

  static List<Map<String, ToolValue>> _vaultItems(VaultData vault) {
    final items = <Map<String, ToolValue>>[];

    for (final note in vault.notes) {
      items.add(_noteToMap(note));
    }
    for (final password in vault.passwords) {
      items.add(_passwordToMap(password));
    }
    for (final event in vault.events) {
      items.add(_eventToMap(event));
    }
    for (final document in vault.documents) {
      items.add(_documentToMap(document));
    }

    return items;
  }

  static Map<String, ToolValue> _searchResultToToolValue(SearchResult result) {
    return {
      'id': StringToolValue(result.id),
      'type': StringToolValue(result.type),
      'title': StringToolValue(result.title),
      'subtitle': StringToolValue(result.subtitle),
      if (result.secret != null) 'secret': StringToolValue(result.secret!),
      'referenceTag': StringToolValue(
        _referenceTag(result.type, result.id, result.title),
      ),
    };
  }

  static Map<String, ToolValue> _noteToMap(VaultNote note) => {
    'id': StringToolValue(note.id),
    'type': StringToolValue('note'),
    'title': StringToolValue(note.title),
    'content': StringToolValue(note.content),
    'updatedAt': StringToolValue(note.updatedAt.toIso8601String()),
    'referenceTag': StringToolValue(_referenceTag('note', note.id, note.title)),
  };

  static Map<String, ToolValue> _passwordToMap(VaultPassword password) => {
    'id': StringToolValue(password.id),
    'type': StringToolValue('password'),
    'title': StringToolValue(password.accountName),
    'accountName': StringToolValue(password.accountName),
    'username': StringToolValue(password.username),
    'password': StringToolValue(password.password),
    'referenceTag': StringToolValue(
      _referenceTag('password', password.id, password.accountName),
    ),
  };

  static Map<String, ToolValue> _eventToMap(VaultEvent event) => {
    'id': StringToolValue(event.id),
    'type': StringToolValue('event'),
    'title': StringToolValue(event.title),
    'startsAt': StringToolValue(event.startsAt.toIso8601String()),
    'description': StringToolValue(event.description),
    'referenceTag': StringToolValue(
      _referenceTag('event', event.id, event.title),
    ),
  };

  static Map<String, ToolValue> _documentToMap(VaultDocument document) => {
    'id': StringToolValue(document.id),
    'type': StringToolValue('document'),
    'title': StringToolValue(document.title),
    'fileName': StringToolValue(document.fileName),
    'content': StringToolValue(document.content),
    'referenceTag': StringToolValue(
      _referenceTag('document', document.id, document.title),
    ),
  };

  static String _referenceTag(String type, String id, String title) {
    return '[[${type.toLowerCase()}:$id|$title]]';
  }
}
