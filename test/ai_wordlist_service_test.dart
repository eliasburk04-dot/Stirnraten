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

  test('hard-resets supabase session for unauthorized 401 details', () {
    expect(
      shouldHardResetSupabaseSessionOn401('unauthorized'),
      isTrue,
    );
    expect(
      shouldHardResetSupabaseSessionOn401('missing_authorization'),
      isTrue,
    );
    expect(
      shouldHardResetSupabaseSessionOn401('auth_verify_failed'),
      isTrue,
    );
  });

  test('does not hard-reset supabase session for unrelated 401 details', () {
    expect(
      shouldHardResetSupabaseSessionOn401('rate_limited'),
      isFalse,
    );
    expect(
      shouldHardResetSupabaseSessionOn401(''),
      isFalse,
    );
  });
}
