class WordlistValidationException implements Exception {
  final String message;

  const WordlistValidationException(this.message);

  @override
  String toString() => message;
}

class WordlistNormalizer {
  static final RegExp _whitespaceRegex = RegExp(r'\s+');
  static final RegExp _leadingBulletRegex =
      RegExp(r'^\s*(?:[-*•]+|\d+[.)]\s*)');
  static final RegExp _emojiRegex = RegExp(
    r'[\u{1F300}-\u{1FAFF}]',
    unicode: true,
  );

  static const Set<String> _defaultBlockedTerms = <String>{
    'nigger',
    'faggot',
    'kike',
    'spic',
    'rape',
    'vergewaltigung',
    'hurensohn',
    'fotze',
    'schlampe',
    'missgeburt',
  };

  static List<String> normalize({
    required Iterable<String> items,
    required int requestedCount,
    int minValid = 5,
    Set<String> blockedTerms = const <String>{},
  }) {
    if (requestedCount < 5 || requestedCount > 100) {
      throw const WordlistValidationException(
        'Anzahl muss zwischen 5 und 100 liegen.',
      );
    }

    final blocked = <String>{
      ..._defaultBlockedTerms,
      ...blockedTerms.map((entry) => entry.trim().toLowerCase()),
    }..removeWhere((entry) => entry.isEmpty);

    final seen = <String>{};
    final normalized = <String>[];

    for (final raw in items) {
      var term = raw.trim();
      if (term.isEmpty) continue;

      term = term.replaceFirst(_leadingBulletRegex, '');
      term = term.replaceAll(_whitespaceRegex, ' ').trim();
      if (term.isEmpty) continue;

      if (_emojiRegex.hasMatch(term)) {
        continue;
      }

      final tokenCount =
          term.split(' ').where((token) => token.isNotEmpty).length;
      if (tokenCount < 1 || tokenCount > 3) {
        continue;
      }

      final lower = term.toLowerCase();
      if (blocked.any((blockedTerm) => lower.contains(blockedTerm))) {
        continue;
      }

      if (seen.add(lower)) {
        normalized.add(term);
      }

      if (normalized.length >= requestedCount) {
        break;
      }
    }

    if (normalized.length < minValid) {
      throw const WordlistValidationException('Zu wenig valide Begriffe');
    }

    if (normalized.length > requestedCount) {
      return normalized.sublist(0, requestedCount);
    }
    return normalized;
  }
}
