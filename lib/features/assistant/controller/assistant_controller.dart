import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../models/vault_model.dart';
import '../repository/ai_repository.dart';
import 'ai_runtime_controller.dart';
import '../../vault/controller/vault_controller.dart';

final assistantControllerProvider = Provider<AssistantController>((ref) {
  return AssistantController(ref);
});

const _uuid = Uuid();

class AssistantController {
  AssistantController(this.ref);

  final Ref ref;

  Future<String> handle(String prompt) async {
    final vault = await ref.read(vaultControllerProvider.future);
    final result = AssistantEngine(vault).handle(prompt);
    if (result.vault != null) {
      await ref
          .read(vaultControllerProvider.notifier)
          .replaceVault(result.vault!);
    }
    if (result.handledLocally) {
      ref.read(aiRepositoryProvider).clearCitations();
      return result.message;
    }

    final aiState = ref.read(aiRuntimeControllerProvider);
    if (aiState.modelLoaded) {
      try {
        final answer = await ref
            .read(aiRepositoryProvider)
            .answer(vault: vault, question: prompt);
        if (answer.trim().isNotEmpty) {
          return answer;
        }
      } catch (_) {
        // Fall back to deterministic local result if on-device AI fails.
      }
    }

    ref.read(aiRepositoryProvider).clearCitations();
    return result.message;
  }
}

class AssistantEngine {
  AssistantEngine(this.vault);

  final VaultData vault;

  AssistantResponse handle(String prompt) {
    final lower = prompt.toLowerCase().trim();

    // --- ADD NOTE ---
    if (_matchesCommand(lower, [
      'add a new note',
      'add note',
      'create a note',
      'create note',
      'new note',
    ])) {
      final title =
          _extractField(prompt, 'title') ??
          _extractAfterCommand(
            prompt,
            [
              'add a new note',
              'add note',
              'create a note',
              'create note',
              'new note',
            ],
            stopAt: ['content', 'body', 'with content'],
          );
      final content =
          _extractField(prompt, 'content') ??
          _extractField(prompt, 'body') ??
          '';
      if (title != null && title.isNotEmpty) {
        return AssistantResponse(
          message: '✅ Added note "$title".',
          vault: vault.copyWith(
            notes: [
              ...vault.notes,
              VaultNote(
                id: _uuid.v4(),
                title: title,
                content: content,
                updatedAt: DateTime.now(),
              ),
            ],
          ),
        );
      }
      return const AssistantResponse(
        message:
            'Please specify a title. Example:\n"Add note title \'Meeting\' content \'Discussed timeline\'"',
      );
    }

    // --- ADD PASSWORD ---
    if (_matchesCommand(lower, [
      'add a new password',
      'add password',
      'create a password',
      'create password',
      'new password',
      'save password',
    ])) {
      final accountName =
          _extractField(prompt, 'account name') ??
          _extractField(prompt, 'account') ??
          _extractField(prompt, 'for');
      final username =
          _extractField(prompt, 'username') ?? _extractField(prompt, 'user');
      final password =
          _extractField(prompt, 'password') ?? _extractField(prompt, 'pass');
      if (accountName != null && username != null && password != null) {
        return AssistantResponse(
          message: '✅ Added password for "$accountName".',
          vault: vault.copyWith(
            passwords: [
              ...vault.passwords,
              VaultPassword(
                id: _uuid.v4(),
                accountName: accountName,
                username: username,
                password: password,
              ),
            ],
          ),
        );
      }
      return const AssistantResponse(
        message:
            'Please specify account, username, and password. Example:\n"Add password account \'Facebook\' username \'john\' password \'secret123\'"',
      );
    }

    // --- ADD EVENT ---
    if (_matchesCommand(lower, [
      'add a new event',
      'add event',
      'create a event',
      'create event',
      'new event',
      'schedule',
    ])) {
      final title =
          _extractField(prompt, 'title') ??
          _extractAfterCommand(
            prompt,
            [
              'add a new event',
              'add event',
              'create a event',
              'create event',
              'new event',
              'schedule',
            ],
            stopAt: ['date', 'time', 'on', 'at', 'description'],
          );
      final date = _extractField(prompt, 'date') ?? _extractField(prompt, 'on');
      final time = _extractField(prompt, 'time') ?? _extractField(prompt, 'at');
      final description =
          _extractField(prompt, 'description') ??
          _extractField(prompt, 'details') ??
          '';
      final startsAt = _parseDateTime(date, time);
      if (title != null && title.isNotEmpty && startsAt != null) {
        return AssistantResponse(
          message: '✅ Added event "$title".',
          vault: vault.copyWith(
            events: [
              ...vault.events,
              VaultEvent(
                id: _uuid.v4(),
                title: title,
                startsAt: startsAt,
                description: description,
              ),
            ],
          ),
        );
      }
      return const AssistantResponse(
        message:
            'Please specify title and date. Example:\n"Add event title \'Meeting\' date \'2025-01-15\' time \'10:00\'"',
      );
    }

    // --- ADD DOCUMENT ---
    if (_matchesCommand(lower, [
      'add a new document',
      'add document',
      'create a document',
      'create document',
      'new document',
      'save document',
    ])) {
      final title =
          _extractField(prompt, 'title') ??
          _extractAfterCommand(
            prompt,
            [
              'add a new document',
              'add document',
              'create a document',
              'create document',
              'new document',
              'save document',
            ],
            stopAt: ['content', 'body'],
          );
      final content =
          _extractField(prompt, 'content') ??
          _extractField(prompt, 'body') ??
          '';
      if (title != null && title.isNotEmpty) {
        return AssistantResponse(
          message: '✅ Added document "$title".',
          vault: vault.copyWith(
            documents: [
              ...vault.documents,
              VaultDocument(
                id: _uuid.v4(),
                title: title,
                fileName: '$title.txt',
                path: '',
                content: content,
                addedAt: DateTime.now(),
              ),
            ],
          ),
        );
      }
      return const AssistantResponse(
        message:
            'Please specify a title. Example:\n"Add document title \'Notes\' content \'Some text\'"',
      );
    }

    // --- SEARCH VAULT ---
    final results = vault.search(prompt);
    if (results.isEmpty) {
      return const AssistantResponse(
        message:
            'I could not find matching local data. Try asking something specific, or add data using commands like:\n• "Add note title \'My Note\' content \'Hello\'"\n• "Add password account \'Gmail\' username \'me\' password \'abc\'"',
        handledLocally: false,
      );
    }
    return AssistantResponse(
      message: results
          .take(3)
          .map((item) => '${item.type}: ${item.title} — ${item.subtitle}')
          .join('\n'),
      handledLocally: false,
    );
  }

  /// Check if input starts with any of the command phrases
  bool _matchesCommand(String lower, List<String> commands) {
    return commands.any((cmd) => lower.startsWith(cmd));
  }

  /// Extract a field value after a label — supports both quoted and unquoted.
  /// Quoted: title 'My Title'  or  title "My Title"
  /// Unquoted: title My Title (stops at next known keyword or end)
  String? _extractField(String text, String label) {
    // Try quoted first
    final quotedPattern = RegExp(
      "${RegExp.escape(label)}\\s*:?\\s*['\"]([^'\"]+)['\"]",
      caseSensitive: false,
    );
    final quotedMatch = quotedPattern.firstMatch(text);
    if (quotedMatch != null) return quotedMatch.group(1)?.trim();

    // Try unquoted: grab text after label until next known keyword or end
    final keywords = [
      'title',
      'content',
      'body',
      'account name',
      'account',
      'username',
      'user',
      'password',
      'pass',
      'date',
      'time',
      'description',
      'details',
      'for',
      'on',
      'at',
      'and',
      'with',
    ];
    final labelPattern = RegExp(
      '${RegExp.escape(label)}\\s*:?\\s+',
      caseSensitive: false,
    );
    final labelMatch = labelPattern.firstMatch(text);
    if (labelMatch == null) return null;

    final afterLabel = text.substring(labelMatch.end).trim();
    if (afterLabel.isEmpty) return null;

    // Find the earliest occurrence of another keyword
    int endIndex = afterLabel.length;
    for (final kw in keywords) {
      if (kw == label) continue;
      final kwPattern = RegExp(
        '\\b${RegExp.escape(kw)}\\s',
        caseSensitive: false,
      );
      final kwMatch = kwPattern.firstMatch(afterLabel);
      if (kwMatch != null && kwMatch.start < endIndex) {
        endIndex = kwMatch.start;
      }
    }

    final value = afterLabel.substring(0, endIndex).trim();
    return value.isEmpty ? null : value;
  }

  /// Extract text immediately after the command phrase (for when user doesn't use 'title' keyword).
  /// e.g. "Add note Meeting with John content Discussed timeline"
  String? _extractAfterCommand(
    String text,
    List<String> commands, {
    List<String> stopAt = const [],
  }) {
    final lower = text.toLowerCase();
    for (final cmd in commands) {
      if (!lower.startsWith(cmd)) continue;
      // Check for "with" right after the command and skip it
      var remaining = text.substring(cmd.length).trim();
      if (remaining.toLowerCase().startsWith('with ') &&
          !remaining.toLowerCase().startsWith('with title') &&
          !remaining.toLowerCase().startsWith('with content')) {
        remaining = remaining.substring(5).trim();
      }
      if (remaining.isEmpty) return null;

      int endIndex = remaining.length;
      for (final stop in stopAt) {
        final stopPattern = RegExp(
          '\\b${RegExp.escape(stop)}\\b',
          caseSensitive: false,
        );
        final stopMatch = stopPattern.firstMatch(remaining);
        if (stopMatch != null && stopMatch.start < endIndex) {
          endIndex = stopMatch.start;
        }
      }

      final value = remaining.substring(0, endIndex).trim();
      // Remove trailing "and" or "with"
      final cleaned = value
          .replaceAll(RegExp(r'\s+(and|with)\s*$', caseSensitive: false), '')
          .trim();
      return cleaned.isEmpty ? null : cleaned;
    }
    return null;
  }

  DateTime? _parseDateTime(String? date, String? time) {
    if (date == null) return null;

    final parsedDate = _parseDateOnly(date);
    if (parsedDate == null) return null;

    final parsedTime = _parseTimeOnly(time);
    return DateTime(
      parsedDate.year,
      parsedDate.month,
      parsedDate.day,
      parsedTime?.hour ?? 0,
      parsedTime?.minute ?? 0,
    );
  }

  DateTime? _parseDateOnly(String input) {
    final value = input.trim().toLowerCase();
    final now = DateTime.now();
    if (value == 'today') {
      return DateTime(now.year, now.month, now.day);
    }
    if (value == 'tomorrow') {
      final d = now.add(const Duration(days: 1));
      return DateTime(d.year, d.month, d.day);
    }

    final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(value);
    if (iso != null) {
      return DateTime(
        int.parse(iso.group(1)!),
        int.parse(iso.group(2)!),
        int.parse(iso.group(3)!),
      );
    }

    final slash = RegExp(
      r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$',
    ).firstMatch(value);
    if (slash != null) {
      final first = int.parse(slash.group(1)!);
      final second = int.parse(slash.group(2)!);
      final year = int.parse(slash.group(3)!);
      // Prefer DD/MM/YYYY, but gracefully handle MM/DD/YYYY inputs.
      if (first > 12) {
        return DateTime(year, second, first);
      }
      return DateTime(year, first, second);
    }

    return null;
  }

  _ParsedTime? _parseTimeOnly(String? input) {
    if (input == null || input.trim().isEmpty) {
      return const _ParsedTime(hour: 0, minute: 0);
    }
    final value = input.trim().toLowerCase();

    final twentyFourHour = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value);
    if (twentyFourHour != null) {
      return _ParsedTime(
        hour: int.parse(twentyFourHour.group(1)!),
        minute: int.parse(twentyFourHour.group(2)!),
      );
    }

    final amPm = RegExp(
      r'^(\d{1,2})(?::(\d{2}))?\s*(am|pm)$',
    ).firstMatch(value);
    if (amPm != null) {
      var hour = int.parse(amPm.group(1)!);
      final minute = int.tryParse(amPm.group(2) ?? '0') ?? 0;
      final meridiem = amPm.group(3)!;
      if (meridiem == 'pm' && hour < 12) {
        hour += 12;
      }
      if (meridiem == 'am' && hour == 12) {
        hour = 0;
      }
      return _ParsedTime(hour: hour, minute: minute);
    }

    return null;
  }
}

class _ParsedTime {
  const _ParsedTime({required this.hour, required this.minute});

  final int hour;
  final int minute;
}

class AssistantResponse {
  const AssistantResponse({
    required this.message,
    this.vault,
    this.handledLocally = true,
  });

  final String message;
  final VaultData? vault;
  final bool handledLocally;
}
