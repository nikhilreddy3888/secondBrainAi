import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../models/vault_model.dart';
import '../repository/vault_repository.dart';
import '../../../core/services/notification_service.dart';

const uuid = Uuid();

final vaultControllerProvider =
    AsyncNotifierProvider<VaultController, VaultData>(VaultController.new);

class VaultController extends AsyncNotifier<VaultData> {
  @override
  Future<VaultData> build() {
    return ref.read(vaultRepositoryProvider).load();
  }

  Future<void> _persist(VaultData vault) async {
    state = AsyncData(vault);
    await ref.read(vaultRepositoryProvider).save(vault);
  }

  Future<void> replaceVault(VaultData vault) {
    return _persist(vault);
  }

  Future<void> upsertNote(VaultNote note) async {
    final vault = await future;
    final notes = [...vault.notes];
    final index = notes.indexWhere((item) => item.id == note.id);
    index == -1 ? notes.add(note) : notes[index] = note;
    await _persist(vault.copyWith(notes: notes));
  }

  Future<void> deleteNote(String id) async {
    final vault = await future;
    await _persist(
      vault.copyWith(notes: vault.notes.where((item) => item.id != id).toList()),
    );
  }

  Future<void> upsertPassword(VaultPassword password) async {
    final vault = await future;
    final passwords = [...vault.passwords];
    final index = passwords.indexWhere((item) => item.id == password.id);
    index == -1 ? passwords.add(password) : passwords[index] = password;
    await _persist(vault.copyWith(passwords: passwords));
  }

  Future<void> deletePassword(String id) async {
    final vault = await future;
    await _persist(
      vault.copyWith(
        passwords: vault.passwords.where((item) => item.id != id).toList(),
      ),
    );
  }

  Future<void> addDocument(VaultDocument document) async {
    final vault = await future;
    await _persist(vault.copyWith(documents: [...vault.documents, document]));
  }

  Future<void> deleteDocument(String id) async {
    final vault = await future;
    await _persist(
      vault.copyWith(
        documents: vault.documents.where((item) => item.id != id).toList(),
      ),
    );
  }

  Future<void> upsertEvent(VaultEvent event) async {
    final vault = await future;
    final events = [...vault.events];
    final index = events.indexWhere((item) => item.id == event.id);
    index == -1 ? events.add(event) : events[index] = event;
    await _persist(vault.copyWith(events: events));
    await ref.read(notificationServiceProvider).scheduleEventReminder(event);
  }

  Future<void> deleteEvent(String id) async {
    final vault = await future;
    await _persist(
      vault.copyWith(
        events: vault.events.where((item) => item.id != id).toList(),
      ),
    );
    await ref.read(notificationServiceProvider).cancelEventReminder(id);
  }
}
