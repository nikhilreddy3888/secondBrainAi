import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../../models/vault_model.dart';
import '../../../core/data/database_helper.dart';
import '../../../core/security/biometric_auth.dart';
import '../../settings/controller/settings_controller.dart';

final vaultRepositoryProvider = Provider<VaultRepository>((ref) {
  return VaultRepository(
    ref,
    ref.read(databaseHelperProvider),
    ref.read(biometricAuthProvider),
  );
});

class VaultRepository {
  final Ref _ref;
  final DatabaseHelper _dbHelper;
  final BiometricAuth _biometricAuth;
  static const _storage = FlutterSecureStorage();
  static const _vaultKey = 'encrypted_local_vault_v1';
  bool _isAuthenticated = false;

  VaultRepository(this._ref, this._dbHelper, this._biometricAuth);

  void markAsAuthenticated() {
    _isAuthenticated = true;
    _biometricAuth.setAuthorized(true);
  }

  Future<void> _ensureAuthenticated() async {
    // Check settings first
    final settings = _ref.read(settingsControllerProvider);
    if (!settings.biometricEnabled) {
      _isAuthenticated = true;
      _biometricAuth.setAuthorized(true);
      return;
    }

    if (!_isAuthenticated && !_biometricAuth.isAuthorized) {
      final success = await _biometricAuth.authenticate();
      if (!success) {
        throw Exception('Biometric authentication failed. Cannot access vault.');
      }
      _isAuthenticated = true;
      _biometricAuth.setAuthorized(true);
    }
  }

  Future<VaultData> load() async {
    // Initial load does NOT require explicit auth here,
    // as the UI (DashboardScreen) will handle the lock screen.
    // This prevents a double-prompt on app startup.
    
    final db = await _dbHelper.database;
    
    // Run migration if old JSON vault exists
    await _migrateLegacyVault(db);

    final notesMap = await db.query('notes');
    final notes = notesMap.map((e) => VaultNote(
      id: e['id'] as String,
      title: e['title'] as String,
      content: e['content'] as String,
      updatedAt: DateTime.parse(e['updated_at'] as String),
    )).toList();

    final docsMap = await db.query('documents');
    final documents = docsMap.map((e) => VaultDocument(
      id: e['id'] as String,
      title: e['title'] as String,
      fileName: e['fileName'] as String,
      path: e['path'] as String,
      content: e['content'] as String,
      addedAt: DateTime.parse(e['addedAt'] as String),
      base64Data: e['base64Data'] as String?,
    )).toList();

    final eventsMap = await db.query('events');
    final events = eventsMap.map((e) => VaultEvent(
      id: e['id'] as String,
      title: e['title'] as String,
      startsAt: DateTime.parse(e['startsAt'] as String),
      description: e['description'] as String,
    )).toList();

    final passMap = await db.query('passwords');
    final passwords = passMap.map((e) => VaultPassword(
      id: e['id'] as String,
      accountName: e['accountName'] as String,
      username: e['username'] as String,
      password: e['password'] as String,
    )).toList();

    return VaultData(
      notes: notes,
      passwords: passwords,
      documents: documents,
      events: events,
    );
  }

  Future<void> upsertNote(VaultNote note) async {
    await _ensureAuthenticated();
    final db = await _dbHelper.database;
    await db.insert(
      'notes',
      {
        'id': note.id,
        'title': note.title,
        'content': note.content,
        'updated_at': note.updatedAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteNote(String id) async {
    await _ensureAuthenticated();
    final db = await _dbHelper.database;
    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> upsertPassword(VaultPassword pw) async {
    await _ensureAuthenticated();
    final db = await _dbHelper.database;
    await db.insert(
      'passwords',
      {
        'id': pw.id,
        'accountName': pw.accountName,
        'username': pw.username,
        'password': pw.password,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deletePassword(String id) async {
    await _ensureAuthenticated();
    final db = await _dbHelper.database;
    await db.delete('passwords', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> upsertDocument(VaultDocument doc) async {
    await _ensureAuthenticated();
    final db = await _dbHelper.database;
    await db.insert(
      'documents',
      {
        'id': doc.id,
        'title': doc.title,
        'fileName': doc.fileName,
        'path': doc.path,
        'content': doc.content,
        'addedAt': doc.addedAt.toIso8601String(),
        'base64Data': doc.base64Data,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteDocument(String id) async {
    await _ensureAuthenticated();
    final db = await _dbHelper.database;
    await db.delete('documents', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> upsertEvent(VaultEvent event) async {
    await _ensureAuthenticated();
    final db = await _dbHelper.database;
    await db.insert(
      'events',
      {
        'id': event.id,
        'title': event.title,
        'startsAt': event.startsAt.toIso8601String(),
        'description': event.description,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteEvent(String id) async {
    await _ensureAuthenticated();
    final db = await _dbHelper.database;
    await db.delete('events', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> _migrateLegacyVault(Database db) async {
    final raw = await _storage.read(key: _vaultKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final legacyVault = VaultData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      
      await db.transaction((txn) async {
        for (var note in legacyVault.notes) {
          await txn.insert('notes', {
            'id': note.id,
            'title': note.title,
            'content': note.content,
            'updated_at': note.updatedAt.toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }

        for (var doc in legacyVault.documents) {
          await txn.insert('documents', {
            'id': doc.id,
            'title': doc.title,
            'fileName': doc.fileName,
            'path': doc.path,
            'content': doc.content,
            'addedAt': doc.addedAt.toIso8601String(),
            'base64Data': doc.base64Data,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }

        for (var event in legacyVault.events) {
          await txn.insert('events', {
            'id': event.id,
            'title': event.title,
            'startsAt': event.startsAt.toIso8601String(),
            'description': event.description,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }

        for (var pw in legacyVault.passwords) {
          await txn.insert('passwords', {
            'id': pw.id,
            'accountName': pw.accountName,
            'username': pw.username,
            'password': pw.password,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      });

      // Delete the legacy key after successful migration
      await _storage.delete(key: _vaultKey);
      print('Legacy vault successfully migrated to SQLCipher.');
    } catch (e) {
      print('Error during legacy vault migration: $e');
    }
  }
}
