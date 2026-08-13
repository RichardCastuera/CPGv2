import 'package:supabase_flutter/supabase_flutter.dart';

/// Keeps the app account-free from the user's perspective while still giving
/// every device a stable `auth.uid()` to hang bookmarks, sync state, and RLS
/// policies off of. No login screen, no email, no password.
///
/// Supabase's anonymous auth creates a real row in `auth.users` and issues a
/// normal session/JWT — `auth.uid()` inside RLS policies works exactly the
/// same as it would for an emailed-in user. The session persists locally
/// (supabase_flutter handles this), so the same anonymous identity — and
/// therefore the same bookmarks/downloads — comes back on next launch
/// without any user action.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  SupabaseClient get _client => Supabase.instance.client;

  bool get isSignedIn => _client.auth.currentSession != null;

  bool get isAnonymous => _client.auth.currentUser?.isAnonymous ?? false;

  /// Call once at app startup, after Supabase.initialize. If a session
  /// already exists (anonymous or otherwise), this is a no-op — the existing
  /// identity and its bookmarks/downloads carry over automatically.
  Future<void> ensureSignedIn() async {
    if (_client.auth.currentSession != null) return;
    await _client.auth.signInAnonymously();
  }

  /// Optional upgrade path for later: link a real email to the existing
  /// anonymous identity so bookmarks/downloads carry over to other devices,
  /// instead of creating a fresh account. Never required — surfaced only if
  /// you add a "sync across devices" affordance in Settings.
  Future<void> linkEmail(String email) async {
    await _client.auth.updateUser(UserAttributes(email: email));
  }
}
