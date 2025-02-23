// lib/services/auth_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String baseUrl = 'http://192.168.1.168:3000';

  Future<Map<String, dynamic>?> register({
    required String email,
    required String pseudo,
    required String password,
    String avatarBase64 = '',
  }) async {
    final url = Uri.parse('$baseUrl/api/auth/register');
    final body = jsonEncode({
      'email': email,
      'pseudo': pseudo,
      'password': password,
      'avatarBase64': avatarBase64,
    });

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Stocker le token
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token']);

        return data;
      } else {
        final errorData = jsonDecode(response.body);
        throw errorData['error'] ?? 'Erreur inscription';
      }
    } catch (e) {
      rethrow;
    }
  }

  // Connexion par PSEUDO
  Future<Map<String, dynamic>?> login({
      required String pseudo,
      required String password,
    }) async {
      final url = Uri.parse('$baseUrl/api/auth/login');
      final body = jsonEncode({
        'pseudo': pseudo,   // On envoie pseudo
        'password': password,
      });

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token']);
        return data;
      } else {
        final errorData = jsonDecode(response.body);
        throw errorData['error'] ?? 'Erreur connexion';
      }
    } catch (e) {
      rethrow;
    }
  }

  // Récupérer le profil utilisateur
  Future<Map<String, dynamic>?> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return null;

    final url = Uri.parse('$baseUrl/api/auth/profile');
    try {
      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token"
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final errorData = jsonDecode(response.body);
        throw errorData['error'] ?? 'Erreur getProfile';
      }
    } catch (e) {
      rethrow;
    }
  }

  // Mettre à jour le profil (avatar, pseudo)
  Future<bool> updateProfile({
    required String newPseudo,
    required String newAvatarBase64,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return false;

    final url = Uri.parse('$baseUrl/api/auth/profile');
    final body = jsonEncode({
      'newPseudo': newPseudo,
      'newAvatarBase64': newAvatarBase64,
    });

    try {
      final response = await http.put(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: body,
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        final errorData = jsonDecode(response.body);
        throw errorData['error'] ?? 'Erreur updateProfile';
      }
    } catch (e) {
      rethrow;
    }
  }

  // Déconnexion
  Future<bool> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    return true;
  }

  // Vérifie la présence du token
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') != null;
  }
}
