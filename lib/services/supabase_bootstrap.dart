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

    // If the app was previously pointed at another Supabase project, we can have
    // a persisted (but now invalid) JWT. Clear it early so later Edge Function
    // calls don't fail with "Invalid JWT".
    try {
      final sb = Supabase.instance.client;
      final session = sb.auth.currentSession;
      final token = session?.accessToken;
      if (session != null && token != null && token.trim().isNotEmpty) {
        await sb.auth.getUser();
      }
    } on AuthException catch (error) {
      final msg = error.message.toLowerCase();
      final invalidJwt = msg.contains('invalid jwt') ||
          msg.contains('invalid_jwt') ||
          msg.contains('invalidjwttoken');
      if (invalidJwt || error.statusCode == '401') {
        try {
          await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
        } catch (_) {
          // ignore
        }
      }
    } catch (_) {
      // ignore
    }

    if (kDebugMode) {
      debugPrint('Supabase initialisiert.');
    }
  }
}
