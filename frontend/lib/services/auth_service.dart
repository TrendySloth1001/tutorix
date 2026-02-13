import 'dart:io';
import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../models/user_model.dart';

class AuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final _storage = const FlutterSecureStorage();
  final String baseUrl = 'https://qjhcp0ph-3010.inc1.devtunnels.ms';

  Future<void> _ensureInitialized() async {
    await _googleSignIn.initialize(
      serverClientId:
          '299795936862-s70dge4e1k99b3db0faqss8qrcrjj12b.apps.googleusercontent.com',
    );
  }

  Future<UserModel?> signInWithGoogle() async {
    try {
      await _ensureInitialized();
      final GoogleSignInAccount? googleUser = await _googleSignIn.authenticate(
        scopeHint: ['email', 'profile'],
      );
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) throw Exception('Failed to get ID Token');

      // Robust device info detection with fallback
      String osVersion = 'Unknown OS';
      try {
        osVersion = Platform.operatingSystemVersion;
      } catch (_) {}

      String deviceInfoString =
          'Device: ${Platform.operatingSystem} ($osVersion)';

      try {
        final deviceInfo = DeviceInfoPlugin();
        if (kIsWeb) {
          deviceInfoString = 'Tutorix-Web';
        } else {
          switch (defaultTargetPlatform) {
            case TargetPlatform.android:
              final android = await deviceInfo.androidInfo;
              deviceInfoString =
                  '${android.manufacturer} ${android.model} (Android ${android.version.release})';
              break;
            case TargetPlatform.iOS:
              final ios = await deviceInfo.iosInfo;
              deviceInfoString =
                  '${ios.name} ${ios.model} (iOS ${ios.systemVersion})';
              break;
            default:
              deviceInfoString =
                  'Tutorix-${defaultTargetPlatform.name} ($osVersion)';
          }
        }
        debugPrint('Final Device Info: $deviceInfoString');
      } catch (e) {
        debugPrint('Plugin error (using Platform fallback): $e');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/auth/google'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': deviceInfoString,
          'X-Device-Info': deviceInfoString,
        },
        body: jsonEncode({'idToken': idToken, 'deviceInfo': deviceInfoString}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final user = UserModel.fromJson(data['user']);

        await _storage.write(key: 'jwt_token', value: data['token']);
        await _storage.write(
          key: 'user_profile',
          value: jsonEncode(user.toJson()),
        );

        return user;
      } else {
        throw Exception('Backend authentication failed: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error during Google Sign-In: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _ensureInitialized();
    await _googleSignIn.signOut();
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'user_profile');
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'jwt_token');
  }

  Future<UserModel?> getUserProfile() async {
    final profile = await _storage.read(key: 'user_profile');
    if (profile == null) return null;
    return UserModel.fromJson(jsonDecode(profile));
  }

  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null;
  }
}
