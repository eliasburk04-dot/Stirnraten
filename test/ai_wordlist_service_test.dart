import 'package:flutter_test/flutter_test.dart';
import 'package:stirnraten/services/ai_wordlist_service.dart';

void main() {
  test('parses strict JSON response', () {
    const body =
        '{"title":"Fußball (easy)","language":"de","items":["Torwart","Ecke","Abseits"]}';

    final parsed = HttpAIWordlistService.parseAIResponse(body);

    expect(parsed.title, 'Fußball (easy)');
    expect(parsed.language, 'de');
    expect(parsed.items, ['Torwart', 'Ecke', 'Abseits']);
  });

  test('parses wrapped OpenAI-like response payload', () {
    const body =
        '{"choices":[{"message":{"content":"```json\\n{\\"title\\":\\"Football\\",\\"language\\":\\"en\\",\\"items\\":[\\"Penalty\\",\\"Corner Kick\\",\\"Coach\\"]}\\n```"}}]}';

    final parsed = HttpAIWordlistService.parseAIResponse(body);

    expect(parsed.title, 'Football');
    expect(parsed.language, 'en');
    expect(parsed.items.length, 3);
  });
}
