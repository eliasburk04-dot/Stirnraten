import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stirnraten/services/ai_wordlist_service.dart';

void main() {
  test('AI wordlist generation fills up to the requested count', () async {
    final calls = <Map<String, dynamic>>[];

    final client = MockClient((req) async {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      calls.add(body);

      // First response: lots of duplicates/invalid items, so normalization yields < 30.
      if (calls.length == 1) {
        final items = <String>[
          // 20 valid unique
          for (var i = 0; i < 20; i++) 'Begriff$i',
          // duplicates
          for (var i = 0; i < 10; i++) 'Begriff1',
          // invalid: emoji, sentence, bullets
          '😀 Emoji',
          'Das ist ein ganzer Satz mit vielen Wörtern',
          '1. Nummeriert',
          '- Bullet',
        ];
        return http.Response(
          jsonEncode(<String, dynamic>{
            'title': 'Test',
            'language': 'de',
            'items': items,
          }),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }

      // Second response: enough additional unique items to reach 30.
      final items = <String>[
        for (var i = 20; i < 60; i++) 'Begriff$i',
      ];
      return http.Response(
        jsonEncode(<String, dynamic>{
          'title': 'Test',
          'language': 'de',
          'items': items,
        }),
        200,
        headers: const <String, String>{'content-type': 'application/json'},
      );
    });

    final service = HttpAIWordlistService(
      config: AIWordlistApiConfig(
        endpoint: Uri.parse('https://example.com/ai'),
        appToken: 'APP_TOKEN_TEST',
        supabaseAnonKey: '',
      ),
      client: client,
    );

    final result = await service.generateWordlistResult(
      request: const AIWordlistRequest(
        topic: 'Fußball',
        language: 'de',
        difficulty: AIWordlistDifficulty.easy,
        count: 30,
      ),
    );

    expect(result.items.length, 30);
    expect(calls.length, 2);

    // Follow-up request should contain an exclude list in instructions.
    final secondInstructions = (calls[1]['instructions'] as String).toLowerCase();
    expect(secondInstructions.contains('do not include any terms from'), isTrue);
  });

  test('AI wordlist generation throws if it cannot reach requested count', () async {
    final client = MockClient((req) async {
      return http.Response(
        jsonEncode(<String, dynamic>{
          'title': 'Test',
          'language': 'de',
          // Always duplicates -> never enough unique terms.
          'items': List<String>.filled(50, 'Duplikat'),
        }),
        200,
        headers: const <String, String>{'content-type': 'application/json'},
      );
    });

    final service = HttpAIWordlistService(
      config: AIWordlistApiConfig(
        endpoint: Uri.parse('https://example.com/ai'),
        appToken: 'APP_TOKEN_TEST',
        supabaseAnonKey: '',
      ),
      client: client,
    );

    await expectLater(
      () => service.generateWordlistResult(
        request: const AIWordlistRequest(
          topic: 'Fußball',
          language: 'de',
          difficulty: AIWordlistDifficulty.easy,
          count: 30,
        ),
      ),
      throwsA(isA<AIWordlistException>()),
    );
  });
}

