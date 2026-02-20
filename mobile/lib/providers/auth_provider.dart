import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class AuthProvider extends ChangeNotifier {
  // ─── État interne ────────────────────────────────────────────────────────────
  User? _user;           // l'utilisateur connecté (null si pas connecté)
  String? _token;        // le token JWT
  bool _isLoading = false; // true pendant une requête en cours
  String? _erreur;       // message d'erreur à afficher

  // ─── Getters — lecture depuis l'extérieur ────────────────────────────────────
  User?   get user      => _user;
  String? get token     => _token;
  bool    get isLoading => _isLoading;
  String? get erreur    => _erreur;
  bool    get estConnecte => _user != null;
  bool    get estClient   => _user?.role == 'client';
  bool    get estLivreur  => _user?.role == 'livreur';

  // ─── Changer l'état et notifier tous les widgets ─────────────────────────────
  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners(); // 🔔 dit à Flutter "mets à jour l'UI"
  }

  void _setErreur(String? msg) {
    _erreur = msg;
    notifyListeners();
  }

  // ─── REGISTER ────────────────────────────────────────────────────────────────
  Future<bool> register({
    required String nom,
    required String email,
    required String motDePasse,
    required String telephone,
    String role = 'client',
  }) async {
    _setLoading(true);
    _setErreur(null);

    try {
      final reponse = await ApiService.register(
        nom:        nom,
        email:      email,
        motDePasse: motDePasse,
        telephone:  telephone,
        role:       role,
      );

      if (reponse['success'] == true) {
        await _sauvegarderSession(reponse);
        return true;  // ✅ succès
      } else {
        _setErreur(reponse['message'] ?? 'Erreur inscription');
        return false; // ❌ échec
      }
    } catch (e) {
      _setErreur('Erreur réseau. Vérifie ta connexion.');
      return false;
    } finally {
      _setLoading(false);
      // finally s'exécute TOUJOURS — succès ou échec
      // garantit que le loading s'arrête dans tous les cas
    }
  }

  // ─── LOGIN ───────────────────────────────────────────────────────────────────
  Future<bool> login({
    required String email,
    required String motDePasse,
  }) async {
    _setLoading(true);
    _setErreur(null);

    try {
      final reponse = await ApiService.login(
        email:      email,
        motDePasse: motDePasse,
      );

      if (reponse['success'] == true) {
        await _sauvegarderSession(reponse);
        return true;
      } else {
        _setErreur(reponse['message'] ?? 'Email ou mot de passe incorrect');
        return false;
      }
    } catch (e) {
      _setErreur('Erreur réseau. Vérifie ta connexion.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ─── Sauvegarder la session après login/register ─────────────────────────────
  Future<void> _sauvegarderSession(Map<String, dynamic> reponse) async {
    _token = reponse['token'];
    _user  = User.fromJson(reponse['user']);

    // Stocker le token sur le téléphone pour rester connecté
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', _token!);
    await prefs.setString('userId', _user!.id);
    await prefs.setString('role',   _user!.role);

    // Connecter Socket.io avec le nouveau token
    SocketService.connecter(_token!);

    notifyListeners();
  }

  // ─── Restaurer la session au démarrage de l'app ──────────────────────────────
  Future<void> restaurerSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) return; // pas de session sauvegardée

    _token = token;

    // Récupérer les infos du profil depuis l'API
    try {
      final reponse = await ApiService.moi();
      if (reponse['success'] == true) {
        _user = User.fromJson(reponse['user']);
        SocketService.connecter(_token!);
        notifyListeners();
      } else {
        // Token expiré → déconnecter
        await deconnecter();
      }
    } catch (e) {
      await deconnecter();
    }
  }

  // ─── DÉCONNEXION ─────────────────────────────────────────────────────────────
  Future<void> deconnecter() async {
    _user  = null;
    _token = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // efface toutes les données locales

    SocketService.deconnecter();
    notifyListeners();
  }
}