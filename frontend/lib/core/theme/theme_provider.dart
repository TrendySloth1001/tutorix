import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Manages the current [ThemeMode] and persists it via secure storage.
class ThemeProvider extends ChangeNotifier {
  ThemeProvider() {
    _load();
  }

  static const _key = 'theme_mode';
  final _storage = const FlutterSecureStorage();

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  Future<void> _load() async {
    final raw = await _storage.read(key: _key);
    if (raw != null) {
      _mode = ThemeMode.values.firstWhere(
        (e) => e.name == raw,
        orElse: () => ThemeMode.system,
      );
      notifyListeners();
    }
  }

  Future<void> setMode(ThemeMode m) async {
    if (_mode == m) return;
    _mode = m;
    notifyListeners();
    await _storage.write(key: _key, value: m.name);
  }

  /// Convenience cycle: system → light → dark → system
  Future<void> toggle() async {
    final next = switch (_mode) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    await setMode(next);
  }
}
