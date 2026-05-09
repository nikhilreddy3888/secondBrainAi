import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../repository/assistant_tools.dart';
import '../../models/chat_session.dart';
import '../../../../core/app_colors.dart';
import 'chat_bubble_tile.dart';
import 'chat_welcome_panel.dart';

class AssistantChatView extends StatefulWidget {
  const AssistantChatView({
    super.key,
    this.initialHistory,
    required this.onMessage,
    this.initialPromptToSend,
    this.welcomeMessage,
    this.accentColor,
    this.enableImagePicker = false,
  });

  final List<ChatMessageEntry>? initialHistory;
  final Stream<String> Function(String content, {Uint8List? imageBytes, void Function(List<VaultCitation>)? onCitations}) onMessage;
  final String? initialPromptToSend;
  final String? welcomeMessage;
  final Color? accentColor;
  final bool enableImagePicker;

  @override
  State<AssistantChatView> createState() => _AssistantChatViewState();
}

class _AssistantChatViewState extends State<AssistantChatView> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatBubble> _messages = [];
  bool _isSending = false;
  bool _sentInitialPrompt = false;

  @override
  void initState() {
    super.initState();
    _syncHistory(widget.initialHistory);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeSendInitialPrompt());
  }

  @override
  void didUpdateWidget(covariant AssistantChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialHistory != widget.initialHistory) {
      _syncHistory(widget.initialHistory);
      _sentInitialPrompt = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeSendInitialPrompt());
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _syncHistory(List<ChatMessageEntry>? history) {
    setState(() {
      _messages.clear();
      _messages.addAll((history ?? []).map((e) => ChatBubble(role: e.role, content: e.content, citations: e.citations ?? [])));
    });
  }

  void _maybeSendInitialPrompt() {
    if (_sentInitialPrompt || widget.initialPromptToSend == null || _messages.isNotEmpty) return;
    _sentInitialPrompt = true;
    _inputController.text = widget.initialPromptToSend!;
    _submitMessage();
  }

  Future<void> _submitMessage() async {
    if (_isSending) return;
    final msg = _inputController.text.trim();
    if (msg.isEmpty) return;

    setState(() {
      _messages.add(ChatBubble(role: 'user', content: msg));
      _messages.add(const ChatBubble(role: 'assistant-stream', content: ''));
      _inputController.clear();
      _isSending = true;
    });
    _scrollToBottom();

    final buffer = StringBuffer();
    List<VaultCitation> citations = [];
    try {
      await for (final token in widget.onMessage(msg, onCitations: (c) => citations = c)) {
        buffer.write(token);
        if (_messages.isNotEmpty && _messages.last.role == 'assistant-stream') _messages.removeLast();
        setState(() => _messages.add(ChatBubble(role: 'assistant-stream', content: buffer.toString(), citations: citations)));
        _scrollToBottom();
      }
    } finally {
      if (_messages.isNotEmpty && _messages.last.role == 'assistant-stream') {
        final text = _messages.last.content.trim();
        _messages.removeLast();
        if (text.isNotEmpty) _messages.add(ChatBubble(role: 'assistant', content: text, citations: citations));
      }
      if (buffer.isEmpty) _messages.add(const ChatBubble(role: 'assistant', content: 'I could not generate a response.'));
      setState(() => _isSending = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final accent = widget.accentColor ?? Colors.purple;

    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? ChatWelcomePanel(message: widget.welcomeMessage ?? 'Start a conversation.', accentColor: accent)
              : ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  itemCount: _messages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) => ChatBubbleTile(message: _messages[index], accentColor: accent),
                ),
        ),
        _buildInput(colors, accent),
      ],
    );
  }

  Widget _buildInput(AppColors colors, Color accent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Container(
        decoration: BoxDecoration(color: colors.surfaceColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: colors.borderColor)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(controller: _inputController, minLines: 1, maxLines: 5, style: TextStyle(color: colors.textColor, fontSize: 15), decoration: InputDecoration(hintText: 'Ask anything...', hintStyle: TextStyle(color: colors.subtextColor), border: InputBorder.none)),
              ),
              const SizedBox(width: 8),
              _buildSendBtn(accent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSendBtn(Color accent) {
    return Material(
      color: _isSending ? accent.withOpacity(0.2) : accent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: _isSending ? null : _submitMessage,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: _isSending ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
