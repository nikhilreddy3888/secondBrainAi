import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repository/ai_repository.dart';
import 'ai_runtime_controller.dart';
import '../../vault/controller/vault_controller.dart';

final assistantControllerProvider = Provider<AssistantController>((ref) {
  return AssistantController(ref);
});

class AssistantController {
  AssistantController(this.ref);

  final Ref ref;

  Future<String> handle(String prompt) async {
    final vault = await ref.read(vaultControllerProvider.future);
    final aiState = ref.read(aiRuntimeControllerProvider);
    if (!aiState.modelLoaded) {
      throw StateError(
        'Local LLM is not loaded. Download and load the model before asking the assistant.',
      );
    }

    final answer = await ref
        .read(aiRepositoryProvider)
        .answer(vault: vault, question: prompt);
    if (answer.trim().isEmpty) {
      throw StateError('Local LLM returned an empty response.');
    }
    return answer;
  }
}
