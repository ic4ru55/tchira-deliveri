import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../client/home_client.dart';
import '../livreur/home_livreur.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _nomCtrl      = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _mdpCtrl      = TextEditingController();
  final _telCtrl      = TextEditingController();
  String _role        = 'client'; // valeur par défaut
  bool   _mdpVisible  = false;

  @override
  void dispose() {
    _nomCtrl.dispose();
    _emailCtrl.dispose();
    _mdpCtrl.dispose();
    _telCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();

    final succes = await auth.register(
      nom:        _nomCtrl.text.trim(),
      email:      _emailCtrl.text.trim(),
      motDePasse: _mdpCtrl.text.trim(),
      telephone:  _telCtrl.text.trim(),
      role:       _role,
    );

    if (!mounted) return;

    if (succes) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => auth.estClient
              ? const HomeClient()
              : const HomeLibreur(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1B3A6B)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Créer un compte',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B3A6B),
                ),
              ),
              const Text(
                'Rejoignez Tchira Delivery',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 32),

              Form(
                key: _formKey,
                child: Column(
                  children: [

                    // Nom complet
                    TextFormField(
                      controller: _nomCtrl,
                      decoration: _inputDecoration(
                        label: 'Nom complet',
                        icone: Icons.person_outlined,
                      ),
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Nom requis' : null,
                    ),
                    const SizedBox(height: 16),

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
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Téléphone
                    TextFormField(
                      controller: _telCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: _inputDecoration(
                        label: 'Téléphone',
                        icone: Icons.phone_outlined,
                      ),
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Téléphone requis' : null,
                    ),
                    const SizedBox(height: 16),

                    // Mot de passe
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
                        if (val == null || val.isEmpty) return 'Mot de passe requis';
                        if (val.length < 6) return 'Minimum 6 caractères';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Sélection du rôle
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text(
                              'Je suis un :',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              _roleOption(
                                valeur: 'client',
                                label:  'Client',
                                icone:  Icons.person,
                              ),
                              _roleOption(
                                valeur: 'livreur',
                                label:  'Livreur',
                                icone:  Icons.delivery_dining,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Message d'erreur
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
                        child: Text(
                          auth.erreur!,
                          style: const TextStyle(color: Color(0xFFDC2626)),
                        ),
                      ),

                    CustomButton(
                      texte:     'Créer mon compte',
                      onPressed: _register,
                      isLoading: auth.isLoading,
                      icone:     Icons.person_add,
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

  // Option de rôle cliquable
  Widget _roleOption({
    required String valeur,
    required String label,
    required IconData icone,
  }) {
    final selectionne = _role == valeur;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _role = valeur),
        child: Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selectionne
                ? const Color(0xFF2563EB)
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Icon(
                icone,
                color: selectionne ? Colors.white : Colors.grey,
                size: 28,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: selectionne ? Colors.white : Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
      filled:    true,
      fillColor: Colors.white,
    );
  }
}