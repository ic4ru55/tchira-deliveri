import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import 'register_screen.dart';
import '../client/home_client.dart';
import '../livreur/home_livreur.dart';
import '../receptionniste/home_receptionniste.dart';
import '../admin/home_admin.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _emailCtrl  = TextEditingController();
  final _mdpCtrl    = TextEditingController();
  bool  _mdpVisible = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _mdpCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final auth   = context.read<AuthProvider>();
    final succes = await auth.login(
      email:      _emailCtrl.text.trim(),
      motDePasse: _mdpCtrl.text.trim(),
    );

    if (!mounted) return;

    if (succes) {
      Widget ecran;

      if (auth.estClient) {
        ecran = const HomeClient();
      } else if (auth.estLivreur) {
        ecran = const HomeLibreur();
      } else if (auth.estReceptionniste) {
        ecran = const HomeReceptionniste();
      } else if (auth.estAdmin) {
        ecran = const HomeAdmin();
      } else {
        ecran = const LoginScreen();
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ecran),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),

              // ── Logo ──────────────────────────────────────────────
              Container(
                width:  100,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                      color:      Colors.black.withValues(alpha: 0.1),
                      blurRadius: 15,
                      offset:     const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(50),
                  child: Image.asset(
                    'assets/images/logo.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Tchira Express',
                style: TextStyle(
                  fontSize:   26,
                  fontWeight: FontWeight.bold,
                  color:      Color(0xFF0D7377),
                ),
              ),
              const Text(
                'Connectez-vous à votre compte',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 40),

              // ── Formulaire ────────────────────────────────────────
              Form(
                key: _formKey,
                child: Column(
                  children: [

                    TextFormField(
                      controller:   _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration:   _inputDecoration(
                        label: 'Email',
                        icone: Icons.email_outlined,
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Email requis';
                        }
                        if (!val.contains('@')) {
                          return 'Email invalide';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller:  _mdpCtrl,
                      obscureText: !_mdpVisible,
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
                          onPressed: () =>
                              setState(() => _mdpVisible = !_mdpVisible),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Mot de passe requis';
                        }
                        if (val.length < 6) {
                          return 'Minimum 6 caractères';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    if (auth.erreur != null)
                      Container(
                        width:   double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin:  const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color:        const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFFF87171)),
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
                                  color:    Color(0xFFDC2626),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    CustomButton(
                      texte:     'Se connecter',
                      onPressed: _login,
                      isLoading: auth.isLoading,
                      icone:     Icons.login,
                      couleur:   const Color(0xFF0D7377),
                    ),
                    const SizedBox(height: 16),

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
                              color:      Color(0xFF0D7377),
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

  InputDecoration _inputDecoration({
    required String   label,
    required IconData icone,
  }) {
    return InputDecoration(
      labelText:  label,
      prefixIcon: Icon(icone, color: const Color(0xFF0D7377)),
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
        borderSide:
            const BorderSide(color: Color(0xFF0D7377), width: 2),
      ),
      filled:    true,
      fillColor: Colors.white,
    );
  }
}