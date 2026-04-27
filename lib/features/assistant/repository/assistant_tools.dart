import 'package:flutter_local_agent_kit/flutter_local_agent_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../models/vault_model.dart';
import '../../vault/controller/vault_controller.dart';

class AgentToolTurnLimiter {
  int _maxCreateActions = 1;
  int _createActionsUsed = 0;
  Set<String>? _allowedCreateTools;

  void beginTurn({int maxCreateActions = 1, Set<String>? allowedCreateTools}) {
    _maxCreateActions = maxCreateActions;
    _createActionsUsed = 0;
    _allowedCreateTools = allowedCreateTools;
  }

  bool tryConsumeCreateAction(String toolName) {
    final allowed = _allowedCreateTools;
    if (allowed != null && !allowed.contains(toolName)) {
      return false;
    }
    if (_createActionsUsed >= _maxCreateActions) {
      return false;
    }
    _createActionsUsed += 1;
    return true;
  }

  void endTurn() {
    _createActionsUsed = 0;
    _allowedCreateTools = null;
  }
}

class CreateNoteTool extends BaseTool {
  CreateNoteTool(this.ref, this.turnLimiter)
      : super(
          name: 'create_note',
          description: 'Create a new text note in the encrypted vault.',
          parameterSchema: {
            'title': 'The title of the note.',
            'content': 'The content or body of the note.',
          },
        );

  final Ref ref;
  final AgentToolTurnLimiter turnLimiter;

  @override
  Future<String> call(Map<String, dynamic> arguments) async {
    if (!turnLimiter.tryConsumeCreateAction(name)) {
      return 'Failed to create note. This request only allows a different action, or the create-action limit was reached.';
    }

    final title = arguments['title']?.toString() ?? 'Untitled Note';
    final content = arguments['content']?.toString() ?? '';

    final newNote = VaultNote(
      id: const Uuid().v4(),
      title: title,
      content: content,
      updatedAt: DateTime.now(),
    );

    try {
      print('CreateNoteTool: Creating note "$title"');
      await ref.read(vaultControllerProvider.notifier).upsertNote(newNote);
      final vault = await ref.read(vaultControllerProvider.future);
      final created = vault.notes.any((n) => n.id == newNote.id);
      if (!created) {
        return 'Failed to create note "$title". Vault write could not be verified.';
      }
      return 'Successfully created note: "$title" (id: ${newNote.id})';
    } catch (e) {
      return 'Failed to create note "$title". Error: $e';
    }
  }
}

class CreatePasswordTool extends BaseTool {
  CreatePasswordTool(this.ref, this.turnLimiter)
      : super(
          name: 'create_password',
          description:
              'Save a new password or credential to the encrypted vault.',
          parameterSchema: {
            'account_name': 'The service or account name (e.g., Facebook).',
            'username': 'The username or email for the account.',
            'password': 'The password for the account.',
          },
        );

  final Ref ref;
  final AgentToolTurnLimiter turnLimiter;

  @override
  Future<String> call(Map<String, dynamic> arguments) async {
    if (!turnLimiter.tryConsumeCreateAction(name)) {
      return 'Failed to save password. This request only allows a different action, or the create-action limit was reached.';
    }

    final account = arguments['account_name']?.toString() ?? 'Unknown Account';
    final user = arguments['username']?.toString() ?? '';
    final pass = arguments['password']?.toString() ?? '';

    final newPw = VaultPassword(
      id: const Uuid().v4(),
      accountName: account,
      username: user,
      password: pass,
    );

    try {
      print('CreatePasswordTool: Saving password for "$account"');
      await ref.read(vaultControllerProvider.notifier).upsertPassword(newPw);
      final vault = await ref.read(vaultControllerProvider.future);
      final created = vault.passwords.any((p) => p.id == newPw.id);
      if (!created) {
        return 'Failed to save password for "$account". Vault write could not be verified.';
      }
      return 'Successfully saved password for "$account" (id: ${newPw.id})';
    } catch (e) {
      return 'Failed to save password for "$account". Error: $e';
    }
  }
}

class ScheduleEventTool extends BaseTool {
  ScheduleEventTool(this.ref, this.turnLimiter)
      : super(
          name: 'create_event',
          description: 'Create/schedule a new calendar event in the encrypted vault.',
          parameterSchema: {
            'title': 'The title of the event.',
            'date': 'The event date in YYYY-MM-DD format.',
            'time': 'The event time in HH:MM format.',
            'description': 'Optional description of the event.',
          },
        );

  final Ref ref;
  final AgentToolTurnLimiter turnLimiter;

  @override
  Future<String> call(Map<String, dynamic> arguments) async {
    if (!turnLimiter.tryConsumeCreateAction(name)) {
      return 'Failed to schedule event. This request only allows a different action, or the create-action limit was reached.';
    }

    final title = arguments['title']?.toString() ?? 'Untitled Event';
    final date = arguments['date']?.toString() ?? '';
    final time = arguments['time']?.toString() ?? '00:00';
    final desc = arguments['description']?.toString() ?? '';

    final newEvent = VaultEvent(
      id: const Uuid().v4(),
      title: title,
      startsAt: DateTime.tryParse('${date}T$time:00') ?? DateTime.now(),
      description: desc,
    );

    try {
      print('ScheduleEventTool: Scheduling event "$title" on $date at $time');
      await ref.read(vaultControllerProvider.notifier).upsertEvent(newEvent);
      final vault = await ref.read(vaultControllerProvider.future);
      final created = vault.events.any((e) => e.id == newEvent.id);
      if (!created) {
        return 'Failed to schedule event "$title". Vault write could not be verified.';
      }
      return 'Successfully scheduled event "$title" for $date at $time (id: ${newEvent.id})';
    } catch (e) {
      return 'Failed to schedule event "$title". Error: $e';
    }
  }
}

class CreateDocumentTool extends BaseTool {
  CreateDocumentTool(this.ref, this.turnLimiter)
      : super(
          name: 'create_document',
          description: 'Create a new text document in the encrypted vault.',
          parameterSchema: {
            'title': 'The title of the document.',
            'content': 'The content or body of the document.',
          },
        );

  final Ref ref;
  final AgentToolTurnLimiter turnLimiter;

  @override
  Future<String> call(Map<String, dynamic> arguments) async {
    if (!turnLimiter.tryConsumeCreateAction(name)) {
      return 'Failed to create document. This request only allows a different action, or the create-action limit was reached.';
    }

    final title = arguments['title']?.toString() ?? 'Untitled Document';
    final content = arguments['content']?.toString() ?? '';

    final newDoc = VaultDocument(
      id: const Uuid().v4(),
      title: title,
      fileName: '$title.txt',
      path: '',
      content: content,
      addedAt: DateTime.now(),
    );

    try {
      print('CreateDocumentTool: Creating document "$title"');
      await ref.read(vaultControllerProvider.notifier).addDocument(newDoc);
      final vault = await ref.read(vaultControllerProvider.future);
      final created = vault.documents.any((d) => d.id == newDoc.id);
      if (!created) {
        return 'Failed to create document "$title". Vault write could not be verified.';
      }
      return 'Successfully created document: "$title" (id: ${newDoc.id})';
    } catch (e) {
      return 'Failed to create document "$title". Error: $e';
    }
  }
}
