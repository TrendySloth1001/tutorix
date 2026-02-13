import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

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

  Future<Map<String, dynamic>?> signInWithGoogle() async {
    try {
      await _ensureInitialized();
      final GoogleSignInAccount? googleUser = await _googleSignIn.authenticate(
        scopeHint: ['email', 'profile'],
      );
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) throw Exception('Failed to get ID Token');

      final response = await http.post(
        Uri.parse('$baseUrl/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _storage.write(key: 'jwt_token', value: data['token']);
        return data['user'];
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
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'jwt_token');
  }

  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null;
  }
}
