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

  Future<void> upsertNote(VaultNote note) async {
    final vault = await future;
    final notes = [...vault.notes];
    final index = notes.indexWhere((item) => item.id == note.id);
    index == -1 ? notes.add(note) : notes[index] = note;
    
    final newVault = vault.copyWith(notes: notes);
    state = AsyncData(newVault);
    await ref.read(vaultRepositoryProvider).upsertNote(note);
  }

  Future<void> deleteNote(String id) async {
    final vault = await future;
    final newNotes = vault.notes.where((item) => item.id != id).toList();
    
    final newVault = vault.copyWith(notes: newNotes);
    state = AsyncData(newVault);
    await ref.read(vaultRepositoryProvider).deleteNote(id);
  }

  Future<void> upsertPassword(VaultPassword password) async {
    final vault = await future;
    final passwords = [...vault.passwords];
    final index = passwords.indexWhere((item) => item.id == password.id);
    index == -1 ? passwords.add(password) : passwords[index] = password;
    
    final newVault = vault.copyWith(passwords: passwords);
    state = AsyncData(newVault);
    await ref.read(vaultRepositoryProvider).upsertPassword(password);
  }

  Future<void> deletePassword(String id) async {
    final vault = await future;
    final newPasswords = vault.passwords.where((item) => item.id != id).toList();
    
    final newVault = vault.copyWith(passwords: newPasswords);
    state = AsyncData(newVault);
    await ref.read(vaultRepositoryProvider).deletePassword(id);
  }

  Future<void> addDocument(VaultDocument document) async {
    final vault = await future;
    final newDocs = [...vault.documents, document];
    
    final newVault = vault.copyWith(documents: newDocs);
    state = AsyncData(newVault);
    await ref.read(vaultRepositoryProvider).upsertDocument(document);
  }

  Future<void> deleteDocument(String id) async {
    final vault = await future;
    final newDocs = vault.documents.where((item) => item.id != id).toList();
    
    final newVault = vault.copyWith(documents: newDocs);
    state = AsyncData(newVault);
    await ref.read(vaultRepositoryProvider).deleteDocument(id);
  }

  Future<void> upsertEvent(VaultEvent event) async {
    final vault = await future;
    final events = [...vault.events];
    final index = events.indexWhere((item) => item.id == event.id);
    index == -1 ? events.add(event) : events[index] = event;
    
    final newVault = vault.copyWith(events: events);
    state = AsyncData(newVault);
    await ref.read(vaultRepositoryProvider).upsertEvent(event);
    await ref.read(notificationServiceProvider).scheduleEventReminder(event);
  }

  Future<void> deleteEvent(String id) async {
    final vault = await future;
    final newEvents = vault.events.where((item) => item.id != id).toList();
    
    final newVault = vault.copyWith(events: newEvents);
    state = AsyncData(newVault);
    await ref.read(vaultRepositoryProvider).deleteEvent(id);
    await ref.read(notificationServiceProvider).cancelEventReminder(id);
  }
}
