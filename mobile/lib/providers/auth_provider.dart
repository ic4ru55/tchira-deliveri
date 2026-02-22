import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class AuthProvider extends ChangeNotifier {
  User?   _user;
  String? _token;
  bool    _isLoading = false;
  String? _erreur;

  User?   get user      => _user;
  String? get token     => _token;
  bool    get isLoading => _isLoading;
  String? get erreur    => _erreur;

  bool get estConnecte       => _user != null;
  bool get estClient         => _user?.role == 'client';
  bool get estLivreur        => _user?.role == 'livreur';
  bool get estReceptionniste => _user?.role == 'receptionniste';
  bool get estAdmin          => _user?.role == 'admin';

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  void _setErreur(String? msg) {
    _erreur = msg;
    notifyListeners();
  }

  // ─── REGISTER ────────────────────────────────────────────────────────────
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
        return true;
      } else {
        _setErreur(reponse['message'] ?? 'Erreur inscription');
        return false;
      }
    } catch (e) {
      _setErreur('Erreur réseau. Vérifie ta connexion.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ─── LOGIN ────────────────────────────────────────────────────────────────
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

  // ─── Sauvegarder la session ───────────────────────────────────────────────
  Future<void> _sauvegarderSession(Map<String, dynamic> reponse) async {
    _token = reponse['token'];
    _user  = User.fromJson(reponse['user']);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token',  _token!);
    await prefs.setString('userId', _user!.id);
    await prefs.setString('role',   _user!.role);

    SocketService.connecter(_token!);
    notifyListeners();
  }

  // ─── Restaurer la session au démarrage ───────────────────────────────────
  Future<void> restaurerSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) return;

    _token = token;

    try {
      final reponse = await ApiService.moi();
      if (reponse['success'] == true) {
        _user = User.fromJson(reponse['user']);
        SocketService.connecter(_token!);
        notifyListeners();
      } else {
        await deconnecter();
      }
    } catch (e) {
      await deconnecter();
    }
  }

  // ─── DÉCONNEXION ─────────────────────────────────────────────────────────
  Future<void> deconnecter() async {
    _user  = null;
    _token = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    SocketService.deconnecter();
    notifyListeners();
  }
}