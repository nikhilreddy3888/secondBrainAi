import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/data/database_helper.dart';
import '../models/chat_session.dart';

final chatSessionRepositoryProvider = Provider<ChatSessionRepository>((ref) {
  return ChatSessionRepository(ref.read(databaseHelperProvider));
});

/// Handles reading and writing chat sessions and messages to the encrypted DB.
class ChatSessionRepository {
  ChatSessionRepository(this._dbHelper);
  final DatabaseHelper _dbHelper;

  /// Ensure tables exist (for existing databases before migration).
  Future<void> ensureTables() async {
    final db = await _dbHelper.database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS chat_sessions (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        model_id TEXT NOT NULL,
        mode TEXT NOT NULL DEFAULT 'chat',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS chat_messages (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (session_id) REFERENCES chat_sessions(id) ON DELETE CASCADE
      )
    ''');
  }

  /// Get all sessions, ordered by most recent first.
  Future<List<ChatSession>> getAllSessions() async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'chat_sessions',
      orderBy: 'updated_at DESC',
    );

    final sessions = <ChatSession>[];
    for (final row in rows) {
      final sessionId = row['id'] as String;
      // Load last message only for preview
      final msgRows = await db.query(
        'chat_messages',
        where: 'session_id = ?',
        whereArgs: [sessionId],
        orderBy: 'timestamp DESC',
        limit: 1,
      );
      final messages = msgRows.map((m) => ChatMessageEntry.fromMap(m)).toList();
      sessions.add(ChatSession.fromMap(row, messages: messages));
    }
    return sessions;
  }

  /// Load a full session with all messages.
  Future<ChatSession?> getSession(String sessionId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'chat_sessions',
      where: 'id = ?',
      whereArgs: [sessionId],
    );
    if (rows.isEmpty) return null;

    final msgRows = await db.query(
      'chat_messages',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp ASC',
    );
    final messages = msgRows.map((m) => ChatMessageEntry.fromMap(m)).toList();
    return ChatSession.fromMap(rows.first, messages: messages);
  }

  /// Create a new session in the database.
  Future<ChatSession> createSession({
    required String modelId,
    String mode = 'chat',
    String title = 'New Chat',
  }) async {
    final session = ChatSession.create(
      modelId: modelId,
      mode: mode,
      title: title,
    );
    final db = await _dbHelper.database;
    await db.insert('chat_sessions', session.toMap());
    return session;
  }

  /// Update session title and timestamp.
  Future<void> updateSession(ChatSession session) async {
    final db = await _dbHelper.database;
    await db.update(
      'chat_sessions',
      {
        'title': session.title,
        'model_id': session.modelId,
        'mode': session.mode,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  /// Add a message to a session.
  Future<void> addMessage({
    required String sessionId,
    required String role,
    required String content,
  }) async {
    final db = await _dbHelper.database;
    final entry = ChatMessageEntry(
      id: const Uuid().v4(),
      sessionId: sessionId,
      role: role,
      content: content,
      timestamp: DateTime.now(),
    );
    await db.insert('chat_messages', entry.toMap());
    // Also update the session's updated_at timestamp
    await db.update(
      'chat_sessions',
      {'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  /// Delete a session and all its messages.
  Future<void> deleteSession(String sessionId) async {
    final db = await _dbHelper.database;
    await db.delete('chat_messages', where: 'session_id = ?', whereArgs: [sessionId]);
    await db.delete('chat_sessions', where: 'id = ?', whereArgs: [sessionId]);
  }

  /// Auto-generate a title from the first user message.
  Future<void> autoTitleSession(String sessionId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'chat_messages',
      where: 'session_id = ? AND role = ?',
      whereArgs: [sessionId, 'user'],
      orderBy: 'timestamp ASC',
      limit: 1,
    );
    if (rows.isNotEmpty) {
      final content = rows.first['content'] as String;
      final title = content.length > 40
          ? '${content.substring(0, 40)}…'
          : content;
      await db.update(
        'chat_sessions',
        {'title': title},
        where: 'id = ?',
        whereArgs: [sessionId],
      );
    }
  }
}
