class WordlistTerms {
  static final RegExp _leadingBulletRegex =
      RegExp(r'^\s*(?:[-*•]+|\d+[.)\-:]\s*)');

  /// Parses a user-entered blob into terms.
  ///
  /// - Commas are treated as separators (common paste format).
  /// - Newlines separate terms.
  /// - For long lines (> [maxPhraseWords] tokens), we split by whitespace to avoid
  ///   accidentally treating a pasted paragraph as a single "term".
  /// - Dedupes case-insensitively.
  static List<String> parse(
    String raw, {
    int maxPhraseWords = 3,
    int? cap,
  }) {
    final normalizedRaw = raw.replaceAll(',', '\n');
    final lines = normalizedRaw.split('\n');

    final seen = <String>{};
    final out = <String>[];

    void push(String term) {
      final t = term.trim();
      if (t.isEmpty) return;
      final key = t.toLowerCase();
      if (!seen.add(key)) return;
      out.add(t);
    }

    for (final line in lines) {
      var s = line.trim();
      if (s.isEmpty) continue;

      s = s.replaceFirst(_leadingBulletRegex, '').trim();
      if (s.isEmpty) continue;

      final tokens =
          s.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
      if (tokens.length > maxPhraseWords) {
        for (final token in tokens) {
          push(token);
          if (cap != null && out.length >= cap) return out;
        }
      } else {
        push(tokens.join(' '));
        if (cap != null && out.length >= cap) return out;
      }
    }

    return out;
  }
}
