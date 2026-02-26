import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {

  static const String _urlProd      = 'https://celebrated-upliftment-production-00fa.up.railway.app/api';
  static const String _urlDevWeb    = 'http://localhost:5000/api';
  static const String _urlDevMobile = 'http://10.0.2.2:5000/api';

  static String get baseUrl {
    if (kReleaseMode) return _urlProd;
    if (kIsWeb)       return _urlDevWeb;
    return _urlDevMobile;
  }

  static Map<String, dynamic> _handleResponse(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return data is Map<String, dynamic>
            ? data
            : {'success': true, 'data': data};
      }
      return {
        'success': false,
        'message': (data is Map && data['message'] != null)
            ? data['message']
            : 'Erreur serveur (${response.statusCode})',
      };
    } catch (_) {
      return {'success': false, 'message': 'Réponse serveur invalide'};
    }
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

  // ─── AUTH ─────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> register({
    required String nom,
    required String email,
    required String motDePasse,
    required String telephone,
    String role = 'client',
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/register'),
            headers: await _headers(withAuth: false),
            body: jsonEncode({
              'nom': nom, 'email': email,
              'mot_de_passe': motDePasse,
              'telephone': telephone, 'role': role,
            }),
          )
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Connexion impossible'};
    }
  }

  // ─── PROFIL ───────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> mettreAJourProfil({
    String? nom,
    String? telephone,
    String? photoBase64,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (nom         != null) body['nom']          = nom;
      if (telephone   != null) body['telephone']    = telephone;
      if (photoBase64 != null) body['photo_base64'] = photoBase64;

      final response = await http
          .put(
            Uri.parse('$baseUrl/profil'),
            headers: await _headers(),
            body:    jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Connexion impossible'};
    }
  }

  static Future<Map<String, dynamic>> changerMotDePasse({
    required String ancienMdp,
    required String nouveauMdp,
  }) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/profil/mot-de-passe'),
            headers: await _headers(),
            body: jsonEncode({
              'ancien_mdp':  ancienMdp,
              'nouveau_mdp': nouveauMdp,
            }),
          )
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Connexion impossible'};
    }
  }



  static Future<Map<String, dynamic>> login({
    required String email,
    required String motDePasse,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: await _headers(withAuth: false),
            body: jsonEncode({
              'email': email, 'mot_de_passe': motDePasse,
            }),
          )
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Connexion impossible'};
    }
  }

  static Future<Map<String, dynamic>> moi() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/auth/moi'), headers: await _headers())
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Connexion impossible'};
    }
  }

  // ─── NOTIFICATIONS FCM ────────────────────────────────────────────────────
  static Future<void> sauvegarderTokenFCM(String fcmToken) async {
    try {
      await http
          .post(
            Uri.parse('$baseUrl/notifications/token'),
            headers: await _headers(),
            body: jsonEncode({'fcm_token': fcmToken}),
          )
          .timeout(const Duration(seconds: 10));
      debugPrint('🔔 Token FCM sauvegardé');
    } catch (e) {
      debugPrint('❌ Erreur FCM : $e');
    }
  }

  // ─── TARIFS ───────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getTarifs() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/tarifs'),
              headers: await _headers(withAuth: false))
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Connexion impossible'};
    }
  }

  static Future<Map<String, dynamic>> calculerPrix({
    required String categorie,
    required String zoneCode,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/tarifs/calculer'),
            headers: await _headers(),
            body: jsonEncode({'categorie': categorie, 'zone_code': zoneCode}),
          )
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Connexion impossible'};
    }
  }

  static Future<Map<String, dynamic>> modifierTarif({
    required String categorie,
    required double prixBase,
    required bool   surDevis,
  }) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/tarifs/tarif/$categorie'),
            headers: await _headers(),
            body: jsonEncode({'prix_base': prixBase, 'sur_devis': surDevis}),
          )
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Connexion impossible'};
    }
  }

  static Future<Map<String, dynamic>> modifierZone({
    required String code,
    required int    fraisSupplementaires,
  }) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/tarifs/zone/$code'),
            headers: await _headers(),
            body: jsonEncode({'frais_supplementaires': fraisSupplementaires}),
          )
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Connexion impossible'};
    }
  }

  // ─── LIVRAISONS ───────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> creerLivraisonComplete({
    required String adresseDepart,
    required String adresseArrivee,
    required String categorie,
    required String zoneCode,
    required double prix,
    required double prixBase,
    required double fraisZone,
    String description = '',
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/livraisons'),
            headers: await _headers(),
            body: jsonEncode({
              'adresse_depart':    adresseDepart,
              'adresse_arrivee':   adresseArrivee,
              'categorie_colis':   categorie,
              'zone':              zoneCode,
              'prix':              prix,
              'prix_base':         prixBase,
              'frais_zone':        fraisZone,
              'description_colis': description,
            }),
          )
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Connexion impossible'};
    }
  }

  static Future<Map<String, dynamic>> getLivraisonsDisponibles() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/livraisons'), headers: await _headers())
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Connexion impossible'};
    }
  }

  static Future<Map<String, dynamic>> mesLivraisons() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/livraisons/mes'), headers: await _headers())
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Connexion impossible'};
    }
  }

// ✅ Mission active du livreur connecté
static Future<Map<String, dynamic>> missionActiveLivreur() async {
  try {
    final response = await http
        .get(
          Uri.parse('$baseUrl/livraisons/mission-active'),
          headers: await _headers(),
        )
        .timeout(const Duration(seconds: 15));

    return _handleResponse(response);
  } catch (e) {
    return {'success': false, 'message': 'Connexion impossible'};
  }
}



  // ✅ Historique des livraisons du livreur connecté
  static Future<Map<String, dynamic>> mesLivraisonsLivreur() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/livraisons/mon-historique'),
              headers: await _headers())
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Connexion impossible'};
    }
  }

  static Future<Map<String, dynamic>> getLivraison(String id) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/livraisons/$id'), headers: await _headers())
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Connexion impossible'};
    }
  }

  static Future<Map<String, dynamic>> accepterLivraison(String id) async {
    try {
      final response = await http
          .put(Uri.parse('$baseUrl/livraisons/$id/accepter'),
              headers: await _headers())
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Connexion impossible'};
    }
  }

  static Future<Map<String, dynamic>> mettreAJourStatut(
      String id, String statut) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/livraisons/$id/statut'),
            headers: await _headers(),
            body: jsonEncode({'statut': statut}),
          )
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Connexion impossible'};
    }
  }

  static Future<Map<String, dynamic>> annulerLivraison(String id) async {
    try {
      final response = await http
          .delete(Uri.parse('$baseUrl/livraisons/$id'),
              headers: await _headers())
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Connexion impossible'};
    }
  }

  // ─── RÉCEPTIONNISTE ───────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getLivreursDisponibles() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/livraisons/livreurs-disponibles'),
              headers: await _headers())
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Connexion impossible'};
    }
  }

  static Future<Map<String, dynamic>> toutesLesLivraisons({
    String? statut,
  }) async {
    try {
      final url = statut != null
          ? '$baseUrl/livraisons/toutes?statut=$statut'
          : '$baseUrl/livraisons/toutes';
      final response = await http
          .get(Uri.parse(url), headers: await _headers())
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Connexion impossible'};
    }
  }

  static Future<Map<String, dynamic>> assignerLivreur({
    required String livraisonId,
    required String livreurId,
  }) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/livraisons/$livraisonId/assigner'),
            headers: await _headers(),
            body: jsonEncode({'livreur_id': livreurId}),
          )
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Connexion impossible'};
    }
  }

  static Future<Map<String, dynamic>> modifierLivraison({
    required String livraisonId,
    String? adresseDepart,
    String? adresseArrivee,
    String? descriptionColis,
    double? prix,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (adresseDepart    != null) body['adresse_depart']    = adresseDepart;
      if (adresseArrivee   != null) body['adresse_arrivee']   = adresseArrivee;
      if (descriptionColis != null) body['description_colis'] = descriptionColis;
      if (prix             != null) body['prix']              = prix;

      final response = await http
          .put(
            Uri.parse('$baseUrl/livraisons/$livraisonId/modifier'),
            headers: await _headers(),
            body:    jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Connexion impossible'};
    }
  }

  // ─── ADMIN ────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getUtilisateurs({String? role}) async {
    try {
      final url = role != null
          ? '$baseUrl/admin/utilisateurs?role=$role'
          : '$baseUrl/admin/utilisateurs';
      final response = await http
          .get(Uri.parse(url), headers: await _headers())
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Connexion impossible'};
    }
  }

  static Future<Map<String, dynamic>> creerUtilisateur({
    required String nom,
    required String email,
    required String motDePasse,
    required String telephone,
    required String role,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/admin/utilisateurs'),
            headers: await _headers(),
            body: jsonEncode({
              'nom': nom, 'email': email,
              'mot_de_passe': motDePasse,
              'telephone': telephone, 'role': role,
            }),
          )
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Connexion impossible'};
    }
  }

  static Future<Map<String, dynamic>> changerStatutCompte({
    required String userId,
    required bool   actif,
  }) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/admin/utilisateurs/$userId/statut'),
            headers: await _headers(),
            body: jsonEncode({'actif': actif}),
          )
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Connexion impossible'};
    }
  }

  static Future<Map<String, dynamic>> supprimerUtilisateur(
      String userId) async {
    try {
      final response = await http
          .delete(Uri.parse('$baseUrl/admin/utilisateurs/$userId'),
              headers: await _headers())
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Connexion impossible'};
    }
  }

  // ✅ Stats avec filtre date optionnel — ?date=2026-02-23
  static Future<Map<String, dynamic>> getStats({String? date}) async {
    try {
      final url = date != null
          ? '$baseUrl/livraisons/stats?date=$date'
          : '$baseUrl/livraisons/stats';
      final response = await http
          .get(Uri.parse(url), headers: await _headers())
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Connexion impossible'};
    }
  }
}