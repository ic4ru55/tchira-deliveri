import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PARAMÈTRES SCREEN
// Langue, thème sombre, notifications push, son
// Les préférences sont sauvegardées dans SharedPreferences
// ═══════════════════════════════════════════════════════════════════════════════

class ParametresScreen extends StatefulWidget {
  const ParametresScreen({super.key});
  @override
  State<ParametresScreen> createState() => _ParametresScreenState();
}

class _ParametresScreenState extends State<ParametresScreen> {
  bool _modeSombre        = false;
  bool _notifsPush        = true;
  bool _notifsVibration   = true;
  bool _notifsLivraison   = true;
  bool _notifsMarketing   = false;
  String _langue          = 'fr';
  bool _chargement        = true;

  @override
  void initState() {
    super.initState();
    _chargerPrefs();
  }

  Future<void> _chargerPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _modeSombre       = prefs.getBool('pref_mode_sombre')      ?? false;
      _notifsPush       = prefs.getBool('pref_notifs_push')       ?? true;
      _notifsVibration  = prefs.getBool('pref_notifs_vibration')  ?? true;
      _notifsLivraison  = prefs.getBool('pref_notifs_livraison')  ?? true;
      _notifsMarketing  = prefs.getBool('pref_notifs_marketing')  ?? false;
      _langue           = prefs.getString('pref_langue')          ?? 'fr';
      _chargement       = false;
    });
  }

  Future<void> _sauvegarder(String cle, dynamic valeur) async {
    final prefs = await SharedPreferences.getInstance();
    if (valeur is bool)   await prefs.setBool(cle, valeur);
    if (valeur is String) await prefs.setString(cle, valeur);
  }

  // ✅ Applique les préférences de notification à Firebase Messaging
  // Si push désactivé → désabonner de tous les topics
  // Si push activé → réabonner aux topics actifs
  Future<void> _appliquerPrefsNotifs() async {
    try {
      if (!_notifsPush) {
        // Désactiver toutes les notifications FCM
        await FirebaseMessaging.instance.unsubscribeFromTopic('livraisons');
        await FirebaseMessaging.instance.unsubscribeFromTopic('promotions');
        // Sur Android : désactiver la réception silencieuse
        await FirebaseMessaging.instance.setAutoInitEnabled(false);
      } else {
        // Réactiver FCM
        await FirebaseMessaging.instance.setAutoInitEnabled(true);
        // Réabonner aux topics selon les préférences
        if (_notifsLivraison) {
          await FirebaseMessaging.instance.subscribeToTopic('livraisons');
        } else {
          await FirebaseMessaging.instance.unsubscribeFromTopic('livraisons');
        }
        if (_notifsMarketing) {
          await FirebaseMessaging.instance.subscribeToTopic('promotions');
        } else {
          await FirebaseMessaging.instance.unsubscribeFromTopic('promotions');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Erreur préfs notifs FCM : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement) {
      return const Scaffold(
        backgroundColor: Color(0xFFF1F5F9),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF0D7377))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D7377),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Paramètres', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── Apparence ───────────────────────────────────────────────────────
          _titreSection('🎨  Apparence'),
          const SizedBox(height: 8),
          _carte([
            _switch(
              icone: Icons.dark_mode_outlined,
              couleur: const Color(0xFF6366F1),
              titre: 'Mode sombre',
              sousTitre: 'Interface en thème sombre',
              valeur: _modeSombre,
              onChanged: (v) {
                setState(() => _modeSombre = v);
                _sauvegarder('pref_mode_sombre', v);
                // TODO: appliquer le thème globalement via ThemeProvider
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(v ? '🌙 Mode sombre activé' : '☀️ Mode clair activé'),
                    backgroundColor: const Color(0xFF0D7377),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
          ]),
          const SizedBox(height: 16),

          // ── Langue ──────────────────────────────────────────────────────────
          _titreSection('🌍  Langue'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
            ),
            child: Column(children: [
              _optionLangue('fr', '🇫🇷', 'Français', 'Langue par défaut'),
              const Divider(height: 1, indent: 60),
              _optionLangue('moore', '🇧🇫', 'Mooré', 'En développement', desactive: true),
              const Divider(height: 1, indent: 60),
              _optionLangue('dioula', '🇧🇫', 'Dioula', 'En développement', desactive: true),
            ]),
          ),
          const SizedBox(height: 16),

          // ── Notifications ────────────────────────────────────────────────────
          _titreSection('🔔  Notifications'),
          const SizedBox(height: 8),
          _carte([
            _switch(
              icone: Icons.notifications_outlined,
              couleur: const Color(0xFFF97316),
              titre: 'Notifications push',
              sousTitre: 'Recevoir des alertes sur ce téléphone',
              valeur: _notifsPush,
              onChanged: (v) {
                setState(() => _notifsPush = v);
                _sauvegarder('pref_notifs_push', v);
              },
            ),
            const Divider(height: 1, indent: 60),
            _switch(
              icone: Icons.vibration,
              couleur: const Color(0xFF10B981),
              titre: 'Vibration',
              sousTitre: 'Vibrer à la réception d\'une notif',
              valeur: _notifsVibration,
              actif: _notifsPush,
              onChanged: (v) {
                setState(() => _notifsVibration = v);
                _sauvegarder('pref_notifs_vibration', v);
              },
            ),
            const Divider(height: 1, indent: 60),
            _switch(
              icone: Icons.local_shipping_outlined,
              couleur: const Color(0xFF0D7377),
              titre: 'Suivi de livraison',
              sousTitre: 'Alertes à chaque étape de votre colis',
              valeur: _notifsLivraison,
              actif: _notifsPush,
              onChanged: (v) async {
                setState(() => _notifsLivraison = v);
                await _sauvegarder('pref_notifs_livraison', v);
                await _appliquerPrefsNotifs();
              },
            ),
            const Divider(height: 1, indent: 60),
            _switch(
              icone: Icons.campaign_outlined,
              couleur: Colors.grey,
              titre: 'Offres et actualités',
              sousTitre: 'Promotions et nouvelles fonctionnalités',
              valeur: _notifsMarketing,
              actif: _notifsPush,
              onChanged: (v) async {
                setState(() => _notifsMarketing = v);
                await _sauvegarder('pref_notifs_marketing', v);
                await _appliquerPrefsNotifs();
              },
            ),
          ]),
          const SizedBox(height: 16),

          // ── À propos de l'app ────────────────────────────────────────────────
          _titreSection('📱  Application'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
            ),
            child: Column(children: [
              _infoLigne('Version', '1.0.0'),
              const Divider(height: 1, indent: 16),
              _infoLigne('Environnement', 'Production'),
              const Divider(height: 1, indent: 16),
              _infoLigne('Plateforme', Theme.of(context).platform == TargetPlatform.iOS ? 'iOS' : 'Android'),
            ]),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─── Widgets helpers ───────────────────────────────────────────────────────

  Widget _titreSection(String titre) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(titre, style: const TextStyle(
        fontSize: 13, fontWeight: FontWeight.w700,
        color: Colors.black54, letterSpacing: 0.3)));

  Widget _carte(List<Widget> enfants) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
    ),
    child: Column(children: enfants));

  Widget _switch({
    required IconData icone, required Color couleur,
    required String titre, required String sousTitre,
    required bool valeur, required ValueChanged<bool> onChanged,
    bool actif = true,
  }) {
    return Opacity(
      opacity: actif ? 1.0 : 0.4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Container(width: 40, height: 40,
            decoration: BoxDecoration(
              color: couleur.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12)),
            child: Icon(icone, size: 20, color: couleur)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titre, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
            Text(sousTitre, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ])),
          Switch.adaptive(
            value: valeur,
            onChanged: actif ? onChanged : null,
            activeColor: const Color(0xFF0D7377),
          ),
        ]),
      ),
    );
  }

  Widget _optionLangue(String code, String drapeau, String nom, String desc, {bool desactive = false}) {
    final selectionne = _langue == code;
    return InkWell(
      onTap: desactive ? null : () {
        setState(() => _langue = code);
        _sauvegarder('pref_langue', code);
      },
      borderRadius: BorderRadius.circular(16),
      child: Opacity(
        opacity: desactive ? 0.4 : 1.0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            Container(width: 40, height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF0D7377).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text(drapeau, style: const TextStyle(fontSize: 20)))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(nom, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
              Text(desc, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ])),
            if (selectionne)
              Container(width: 24, height: 24,
                decoration: const BoxDecoration(color: Color(0xFF0D7377), shape: BoxShape.circle),
                child: const Icon(Icons.check, size: 14, color: Colors.white))
            else if (!desactive)
              Container(width: 24, height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade300, width: 2)),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _infoLigne(String label, String valeur) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(children: [
      Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey))),
      Text(valeur, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
    ]));
}