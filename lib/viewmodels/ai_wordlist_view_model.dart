import 'package:flutter/foundation.dart';

import '../services/ai_wordlist_service.dart';
import '../services/custom_word_storage.dart';
import '../services/supabase_wordlist_repository.dart';
import '../services/wordlist_normalizer.dart';

enum AIWordlistUiState {
  idle,
  loading,
  preview,
  saving,
  error,
}

class AIWordlistViewModel extends ChangeNotifier {
  final AIWordlistService aiService;
  final WordlistRepository repository;

  AIWordlistUiState state = AIWordlistUiState.idle;
  String? errorMessage;
  double progress = 0;
  String progressLabel = '';

  String topic = '';
  String language = 'de';
  AIWordlistDifficulty difficulty = AIWordlistDifficulty.medium;
  int count = 30;
  String tagsRaw = '';
  String title = '';
  bool includeHints = false;

  List<String> previewItems = <String>[];

  AIWordlistViewModel({
    required this.aiService,
    required this.repository,
  });

  bool get canGenerate =>
      topic.trim().length >= 2 &&
      count >= 5 &&
      count <= 100 &&
      state != AIWordlistUiState.loading &&
      state != AIWordlistUiState.saving;

  bool get canSave =>
      previewItems.length >= 5 &&
      state != AIWordlistUiState.loading &&
      state != AIWordlistUiState.saving;

  List<String> _parsedTags() {
    return tagsRaw
        .split(',')
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
  }

  AIWordlistRequest _buildRequest() {
    return AIWordlistRequest(
      topic: topic,
      language: language,
      difficulty: difficulty,
      count: count,
      styleTags: _parsedTags(),
      includeHints: includeHints,
      title: title.trim().isEmpty ? null : title.trim(),
    );
  }

  Future<void> generate() async {
    final request = _buildRequest();

    state = AIWordlistUiState.loading;
    errorMessage = null;
    progress = 0;
    progressLabel = 'Starte ...';
    notifyListeners();

    try {
      await for (final step
          in aiService.generateWordlistStream(request: request)) {
        progress = step.progress;
        progressLabel = step.message;
        if (step.result != null) {
          previewItems = step.result!.items;
          if (title.trim().isEmpty) {
            title = step.result!.title;
          }
        }
        notifyListeners();
      }

      state = AIWordlistUiState.preview;
      errorMessage = null;
      notifyListeners();
    } catch (error) {
      state = AIWordlistUiState.error;
      errorMessage = error.toString();
      notifyListeners();
    }
  }

  Future<void> regenerate() async {
    await generate();
  }

  void updateItem(int index, String value) {
    if (index < 0 || index >= previewItems.length) return;
    previewItems[index] = value;
    notifyListeners();
  }

  void removeItemAt(int index) {
    if (index < 0 || index >= previewItems.length) return;
    previewItems.removeAt(index);
    notifyListeners();
  }

  Future<CustomWordList?> save() async {
    if (!canSave) {
      errorMessage = 'Mindestens 5 Begriffe erforderlich.';
      state = AIWordlistUiState.error;
      notifyListeners();
      return null;
    }

    state = AIWordlistUiState.saving;
    errorMessage = null;
    notifyListeners();

    try {
      final normalized = WordlistNormalizer.normalize(
        items: previewItems,
        requestedCount: count,
      );

      final saved = await repository.createList(
        title: title.trim().isEmpty
            ? '${topic.trim()} (${_difficultyLabelDe(difficulty)})'
            : title.trim(),
        language: language,
        source: WordListSource.ai,
        items: normalized,
      );

      state = AIWordlistUiState.preview;
      notifyListeners();
      return saved;
    } on WordlistValidationException catch (error) {
      state = AIWordlistUiState.error;
      errorMessage = error.message;
      notifyListeners();
      return null;
    } catch (error) {
      state = AIWordlistUiState.error;
      errorMessage = error.toString();
      notifyListeners();
      return null;
    }
  }

  static String _difficultyLabelDe(AIWordlistDifficulty difficulty) {
    switch (difficulty) {
      case AIWordlistDifficulty.easy:
        return 'Leicht';
      case AIWordlistDifficulty.medium:
        return 'Mittel';
      case AIWordlistDifficulty.hard:
        return 'Schwer';
    }
  }
}
