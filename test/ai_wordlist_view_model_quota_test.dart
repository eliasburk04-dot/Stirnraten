import 'package:flutter_test/flutter_test.dart';
import 'package:stirnraten/monetization/ai_usage_snapshot.dart';
import 'package:stirnraten/services/ai_wordlist_service.dart';
import 'package:stirnraten/services/custom_word_storage.dart';
import 'package:stirnraten/services/supabase_wordlist_repository.dart';
import 'package:stirnraten/viewmodels/ai_wordlist_view_model.dart';

void main() {
  test('sets quota flag and usage on AIQuotaExceededException', () async {
    final service = _ThrowingQuotaService();
    final vm = AIWordlistViewModel(
      aiService: service,
      repository: _NoopWordlistRepository(),
    )
      ..topic = 'Bundesliga'
      ..count = 20;

    await vm.generate();

    expect(vm.state, AIWordlistUiState.error);
    expect(vm.lastErrorWasQuotaExceeded, isTrue);
    expect(vm.lastUsage, isNotNull);
    expect(vm.lastUsage!.used, 3);
    expect(vm.errorMessage, contains('Premium = unbegrenzt'));
  });

  test('clears quota flag after successful generation', () async {
    final service = _ScriptedQuotaThenSuccessService();
    final vm = AIWordlistViewModel(
      aiService: service,
      repository: _NoopWordlistRepository(),
    )
      ..topic = 'Bundesliga'
      ..count = 5;

    await vm.generate();
    expect(vm.lastErrorWasQuotaExceeded, isTrue);

    await vm.generate();
    expect(vm.state, AIWordlistUiState.preview);
    expect(vm.lastErrorWasQuotaExceeded, isFalse);
    expect(vm.previewItems.length, 5);
  });
}

class _ThrowingQuotaService implements AIWordlistService {
  @override
  Future<List<String>> generateWordlist({
    required AIWordlistRequest request,
  }) async {
    throw const AIQuotaExceededException(
      'Heute sind 3 KI-Generierungen frei. Premium = unbegrenzt.',
      usage: AiUsageSnapshot(
        dateKey: '2026-02-11',
        used: 3,
        limit: 3,
        isPremium: false,
      ),
    );
  }

  @override
  Future<AIWordlistResult> generateWordlistResult({
    required AIWordlistRequest request,
  }) async {
    throw const AIQuotaExceededException(
      'Heute sind 3 KI-Generierungen frei. Premium = unbegrenzt.',
      usage: AiUsageSnapshot(
        dateKey: '2026-02-11',
        used: 3,
        limit: 3,
        isPremium: false,
      ),
    );
  }

  @override
  Stream<AIWordlistProgress> generateWordlistStream({
    required AIWordlistRequest request,
  }) async* {
    throw const AIQuotaExceededException(
      'Heute sind 3 KI-Generierungen frei. Premium = unbegrenzt.',
      usage: AiUsageSnapshot(
        dateKey: '2026-02-11',
        used: 3,
        limit: 3,
        isPremium: false,
      ),
    );
  }
}

class _ScriptedQuotaThenSuccessService implements AIWordlistService {
  int _calls = 0;

  @override
  Future<List<String>> generateWordlist({
    required AIWordlistRequest request,
  }) async {
    final result = await generateWordlistResult(request: request);
    return result.items;
  }

  @override
  Future<AIWordlistResult> generateWordlistResult({
    required AIWordlistRequest request,
  }) async {
    _calls += 1;
    if (_calls == 1) {
      throw const AIQuotaExceededException(
        'Heute sind 3 KI-Generierungen frei. Premium = unbegrenzt.',
        usage: AiUsageSnapshot(
          dateKey: '2026-02-11',
          used: 3,
          limit: 3,
          isPremium: false,
        ),
      );
    }
    return const AIWordlistResult(
      title: 'Bundesliga',
      language: 'de',
      items: <String>['Tor', 'Ecke', 'Abseits', 'Elfmeter', 'Dribbling'],
      usage: AiUsageSnapshot(
        dateKey: '2026-02-11',
        used: 4,
        limit: 999,
        isPremium: true,
      ),
    );
  }

  @override
  Stream<AIWordlistProgress> generateWordlistStream({
    required AIWordlistRequest request,
  }) async* {
    final result = await generateWordlistResult(request: request);
    yield AIWordlistProgress(
      stage: AIWordlistProgressStage.done,
      progress: 1,
      message: 'Fertig.',
      result: result,
    );
  }
}

class _NoopWordlistRepository implements WordlistRepository {
  @override
  Future<CustomWordList> createList({
    required String title,
    required String language,
    required WordListSource source,
    required List<String> items,
  }) async {
    final now = DateTime.now();
    return CustomWordList(
      id: '1',
      title: title,
      words: items,
      createdAt: now,
      updatedAt: now,
      language: language,
      source: source,
    );
  }

  @override
  Future<void> deleteList(String id) async {}

  @override
  Future<List<CustomWordList>> fetchListsForUser() async =>
      const <CustomWordList>[];

  @override
  Future<void> renameList({required String id, required String title}) async {}

  @override
  Future<void> upsertItemsBatch({
    required String wordlistId,
    required List<String> items,
  }) async {}
}
