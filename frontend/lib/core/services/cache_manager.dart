import 'database_service.dart';

/// Manages the "offline cache enabled" setting and wires caching logic.
///
/// Acts as a thin layer on top of [DatabaseService], adding the concept
/// of a user-toggleable cache. When caching is **off** (the default),
/// [get] always returns `null` and [put] is a no-op — this means the
/// rest of the app can call cache helpers unconditionally without
/// checking the toggle themselves.
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
