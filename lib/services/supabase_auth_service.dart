import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthService {
  final SupabaseClient _client;

  const SupabaseAuthService(this._client);

  static SupabaseAuthService? fromInitializedClient() {
    try {
      return SupabaseAuthService(Supabase.instance.client);
    } catch (_) {
      return null;
    }
  }

  bool get hasSession {
    final session = _client.auth.currentSession;
    final token = session?.accessToken;
    return session != null && token != null && token.trim().isNotEmpty;
  }

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Future<bool> ensureAnonymousSession({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    if (hasSession) {
      // We can have a persisted but invalid token (e.g. after switching Supabase projects).
      // Validate once; on failure, clear local session and re-sign-in anonymously.
      try {
        await _client.auth.getUser();
        return true;
      } on AuthException catch (error) {
        final msg = error.message.toLowerCase();
        final invalidJwt = msg.contains('invalid jwt') ||
            msg.contains('invalid_jwt') ||
            msg.contains('invalidjwttoken');
        if (invalidJwt || error.statusCode == '401') {
          try {
            await _client.auth.signOut(scope: SignOutScope.local);
          } catch (_) {
            // ignore
          }
        } else {
          rethrow;
        }
      } catch (_) {
        // Ignore and fall through to sign-in.
      }
    }

    final completer = Completer<bool>();
    late final StreamSubscription<AuthState> subscription;
    subscription = onAuthStateChange.listen((event) {
      if (!completer.isCompleted && event.session != null) {
        completer.complete(true);
      }
    });

    try {
      final response = await _client.auth.signInAnonymously();
      if (response.session != null) {
        return true;
      }

      return await completer.future.timeout(
        timeout,
        onTimeout: () => false,
      );
    } on AuthException catch (error) {
      final message = error.message.toLowerCase();
      if (message.contains('anonymous') && message.contains('disabled')) {
        throw const SupabaseAuthException(
          'Supabase Anonymous Auth ist deaktiviert. '
          'Aktiviere in Supabase: Authentication -> Providers -> Anonymous.',
        );
      }
      throw SupabaseAuthException(error.message);
    } catch (error) {
      throw SupabaseAuthException(error.toString());
    } finally {
      await subscription.cancel();
    }
  }
}

class SupabaseAuthException implements Exception {
  final String message;

  const SupabaseAuthException(this.message);

  @override
  String toString() => message;
}
