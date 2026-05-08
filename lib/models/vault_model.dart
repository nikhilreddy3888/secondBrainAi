import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class VaultData {
  const VaultData({
    required this.notes,
    required this.passwords,
    required this.documents,
    required this.events,
  });

  factory VaultData.empty() => const VaultData(
        notes: [],
        passwords: [],
        documents: [],
        events: [],
      );

  factory VaultData.fromJson(Map<String, dynamic> json) => VaultData(
        notes: (json['notes'] as List? ?? [])
            .map((item) => VaultNote.fromJson(item))
            .toList(),
        passwords: (json['passwords'] as List? ?? [])
            .map((item) => VaultPassword.fromJson(item))
            .toList(),
        documents: (json['documents'] as List? ?? [])
            .map((item) => VaultDocument.fromJson(item))
            .toList(),
        events: (json['events'] as List? ?? [])
            .map((item) => VaultEvent.fromJson(item))
            .toList(),
      );

  final List<VaultNote> notes;
  final List<VaultPassword> passwords;
  final List<VaultDocument> documents;
  final List<VaultEvent> events;

  VaultData copyWith({
    List<VaultNote>? notes,
    List<VaultPassword>? passwords,
    List<VaultDocument>? documents,
    List<VaultEvent>? events,
  }) {
    return VaultData(
      notes: notes ?? this.notes,
      passwords: passwords ?? this.passwords,
      documents: documents ?? this.documents,
      events: events ?? this.events,
    );
  }

  List<SearchResult> search(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return [];

    final stopWords = {'i', 'me', 'my', 'we', 'our', 'you', 'your', 'he', 'him', 'his', 'she', 'her', 'it', 'its', 'they', 'them', 'their', 'what', 'which', 'who', 'whom', 'this', 'that', 'these', 'those', 'am', 'is', 'are', 'was', 'were', 'be', 'been', 'being', 'have', 'has', 'had', 'do', 'does', 'did', 'a', 'an', 'the', 'and', 'but', 'if', 'or', 'because', 'as', 'until', 'while', 'of', 'at', 'by', 'for', 'with', 'about', 'against', 'between', 'into', 'through', 'during', 'before', 'after', 'above', 'below', 'to', 'from', 'up', 'down', 'in', 'out', 'on', 'off', 'over', 'under', 'again', 'further', 'then', 'once', 'here', 'there', 'when', 'where', 'why', 'how', 'all', 'any', 'both', 'each', 'few', 'more', 'most', 'other', 'some', 'such', 'no', 'nor', 'not', 'only', 'own', 'same', 'so', 'than', 'too', 'very', 's', 't', 'can', 'will', 'just', 'don', 'should', 'now', 'many', 'much', 'show', 'find', 'get', 'tell', 'list'};

    final tokens = normalized
        .split(RegExp(r'\s+'))
        .map((token) => token.replaceAll(RegExp(r'[^a-z0-9]'), ''))
        .where((token) => token.length >= 2 && !stopWords.contains(token))
        .toSet();

    bool matches(String haystack) {
      final text = haystack.toLowerCase();
      if (text.contains(normalized)) return true;
      if (tokens.isEmpty) return false;
      return tokens.any(text.contains);
    }

    int score(String haystack) {
      final text = haystack.toLowerCase();
      var value = text.contains(normalized) ? 1000 : 0;
      for (final token in tokens) {
        if (text.contains(token)) {
          if (token.length > 4) {
            value += token.length * token.length; // Stronger weight for longer/distinct words
          } else {
            value += token.length;
          }
        }
      }
      return value;
    }

    final scored = <MapEntry<int, SearchResult>>[];

    for (final note in notes) {
      final haystack = '${note.title} ${note.content}';
      if (!matches(haystack)) continue;
      scored.add(
        MapEntry(
          score(haystack),
          SearchResult(
            id: note.id,
            type: 'Note',
            icon: Icons.sticky_note_2_outlined,
            title: note.title,
            subtitle: note.content,
          ),
        ),
      );
    }

    for (final password in passwords) {
      final haystack = '${password.accountName} ${password.username}';
      if (!matches(haystack)) continue;
      scored.add(
        MapEntry(
          score(haystack),
          SearchResult(
            id: password.id,
            type: 'Password',
            icon: Icons.lock_outline,
            title: password.accountName,
            subtitle: password.username,
            secret: password.password,
          ),
        ),
      );
    }

    for (final doc in documents) {
      final haystack = '${doc.title} ${doc.fileName} ${doc.content}';
      if (!matches(haystack)) continue;
      scored.add(
        MapEntry(
          score(haystack),
          SearchResult(
            id: doc.id,
            type: 'Document',
            icon: Icons.description_outlined,
            title: doc.title,
            subtitle: doc.content.isEmpty ? doc.fileName : doc.content,
          ),
        ),
      );
    }

    for (final event in events) {
      final haystack = '${event.title} ${event.description}';
      if (!matches(haystack)) continue;
      scored.add(
        MapEntry(
          score(haystack),
          SearchResult(
            id: event.id,
            type: 'Event',
            icon: Icons.event_outlined,
            title: event.title,
            subtitle:
                '${DateFormat.yMMMd().add_jm().format(event.startsAt)} - ${event.description}',
          ),
        ),
      );
    }

    scored.sort((a, b) => b.key.compareTo(a.key));
    return scored.map((entry) => entry.value).toList();
  }

  Map<String, dynamic> toJson() => {
        'notes': notes.map((item) => item.toJson()).toList(),
        'passwords': passwords.map((item) => item.toJson()).toList(),
        'documents': documents.map((item) => item.toJson()).toList(),
        'events': events.map((item) => item.toJson()).toList(),
      };
}

class VaultNote {
  const VaultNote({
    required this.id,
    required this.title,
    required this.content,
    required this.updatedAt,
  });

  factory VaultNote.fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    return VaultNote(
      id: map['id'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  final String id;
  final String title;
  final String content;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'updatedAt': updatedAt.toIso8601String(),
      };
}

class VaultPassword {
  const VaultPassword({
    required this.id,
    required this.accountName,
    required this.username,
    required this.password,
  });

  factory VaultPassword.fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    return VaultPassword(
      id: map['id'] as String,
      accountName: map['accountName'] as String,
      username: map['username'] as String,
      password: map['password'] as String,
    );
  }

  final String id;
  final String accountName;
  final String username;
  final String password;

  Map<String, dynamic> toJson() => {
        'id': id,
        'accountName': accountName,
        'username': username,
        'password': password,
      };
}

class VaultDocument {
  const VaultDocument({
    required this.id,
    required this.title,
    required this.fileName,
    required this.path,
    required this.content,
    required this.addedAt,
    this.base64Data,
  });

  factory VaultDocument.fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    return VaultDocument(
      id: map['id'] as String,
      title: map['title'] as String,
      fileName: map['fileName'] as String,
      path: map['path'] as String,
      content: map['content'] as String,
      addedAt: DateTime.parse(map['addedAt'] as String),
      base64Data: map['base64Data'] as String?,
    );
  }

  final String id;
  final String title;
  final String fileName;
  final String path;
  final String content;
  final DateTime addedAt;
  final String? base64Data;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'fileName': fileName,
        'path': path,
        'content': content,
        'addedAt': addedAt.toIso8601String(),
        if (base64Data != null) 'base64Data': base64Data,
      };
}

class VaultEvent {
  const VaultEvent({
    required this.id,
    required this.title,
    required this.startsAt,
    required this.description,
  });

  factory VaultEvent.fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    return VaultEvent(
      id: map['id'] as String,
      title: map['title'] as String,
      startsAt: DateTime.parse(map['startsAt'] as String),
      description: map['description'] as String,
    );
  }

  final String id;
  final String title;
  final DateTime startsAt;
  final String description;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'startsAt': startsAt.toIso8601String(),
        'description': description,
      };
}

class SearchResult {
  const SearchResult({
    required this.id,
    required this.type,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.secret,
  });

  final String id;
  final String type;
  final IconData icon;
  final String title;
  final String subtitle;
  final String? secret;
}
