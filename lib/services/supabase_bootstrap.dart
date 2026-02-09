import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseBootstrap {
  static const _urlRaw = String.fromEnvironment('SUPABASE_URL');
  static const _anonRaw = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool _initialized = false;

  static bool get isConfigured =>
      _urlRaw.trim().isNotEmpty && _anonRaw.trim().isNotEmpty;

  static Future<void> initializeIfConfigured() async {
    if (_initialized) return;

    final url = _urlRaw.trim();
    final anonKey = _anonRaw.trim();
    if (url.isEmpty || anonKey.isEmpty) {
      return;
    }

    final parsed = Uri.tryParse(url);
    if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
      throw StateError('SUPABASE_URL ist ungültig: $url');
    }

    try {
      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
      );
      _initialized = true;
    } catch (error) {
      final message = error.toString().toLowerCase();
      final alreadyInitialized = message.contains('already initialized') ||
          message.contains('already been initialized');
      if (alreadyInitialized) {
        _initialized = true;
        return;
      }
      rethrow;
    }

    if (kDebugMode) {
      debugPrint('Supabase initialisiert.');
    }
  }
}
