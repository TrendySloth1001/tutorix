import 'dart:async';
import 'database_service.dart';

/// Manages the "offline cache enabled" setting and wires caching logic.
///
/// Acts as a thin layer on top of [DatabaseService], adding the concept
/// of a user-toggleable cache. When caching is **off** (the default),
/// [get] always returns `null` and [put] is a no-op — this means the
/// rest of the app can call cache helpers unconditionally without
/// checking the toggle themselves.
///
/// ### Stale-While-Revalidate
/// When caching is enabled the service layer can use [swr] to instantly
/// return cached data and refresh in the background. The returned
/// [Stream] emits the cached value first (if available), followed by
/// the fresh network value. Screens simply use `StreamBuilder` for a
/// *no-shimmer* experience.
class CacheManager {
  CacheManager._();
  static final CacheManager instance = CacheManager._();

  static const _enabledKey = 'offline_cache_enabled';

  final _db = DatabaseService.instance;

  bool? _enabled;

  /// Whether offline caching is turned on. Reads from the DB the first
  /// time and then keeps an in-memory copy for speed.
  Future<bool> get isEnabled async {
    if (_enabled != null) return _enabled!;
    final v = await _db.getSetting(_enabledKey);
    _enabled = v == 'true';
    return _enabled!;
  }

  /// Toggle offline caching on / off. When turning off, existing cache
  /// data is **not** deleted (the user can clear it explicitly).
  Future<void> setEnabled(bool value) async {
    _enabled = value;
    await _db.setSetting(_enabledKey, value.toString());
  }

  // ── Proxy helpers (no-op when disabled) ─────────────────────────────

  /// Cache [value] under [key] only if caching is enabled.
  Future<void> put(String key, dynamic value) async {
    if (!await isEnabled) return;
    await _db.put(key, value);
  }

  /// Retrieve a cached entry. Returns `null` when caching is disabled or
  /// the entry is missing / stale.
  Future<dynamic> get(String key, {Duration? maxAge}) async {
    if (!await isEnabled) return null;
    return _db.get(key, maxAge: maxAge);
  }

  // ── Stale-While-Revalidate ──────────────────────────────────────────

  /// Returns a [Stream] that:
  ///   1. Emits the **cached** value immediately (if cache is enabled and
  ///      there is a hit).
  ///   2. Calls [rawFetcher] in the background to get fresh raw JSON from
  ///      the network, caches it, and emits the parsed fresh value.
  ///   3. If the network call fails and we already emitted a cached value,
  ///      the stream simply closes — the user keeps the stale data. If
  ///      there was no cached value the error is forwarded.
  ///
  /// [rawFetcher] should return the raw API response (a `Map` or `List`).
  /// [parser] converts the raw JSON to the desired model type [T].
  ///
  /// When caching is disabled the stream just calls [rawFetcher] once.
  Stream<T> swr<T>(
    String key,
    Future<dynamic> Function() rawFetcher,
    T Function(dynamic raw) parser,
  ) async* {
    final enabled = await isEnabled;
    bool emittedCache = false;

    // 1. Emit cached value if available
    if (enabled) {
      final cached = await _db.get(key);
      if (cached != null) {
        try {
          yield parser(cached);
          emittedCache = true;
        } catch (_) {
          // Corrupted cache — ignore, fetch fresh.
        }
      }
    }

    // 2. Fetch fresh data
    try {
      final raw = await rawFetcher();
      if (enabled) {
        await _db.put(key, raw);
      }
      yield parser(raw);
    } catch (e) {
      // If we already gave the user cached data, silently swallow the
      // network error — they keep stale data.
      if (!emittedCache) rethrow;
    }
  }

  /// Invalidate a single key.
  Future<void> invalidate(String key) async => _db.remove(key);

  /// Invalidate everything under a prefix (e.g. `coaching:abc123:`).
  Future<void> invalidatePrefix(String prefix) async =>
      _db.removeByPrefix(prefix);

  /// Clear the entire cache.
  Future<void> clearAll() async => _db.clearCache();

  /// Approximate size in bytes.
  Future<int> get sizeInBytes => _db.cacheSize();

  /// Entry count.
  Future<int> get entryCount => _db.cacheCount();

  /// Nuke the database file — resets everything including settings.
  Future<void> deleteAll() async => _db.deleteDatabase_();
}
