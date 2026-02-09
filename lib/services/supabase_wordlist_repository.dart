import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'custom_word_storage.dart';

class SupabaseWordlistException implements Exception {
  final String message;

  const SupabaseWordlistException(this.message);

  @override
  String toString() => message;
}

class SupabaseConfig {
  final String baseUrl;
  final String anonKey;

  const SupabaseConfig({
    required this.baseUrl,
    required this.anonKey,
  });

  static SupabaseConfig? fromEnvironment() {
    const urlRaw = String.fromEnvironment('SUPABASE_URL');
    const anonRaw = String.fromEnvironment('SUPABASE_ANON_KEY');
    final url = urlRaw.trim();
    final anonKey = anonRaw.trim();
    if (url.isEmpty || anonKey.isEmpty) {
      return null;
    }
    final parsed = Uri.tryParse(url);
    if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
      return null;
    }
    return SupabaseConfig(baseUrl: url, anonKey: anonKey);
  }
}

class SupabaseAuthContext {
  final String userId;
  final String accessToken;

  const SupabaseAuthContext({
    required this.userId,
    required this.accessToken,
  });
}

abstract class SupabaseAuthProvider {
  Future<SupabaseAuthContext?> current();
}

class SupabaseSessionAuthProvider implements SupabaseAuthProvider {
  const SupabaseSessionAuthProvider();

  @override
  Future<SupabaseAuthContext?> current() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      final user = session?.user;
      final token = session?.accessToken;
      if (user == null || token == null || token.trim().isEmpty) {
        return null;
      }
      return SupabaseAuthContext(
        userId: user.id,
        accessToken: token,
      );
    } catch (_) {
      // Supabase SDK is not initialized yet.
      return null;
    }
  }
}

class EnvSupabaseAuthProvider implements SupabaseAuthProvider {
  const EnvSupabaseAuthProvider();

  static const _userId = String.fromEnvironment('SUPABASE_USER_ID');
  static const _accessToken = String.fromEnvironment('SUPABASE_ACCESS_TOKEN');

  @override
  Future<SupabaseAuthContext?> current() async {
    final userId = _userId.trim();
    final accessToken = _accessToken.trim();
    if (userId.isEmpty || accessToken.isEmpty) {
      return null;
    }
    return SupabaseAuthContext(userId: userId, accessToken: accessToken);
  }
}

class CompositeSupabaseAuthProvider implements SupabaseAuthProvider {
  final List<SupabaseAuthProvider> providers;

  const CompositeSupabaseAuthProvider(this.providers);

  @override
  Future<SupabaseAuthContext?> current() async {
    for (final provider in providers) {
      final result = await provider.current();
      if (result != null) return result;
    }
    return null;
  }
}

abstract class WordlistRepository {
  Future<List<CustomWordList>> fetchListsForUser();

  Future<CustomWordList> createList({
    required String title,
    required String language,
    required WordListSource source,
    required List<String> items,
  });

  Future<void> renameList({
    required String id,
    required String title,
  });

  Future<void> deleteList(String id);

  Future<void> upsertItemsBatch({
    required String wordlistId,
    required List<String> items,
  });
}

class SupabaseWordlistRepository implements WordlistRepository {
  final SupabaseConfig config;
  final SupabaseAuthProvider authProvider;
  final http.Client _client;

  SupabaseWordlistRepository({
    required this.config,
    required this.authProvider,
    http.Client? client,
  }) : _client = client ?? http.Client();

  static SupabaseWordlistRepository? fromEnvironment() {
    final config = SupabaseConfig.fromEnvironment();
    if (config == null) return null;
    return SupabaseWordlistRepository(
      config: config,
      authProvider: const CompositeSupabaseAuthProvider(
        <SupabaseAuthProvider>[
          SupabaseSessionAuthProvider(),
          EnvSupabaseAuthProvider(), // Dev fallback
        ],
      ),
    );
  }

  @override
  Future<List<CustomWordList>> fetchListsForUser() async {
    final auth = await _requireAuth();
    final uri = _restUri(
      'wordlists',
      query: <String, String>{
        'select':
            'id,title,language,source,created_at,updated_at,wordlist_items(term,position)',
        'order': 'created_at.desc',
      },
    );

    final response = await _client.get(uri, headers: _headers(auth));
    _ensureSuccess(response, operation: 'Listen laden');

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const SupabaseWordlistException('Ungültige Antwort beim Laden.');
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(mapSupabaseWordlistRow)
        .toList();
  }

  @override
  Future<CustomWordList> createList({
    required String title,
    required String language,
    required WordListSource source,
    required List<String> items,
  }) async {
    final auth = await _requireAuth();
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final createUri = _restUri('wordlists');
    final createResponse = await _client.post(
      createUri,
      headers: _headers(auth, withRepresentation: true),
      body: jsonEncode(<String, dynamic>{
        'title': title,
        'language': language,
        'source': source.dbValue,
        'updated_at': nowIso,
      }),
    );
    _ensureSuccess(createResponse, operation: 'Liste erstellen');

    final decoded = jsonDecode(createResponse.body);
    if (decoded is! List || decoded.isEmpty) {
      throw const SupabaseWordlistException(
        'Liste wurde erstellt, aber Antwort war leer.',
      );
    }

    final createdRow = decoded.first;
    if (createdRow is! Map<String, dynamic>) {
      throw const SupabaseWordlistException('Ungültige Liste nach Erstellung.');
    }

    final listId = createdRow['id']?.toString();
    if (listId == null || listId.isEmpty) {
      throw const SupabaseWordlistException(
        'Erstellte Liste enthält keine ID.',
      );
    }

    await upsertItemsBatch(wordlistId: listId, items: items);

    final withItems = <String, dynamic>{
      ...createdRow,
      'wordlist_items': List.generate(
        items.length,
        (index) => <String, dynamic>{
          'term': items[index],
          'position': index,
        },
      ),
    };
    return mapSupabaseWordlistRow(withItems);
  }

  @override
  Future<void> renameList({
    required String id,
    required String title,
  }) async {
    final auth = await _requireAuth();
    final uri = _restUri(
      'wordlists',
      query: <String, String>{'id': 'eq.$id'},
    );
    final response = await _client.patch(
      uri,
      headers: _headers(auth),
      body: jsonEncode(<String, dynamic>{
        'title': title,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }),
    );
    _ensureSuccess(response, operation: 'Liste umbenennen');
  }

  @override
  Future<void> deleteList(String id) async {
    final auth = await _requireAuth();
    final uri = _restUri(
      'wordlists',
      query: <String, String>{'id': 'eq.$id'},
    );
    final response = await _client.delete(uri, headers: _headers(auth));
    _ensureSuccess(response, operation: 'Liste löschen');
  }

  @override
  Future<void> upsertItemsBatch({
    required String wordlistId,
    required List<String> items,
  }) async {
    final auth = await _requireAuth();

    final deleteUri = _restUri(
      'wordlist_items',
      query: <String, String>{'wordlist_id': 'eq.$wordlistId'},
    );
    final deleteResponse =
        await _client.delete(deleteUri, headers: _headers(auth));
    _ensureSuccess(deleteResponse, operation: 'Alte Begriffe entfernen');

    if (items.isEmpty) return;

    final insertUri = _restUri('wordlist_items');
    final rows = List.generate(
      items.length,
      (index) => <String, dynamic>{
        'wordlist_id': wordlistId,
        'term': items[index],
        'position': index,
      },
    );

    final insertResponse = await _client.post(
      insertUri,
      headers: _headers(auth),
      body: jsonEncode(rows),
    );
    _ensureSuccess(insertResponse, operation: 'Begriffe speichern');
  }

  Future<SupabaseAuthContext> _requireAuth() async {
    final auth = await authProvider.current();
    if (auth == null) {
      throw const SupabaseWordlistException(
        'Supabase Auth fehlt. Bitte zuerst einloggen '
        '(Session) oder lokal SUPABASE_USER_ID/SUPABASE_ACCESS_TOKEN setzen.',
      );
    }
    return auth;
  }

  Map<String, String> _headers(
    SupabaseAuthContext auth, {
    bool withRepresentation = false,
  }) {
    return <String, String>{
      'apikey': config.anonKey,
      'Authorization': 'Bearer ${auth.accessToken}',
      'Content-Type': 'application/json',
      if (withRepresentation) 'Prefer': 'return=representation',
    };
  }

  Uri _restUri(String path, {Map<String, String>? query}) {
    final base = config.baseUrl.endsWith('/')
        ? config.baseUrl.substring(0, config.baseUrl.length - 1)
        : config.baseUrl;
    final uri = Uri.parse('$base/rest/v1/$path');
    if (query == null || query.isEmpty) {
      return uri;
    }
    return uri.replace(queryParameters: query);
  }

  void _ensureSuccess(http.Response response, {required String operation}) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    final body = response.body.trim();
    final details = body.isEmpty ? '' : ' $body';
    throw SupabaseWordlistException(
      '$operation fehlgeschlagen (HTTP ${response.statusCode}).$details',
    );
  }
}

@visibleForTesting
CustomWordList mapSupabaseWordlistRow(Map<String, dynamic> row) {
  final createdAt = _parseTimestamp(row['created_at']);
  final updatedAt = _parseTimestamp(row['updated_at']) ?? createdAt;
  final title = row['title']?.toString().trim();
  if (title == null || title.isEmpty) {
    throw const FormatException('wordlist row without title');
  }

  return CustomWordList(
    id: row['id']?.toString() ?? '',
    title: title,
    words: mapSupabaseItems(row['wordlist_items']),
    createdAt: createdAt ?? DateTime.now(),
    updatedAt: updatedAt ?? DateTime.now(),
    lastPlayedAt: null,
    language: row['language']?.toString() ?? 'de',
    source: WordListSource.fromStorageValue(row['source']?.toString()),
  );
}

@visibleForTesting
List<String> mapSupabaseItems(dynamic rawItems) {
  if (rawItems is! List) {
    return <String>[];
  }

  final pairs = <MapEntry<int, String>>[];
  for (final entry in rawItems) {
    if (entry is! Map<String, dynamic>) continue;
    final term = entry['term']?.toString().trim();
    if (term == null || term.isEmpty) continue;
    final position = (entry['position'] as num?)?.toInt() ?? 0;
    pairs.add(MapEntry(position, term));
  }

  pairs.sort((a, b) => a.key.compareTo(b.key));
  return pairs.map((entry) => entry.value).toList(growable: false);
}

DateTime? _parseTimestamp(dynamic raw) {
  final value = raw?.toString();
  if (value == null || value.isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}
