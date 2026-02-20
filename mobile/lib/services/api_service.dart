import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Détecte automatiquement Chrome ou Android
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:5000/api';
    return 'http://10.0.2.2:5000/api';
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<Map<String, String>> _headers({bool withAuth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (withAuth) {
      final token = await getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<Map<String, dynamic>> register({
    required String nom,
    required String email,
    required String motDePasse,
    required String telephone,
    String role = 'client',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: await _headers(withAuth: false),
      body: jsonEncode({
        'nom':          nom,
        'email':        email,
        'mot_de_passe': motDePasse,
        'telephone':    telephone,
        'role':         role,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String motDePasse,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: await _headers(withAuth: false),
      body: jsonEncode({
        'email':        email,
        'mot_de_passe': motDePasse,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> moi() async {
    final response = await http.get(
      Uri.parse('$baseUrl/auth/moi'),
      headers: await _headers(),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> creerLivraison({
    required String adresseDepart,
    required String adresseArrivee,
    required double prix,
    String description = '',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/livraisons'),
      headers: await _headers(),
      body: jsonEncode({
        'adresse_depart':    adresseDepart,
        'adresse_arrivee':   adresseArrivee,
        'prix':              prix,
        'description_colis': description,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getLivraisonsDisponibles() async {
    final response = await http.get(
      Uri.parse('$baseUrl/livraisons'),
      headers: await _headers(),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> mesLivraisons() async {
    final response = await http.get(
      Uri.parse('$baseUrl/livraisons/mes'),
      headers: await _headers(),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> accepterLivraison(String id) async {
    final response = await http.put(
      Uri.parse('$baseUrl/livraisons/$id/accepter'),
      headers: await _headers(),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> mettreAJourStatut(
      String id, String statut) async {
    final response = await http.put(
      Uri.parse('$baseUrl/livraisons/$id/statut'),
      headers: await _headers(),
      body: jsonEncode({'statut': statut}),
    );
    return jsonDecode(response.body);
  }
}