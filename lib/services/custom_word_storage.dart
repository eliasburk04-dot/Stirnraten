import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

enum WordListSource {
  manual,
  ai;

  String get dbValue {
    switch (this) {
      case WordListSource.manual:
        return 'manual';
      case WordListSource.ai:
        return 'ai';
    }
  }

  static WordListSource fromStorageValue(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'ai':
        return WordListSource.ai;
      case 'manual':
      default:
        return WordListSource.manual;
    }
  }
}

class CustomWordList {
  final String id;
  final String title;
  final List<String> words;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastPlayedAt;
  final String language;
  final WordListSource source;

  const CustomWordList({
    required this.id,
    required this.title,
    required this.words,
    required this.createdAt,
    required this.updatedAt,
    this.lastPlayedAt,
    this.language = 'de',
    this.source = WordListSource.manual,
  });

  int get wordCount => words.length;

  CustomWordList copyWith({
    String? id,
    String? title,
    List<String>? words,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastPlayedAt,
    String? language,
    WordListSource? source,
  }) {
    return CustomWordList(
      id: id ?? this.id,
      title: title ?? this.title,
      words: words ?? this.words,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      language: language ?? this.language,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'words': words,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'lastPlayedAt': lastPlayedAt?.millisecondsSinceEpoch,
      'language': language,
      'source': source.dbValue,
    };
  }

  factory CustomWordList.fromMap(Map<String, dynamic> map) {
    return CustomWordList(
      id: map['id']?.toString() ?? const Uuid().v4(),
      title: map['title']?.toString() ?? '',
      words: List<String>.from(map['words'] ?? const <String>[]),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['createdAt'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['updatedAt'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      ),
      lastPlayedAt: map['lastPlayedAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              (map['lastPlayedAt'] as num).toInt(),
            ),
      language: map['language']?.toString() ?? 'de',
      source: WordListSource.fromStorageValue(map['source']?.toString()),
    );
  }
}

class CustomWordStorage {
  static const String _storageKey = 'custom_word_lists_v2';
  static const String _legacyKey = 'custom_categories';
  final Uuid _uuid = const Uuid();

  Future<List<CustomWordList>> getLists() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    if (jsonString == null) {
      final legacyString = prefs.getString(_legacyKey);
      if (legacyString == null) return [];
      final migrated = _migrateLegacy(legacyString);
      if (migrated.isNotEmpty) {
        await _saveToPrefs(migrated);
      }
      return migrated;
    }

    try {
      final decoded = json.decode(jsonString) as List<dynamic>;
      return decoded
          .map((item) => CustomWordList.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveList(CustomWordList list) async {
    final lists = await getLists();
    final index = lists.indexWhere((item) => item.id == list.id);
    if (index >= 0) {
      lists[index] = list;
    } else {
      lists.add(list);
    }
    lists.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _saveToPrefs(lists);
  }

  Future<void> updateList(CustomWordList list) async {
    await saveList(list);
  }

  Future<void> deleteList(String id) async {
    final lists = await getLists();
    lists.removeWhere((item) => item.id == id);
    await _saveToPrefs(lists);
  }

  Future<void> markPlayed(String id) async {
    final lists = await getLists();
    final index = lists.indexWhere((item) => item.id == id);
    if (index == -1) return;
    final updated = lists[index].copyWith(
      lastPlayedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    lists[index] = updated;
    lists.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _saveToPrefs(lists);
  }

  CustomWordList buildNewList({
    required String title,
    required List<String> words,
    String language = 'de',
    WordListSource source = WordListSource.manual,
  }) {
    final now = DateTime.now();
    return CustomWordList(
      id: _uuid.v4(),
      title: title,
      words: words,
      createdAt: now,
      updatedAt: now,
      lastPlayedAt: null,
      language: language,
      source: source,
    );
  }

  Future<void> _saveToPrefs(List<CustomWordList> lists) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(lists.map((list) => list.toMap()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  List<CustomWordList> _migrateLegacy(String legacyString) {
    try {
      final decoded = json.decode(legacyString) as List<dynamic>;
      final now = DateTime.now();
      return decoded.map((item) {
        final map = item as Map<String, dynamic>;
        return CustomWordList(
          id: _uuid.v4(),
          title: map['name']?.toString() ?? 'Eigene Liste',
          words: List<String>.from(map['words'] ?? const <String>[]),
          createdAt: now,
          updatedAt: now,
          lastPlayedAt: null,
          language: 'de',
          source: WordListSource.manual,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }
}
