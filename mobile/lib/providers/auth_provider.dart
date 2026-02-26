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
      FirebaseMessaging.instance.onTokenRefresh.listen(ApiService.sauvegarderTokenFCM);
    } catch (e) {
      debugPrint('❌ Erreur FCM : $e');
    }
  }

  // ─── REGISTER ─────────────────────────────────────────────────────────────
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
        nom: nom, email: email, motDePasse: motDePasse, telephone: telephone, role: role,
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
  Future<bool> login({required String email, required String motDePasse}) async {
    _setLoading(true);
    _setErreur(null);
    try {
      final r = await ApiService.login(email: email, motDePasse: motDePasse);
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
  // ✅ FIX BUG PHOTO : on sauvegarde maintenant photo_base64 dans SharedPreferences
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
    // ✅ Sauvegarde photo pour persistence après fermeture/reconnexion
    if (_user!.photoBase64 != null) {
      await prefs.setString('userPhoto', _user!.photoBase64!);
    } else {
      await prefs.remove('userPhoto');
    }

    SocketService.connecter(_token!);
    await _enregistrerTokenFCM();
    notifyListeners();
  }

  // ─── Restaurer la session au démarrage ────────────────────────────────────
  // ✅ FIX BUG PHOTO : on relit photo_base64 depuis SharedPreferences
  Future<void> restaurerSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    _token = token;

    // Étape 1 : cache local → affichage immédiat avec photo incluse
    final id    = prefs.getString('userId')    ?? '';
    final nom   = prefs.getString('userNom')   ?? '';
    final email = prefs.getString('userEmail') ?? '';
    final role  = prefs.getString('role')      ?? 'client';
    final tel   = prefs.getString('userTel')   ?? '';
    final photo = prefs.getString('userPhoto'); // ✅ photo restaurée

    if (id.isNotEmpty && nom.isNotEmpty) {
      _user = User(
        id: id, nom: nom, email: email,
        role: role, telephone: tel,
        photoBase64: photo, // ✅ photo incluse dans l'objet User local
      );
      SocketService.connecter(_token!);
      notifyListeners();
    }

    // Étape 2 : vérification serveur en arrière-plan
    try {
      final reponse = await ApiService.moi();
      if (reponse['success'] == true) {
        _user = User.fromJson(reponse['user']);
        final prefs2 = await SharedPreferences.getInstance();
        await prefs2.setString('userNom',   _user!.nom);
        await prefs2.setString('userEmail', _user!.email);
        await prefs2.setString('role',      _user!.role);
        await prefs2.setString('userTel',   _user!.telephone);
        // ✅ Resauvegarder la photo si elle vient du serveur
        if (_user!.photoBase64 != null) {
          await prefs2.setString('userPhoto', _user!.photoBase64!);
        }
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
  // ✅ FIX BUG PHOTO : on persiste la photo après chaque rafraîchissement
  Future<void> rafraichirProfil() async {
    try {
      final reponse = await ApiService.moi();
      if (reponse['success'] == true) {
        _user = User.fromJson(reponse['user']);
        // ✅ Persister immédiatement dans prefs pour survivre à la fermeture
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userNom',   _user!.nom);
        await prefs.setString('userEmail', _user!.email);
        await prefs.setString('userTel',   _user!.telephone);
        if (_user!.photoBase64 != null) {
          await prefs.setString('userPhoto', _user!.photoBase64!);
        } else {
          await prefs.remove('userPhoto');
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  // ─── DÉCONNEXION ──────────────────────────────────────────────────────────
  // ✅ FIX BUG ONBOARDING : on NE fait plus prefs.clear() — on efface seulement
  // les clés de session. L'onboarding_vu reste intact pour ne pas re-afficher.
  Future<void> deconnecter() async {
    _user  = null;
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    // ✅ Effacer uniquement les données de session, PAS onboarding_vu
    await prefs.remove('token');
    await prefs.remove('userId');
    await prefs.remove('role');
    await prefs.remove('userNom');
    await prefs.remove('userEmail');
    await prefs.remove('userTel');
    await prefs.remove('userPhoto');
    // ⚠️ On ne touche PAS 'onboarding_vu' → l'onboarding ne réapparaît plus
    SocketService.deconnecter();
    notifyListeners();
  }
}