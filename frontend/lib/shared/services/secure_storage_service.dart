import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants/storage_keys.dart';

/// Thin wrapper around [FlutterSecureStorage] so every service does not
/// instantiate its own copy and key-strings are centralised.
class SecureStorageService {
  SecureStorageService._();
  static final SecureStorageService instance = SecureStorageService._();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // ── Token ──────────────────────────────────────────────────────────────

  Future<String?> getToken() => _storage.read(key: StorageKeys.jwtToken);

  Future<void> saveToken(String token) =>
      _storage.write(key: StorageKeys.jwtToken, value: token);

  Future<void> deleteToken() => _storage.delete(key: StorageKeys.jwtToken);

  // ── User profile cache ─────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getCachedUserProfile() async {
    final raw = await _storage.read(key: StorageKeys.userProfile);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> cacheUserProfile(Map<String, dynamic> json) =>
      _storage.write(key: StorageKeys.userProfile, value: jsonEncode(json));

  Future<void> clearUserProfile() =>
      _storage.delete(key: StorageKeys.userProfile);

  // ── Bulk clear ─────────────────────────────────────────────────────────

  Future<void> clearAll() async {
    await deleteToken();
    await clearUserProfile();
  }
}
