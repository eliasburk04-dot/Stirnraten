import 'package:flutter_test/flutter_test.dart';
import 'package:stirnraten/services/custom_word_storage.dart';
import 'package:stirnraten/services/supabase_wordlist_repository.dart';

void main() {
  test('maps supabase row to CustomWordList', () {
    final row = <String, dynamic>{
      'id': 'f6f7de36-66c4-4bd3-bf55-2f7f4ad381f1',
      'title': 'Fußball AI',
      'language': 'de',
      'source': 'ai',
      'created_at': '2026-02-09T16:00:00Z',
      'updated_at': '2026-02-09T17:00:00Z',
      'wordlist_items': <Map<String, dynamic>>[
        {'term': 'Abseits', 'position': 2},
        {'term': 'Torwart', 'position': 0},
        {'term': 'Ecke', 'position': 1},
      ],
    };

    final mapped = mapSupabaseWordlistRow(row);

    expect(mapped.id, row['id']);
    expect(mapped.title, 'Fußball AI');
    expect(mapped.language, 'de');
    expect(mapped.source, WordListSource.ai);
    expect(mapped.words, ['Torwart', 'Ecke', 'Abseits']);
  });

  test('maps empty item payload safely', () {
    expect(mapSupabaseItems(null), isEmpty);
    expect(mapSupabaseItems(<dynamic>[]), isEmpty);
  });
}
