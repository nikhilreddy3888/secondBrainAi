import 'package:uuid/uuid.dart';

/// Represents a single chat session with metadata.
class ChatSession {
  ChatSession({
    required this.id,
    required this.title,
    required this.modelId,
    required this.mode,
    required this.createdAt,
    required this.updatedAt,
    this.messages = const [],
  });

  final String id;
  final String title;
  final String modelId;
  final String mode;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ChatMessageEntry> messages;

  /// Create a new session with a generated ID.
  factory ChatSession.create({
    required String modelId,
    String mode = 'chat',
    String title = 'New Chat',
  }) {
    final now = DateTime.now();
    return ChatSession(
      id: const Uuid().v4(),
      title: title,
      modelId: modelId,
      mode: mode,
      createdAt: now,
      updatedAt: now,
    );
  }

  ChatSession copyWith({
    String? title,
    String? modelId,
    String? mode,
    DateTime? updatedAt,
    List<ChatMessageEntry>? messages,
  }) {
    return ChatSession(
      id: id,
      title: title ?? this.title,
      modelId: modelId ?? this.modelId,
      mode: mode ?? this.mode,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'model_id': modelId,
    'mode': mode,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory ChatSession.fromMap(Map<String, dynamic> map, {
    List<ChatMessageEntry> messages = const [],
  }) {
    return ChatSession(
      id: map['id'] as String,
      title: map['title'] as String,
      modelId: map['model_id'] as String,
      mode: map['mode'] as String? ?? 'chat',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      messages: messages,
    );
  }

  /// Preview of the last message in the session, for listing.
  String get lastMessagePreview {
    if (messages.isEmpty) return 'No messages yet';
    final last = messages.last;
    final prefix = last.role == 'user' ? 'You: ' : 'AI: ';
    final content = last.content.replaceAll('\n', ' ');
    return '$prefix${content.length > 80 ? '${content.substring(0, 80)}…' : content}';
  }
}

/// A single message entry stored in the database.
class ChatMessageEntry {
  const ChatMessageEntry({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    required this.timestamp,
  });

  final String id;
  final String sessionId;
  final String role; // 'user', 'assistant', 'system'
  final String content;
  final DateTime timestamp;

  Map<String, dynamic> toMap() => {
    'id': id,
    'session_id': sessionId,
    'role': role,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
  };

  factory ChatMessageEntry.fromMap(Map<String, dynamic> map) {
    return ChatMessageEntry(
      id: map['id'] as String,
      sessionId: map['session_id'] as String,
      role: map['role'] as String,
      content: map['content'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }
}
