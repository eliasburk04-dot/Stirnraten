import 'package:flutter_test/flutter_test.dart';
import 'package:stirnraten/services/wordlist_normalizer.dart';

void main() {
  test('normalizes, dedupes and trims requested count', () {
    final items = <String>[
      ' 1. Torwart ',
      'torwart',
      '- Ecke',
      'Abseits',
      'Freistoß',
      'VAR',
      'Bundesliga',
      'Weltmeisterschaft',
    ];

    final normalized = WordlistNormalizer.normalize(
      items: items,
      requestedCount: 5,
    );

    expect(normalized, ['Torwart', 'Ecke', 'Abseits', 'Freistoß', 'VAR']);
  });

  test('throws when fewer than minimum valid terms remain', () {
    expect(
      () => WordlistNormalizer.normalize(
        items: const ['', '  ', '1. Hallo Welt heute', '🤖'],
        requestedCount: 10,
      ),
      throwsA(isA<WordlistValidationException>()),
    );
  });
}
