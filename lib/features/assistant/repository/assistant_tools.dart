import 'package:flutter_local_agent_kit/flutter_local_agent_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../models/vault_model.dart';
import '../../vault/controller/vault_controller.dart';

class CreateNoteTool extends BaseTool {
  CreateNoteTool(this.ref)
      : super(
          name: 'create_note',
          description: 'Create a new text note in the encrypted vault.',
          parameterSchema: {
            'title': 'The title of the note.',
            'content': 'The content or body of the note.',
          },
        );

  final Ref ref;

  @override
  Future<String> call(Map<String, dynamic> arguments) async {
    final title = arguments['title']?.toString() ?? 'Untitled Note';
    final content = arguments['content']?.toString() ?? '';

    final newNote = VaultNote(
      id: const Uuid().v4(),
      title: title,
      content: content,
      updatedAt: DateTime.now(),
    );

    print('CreateNoteTool: Creating note "$title"');
    await ref.read(vaultControllerProvider.notifier).upsertNote(newNote);

    return 'Successfully created note: "$title"';
  }
}

class CreatePasswordTool extends BaseTool {
  CreatePasswordTool(this.ref)
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

  @override
  Future<String> call(Map<String, dynamic> arguments) async {
    final account = arguments['account_name']?.toString() ?? 'Unknown Account';
    final user = arguments['username']?.toString() ?? '';
    final pass = arguments['password']?.toString() ?? '';

    final newPw = VaultPassword(
      id: const Uuid().v4(),
      accountName: account,
      username: user,
      password: pass,
    );

    print('CreatePasswordTool: Saving password for "$account"');
    await ref.read(vaultControllerProvider.notifier).upsertPassword(newPw);

    return 'Successfully saved password for "$account"';
  }
}

class ScheduleEventTool extends BaseTool {
  ScheduleEventTool(this.ref)
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

  @override
  Future<String> call(Map<String, dynamic> arguments) async {
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

    print('ScheduleEventTool: Scheduling event "$title" on $date at $time');
    await ref.read(vaultControllerProvider.notifier).upsertEvent(newEvent);

    return 'Successfully scheduled event "$title" for $date at $time';
  }
}

class CreateDocumentTool extends BaseTool {
  CreateDocumentTool(this.ref)
      : super(
          name: 'create_document',
          description: 'Create a new text document in the encrypted vault.',
          parameterSchema: {
            'title': 'The title of the document.',
            'content': 'The content or body of the document.',
          },
        );

  final Ref ref;

  @override
  Future<String> call(Map<String, dynamic> arguments) async {
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

    print('CreateDocumentTool: Creating document "$title"');
    await ref.read(vaultControllerProvider.notifier).addDocument(newDoc);

    return 'Successfully created document: "$title"';
  }
}
