import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'wordlist_normalizer.dart';

enum AIWordlistDifficulty { easy, medium, hard }

class AIWordlistRequest {
  final String topic;
  final String language;
  final AIWordlistDifficulty difficulty;
  final int count;
  final List<String> styleTags;
  final bool includeHints;
  final String? title;

  const AIWordlistRequest({
    required this.topic,
    required this.language,
    required this.difficulty,
    required this.count,
    this.styleTags = const <String>[],
    this.includeHints = false,
    this.title,
  });

  void validate() {
    if (topic.trim().length < 2) {
      throw const AIWordlistException('Thema muss mindestens 2 Zeichen haben.');
    }
    if (count < 5 || count > 100) {
      throw const AIWordlistException('Anzahl muss zwischen 5 und 100 liegen.');
    }
    if (language != 'de' && language != 'en') {
      throw const AIWordlistException('Sprache muss de oder en sein.');
    }
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'topic': topic.trim(),
      'language': language,
      'difficulty': difficulty.name,
      'count': count,
      'styleTags': styleTags.where((tag) => tag.trim().isNotEmpty).toList(),
      'includeHints': includeHints,
      if (title != null && title!.trim().isNotEmpty) 'title': title!.trim(),
    };
  }
}

class AIWordlistResult {
  final String title;
  final String language;
  final List<String> items;

  const AIWordlistResult({
    required this.title,
    required this.language,
    required this.items,
  });
}

class AIWordlistResponse {
  final String title;
  final String language;
  final List<String> items;

  const AIWordlistResponse({
    required this.title,
    required this.language,
    required this.items,
  });

  factory AIWordlistResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    if (rawItems is! List) {
      throw const FormatException('items fehlt oder ist kein Array.');
    }

    final title = json['title']?.toString().trim();
    final language = json['language']?.toString().trim();
    if (title == null || title.isEmpty) {
      throw const FormatException('title fehlt.');
    }
    if (language == null || language.isEmpty) {
      throw const FormatException('language fehlt.');
    }

    return AIWordlistResponse(
      title: title,
      language: language,
      items: rawItems.map((entry) => entry.toString()).toList(growable: false),
    );
  }
}

class AIWordlistApiConfig {
  final Uri endpoint;
  final String appToken;
  final String supabaseAnonKey;
  final Duration timeout;
  final Duration minInterval;

  const AIWordlistApiConfig({
    required this.endpoint,
    required this.appToken,
    required this.supabaseAnonKey,
    this.timeout = const Duration(seconds: 30),
    this.minInterval = const Duration(seconds: 2),
  });

  static AIWordlistApiConfig? fromEnvironment() {
    const endpointRaw = String.fromEnvironment('AI_WORDLIST_ENDPOINT');
    const tokenRaw = String.fromEnvironment('APP_TOKEN');
    const supabaseAnonRaw = String.fromEnvironment('SUPABASE_ANON_KEY');
    final endpoint = endpointRaw.trim();
    final token = tokenRaw.trim();
    final supabaseAnonKey = supabaseAnonRaw.trim();
    if (endpoint.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(endpoint);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return null;
    }
    return AIWordlistApiConfig(
      endpoint: uri,
      appToken: token,
      supabaseAnonKey: supabaseAnonKey,
    );
  }
}

class AIWordlistException implements Exception {
  final String message;

  const AIWordlistException(this.message);

  @override
  String toString() => message;
}

class AIRateLimitException extends AIWordlistException {
  final Duration retryAfter;

  const AIRateLimitException(super.message, this.retryAfter);
}

enum AIWordlistProgressStage { requesting, parsing, normalizing, done }

class AIWordlistProgress {
  final AIWordlistProgressStage stage;
  final double progress;
  final String message;
  final AIWordlistResult? result;

  const AIWordlistProgress({
    required this.stage,
    required this.progress,
    required this.message,
    this.result,
  });
}

abstract class AIWordlistService {
  Future<List<String>> generateWordlist({required AIWordlistRequest request});

  Future<AIWordlistResult> generateWordlistResult({
    required AIWordlistRequest request,
  });

  Stream<AIWordlistProgress> generateWordlistStream({
    required AIWordlistRequest request,
  });
}

class HttpAIWordlistService implements AIWordlistService {
  final AIWordlistApiConfig config;
  final http.Client _client;

  DateTime? _lastCallAt;

  HttpAIWordlistService({
    required this.config,
    http.Client? client,
  }) : _client = client ?? http.Client();

  static HttpAIWordlistService? fromEnvironment() {
    final config = AIWordlistApiConfig.fromEnvironment();
    if (config == null) return null;
    return HttpAIWordlistService(config: config);
  }

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
    request.validate();
    _enforceRateLimit();

    // Groq sometimes returns duplicates/invalid items. To reliably hit the target count,
    // we over-request and (if still short after normalization) fetch additional batches
    // excluding already accepted terms.
    final targetCount = request.count;
    final rawPool = <String>[];
    List<String> normalized = <String>[];
    String? effectiveTitle;

    for (var attempt = 0; attempt < 3; attempt++) {
      final askCount = _computeAskCount(
        targetCount: targetCount,
        currentValidCount: normalized.length,
        attempt: attempt,
      );

      final payload = <String, dynamic>{
        'input': <String, dynamic>{
          ...request.toJson(),
          'count': askCount,
        },
        'instructions': _buildStrictPrompt(
          request,
          countOverride: askCount,
          excludeTerms: normalized,
        ),
        'responseSchema': <String, dynamic>{
          'type': 'object',
          'required': <String>['title', 'language', 'items'],
          'properties': <String, dynamic>{
            'title': <String, dynamic>{'type': 'string'},
            'language': <String, dynamic>{'type': 'string'},
            'items': <String, dynamic>{
              'type': 'array',
              'items': <String, dynamic>{'type': 'string'},
            },
          },
        },
      };

      http.Response response;
      try {
        response = await _postJsonWithSessionRecovery(payload: payload);
      } on TimeoutException {
        throw const AIWordlistException(
          'KI-Anfrage Timeout. Bitte erneut versuchen.',
        );
      } catch (error) {
        throw AIWordlistException('Netzwerkfehler bei KI-Anfrage: $error');
      }

      if (response.statusCode == 429) {
        throw const AIRateLimitException(
          'Zu viele KI-Anfragen. Bitte kurz warten.',
          Duration(seconds: 20),
        );
      }
      if (response.statusCode == 401) {
        final detail = _extractErrorDetail(response.body);
        throw AIWordlistException(
          'KI-Service nicht autorisiert (HTTP 401${detail.isEmpty ? '' : ': $detail'}). '
          'Prüfe: Supabase Anonymous Auth ist aktiv, '
          'AI_WORDLIST_ENDPOINT zeigt auf die Supabase Edge Function '
          'und SUPABASE_ANON_KEY ist gesetzt.',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = _extractErrorDetail(response.body);
        throw AIWordlistException(
          'KI-Service Fehler (HTTP ${response.statusCode}${detail.isEmpty ? '' : ': $detail'}).',
        );
      }

      final raw = parseAIResponse(response.body);
      effectiveTitle ??= raw.title;
      rawPool.addAll(raw.items);

      // Allow <5 during filling; enforce count at the end.
      normalized = WordlistNormalizer.normalize(
        items: rawPool,
        requestedCount: targetCount,
        minValid: 0,
      );

      if (normalized.length >= targetCount) {
        break;
      }
    }

    if (normalized.length < targetCount) {
      throw AIWordlistException(
        'Zu wenig valide Begriffe (${normalized.length}/$targetCount). '
        'Bitte erneut generieren.',
      );
    }

    return AIWordlistResult(
      title: request.title?.trim().isNotEmpty == true
          ? request.title!.trim()
          : (effectiveTitle ??
              '${request.topic.trim()} (${request.difficulty.name})'),
      language: request.language,
      items: normalized,
    );
  }

  static int _computeAskCount({
    required int targetCount,
    required int currentValidCount,
    required int attempt,
  }) {
    final remaining = (targetCount - currentValidCount).clamp(0, targetCount);
    if (attempt == 0) {
      final buffer = (targetCount ~/ 2).clamp(10, 35);
      return (targetCount + buffer).clamp(5, 100);
    }
    final followUp = remaining + 12;
    return followUp.clamp(5, 100);
  }

  Future<http.Response> _postJsonWithSessionRecovery({
    required Map<String, dynamic> payload,
  }) async {
    var response =
        await _postJsonWithAuth(uri: config.endpoint, payload: payload);
    if (response.statusCode != 401) return response;

    final detail = _extractErrorDetail(response.body).toLowerCase();
    final looksLikeInvalidJwt = detail.contains('invalid jwt') ||
        detail.contains('invalid_jwt') ||
        detail.contains('invalidjwttoken');

    if (looksLikeInvalidJwt) {
      await _hardResetSupabaseSession();
    } else {
      await _refreshSupabaseSessionIfPossible();
    }

    response = await _postJsonWithAuth(uri: config.endpoint, payload: payload);
    return response;
  }

  Future<http.Response> _postJsonWithAuth({
    required Uri uri,
    required Map<String, dynamic> payload,
  }) async {
    final bearerToken = await _resolveBearerToken();
    return await _client
        .post(
          uri,
          headers: <String, String>{
            'Content-Type': 'application/json',
            if (config.supabaseAnonKey.trim().isNotEmpty)
              'apikey': config.supabaseAnonKey.trim(),
            'Authorization': 'Bearer $bearerToken',
          },
          body: jsonEncode(payload),
        )
        .timeout(config.timeout);
  }

  Future<String> _resolveBearerToken() async {
    // If you're calling a Supabase Edge Function, always use the Supabase session JWT,
    // even if APP_TOKEN is set (APP_TOKEN was only meant as a dev placeholder).
    final endpointLooksLikeSupabase =
        config.endpoint.host.toLowerCase().endsWith('.supabase.co') &&
            config.endpoint.pathSegments.contains('functions');

    final appToken = config.appToken.trim();
    if (!endpointLooksLikeSupabase && appToken.isNotEmpty) {
      return appToken;
    }

    return await _resolveSupabaseBearerToken();
  }

  Future<String> _resolveSupabaseBearerToken() async {
    try {
      final sb = Supabase.instance.client;
      var token = sb.auth.currentSession?.accessToken;

      if (token == null || token.trim().isEmpty) {
        // "No login UI" flow: use Supabase Anonymous sign-in.
        await sb.auth.signInAnonymously();
        token = sb.auth.currentSession?.accessToken;
      }

      if (token != null && token.trim().isNotEmpty) {
        return token;
      }
    } on AuthException catch (error) {
      final message = error.message.toLowerCase();
      if (message.contains('anonymous') && message.contains('disabled')) {
        throw const AIWordlistException(
          'Supabase Anonymous Auth ist deaktiviert. '
          'Aktiviere in Supabase: Authentication -> Providers -> Anonymous.',
        );
      }
      throw AIWordlistException('Supabase Auth Fehler: ${error.message}');
    } catch (_) {
      // Supabase may not be initialized in some dev/test contexts.
    }

    throw const AIWordlistException(
      'Keine Supabase Session vorhanden. '
      'Bitte sicherstellen, dass SUPABASE_URL und SUPABASE_ANON_KEY gesetzt sind.',
    );
  }

  Future<void> _refreshSupabaseSessionIfPossible() async {
    try {
      final sb = Supabase.instance.client;
      await sb.auth.refreshSession();
    } on AuthException {
      // ignore
    } catch (_) {
      // ignore
    }
  }

  Future<void> _hardResetSupabaseSession() async {
    try {
      final sb = Supabase.instance.client;
      await sb.auth.signOut();
    } catch (_) {
      // ignore
    }
    try {
      final sb = Supabase.instance.client;
      await sb.auth.signInAnonymously();
    } catch (_) {
      // ignore - caller will surface missing token if this fails
    }
  }

  static String _extractErrorDetail(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return '';
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        final error = decoded['error']?.toString().trim();
        if (error != null && error.isNotEmpty) return error;
        final message = decoded['message']?.toString().trim();
        if (message != null && message.isNotEmpty) return message;
      }
    } catch (_) {
      // fall through to snippet
    }
    final snippet =
        trimmed.length > 140 ? '${trimmed.substring(0, 140)}…' : trimmed;
    return snippet.replaceAll(RegExp(r'\\s+'), ' ');
  }

  @override
  Stream<AIWordlistProgress> generateWordlistStream({
    required AIWordlistRequest request,
  }) async* {
    yield const AIWordlistProgress(
      stage: AIWordlistProgressStage.requesting,
      progress: 0.2,
      message: 'KI wird angefragt ...',
    );

    AIWordlistResult result;
    try {
      yield const AIWordlistProgress(
        stage: AIWordlistProgressStage.parsing,
        progress: 0.55,
        message: 'Antwort wird verarbeitet ...',
      );
      result = await generateWordlistResult(request: request);
      yield const AIWordlistProgress(
        stage: AIWordlistProgressStage.normalizing,
        progress: 0.85,
        message: 'Begriffe werden bereinigt ...',
      );
    } catch (_) {
      rethrow;
    }

    yield AIWordlistProgress(
      stage: AIWordlistProgressStage.done,
      progress: 1,
      message: 'Fertig.',
      result: result,
    );
  }

  void _enforceRateLimit() {
    final now = DateTime.now();
    final previous = _lastCallAt;
    if (previous != null) {
      final elapsed = now.difference(previous);
      if (elapsed < config.minInterval) {
        final retryAfter = config.minInterval - elapsed;
        throw AIRateLimitException(
          'Bitte ${retryAfter.inSeconds + 1}s warten.',
          retryAfter,
        );
      }
    }
    _lastCallAt = now;
  }

  static AIWordlistResponse parseAIResponse(String body) {
    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      final extracted = _extractFirstJsonObject(body);
      decoded = jsonDecode(extracted);
    }
    final payload = _extractPayload(decoded);
    return AIWordlistResponse.fromJson(payload);
  }

  static Map<String, dynamic> _extractPayload(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      if (decoded.containsKey('title') && decoded.containsKey('items')) {
        return decoded;
      }
      for (final key in <String>['result', 'data', 'output']) {
        final nested = decoded[key];
        if (nested is Map<String, dynamic> &&
            nested.containsKey('title') &&
            nested.containsKey('items')) {
          return nested;
        }
      }
      final content = decoded['content'];
      if (content is String) {
        final parsed = jsonDecode(_extractFirstJsonObject(content));
        if (parsed is Map<String, dynamic>) {
          return parsed;
        }
      }

      final choices = decoded['choices'];
      if (choices is List && choices.isNotEmpty) {
        final first = choices.first;
        if (first is Map<String, dynamic>) {
          final message = first['message'];
          if (message is Map<String, dynamic>) {
            final content = message['content'];
            if (content is String) {
              final parsed = jsonDecode(_extractFirstJsonObject(content));
              if (parsed is Map<String, dynamic>) {
                return parsed;
              }
            }
          }
        }
      }
    }

    if (decoded is String) {
      final parsed = jsonDecode(_extractFirstJsonObject(decoded));
      if (parsed is Map<String, dynamic>) {
        return parsed;
      }
    }

    throw const FormatException(
      'KI-Antwort konnte nicht als JSON gelesen werden.',
    );
  }

  static String _extractFirstJsonObject(String input) {
    final trimmed = input.trim();
    final withoutFence = _stripFence(trimmed);

    final start = withoutFence.indexOf('{');
    if (start < 0) {
      throw const FormatException('Kein JSON-Objekt gefunden.');
    }

    var depth = 0;
    for (var i = start; i < withoutFence.length; i++) {
      final char = withoutFence[i];
      if (char == '{') depth++;
      if (char == '}') {
        depth--;
        if (depth == 0) {
          return withoutFence.substring(start, i + 1);
        }
      }
    }

    throw const FormatException('Unvollständiges JSON-Objekt.');
  }

  static String _stripFence(String input) {
    if (!input.startsWith('```')) return input;
    final lines = input.split('\n');
    final filtered =
        lines.where((line) => !line.trim().startsWith('```')).toList();
    return filtered.join('\n').trim();
  }

  static String _buildStrictPrompt(
    AIWordlistRequest request, {
    int? countOverride,
    List<String> excludeTerms = const <String>[],
  }) {
    final tagPart =
        request.styleTags.isEmpty ? 'none' : request.styleTags.join(', ');
    final targetCount = countOverride ?? request.count;
    final excludePart =
        excludeTerms.isEmpty ? 'none' : excludeTerms.take(60).join(', ');
    return '''
Generate a guessing-game wordlist.
Return STRICT JSON only in this schema:
{"title":"...","language":"de|en","items":["term1","term2"]}
Rules:
- language: ${request.language}
- topic: ${request.topic}
- difficulty: ${request.difficulty.name}
- target_count: $targetCount
- style_tags: $tagPart
- each item must be 1-3 words (no full sentences)
- no duplicates (case-insensitive)
- no emojis
- no numbering or bullet prefixes
- avoid NSFW, hate, insults
- no hints unless explicitly requested
- do not include any terms from: $excludePart
- IMPORTANT: return at least target_count unique valid items (prefer exactly target_count)
''';
  }
}
