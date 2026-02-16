import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Local SQLite database for offline caching.
///
/// Uses a simple key-value `cache` table plus a `settings` table.
/// All cached API responses are stored as JSON blobs keyed by endpoint path.
class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  static const _dbName = 'tutorix_cache.db';
  static const _dbVersion = 1;

  Database? _db;

  /// Opens (or creates) the database. Idempotent.
  Future<Database> get database async {
    if (_db != null) return _db!;
    final dbPath = join(await getDatabasesPath(), _dbName);
    _db = await openDatabase(dbPath, version: _dbVersion, onCreate: _onCreate);
    return _db!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE cache (
        key    TEXT PRIMARY KEY,
        value  TEXT NOT NULL,
        ts     INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE settings (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  // ── Cache CRUD ──────────────────────────────────────────────────────

  /// Store a JSON-encodable value under [key].
  Future<void> put(String key, dynamic value) async {
    final db = await database;
    await db.insert('cache', {
      'key': key,
      'value': jsonEncode(value),
      'ts': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Retrieve a previously cached value. Returns `null` if not found or
  /// if it is older than [maxAge].
  Future<dynamic> get(String key, {Duration? maxAge}) async {
    final db = await database;
    final rows = await db.query(
      'cache',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final row = rows.first;
    if (maxAge != null) {
      final ts = row['ts'] as int;
      final age = DateTime.now().millisecondsSinceEpoch - ts;
      if (age > maxAge.inMilliseconds) return null;
    }
    return jsonDecode(row['value'] as String);
  }

  /// Remove a single cache entry.
  Future<void> remove(String key) async {
    final db = await database;
    await db.delete('cache', where: 'key = ?', whereArgs: [key]);
  }

  /// Remove all cache entries whose key starts with [prefix].
  Future<void> removeByPrefix(String prefix) async {
    final db = await database;
    await db.delete('cache', where: 'key LIKE ?', whereArgs: ['$prefix%']);
  }

  /// Drop every cache row.
  Future<void> clearCache() async {
    final db = await database;
    await db.delete('cache');
  }

  /// Total bytes occupied by cached values (approximate).
  Future<int> cacheSize() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(LENGTH(value)),0) AS size FROM cache',
    );
    return (result.first['size'] as int?) ?? 0;
  }

  /// Number of cache entries.
  Future<int> cacheCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) AS cnt FROM cache');
    return (result.first['cnt'] as int?) ?? 0;
  }

  // ── Settings helpers ────────────────────────────────────────────────

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  /// Delete the entire database file (nuclear option).
  Future<void> deleteDatabase_() async {
    final dbPath = join(await getDatabasesPath(), _dbName);
    _db?.close();
    _db = null;
    await deleteDatabase(dbPath);
  }
}
