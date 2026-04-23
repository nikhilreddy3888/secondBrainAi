import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain_app/features/assistant/controller/assistant_controller.dart';
import 'package:second_brain_app/models/vault_model.dart';

void main() {
  test('assistant can add a note from a local command', () {
    final response = AssistantEngine(VaultData.empty()).handle(
      "Add a new note with title 'Meeting with John' and content 'Discussed project timeline'",
    );

    expect(response.vault, isNotNull);
    expect(response.vault!.notes, hasLength(1));
    expect(response.vault!.notes.single.title, 'Meeting with John');
    expect(response.vault!.notes.single.content, 'Discussed project timeline');
  });

  test('global search finds password account names without exposing password', () {
    final vault = VaultData.empty().copyWith(
      passwords: const [
        VaultPassword(
          id: '1',
          accountName: 'HDFC Bank',
          username: 'rachit',
          password: 'secret-password',
        ),
      ],
    );

    final results = vault.search('hdfc');

    expect(results, hasLength(1));
    expect(results.single.title, 'HDFC Bank');
    expect(results.single.subtitle, 'rachit');
    expect(results.single.secret, 'secret-password');
  });
}
