import 'package:flutter_test/flutter_test.dart';
import 'package:stirnraten/services/ai_wordlist_service.dart';

void main() {
  test('prefers explicit endpoint service over invoke fallback', () {
    final endpointService = _FakeAIWordlistService();
    final invokeService = _FakeAIWordlistService();

    final selected = selectPreferredAIWordlistService(
      endpointService: endpointService,
      invokeService: invokeService,
    );

    expect(selected, same(endpointService));
  });

  test('falls back to invoke service when endpoint service is unavailable', () {
    final invokeService = _FakeAIWordlistService();

    final selected = selectPreferredAIWordlistService(
      endpointService: null,
      invokeService: invokeService,
    );

    expect(selected, same(invokeService));
  });

  test('returns null when no AI service is configured', () {
    final selected = selectPreferredAIWordlistService(
      endpointService: null,
      invokeService: null,
    );

    expect(selected, isNull);
  });
}

class _FakeAIWordlistService implements AIWordlistService {
  @override
  Future<List<String>> generateWordlist({
    required AIWordlistRequest request,
  }) async =>
      const <String>[];

  @override
  Future<AIWordlistResult> generateWordlistResult({
    required AIWordlistRequest request,
  }) async =>
      const AIWordlistResult(
        title: 'Test',
        language: 'de',
        items: <String>[],
      );

  @override
  Stream<AIWordlistProgress> generateWordlistStream({
    required AIWordlistRequest request,
  }) async* {}
}
