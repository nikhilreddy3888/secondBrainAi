import 'package:flutter_local_agent_kit/flutter_local_agent_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_session.dart';
import '../repository/chat_session_repository.dart';

/// State for the chat session manager.
class ChatSessionState {
  const ChatSessionState({
    this.sessions = const [],
    this.activeSessionId,
    this.isLoading = false,
  });

  /// All persisted sessions (ordered by last updated).
  final List<ChatSession> sessions;

  /// The currently active session ID.
  final String? activeSessionId;

  /// True while loading from DB.
  final bool isLoading;

  /// The currently active session object.
  ChatSession? get activeSession {
    if (activeSessionId == null) return null;
    return sessions.cast<ChatSession?>().firstWhere(
      (s) => s?.id == activeSessionId,
      orElse: () => null,
    );
  }

  ChatSessionState copyWith({
    List<ChatSession>? sessions,
    String? activeSessionId,
    bool? isLoading,
    bool clearActiveSession = false,
  }) {
    return ChatSessionState(
      sessions: sessions ?? this.sessions,
      activeSessionId: clearActiveSession
          ? null
          : (activeSessionId ?? this.activeSessionId),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

final chatSessionControllerProvider =
    NotifierProvider<ChatSessionController, ChatSessionState>(
  ChatSessionController.new,
);

class ChatSessionController extends Notifier<ChatSessionState> {
  @override
  ChatSessionState build() {
    return const ChatSessionState(isLoading: true);
  }

  ChatSessionRepository get _repo => ref.read(chatSessionRepositoryProvider);

  /// Load all sessions from the database. Call once at init.
  Future<void> loadSessions() async {
    state = state.copyWith(isLoading: true);
    try {
      await _repo.ensureTables();
      final sessions = await _repo.getAllSessions();
      state = state.copyWith(sessions: sessions, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Create a new chat session and set it as active.
  Future<ChatSession> createSession({
    required String modelId,
    String mode = 'chat',
  }) async {
    final session = await _repo.createSession(
      modelId: modelId,
      mode: mode,
    );
    final sessions = [session, ...state.sessions];
    state = state.copyWith(
      sessions: sessions,
      activeSessionId: session.id,
    );
    return session;
  }

  /// Switch to an existing session by ID.
  Future<ChatSession?> switchToSession(String sessionId) async {
    final session = await _repo.getSession(sessionId);
    if (session == null) return null;

    // Replace the session in the list with the fully-loaded version
    final sessions = state.sessions.map((s) {
      return s.id == sessionId ? session : s;
    }).toList();

    state = state.copyWith(
      sessions: sessions,
      activeSessionId: sessionId,
    );
    return session;
  }

  /// Save a user message to a specific session.
  Future<void> addUserMessage(String content, {String? sessionId}) async {
    final targetId = sessionId ?? state.activeSessionId;
    if (targetId == null) return;

    await _repo.addMessage(
      sessionId: targetId,
      role: 'user',
      content: content,
    );
    // Auto-title on first user message
    final session = state.sessions.cast<ChatSession?>().firstWhere(
          (s) => s?.id == targetId,
          orElse: () => null,
        );
    if (session != null && session.title == 'New Chat') {
      await _repo.autoTitleSession(targetId);
    }
    // Reload active session fully
    await _reloadActiveSession();
  }

  /// Save an assistant response to a specific session.
  Future<void> addAssistantMessage(String content, {String? sessionId}) async {
    final targetId = sessionId ?? state.activeSessionId;
    if (targetId == null) return;

    await _repo.addMessage(
      sessionId: targetId,
      role: 'assistant',
      content: content,
    );
    // Reload active session fully
    await _reloadActiveSession();
  }

  Future<void> _reloadActiveSession() async {
    final sessionId = state.activeSessionId;
    if (sessionId == null) return;
    final session = await _repo.getSession(sessionId);
    if (session == null) return;

    final sessions = state.sessions.map((s) {
      return s.id == sessionId ? session : s;
    }).toList();

    state = state.copyWith(sessions: sessions);
  }

  /// Delete a session.
  Future<void> deleteSession(String sessionId) async {
    await _repo.deleteSession(sessionId);
    final sessions = state.sessions.where((s) => s.id != sessionId).toList();
    final clearActive = state.activeSessionId == sessionId;
    state = state.copyWith(
      sessions: sessions,
      clearActiveSession: clearActive,
    );
  }

  /// Reload the session list (call after mutations).
  Future<void> refreshSessions() async {
    final newSessions = await _repo.getAllSessions();
    final activeSessionId = state.activeSessionId;
    
    // Preserve the fully-loaded active session if it exists
    final activeSession = state.activeSession;
    
    final sessions = newSessions.map((s) {
      if (s.id == activeSessionId && activeSession != null) {
        // Keep the fully loaded messages, just update metadata
        return s.copyWith(messages: activeSession.messages);
      }
      return s;
    }).toList();

    state = state.copyWith(sessions: sessions);
  }

  /// Convert persisted messages to AgentChatMessages for the LLM.
  List<AgentChatMessage> getHistoryForLLM(ChatSession session) {
    return session.messages
        .where((m) => m.role == 'user' || m.role == 'assistant')
        .map((m) {
      return AgentChatMessage(
        id: m.id,
        content: m.content,
        role: m.role == 'user' ? MessageRole.user : MessageRole.assistant,
        timestamp: m.timestamp,
      );
    }).toList();
  }

  /// Get full history for a specific session, loading from DB if needed.
  Future<List<AgentChatMessage>> getFullHistory(String sessionId) async {
    // Check if it's already fully loaded in memory
    final active = state.activeSession;
    if (active != null && active.id == sessionId && active.messages.length > 1) {
      return getHistoryForLLM(active);
    }
    
    // Otherwise load from DB
    final session = await _repo.getSession(sessionId);
    if (session == null) return [];
    return getHistoryForLLM(session);
  }

  void startNewSession() {
    state = state.copyWith(clearActiveSession: true);
  }
}
