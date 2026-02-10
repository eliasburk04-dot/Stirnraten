import 'package:flutter_test/flutter_test.dart';

import 'package:stirnraten/utils/word_token_count.dart';

void main() {
  test('WordTokenCount counts whitespace tokens across items', () {
    expect(WordTokenCount.count(['a', 'b c', '  ', 'd']), 4);
  });

  test('WordTokenCount ignores empty items', () {
    expect(WordTokenCount.count(['', '   ', '\n']), 0);
  });
}

