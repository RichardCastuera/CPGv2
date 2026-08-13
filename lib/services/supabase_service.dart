import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/guideline.dart';
import '../models/guideline_content.dart';

/// Thin wrapper around the Supabase client. Every query here relies on the
/// server-side RLS policies (published + archived only) — this class does
/// not re-filter status client-side, since the DB is the source of truth.
class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: const String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: 'https://YOUR-PROJECT-REF.supabase.co',
      ),
      // supabase_flutter renamed this from anonKey to publishableKey; same
      // value (the anon/public key from your project's API settings).
      publishableKey: const String.fromEnvironment(
        'SUPABASE_ANON_KEY',
        defaultValue: 'YOUR-ANON-KEY',
      ),
    );
    await instance.ensureSession();
  }

  /// Silently establishes a Supabase anonymous session on first launch, with
  /// no sign-in screen and no user-visible step. Anonymous sessions are real
  /// `auth.users` rows (with `is_anonymous = true`), so `auth.uid()` in RLS
  /// policies, `bookmarks`, and `user_guideline_sync` all work unchanged.
  /// Once created, `supabase_flutter` persists the session locally, so this
  /// is a no-op on every subsequent launch.
  ///
  /// Requires "Allow anonymous sign-ins" to be enabled in the Supabase
  /// project's Auth settings (Dashboard → Authentication → Providers).
  Future<void> ensureSession() async {
    if (client.auth.currentSession != null) return;
    await client.auth.signInAnonymously();
  }

  /// True if the current session is anonymous (the default, offline-first
  /// state) rather than a linked email/OAuth account.
  bool get isAnonymous => client.auth.currentUser?.isAnonymous ?? true;

  /// Upgrades the current anonymous session to a permanent account by
  /// attaching an email — the session, user_id, bookmarks, and sync history
  /// all carry over unchanged. Supabase sends a confirmation link/OTP to
  /// [email]; call this, then complete verification via your chosen flow
  /// (magic link deep link, or `verifyOTP` if using a numeric code).
  Future<void> linkEmail(String email) async {
    await client.auth.updateUser(UserAttributes(email: email));
  }

  SupabaseClient get client => Supabase.instance.client;

  /// Guidelines whose current version is published or archived, i.e. every
  /// guideline the mobile app is allowed to see. Ordering: most recently
  /// updated first, to naturally surface "Featured & recently updated".
  Future<List<Guideline>> fetchGuidelines(
      {bool includeArchivedOnly = false}) async {
    final rows = await client
        .from('guidelines')
        .select()
        .order('updated_at', ascending: false);

    return (rows as List<dynamic>)
        .map((r) => Guideline.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<GuidelineVersion?> fetchCurrentVersion(String guidelineId) async {
    final guideline = await client
        .from('guidelines')
        .select('current_version_id')
        .eq('id', guidelineId)
        .single();

    final versionId = guideline['current_version_id'] as String?;
    if (versionId == null) return null;

    final row = await client
        .from('guideline_versions')
        .select()
        .eq('id', versionId)
        .single();

    return GuidelineVersion.fromJson(row);
  }

  /// All versions of a guideline the mobile app can see (published/archived),
  /// newest first — powers the version picker on the detail screen.
  Future<List<GuidelineVersion>> fetchVersionHistory(String guidelineId) async {
    final rows = await client
        .from('guideline_versions')
        .select()
        .eq('guideline_id', guidelineId)
        .order('published_at', ascending: false);

    return (rows as List<dynamic>)
        .map((r) => GuidelineVersion.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Full content tree for a single version — sections, nested questions,
  /// nested recommendations — fetched as three flat queries and stitched
  /// together client-side (cheaper than deep PostgREST embeds at this depth).
  Future<List<GuidelineSection>> fetchVersionTree(String versionId) async {
    final sectionRows = await client
        .from('sections')
        .select()
        .eq('version_id', versionId)
        .order('sort_order');

    final sectionIds =
        (sectionRows as List<dynamic>).map((s) => s['id'] as String).toList();
    if (sectionIds.isEmpty) return [];

    final questionRows = await client
        .from('questions')
        .select()
        .inFilter('section_id', sectionIds)
        .order('sort_order');

    final questionIds =
        (questionRows as List<dynamic>).map((q) => q['id'] as String).toList();

    final recommendationRows = questionIds.isEmpty
        ? <dynamic>[]
        : await client
            .from('recommendations')
            .select()
            .inFilter('question_id', questionIds)
            .order('sort_order');

    final recsByQuestion = <String, List<Map<String, dynamic>>>{};
    for (final r in recommendationRows) {
      final map = r as Map<String, dynamic>;
      recsByQuestion
          .putIfAbsent(map['question_id'] as String, () => [])
          .add(map);
    }

    final questionsBySection = <String, List<Map<String, dynamic>>>{};
    for (final q in questionRows) {
      final map = Map<String, dynamic>.from(q);
      map['recommendations'] = recsByQuestion[map['id']] ?? [];
      questionsBySection
          .putIfAbsent(map['section_id'] as String, () => [])
          .add(map);
    }

    return sectionRows.map((s) {
      final map = Map<String, dynamic>.from(s);
      map['questions'] = questionsBySection[map['id']] ?? [];
      return GuidelineSection.fromJson(map);
    }).toList();
  }

  Future<List<GuidelineArtifact>> fetchArtifacts(String guidelineId) async {
    final rows =
        await client.from('artifacts').select().eq('guideline_id', guidelineId);

    return (rows as List<dynamic>)
        .map((r) => GuidelineArtifact.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Builds a viewable URL for an artifact's `storage_path`.
  ///
  /// Assumes a bucket named 'artifacts' — rename this if your Storage
  /// bucket is called something else. Also assumes the bucket is public;
  /// if it's private, swap `getPublicUrl` for a signed URL instead:
  ///   await client.storage.from('artifacts').createSignedUrl(storagePath, 3600)
  String artifactUrl(String storagePath) {
    return client.storage.from('artifacts').getPublicUrl(storagePath);
  }

  /// Structured author rows (name, position, affiliation) — powers the
  /// Authors section on the detail screen. Distinct from `guidelines.authors`
  /// (a jsonb summary field); this is the normalized table.
  Future<List<GuidelineAuthorRow>> fetchAuthors(String guidelineId) async {
    final rows = await client
        .from('guideline_authors')
        .select()
        .eq('guideline_id', guidelineId)
        .order('sort_order');

    return (rows as List<dynamic>)
        .map((r) => GuidelineAuthorRow.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<List<GuidelineReference>> fetchReferences(String guidelineId) async {
    final rows = await client
        .from('guideline_references')
        .select('sort_order, references(*)')
        .eq('guideline_id', guidelineId)
        .order('sort_order');

    return (rows as List<dynamic>)
        .map((r) => GuidelineReference.fromJson(
            (r as Map<String, dynamic>)['references'] as Map<String, dynamic>))
        .toList();
  }

  // --- Bookmarks -----------------------------------------------------

  Future<void> addBookmark(
      {required String entityType, required String entityId}) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    await client.from('bookmarks').upsert({
      'user_id': userId,
      'entity_type': entityType,
      'entity_id': entityId,
    });
  }

  Future<void> removeBookmark(
      {required String entityType, required String entityId}) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    await client
        .from('bookmarks')
        .delete()
        .eq('user_id', userId)
        .eq('entity_type', entityType)
        .eq('entity_id', entityId);
  }

  Future<List<Map<String, dynamic>>> fetchBookmarks() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];
    final rows = await client
        .from('bookmarks')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  // --- Sync --------------------------------------------------------------

  Future<void> recordSync(
      {required String guidelineId, required String versionId}) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    await client.from('user_guideline_sync').upsert({
      'user_id': userId,
      'guideline_id': guidelineId,
      'downloaded_version_id': versionId,
      'downloaded_at': DateTime.now().toIso8601String(),
    });
  }
}
