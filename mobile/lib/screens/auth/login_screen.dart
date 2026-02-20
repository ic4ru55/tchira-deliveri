import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import 'register_screen.dart';
import '../client/home_client.dart';
import '../livreur/home_livreur.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Clé unique qui identifie le formulaire — permet de le valider
  final _formKey    = GlobalKey<FormState>();
  final _emailCtrl  = TextEditingController();
  final _mdpCtrl    = TextEditingController();
  bool  _mdpVisible = false; // afficher/cacher le mot de passe

  @override
  void dispose() {
    // Libérer la mémoire quand l'écran est fermé
    _emailCtrl.dispose();
    _mdpCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    // Valider le formulaire — si invalide on s'arrête
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();

    final succes = await auth.login(
      email:      _emailCtrl.text.trim(),
      motDePasse: _mdpCtrl.text.trim(),
    );

    if (!mounted) return;

    if (succes) {
      // Rediriger selon le rôle
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => auth.estClient
              ? const HomeClient()
              : const HomeLibreur(),
        ),
      );
    }
    // Si échec → le Provider a mis à jour auth.erreur
    // → le widget se rebuild et affiche l'erreur automatiquement
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    // context.watch → ce widget se rebuild quand AuthProvider change
    // utile pour afficher isLoading et erreur en temps réel

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),

              // ── Logo ──────────────────────────────────────────────────
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.delivery_dining,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Center(
                child: Text(
                  'Tchira Delivery',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B3A6B),
                  ),
                ),
              ),
              const Center(
                child: Text(
                  'Connectez-vous à votre compte',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 48),

              // ── Formulaire ────────────────────────────────────────────
              Form(
                key: _formKey,
                child: Column(
                  children: [

                    // Email
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _inputDecoration(
                        label: 'Email',
                        icone: Icons.email_outlined,
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Email requis';
                        if (!val.contains('@')) return 'Email invalide';
                        return null; // null = valide
                      },
                    ),
                    const SizedBox(height: 16),

                    // Mot de passe
                    TextFormField(
                      controller:  _mdpCtrl,
                      obscureText: !_mdpVisible,
                      // obscureText: true → affiche des points à la place des lettres
                      decoration: _inputDecoration(
                        label: 'Mot de passe',
                        icone: Icons.lock_outlined,
                      ).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _mdpVisible
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(() => _mdpVisible = !_mdpVisible);
                            // setState → rebuild uniquement ce widget
                          },
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Mot de passe requis';
                        if (val.length < 6) return 'Minimum 6 caractères';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Message d'erreur (vient du Provider)
                    if (auth.erreur != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFF87171)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: Color(0xFFDC2626), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                auth.erreur!,
                                style: const TextStyle(
                                  color: Color(0xFFDC2626),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Bouton connexion
                    CustomButton(
                      texte:     'Se connecter',
                      onPressed: _login,
                      isLoading: auth.isLoading,
                      icone:     Icons.login,
                    ),
                    const SizedBox(height: 16),

                    // Lien vers Register
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Pas encore de compte ? ',
                          style: TextStyle(color: Colors.grey),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RegisterScreen(),
                            ),
                          ),
                          child: const Text(
                            'S\'inscrire',
                            style: TextStyle(
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Décoration commune pour tous les champs ──────────────────────────────────
  InputDecoration _inputDecoration({
    required String label,
    required IconData icone,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icone, color: const Color(0xFF2563EB)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }
}