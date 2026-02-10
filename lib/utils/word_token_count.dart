class WordTokenCount {
  static final RegExp _ws = RegExp(r'\s+');

  /// Counts "words" as whitespace-separated tokens across all items.
  /// Empty/whitespace-only items are ignored.
  static int count(Iterable<String> items) {
    var total = 0;
    for (final raw in items) {
      final s = raw.trim();
      if (s.isEmpty) continue;
      total += s.split(_ws).where((t) => t.isNotEmpty).length;
    }
    return total;
  }
}

