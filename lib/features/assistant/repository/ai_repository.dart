import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/vault_model.dart';
import 'rag_engine.dart';

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  return AiRepository();
});

class AiCitation {
  const AiCitation({
    required this.label,
    required this.sourceId,
    required this.sourceType,
    required this.title,
    required this.excerpt,
    required this.score,
  });

  final String label;
  final String sourceId;
  final String sourceType;
  final String title;
  final String excerpt;
  final double score;
}

enum DownloadProgressStage { downloading, completed, failed }

class DownloadProgressState {
  const DownloadProgressState._(this.isCompleted);

  final bool isCompleted;

  static const downloading = DownloadProgressState._(false);
  static const completed = DownloadProgressState._(true);
  static const failed = DownloadProgressState._(true);
}

class DownloadProgress {
  const DownloadProgress({
    required this.bytesDownloaded,
    required this.totalBytes,
    required this.state,
    this.stage = DownloadProgressStage.downloading,
  });

  final int bytesDownloaded;
  final int totalBytes;
  final DownloadProgressState state;
  final DownloadProgressStage stage;

  double get percentage {
    if (totalBytes <= 0) return 0;
    final ratio = bytesDownloaded / totalBytes;
    return ratio.clamp(0, 1).toDouble();
  }
}

class AiRepository {
  static const modelId = 'qwen2.5-0.5b-instruct-q4';
  static const modelName = 'Qwen 2.5 0.5B (400 MB)';

  final VaultRagEngine _ragEngine = VaultRagEngine();
  List<AiCitation> _lastCitations = const [];

  List<AiCitation> get lastCitations => _lastCitations;

  void clearCitations() {
    _lastCitations = const [];
  }

  Future<void> initialize() async {
    return;
  }

  bool _isLoaded = false;

  bool get isModelLoaded => _isLoaded;

  Future<bool> isModelDownloaded() async {
    await initialize();
    return true;
  }

  Future<void> loadModel() async {
    await initialize();
    await Future.delayed(const Duration(seconds: 1));
    _isLoaded = true;
  }

  Stream<DownloadProgress> downloadModel() async* {
    await initialize();
    for (int i = 0; i <= 100; i += 20) {
      await Future.delayed(const Duration(milliseconds: 200));
      yield DownloadProgress(
        bytesDownloaded: i,
        totalBytes: 100,
        state: i == 100
            ? DownloadProgressState.completed
            : DownloadProgressState.downloading,
        stage: i == 100
            ? DownloadProgressStage.completed
            : DownloadProgressStage.downloading,
      );
    }
  }

  Future<String> answer({
    required VaultData vault,
    required String question,
  }) async {
    await initialize();

    final normalizedQuestion = question.trim().toLowerCase();

    final passwordAnswer = _answerPasswordQuestion(vault, normalizedQuestion);
    if (passwordAnswer != null) {
      _lastCitations = const [];
      return passwordAnswer;
    }

    final ragContext = _ragEngine.retrieve(vault, question, topK: 3);
    _lastCitations = ragContext
        .asMap()
        .entries
        .map(
          (entry) => AiCitation(
            label: 'S${entry.key + 1}',
            sourceId: entry.value.sourceId,
            sourceType: entry.value.sourceType,
            title: entry.value.title,
            excerpt: entry.value.text,
            score: entry.value.score,
          ),
        )
        .toList();

    if (ragContext.isEmpty) {
      return 'I could not find matching local data.';
    }

    final expiryAnswer = _answerExpiryQuestion(normalizedQuestion, ragContext);
    if (expiryAnswer != null) {
      return expiryAnswer;
    }

    final focusedAnswer = _answerFromTopChunk(normalizedQuestion, ragContext);
    if (focusedAnswer != null) {
      return focusedAnswer;
    }

    final lines = <String>[];
    for (var i = 0; i < ragContext.length; i++) {
      final chunk = ragContext[i];
      lines.add(
        '- ${chunk.sourceType}: ${chunk.title} [S${i + 1}]\n  ${_truncate(chunk.text)}',
      );
    }
    return 'Here is what I found in your local data:\n${lines.join('\n')}';
  }

  String? _answerPasswordQuestion(VaultData vault, String question) {
    final asksCredentials =
        question.contains('password') ||
        question.contains('username') ||
        question.contains('account number') ||
        question.contains('account no') ||
        question.contains('login');
    if (!asksCredentials) return null;

    if (vault.passwords.isEmpty) return null;

    VaultPassword? best;
    var bestScore = 0;
    for (final item in vault.passwords) {
      final account = item.accountName.toLowerCase();
      var score = 0;
      if (question.contains(account)) {
        score += 20;
      }

      final accountTokens = account
          .split(RegExp(r'\s+'))
          .where((token) => token.trim().length >= 3)
          .toList();
      for (final token in accountTokens) {
        if (question.contains(token)) {
          score += 3;
        }
      }

      if (score > bestScore) {
        bestScore = score;
        best = item;
      }
    }

    if (best == null || bestScore == 0) return null;

    if (question.contains('username') || question.contains('user name')) {
      return 'Sensitive info from your local vault: ${best.accountName} username is ${best.username}.';
    }
    if (question.contains('password')) {
      return 'Sensitive info from your local vault: ${best.accountName} password is ${best.password}.';
    }
    if (question.contains('account number') ||
        question.contains('account no') ||
        question.contains('account #')) {
      final candidate =
          _extractNumericToken(best.username) ??
          _extractNumericToken(best.password);
      if (candidate != null) {
        return 'Sensitive info from your local vault: ${best.accountName} account number appears to be $candidate.';
      }
      return 'I found ${best.accountName}, but no clear account number is stored in its username/password fields.';
    }

    return 'Sensitive info from your local vault: ${best.accountName} username is ${best.username}.';
  }

  String? _answerExpiryQuestion(String question, List<RagChunk> ragContext) {
    if (!question.contains('expir')) return null;
    final top = ragContext.first;
    final extractedDate = _extractDate(top.text);
    if (extractedDate == null) {
      return 'I found relevant data in ${top.title} [S1], but I could not detect a clear expiry date.';
    }
    return 'From your local data, ${top.title} appears to expire on $extractedDate [S1].';
  }

  String? _answerFromTopChunk(String question, List<RagChunk> ragContext) {
    if (ragContext.isEmpty) return null;
    final top = ragContext.first;

    final asksWhen =
        question.startsWith('when ') || question.contains(' when ');
    final asksWhat =
        question.startsWith('what ') ||
        question.startsWith("what's") ||
        question.contains(' what ');

    if (asksWhen) {
      final extractedDate = _extractDate(top.text);
      if (extractedDate != null) {
        return 'According to your local data, this is scheduled for $extractedDate [S1].';
      }
    }

    if (asksWhat || question.contains('show')) {
      return 'From your local data: ${_truncate(top.text)} [S1]';
    }

    return null;
  }

  String? _extractNumericToken(String input) {
    final match = RegExp(r'\b\d{6,}\b').firstMatch(input);
    return match?.group(0);
  }

  String? _extractDate(String text) {
    final iso = RegExp(r'\b\d{4}-\d{2}-\d{2}\b').firstMatch(text);
    if (iso != null) return iso.group(0);

    final slashed = RegExp(r'\b\d{1,2}[/-]\d{1,2}[/-]\d{4}\b').firstMatch(text);
    if (slashed != null) return slashed.group(0);

    final named = RegExp(
      r'\b(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\s+\d{1,2},?\s+\d{4}\b',
      caseSensitive: false,
    ).firstMatch(text);
    return named?.group(0);
  }

  String _truncate(String text, {int max = 180}) {
    final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length <= max) return clean;
    return '${clean.substring(0, max - 3)}...';
  }
}
