import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../security/key_manager.dart';

final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  final keyManager = ref.read(keyManagerProvider);
  return DatabaseHelper(keyManager);
});

class DatabaseHelper {
  final KeyManager _keyManager;
  Database? _database;

  DatabaseHelper(this._keyManager);

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'second_brain_vault.db');

    // Retrieve the master key to unlock SQLCipher
    final password = await _keyManager.getOrCreateMasterKey();

    try {
      return await openDatabase(
        path,
        version: 1,
        password: password,
        onCreate: _onCreate,
      );
    } catch (e) {
      // If the database file exists but can't be opened (e.g. old unencrypted
      // database incompatible with SQLCipher), delete it and create fresh.
      final dbFile = File(path);
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
      return await openDatabase(
        path,
        version: 1,
        password: password,
        onCreate: _onCreate,
      );
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE notes (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE documents (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        fileName TEXT NOT NULL,
        path TEXT NOT NULL,
        content TEXT NOT NULL,
        addedAt TEXT NOT NULL,
        base64Data TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE events (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        startsAt TEXT NOT NULL,
        description TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE passwords (
        id TEXT PRIMARY KEY,
        accountName TEXT NOT NULL,
        username TEXT NOT NULL,
        password TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE audit_log (
        id TEXT PRIMARY KEY,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        action TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
