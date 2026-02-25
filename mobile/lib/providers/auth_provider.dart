import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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

  void _setLoading(bool val) { _isLoading = val; notifyListeners(); }
  void _setErreur(String? msg) { _erreur = msg; notifyListeners(); }

  // ─── Token FCM ────────────────────────────────────────────────────────────
  Future<void> _enregistrerTokenFCM() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true, badge: true, sound: true, provisional: false,
      );
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        return;
      }
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) return;
      await ApiService.sauvegarderTokenFCM(fcmToken);
      FirebaseMessaging.instance.onTokenRefresh
          .listen(ApiService.sauvegarderTokenFCM);
    } catch (e) {
      debugPrint('❌ Erreur FCM : $e');
    }
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
      final r = await ApiService.register(
        nom: nom, email: email, motDePasse: motDePasse,
        telephone: telephone, role: role,
      );
      if (r['success'] == true) {
        await _sauvegarderSession(r);
        return true;
      }
      _setErreur(r['message'] ?? 'Erreur inscription');
      return false;
    } catch (e) {
      _setErreur('Erreur réseau.');
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
      final r = await ApiService.login(
          email: email, motDePasse: motDePasse);
      if (r['success'] == true) {
        await _sauvegarderSession(r);
        return true;
      }
      _setErreur(r['message'] ?? 'Email ou mot de passe incorrect');
      return false;
    } catch (e) {
      _setErreur('Erreur réseau.');
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
    await prefs.setString('token',     _token!);
    await prefs.setString('userId',    _user!.id);
    await prefs.setString('role',      _user!.role);
    await prefs.setString('userNom',   _user!.nom);
    await prefs.setString('userEmail', _user!.email);
    await prefs.setString('userTel',   _user!.telephone);

    SocketService.connecter(_token!);
    await _enregistrerTokenFCM();
    notifyListeners();
  }

  // ─── Restaurer la session au démarrage ───────────────────────────────────
  Future<void> restaurerSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    _token = token;

    // Étape 1 : cache local → affichage immédiat
    final id    = prefs.getString('userId')    ?? '';
    final nom   = prefs.getString('userNom')   ?? '';
    final email = prefs.getString('userEmail') ?? '';
    final role  = prefs.getString('role')      ?? 'client';
    final tel   = prefs.getString('userTel')   ?? '';

    if (id.isNotEmpty && nom.isNotEmpty) {
      _user = User(
        id: id, nom: nom, email: email,
        role: role, telephone: tel,
      );
      SocketService.connecter(_token!);
      notifyListeners();
    }

    // Étape 2 : vérification serveur en arrière-plan
    try {
      final reponse = await ApiService.moi();
      if (reponse['success'] == true) {
        // ✅ User.fromJson — pas UserModel
        _user = User.fromJson(reponse['user']);
        await prefs.setString('userNom',   _user!.nom);
        await prefs.setString('userEmail', _user!.email);
        await prefs.setString('role',      _user!.role);
        await _enregistrerTokenFCM();
        notifyListeners();
      } else {
        await deconnecter();
      }
    } catch (e) {
      debugPrint('⚠️ Vérification session : pas de réseau ($e)');
    }
  }

  // ─── Rafraîchir le profil après modification ──────────────────────────────
  // ✅ Utilisé par ProfilScreen après modif nom/photo/mdp
  Future<void> rafraichirProfil() async {
    try {
      final reponse = await ApiService.moi();
      if (reponse['success'] == true) {
        // ✅ User.fromJson — pas UserModel
        _user = User.fromJson(reponse['user']);
        notifyListeners();
      }
    } catch (_) {}
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