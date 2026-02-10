import 'package:flutter_test/flutter_test.dart';
import 'package:stirnraten/utils/wordlist_terms.dart';

void main() {
  test('WordlistTerms.parse dedupes case-insensitively', () {
    final terms = WordlistTerms.parse('Harry Potter\nharry potter\nHARRY POTTER');
    expect(terms, ['Harry Potter']);
  });

  test('WordlistTerms.parse splits very long lines by whitespace', () {
    final terms = WordlistTerms.parse('a b c d');
    expect(terms, ['a', 'b', 'c', 'd']);
  });

  test('WordlistTerms.parse keeps short phrases (<= 3 words) as a term', () {
    final terms = WordlistTerms.parse('corner kick');
    expect(terms, ['corner kick']);
  });
}
