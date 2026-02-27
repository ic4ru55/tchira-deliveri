import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../client/home_client.dart';
import '../livreur/home_livreur.dart';
import '../info_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  final _formKey   = GlobalKey<FormState>();
  final _nomCtrl   = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _mdpCtrl   = TextEditingController();
  final _telCtrl   = TextEditingController(); // 8 chiffres seulement
  String _role             = 'client';
  bool   _mdpVisible       = false;
  int    _etape            = 0; // 0=rôle, 1=infos, 2=sécurité
  bool   _politiqueAcceptee = false; // ✅ Doit être coché avant inscription

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _nomCtrl.dispose(); _emailCtrl.dispose(); _mdpCtrl.dispose(); _telCtrl.dispose();
    super.dispose();
  }

  // ─── Validation numéro Burkina ─────────────────────────────────────────────
  String? _validerTelephone(String? v) {
    if (v == null || v.isEmpty) return 'Numéro requis';
    final chiffres = v.replaceAll(RegExp(r'\D'), '');
    if (chiffres.length != 8) return '8 chiffres exactement (sans indicatif)';
    return null;
  }

  String _telephoneComplet() => '+226${_telCtrl.text.trim().replaceAll(RegExp(r'\D'), '')}';

  void _allerEtapeSuivante() {
    if (_etape == 0) { _animCtrl.forward(from: 0); setState(() => _etape = 1); return; }
    if (_etape == 1) {
      // Valider infos étape 1
      if (_nomCtrl.text.isEmpty) { _snack('Nom requis'); return; }
      if (_emailCtrl.text.isEmpty || !_emailCtrl.text.contains('@')) { _snack('Email invalide'); return; }
      if (_validerTelephone(_telCtrl.text) != null) { _snack(_validerTelephone(_telCtrl.text)!); return; }
      _animCtrl.forward(from: 0); setState(() => _etape = 2);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red));

  void _retourEtape() { _animCtrl.forward(from: 0); setState(() => _etape = _etape > 0 ? _etape - 1 : 0); }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    // ✅ Vérifier que la politique est acceptée
    if (!_politiqueAcceptee) {
      _snack('Veuillez accepter la politique de confidentialité pour continuer');
      return;
    }
    final auth = context.read<AuthProvider>();
    final succes = await auth.register(
      nom: _nomCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      motDePasse: _mdpCtrl.text.trim(),
      telephone: _telephoneComplet(), // envoie +22676XXXXXX
      role: _role,
    );
    if (!mounted) return;
    if (succes) {
      Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => auth.estClient ? const HomeClient() : const HomeLibreur()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFF0D7377),
      body: Column(children: [
        // ─── Header ──────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
          child: Column(children: [
            Row(children: [
              if (_etape > 0) GestureDetector(
                onTap: _retourEtape,
                child: Container(padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18)),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.close, color: Colors.white, size: 18)),
              ),
            ]),
            const SizedBox(height: 20),
            Container(width: 70, height: 70,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2.5), color: Colors.white.withValues(alpha: 0.1)),
              child: ClipOval(child: Image.asset('assets/images/logo.jpg', fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.local_shipping, color: Colors.white, size: 36)))),
            const SizedBox(height: 16),
            const Text('Tchira Express', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(_sousTitreEtape(), style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(3, (i) =>
              AnimatedContainer(duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _etape == i ? 28 : 8, height: 8,
                decoration: BoxDecoration(
                  color: _etape == i ? Colors.white : Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4)),
              ))),
          ]),
        ),

        // ─── Corps ───────────────────────────────────────────────────────────
        Expanded(child: Container(
          decoration: const BoxDecoration(color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32))),
          child: FadeTransition(opacity: _fadeAnim, child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Form(key: _formKey, child: Column(children: [

              // ─ Étape 0 : Choix du rôle ─────────────────────────────────────
              if (_etape == 0) ...[
                const Text('Je suis un...', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0D7377))),
                const SizedBox(height: 8),
                const Text('Choisis ton type de compte', style: TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center),
                const SizedBox(height: 32),
                Row(children: [
                  _carteRole(valeur: 'client', label: 'Client', sousTitre: 'Envoyer des colis', icone: '🛍️', couleur: const Color(0xFF0D7377)),
                  const SizedBox(width: 16),
                  _carteRole(valeur: 'livreur', label: 'Livreur', sousTitre: 'Livrer des colis', icone: '🚴', couleur: const Color(0xFFF97316)),
                ]),
                const SizedBox(height: 32),
                _boutonSuivant('Continuer →', _allerEtapeSuivante),
              ],

              // ─ Étape 1 : Infos personnelles ────────────────────────────────
              if (_etape == 1) ...[
                const Text('Tes informations', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0D7377))),
                const SizedBox(height: 8),
                const Text('Ces infos seront visibles dans ton profil', style: TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center),
                const SizedBox(height: 28),
                _champ(_nomCtrl, 'Nom complet', Icons.person_outlined, validateur: (v) => v!.isEmpty ? 'Nom requis' : null),
                const SizedBox(height: 14),
                _champ(_emailCtrl, 'Email', Icons.email_outlined, clavier: TextInputType.emailAddress,
                  validateur: (v) { if (v!.isEmpty) return 'Email requis'; if (!v.contains('@')) return 'Email invalide'; return null; }),
                const SizedBox(height: 14),

                // Téléphone avec +226 fixe
                TextFormField(
                  controller: _telCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
                  validator: _validerTelephone,
                  decoration: InputDecoration(
                    labelText: 'Numéro de téléphone (8 chiffres)',
                    prefixIcon: Container(
                      margin: const EdgeInsets.fromLTRB(12, 8, 0, 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFF0D7377), borderRadius: BorderRadius.circular(8)),
                      child: const Text('+226', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    hintText: 'Ex: 76123456',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0D7377), width: 2)),
                    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red)),
                    filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  ),
                ),
                const SizedBox(height: 6),
                Text('Indicatif Burkina Faso (+226) inclus automatiquement',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                const SizedBox(height: 28),
                _boutonSuivant('Continuer →', _allerEtapeSuivante),
              ],

              // ─ Étape 2 : Mot de passe ──────────────────────────────────────
              if (_etape == 2) ...[
                const Text('Sécurise ton compte', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0D7377))),
                const SizedBox(height: 8),
                const Text('Choisis un mot de passe sécurisé', style: TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center),
                const SizedBox(height: 28),
                // Récap
                Container(padding: const EdgeInsets.all(14), margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: const Color(0xFF0D7377).withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF0D7377).withValues(alpha: 0.2))),
                  child: Column(children: [
                    _ligneRecap(Icons.person, _nomCtrl.text),
                    const SizedBox(height: 8),
                    _ligneRecap(Icons.email_outlined, _emailCtrl.text),
                    const SizedBox(height: 8),
                    _ligneRecap(Icons.phone_outlined, '${_telephoneComplet()} (Burkina)'),
                  ])),
                TextFormField(
                  controller: _mdpCtrl, obscureText: !_mdpVisible,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe', prefixIcon: const Icon(Icons.lock_outlined, color: Color(0xFF0D7377), size: 18),
                    suffixIcon: IconButton(icon: Icon(_mdpVisible ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                        onPressed: () => setState(() => _mdpVisible = !_mdpVisible)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0D7377), width: 2)),
                    filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  ),
                  validator: (v) { if (v!.isEmpty) return 'Mot de passe requis'; if (v.length < 6) return 'Minimum 6 caractères'; return null; },
                ),
                const SizedBox(height: 6),
                const Text('Minimum 6 caractères', style: TextStyle(color: Colors.grey, fontSize: 12)),
                if (auth.erreur != null) ...[
                  const SizedBox(height: 16),
                  Container(width: double.infinity, padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFF87171))),
                    child: Row(children: [const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18), const SizedBox(width: 8),
                      Expanded(child: Text(auth.erreur!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13)))])),
                ],
                const SizedBox(height: 20),

                // ✅ Case à cocher — Politique de confidentialité
                GestureDetector(
                  onTap: () => setState(() => _politiqueAcceptee = !_politiqueAcceptee),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _politiqueAcceptee
                          ? const Color(0xFF0D7377).withValues(alpha: 0.06)
                          : Colors.orange.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _politiqueAcceptee
                            ? const Color(0xFF0D7377).withValues(alpha: 0.4)
                            : Colors.orange.withValues(alpha: 0.4),
                        width: 1.5),
                    ),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Case à cocher
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 22, height: 22, margin: const EdgeInsets.only(top: 1),
                        decoration: BoxDecoration(
                          color: _politiqueAcceptee ? const Color(0xFF0D7377) : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _politiqueAcceptee ? const Color(0xFF0D7377) : Colors.grey.shade400,
                            width: 2),
                        ),
                        child: _politiqueAcceptee
                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      // Texte avec lien cliquable
                      Expanded(child: RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.5),
                          children: [
                            const TextSpan(text: "J'ai lu et j'accepte la "),
                            WidgetSpan(child: GestureDetector(
                              onTap: () {
                                // Ouvrir la politique sans cocher automatiquement
                                Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => const InfoScreen(ongletInitial: 2)));
                              },
                              child: const Text(
                                'politique de confidentialité',
                                style: TextStyle(
                                  fontSize: 13, color: Color(0xFF0D7377),
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline),
                              ),
                            )),
                            const TextSpan(text: " et les conditions d'utilisation de Tchira Express."),
                          ],
                        ),
                      )),
                    ]),
                  ),
                ),

                const SizedBox(height: 16),
                SizedBox(width: double.infinity, height: 52, child: ElevatedButton.icon(
                  onPressed: auth.isLoading ? null : _register,
                  icon: auth.isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check_circle_outline),
                  label: const Text('Créer mon compte', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D7377), foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                )),
              ],

              const SizedBox(height: 20),
              if (_etape == 0) Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('Déjà un compte ? ', style: TextStyle(color: Colors.grey)),
                GestureDetector(onTap: () => Navigator.pop(context),
                    child: const Text('Se connecter', style: TextStyle(color: Color(0xFF0D7377), fontWeight: FontWeight.bold))),
              ]),
            ])),
          )),
        )),
      ]),
    );
  }

  Widget _carteRole({required String valeur, required String label, required String sousTitre, required String icone, required Color couleur}) {
    final sel = _role == valeur;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _role = valeur),
      child: AnimatedContainer(duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: sel ? couleur : Colors.white, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? couleur : const Color(0xFFE2E8F0), width: sel ? 2 : 1),
          boxShadow: sel ? [BoxShadow(color: couleur.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))]
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(children: [
          Text(icone, style: const TextStyle(fontSize: 36)),
          const SizedBox(height: 10),
          Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: sel ? Colors.white : const Color(0xFF0D7377))),
          const SizedBox(height: 4),
          Text(sousTitre, style: TextStyle(fontSize: 11, color: sel ? Colors.white70 : Colors.grey), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          AnimatedContainer(duration: const Duration(milliseconds: 200), width: 24, height: 24,
            decoration: BoxDecoration(shape: BoxShape.circle, color: sel ? Colors.white : Colors.transparent,
                border: Border.all(color: sel ? Colors.white : const Color(0xFFE2E8F0), width: 2)),
            child: sel ? Icon(Icons.check, color: couleur, size: 14) : null),
        ]),
      ),
    ));
  }

  Widget _boutonSuivant(String label, VoidCallback onTap) => SizedBox(width: double.infinity, height: 52,
    child: ElevatedButton(onPressed: onTap,
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D7377), foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))));

  Widget _champ(TextEditingController ctrl, String label, IconData icone, {TextInputType clavier = TextInputType.text, String? Function(String?)? validateur}) =>
    TextFormField(controller: ctrl, keyboardType: clavier, validator: validateur,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icone, color: const Color(0xFF0D7377), size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0D7377), width: 2)),
        filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14)));

  Widget _ligneRecap(IconData ic, String val) => Row(children: [
    Icon(ic, size: 14, color: const Color(0xFF0D7377)), const SizedBox(width: 8),
    Expanded(child: Text(val, style: const TextStyle(fontSize: 13, color: Color(0xFF0D7377), fontWeight: FontWeight.w500))),
  ]);

  String _sousTitreEtape() { switch (_etape) { case 0: return 'Choisis ton type de compte'; case 1: return 'Tes informations personnelles'; case 2: return 'Sécurise ton compte'; default: return ''; } }
}