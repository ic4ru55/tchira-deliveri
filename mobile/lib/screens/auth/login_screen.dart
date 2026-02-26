// ignore_for_file: unnecessary_underscores

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../client/home_client.dart';
import '../livreur/home_livreur.dart';
import '../receptionniste/home_receptionniste.dart';
import '../admin/home_admin.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey        = GlobalKey<FormState>();
  final _identifiantCtrl = TextEditingController();
  final _mdpCtrl         = TextEditingController();
  bool  _mdpVisible      = false;

  late AnimationController _animCtrl;
  late Animation<Offset>   _slideAnim;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);
    _animCtrl.forward();
  }

  @override
  void dispose() { _animCtrl.dispose(); _identifiantCtrl.dispose(); _mdpCtrl.dispose(); super.dispose(); }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final auth   = context.read<AuthProvider>();
    String identifiant = _identifiantCtrl.text.trim();
    // Si mode téléphone, construire l'identifiant complet avec indicatif
    if (_modetelephoneActif) {
      identifiant = '+226${identifiant.replaceAll(RegExp(r'\D'), '')}';
    }
    final succes = await auth.login(email: identifiant, motDePasse: _mdpCtrl.text.trim());
    if (!mounted) return;
    if (succes) {
      Widget ecran;
      if (auth.estClient)              ecran = const HomeClient();
      else if (auth.estLivreur)        ecran = const HomeLibreur();
      else if (auth.estReceptionniste) ecran = const HomeReceptionniste();
      else if (auth.estAdmin)          ecran = const HomeAdmin();
      else ecran = const LoginScreen();
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ecran));
    }
  }

  bool get _modetelephoneActif => _modetelephoneActif2;
  bool _modetelephoneActif2 = false;

  void _basculerMode() {
    setState(() {
      _modetelephoneActif2 = !_modetelephoneActif2;
      _identifiantCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFF0D7377),
      body: Column(children: [
        // ─── Header ──────────────────────────────────────────────────────────
        Expanded(flex: 2, child: Container(
          padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 80, height: 80,
              decoration: BoxDecoration(shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 16, offset: const Offset(0, 6))]),
              child: ClipOval(child: Image.asset('assets/images/logo.jpg', fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.local_shipping, color: Colors.white, size: 40)))),
            const SizedBox(height: 16),
            const Text('Tchira Express', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            const SizedBox(height: 6),
            const Text('Livraison rapide à Bobo-Dioulasso', style: TextStyle(color: Colors.white60, fontSize: 13)),
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _puceStatut(Icons.local_shipping_outlined, 'Livraison rapide'),
              const SizedBox(width: 16),
              _puceStatut(Icons.location_on_outlined, 'GPS temps réel'),
              const SizedBox(width: 16),
              _puceStatut(Icons.security_outlined, 'Sécurisé'),
            ]),
          ]),
        )),

        // ─── Formulaire ───────────────────────────────────────────────────────
        Expanded(flex: 3, child: SlideTransition(position: _slideAnim, child: FadeTransition(opacity: _fadeAnim, child:
          Container(
            decoration: const BoxDecoration(color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32))),
            child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(24, 32, 24, 24), child:
              Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Connexion', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0D7377))),
                const SizedBox(height: 4),
                const Text('Accédez à votre compte', style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 24),

                // Sélecteur Email / Téléphone
                Container(
                  decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Expanded(child: GestureDetector(
                      onTap: () { if (_modetelephoneActif2) _basculerMode(); },
                      child: AnimatedContainer(duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.all(4), padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !_modetelephoneActif2 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: !_modetelephoneActif2 ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4)] : [],
                        ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.email_outlined, size: 16, color: !_modetelephoneActif2 ? const Color(0xFF0D7377) : Colors.grey),
                          const SizedBox(width: 6),
                          Text('Email', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: !_modetelephoneActif2 ? const Color(0xFF0D7377) : Colors.grey)),
                        ]),
                      ),
                    )),
                    Expanded(child: GestureDetector(
                      onTap: () { if (!_modetelephoneActif2) _basculerMode(); },
                      child: AnimatedContainer(duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.all(4), padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _modetelephoneActif2 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _modetelephoneActif2 ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4)] : [],
                        ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.phone_outlined, size: 16, color: _modetelephoneActif2 ? const Color(0xFF0D7377) : Colors.grey),
                          const SizedBox(width: 6),
                          Text('Téléphone', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _modetelephoneActif2 ? const Color(0xFF0D7377) : Colors.grey)),
                        ]),
                      ),
                    )),
                  ]),
                ),
                const SizedBox(height: 16),

                // Champ identifiant
                if (!_modetelephoneActif2)
                  TextFormField(
                    controller: _identifiantCtrl, keyboardType: TextInputType.emailAddress,
                    decoration: _inputDeco('Email', Icons.email_outlined),
                    validator: (v) { if (v!.isEmpty) return 'Email requis'; if (!v.contains('@')) return 'Email invalide'; return null; },
                  )
                else
                  // Champ téléphone avec indicatif +226 fixe
                  TextFormField(
                    controller: _identifiantCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
                    decoration: InputDecoration(
                      labelText: 'Numéro (8 chiffres)',
                      prefixIcon: Container(
                        margin: const EdgeInsets.fromLTRB(12, 8, 0, 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: const Color(0xFF0D7377), borderRadius: BorderRadius.circular(8)),
                        child: const Text('+226', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0D7377), width: 2)),
                      filled: true, fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Numéro requis';
                      if (v.length != 8) return '8 chiffres exactement';
                      return null;
                    },
                  ),
                const SizedBox(height: 14),

                // Mot de passe
                TextFormField(
                  controller: _mdpCtrl, obscureText: !_mdpVisible,
                  decoration: _inputDeco('Mot de passe', Icons.lock_outlined).copyWith(
                    suffixIcon: IconButton(icon: Icon(_mdpVisible ? Icons.visibility_off : Icons.visibility, color: Colors.grey, size: 20),
                        onPressed: () => setState(() => _mdpVisible = !_mdpVisible))),
                  validator: (v) { if (v!.isEmpty) return 'Mot de passe requis'; if (v.length < 6) return 'Minimum 6 caractères'; return null; },
                ),

                // Message d'erreur
                if (auth.erreur != null) ...[
                  const SizedBox(height: 14),
                  Container(width: double.infinity, padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFF87171))),
                    child: Row(children: [const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18), const SizedBox(width: 8),
                      Expanded(child: Text(auth.erreur!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13)))])),
                ],
                const SizedBox(height: 24),

                // Bouton connexion
                SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
                  onPressed: auth.isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D7377), foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 3,
                      shadowColor: const Color(0xFF0D7377).withValues(alpha: 0.4)),
                  child: auth.isLoading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.login, size: 20), SizedBox(width: 8),
                          Text('Se connecter', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ]),
                )),
                const SizedBox(height: 20),

                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text("Pas encore de compte ? ", style: TextStyle(color: Colors.grey, fontSize: 14)),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                    child: const Text("S'inscrire", style: TextStyle(color: Color(0xFF0D7377), fontWeight: FontWeight.bold, fontSize: 14))),
                ]),
                const SizedBox(height: 16),
                Row(children: [const Expanded(child: Divider()),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('Rôles', style: TextStyle(color: Colors.grey.shade400, fontSize: 11))),
                  const Expanded(child: Divider())]),
                const SizedBox(height: 12),
                Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
                  _badgeRole('👤 Client', const Color(0xFF0D7377)),
                  _badgeRole('🚴 Livreur', const Color(0xFFF97316)),
                  _badgeRole('📋 Réceptionniste', Colors.blue),
                  _badgeRole('👑 Admin', Colors.purple),
                ]),
              ]))),
          ),
        ))),
      ]),
    );
  }

  Widget _puceStatut(IconData ic, String label) => Column(children: [
    Container(padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
      child: Icon(ic, color: Colors.white, size: 18)),
    const SizedBox(height: 4),
    Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
  ]);

  Widget _badgeRole(String label, Color couleur) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: couleur.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20), border: Border.all(color: couleur.withValues(alpha: 0.2))),
    child: Text(label, style: TextStyle(color: couleur, fontSize: 11, fontWeight: FontWeight.w600)));

  InputDecoration _inputDeco(String label, IconData icone) => InputDecoration(
    labelText: label, prefixIcon: Icon(icone, color: const Color(0xFF0D7377), size: 18),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0D7377), width: 2)),
    filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14));
}