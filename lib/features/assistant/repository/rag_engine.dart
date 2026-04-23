import '../../../models/vault_model.dart';

class RagChunk {
  const RagChunk({
    required this.sourceId,
    required this.sourceType,
    required this.title,
    required this.text,
    required this.score,
  });

  final String sourceId;
  final String sourceType;
  final String title;
  final String text;
  final double score;
}

class _RawChunk {
  const _RawChunk({
    required this.sourceId,
    required this.sourceType,
    required this.title,
    required this.text,
  });

  final String sourceId;
  final String sourceType;
  final String title;
  final String text;
}

class VaultRagEngine {
  static const _k1 = 1.5;
  static const _b = 0.75;

  static final RegExp _tokenPattern = RegExp(r'[a-z0-9]{2,}');
  static const Set<String> _stopwords = {
    'the',
    'is',
    'are',
    'a',
    'an',
    'to',
    'for',
    'of',
    'in',
    'on',
    'at',
    'and',
    'or',
    'my',
    'me',
    'what',
    'which',
    'where',
    'when',
    'how',
    'with',
    'from',
    'show',
    'tell',
    'about',
    'please',
  };

  List<RagChunk> retrieve(
    VaultData vault,
    String query, {
    int topK = 6,
  }) {
    final corpus = _buildCorpus(vault);
    if (corpus.isEmpty) return const [];

    final queryTerms = _tokenize(query);
    if (queryTerms.isEmpty) return const [];

    final docsTerms = <List<String>>[];
    final docsTf = <Map<String, int>>[];
    final docFreq = <String, int>{};
    var totalDocLength = 0;

    for (final chunk in corpus) {
      final terms = _tokenize('${chunk.title} ${chunk.text}');
      docsTerms.add(terms);
      totalDocLength += terms.length;

      final tf = <String, int>{};
      for (final term in terms) {
        tf[term] = (tf[term] ?? 0) + 1;
      }
      docsTf.add(tf);

      for (final term in tf.keys) {
        docFreq[term] = (docFreq[term] ?? 0) + 1;
      }
    }

    final avgDl = corpus.isEmpty ? 1 : totalDocLength / corpus.length;
    final scored = <RagChunk>[];

    for (var i = 0; i < corpus.length; i++) {
      final chunk = corpus[i];
      final tf = docsTf[i];
      final dl = docsTerms[i].length;
      var score = 0.0;

      for (final term in queryTerms) {
        final freq = tf[term] ?? 0;
        if (freq == 0) continue;

        final df = docFreq[term] ?? 0;
        final idf = _idf(corpus.length, df);
        final numerator = freq * (_k1 + 1.0);
        final denominator = freq + _k1 * (1.0 - _b + _b * (dl / avgDl));
        score += idf * (numerator / denominator);
      }

      final lowerQuery = query.toLowerCase().trim();
      final lowerText = '${chunk.title} ${chunk.text}'.toLowerCase();
      if (lowerText.contains(lowerQuery) && lowerQuery.isNotEmpty) {
        score += 2.5;
      }
      if (queryTerms.any(chunk.title.toLowerCase().contains)) {
        score += 1.0;
      }

      if (score > 0) {
        scored.add(
          RagChunk(
            sourceId: chunk.sourceId,
            sourceType: chunk.sourceType,
            title: chunk.title,
            text: chunk.text,
            score: score,
          ),
        );
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    if (scored.length > topK) {
      return scored.sublist(0, topK);
    }
    return scored;
  }

  List<_RawChunk> _buildCorpus(VaultData vault) {
    final chunks = <_RawChunk>[];

    for (final note in vault.notes) {
      chunks.addAll(
        _chunkText(
          sourceId: note.id,
          sourceType: 'Note',
          title: note.title,
          text: note.content,
        ),
      );
    }

    for (final doc in vault.documents) {
      final body = doc.content.isNotEmpty ? doc.content : doc.fileName;
      chunks.addAll(
        _chunkText(
          sourceId: doc.id,
          sourceType: 'Document',
          title: doc.title,
          text: body,
        ),
      );
    }

    for (final password in vault.passwords) {
      chunks.add(
        _RawChunk(
          sourceId: password.id,
          sourceType: 'Password',
          title: password.accountName,
          text:
              'account ${password.accountName}, username ${password.username}, password ${password.password}',
        ),
      );
    }

    for (final event in vault.events) {
      chunks.add(
        _RawChunk(
          sourceId: event.id,
          sourceType: 'Event',
          title: event.title,
          text: '${event.startsAt.toIso8601String()} ${event.description}',
        ),
      );
    }

    return chunks;
  }

  List<_RawChunk> _chunkText({
    required String sourceId,
    required String sourceType,
    required String title,
    required String text,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const [];

    const maxLen = 320;
    const overlap = 64;

    if (trimmed.length <= maxLen) {
      return [
        _RawChunk(
          sourceId: sourceId,
          sourceType: sourceType,
          title: title,
          text: trimmed,
        ),
      ];
    }

    final output = <_RawChunk>[];
    var start = 0;
    while (start < trimmed.length) {
      final end = (start + maxLen).clamp(0, trimmed.length);
      final slice = trimmed.substring(start, end).trim();
      if (slice.isNotEmpty) {
        output.add(
          _RawChunk(
            sourceId: sourceId,
            sourceType: sourceType,
            title: title,
            text: slice,
          ),
        );
      }
      if (end == trimmed.length) break;
      start = (end - overlap).clamp(0, trimmed.length);
      if (start == end) {
        break;
      }
    }

    return output;
  }

  List<String> _tokenize(String input) {
    final matches = _tokenPattern
        .allMatches(input.toLowerCase())
        .map((m) => m.group(0)!)
        .where((token) => !_stopwords.contains(token))
        .toList();
    return matches;
  }

  double _idf(int totalDocs, int docFreq) {
    if (docFreq <= 0) return 0;
    return ((totalDocs - docFreq + 0.5) / (docFreq + 0.5) + 1.0);
  }
}
