import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../screens/auth/login_screen.dart';
import '../../services/api_service.dart';

class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  final _nomCtrl        = TextEditingController();
  final _telCtrl        = TextEditingController();
  final _ancienMdpCtrl  = TextEditingController();
  final _nouveauMdpCtrl = TextEditingController();
  final _confirmMdpCtrl = TextEditingController();

  bool _modificationEnCours = false;
  bool _mdpEnCours          = false;
  bool _afficherMdp         = false;
  bool _chargementPhoto     = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nomCtrl.text = user?.nom       ?? '';
    _telCtrl.text = user?.telephone ?? '';
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _telCtrl.dispose();
    _ancienMdpCtrl.dispose();
    _nouveauMdpCtrl.dispose();
    _confirmMdpCtrl.dispose();
    super.dispose();
  }

  // ─── Choisir photo depuis galerie ─────────────────────────────────────────
  Future<void> _choisirPhoto() async {
    final picker = ImagePicker();
    final image  = await picker.pickImage(
      source:       ImageSource.gallery,
      maxWidth:     400,
      maxHeight:    400,
      imageQuality: 70,
    );
    if (image == null) return;
    if (!mounted) return;

    setState(() => _chargementPhoto = true);
    try {
      final bytes  = await File(image.path).readAsBytes();
      final base64Str = base64Encode(bytes);

      final reponse = await ApiService.mettreAJourProfil(
        photoBase64: 'data:image/jpeg;base64,$base64Str',
      );

      if (!mounted) return;
      if (reponse['success'] == true) {
        // ✅ Rafraîchir le provider pour afficher la nouvelle photo
        await context.read<AuthProvider>().rafraichirProfil();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:         Text('✅ Photo mise à jour !'),
          backgroundColor: Colors.green,
        ));
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:         Text('❌ ${reponse['message']}'),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:         Text('❌ Erreur : $e'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _chargementPhoto = false);
    }
  }

  // ─── Sauvegarder nom / téléphone ──────────────────────────────────────────
  Future<void> _sauvegarderProfil() async {
    if (_nomCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:         Text('Le nom ne peut pas être vide'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    setState(() => _modificationEnCours = true);
    try {
      final reponse = await ApiService.mettreAJourProfil(
        nom:       _nomCtrl.text.trim(),
        telephone: _telCtrl.text.trim(),
      );
      if (!mounted) return;
      if (reponse['success'] == true) {
        await context.read<AuthProvider>().rafraichirProfil();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:         Text('✅ Profil mis à jour !'),
          backgroundColor: Colors.green,
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:         Text('❌ ${reponse['message']}'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _modificationEnCours = false);
    }
  }

  // ─── Changer mot de passe ─────────────────────────────────────────────────
  Future<void> _changerMotDePasse() async {
    if (_nouveauMdpCtrl.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:         Text('Le mot de passe doit faire au moins 6 caractères'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    if (_nouveauMdpCtrl.text != _confirmMdpCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:         Text('Les mots de passe ne correspondent pas'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    setState(() => _mdpEnCours = true);
    try {
      final reponse = await ApiService.changerMotDePasse(
        ancienMdp:  _ancienMdpCtrl.text,
        nouveauMdp: _nouveauMdpCtrl.text,
      );
      if (!mounted) return;
      if (reponse['success'] == true) {
        _ancienMdpCtrl.clear();
        _nouveauMdpCtrl.clear();
        _confirmMdpCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:         Text('✅ Mot de passe changé !'),
          backgroundColor: Colors.green,
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:         Text('❌ ${reponse['message']}'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _mdpEnCours = false);
    }
  }

  // ─── Déconnexion ──────────────────────────────────────────────────────────
  Future<void> _deconnecter() async {
    final auth      = context.read<AuthProvider>();
    final navigator = Navigator.of(context);
    await auth.deconnecter();
    if (!mounted) return;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D7377),
        elevation:       0,
        leading: IconButton(
          icon:      const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Mon Profil',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        child: Column(children: [
          // ── Header avec photo ──────────────────────────────────────────
          Container(
            width:   double.infinity,
            padding: const EdgeInsets.fromLTRB(0, 28, 0, 32),
            decoration: const BoxDecoration(
              color: Color(0xFF0D7377),
              borderRadius: BorderRadius.only(
                bottomLeft:  Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: Column(children: [
              // Photo cliquable
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  GestureDetector(
                    onTap: _choisirPhoto,
                    child: Container(
                      width:  100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape:  BoxShape.circle,
                        border: Border.all(
                            color: Colors.white, width: 3),
                        color: Colors.white
                            .withValues(alpha: 0.2),
                      ),
                      child: _chargementPhoto
                          ? const Padding(
                              padding: EdgeInsets.all(28),
                              child: CircularProgressIndicator(
                                  color:       Colors.white,
                                  strokeWidth: 2),
                            )
                          : ClipOval(
                              child: _buildPhoto(user?.photoBase64),
                            ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF97316),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt,
                        size: 14, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(user?.nom ?? '',
                  style: const TextStyle(
                    color:      Colors.white,
                    fontSize:   20,
                    fontWeight: FontWeight.bold,
                  )),
              const SizedBox(height: 8),
              // ✅ Badge rôle
              _badgeRole(user?.role ?? 'client'),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              // ── Infos compte ───────────────────────────────────────────
              _section(
                titre: '👤 Informations du compte',
                child: Column(children: [
                  _infoLigne('Email',
                      user?.email ?? '', Icons.email_outlined),
                  const Divider(height: 1),
                  _champModifiable(
                    label: 'Nom complet',
                    ctrl:  _nomCtrl,
                    icone: Icons.person_outline,
                  ),
                  const Divider(height: 1),
                  _champModifiable(
                    label:   'Téléphone',
                    ctrl:    _telCtrl,
                    icone:   Icons.phone_outlined,
                    clavier: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity, height: 46,
                    child: ElevatedButton.icon(
                      onPressed: _modificationEnCours
                          ? null
                          : _sauvegarderProfil,
                      icon: _modificationEnCours
                          ? const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white))
                          : const Icon(Icons.save_outlined,
                              size: 18),
                      label: const Text('Sauvegarder'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D7377),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),

              // ── Changer mot de passe ───────────────────────────────────
              _section(
                titre: '🔒 Changer le mot de passe',
                child: Column(children: [
                  _champMdp(
                      ctrl:  _ancienMdpCtrl,
                      label: 'Ancien mot de passe'),
                  const SizedBox(height: 10),
                  _champMdp(
                      ctrl:  _nouveauMdpCtrl,
                      label: 'Nouveau mot de passe'),
                  const SizedBox(height: 10),
                  _champMdp(
                      ctrl:  _confirmMdpCtrl,
                      label: 'Confirmer le nouveau mot de passe'),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity, height: 46,
                    child: ElevatedButton.icon(
                      onPressed:
                          _mdpEnCours ? null : _changerMotDePasse,
                      icon: _mdpEnCours
                          ? const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white))
                          : const Icon(Icons.lock_outline,
                              size: 18),
                      label: const Text('Changer le mot de passe'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B3A6B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),

              // ── Déconnexion ────────────────────────────────────────────
              SizedBox(
                width: double.infinity, height: 50,
                child: OutlinedButton.icon(
                  onPressed: _deconnecter,
                  icon: const Icon(Icons.logout,
                      color: Colors.red, size: 20),
                  label: const Text('Déconnexion',
                      style: TextStyle(
                          color: Colors.red, fontSize: 15)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ]),
          ),
        ]),
      ),
    );
  }

  // ─── Photo : base64 ou icône par défaut ───────────────────────────────────
  Widget _buildPhoto(String? photoBase64) {
    if (photoBase64 != null && photoBase64.isNotEmpty) {
      try {
        final data = photoBase64.replaceFirst(
            RegExp(r'data:image/[^;]+;base64,'), '');
        return Image.memory(
          base64Decode(data),
          fit:    BoxFit.cover,
          width:  100,
          height: 100,
        );
      } catch (_) {}
    }
    return const Icon(Icons.person, size: 56, color: Colors.white70);
  }

  // ─── Badge rôle ───────────────────────────────────────────────────────────
  Widget _badgeRole(String role) {
    final config = _configRole(role);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color:        config['couleur'] as Color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(config['label'] as String,
          style: const TextStyle(
            color:      Colors.white,
            fontWeight: FontWeight.bold,
            fontSize:   13,
          )),
    );
  }

  Map<String, dynamic> _configRole(String role) {
    switch (role) {
      case 'admin':
        return {
          'label':   '👑 Administrateur',
          'couleur': const Color(0xFF7C3AED),
        };
      case 'livreur':
        return {
          'label':   '🚴 Livreur',
          'couleur': const Color(0xFF0D9488),
        };
      case 'receptionniste':
        return {
          'label':   '📋 Réceptionniste',
          'couleur': const Color(0xFF2563EB),
        };
      default:
        return {
          'label':   '👤 Client',
          'couleur': const Color(0xFFF97316),
        };
    }
  }

  // ─── Widgets helpers ──────────────────────────────────────────────────────
  Widget _section({required String titre, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset:     const Offset(0, 2)),
        ],
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Text(titre,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize:   15,
                color:      Color(0xFF0D7377))),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }

  Widget _infoLigne(
      String label, String valeur, IconData icone) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Icon(icone, size: 18, color: Colors.grey),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: Colors.grey)),
          Text(valeur,
              style: const TextStyle(
                  fontSize:   14,
                  color:      Colors.black87,
                  fontWeight: FontWeight.w500)),
        ]),
      ]),
    );
  }

  Widget _champModifiable({
    required TextEditingController ctrl,
    required String                label,
    required IconData              icone,
    TextInputType clavier = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller:   ctrl,
        keyboardType: clavier,
        decoration: InputDecoration(
          labelText:  label,
          prefixIcon: Icon(icone,
              size: 18, color: const Color(0xFF0D7377)),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFFE2E8F0))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFFE2E8F0))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                  color: Color(0xFF0D7377), width: 2)),
          filled:         true,
          fillColor:      const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  Widget _champMdp({
    required TextEditingController ctrl,
    required String                label,
  }) {
    return TextField(
      controller:  ctrl,
      obscureText: !_afficherMdp,
      decoration: InputDecoration(
        labelText:  label,
        prefixIcon: const Icon(Icons.lock_outline,
            size: 18, color: Color(0xFF0D7377)),
        suffixIcon: IconButton(
          icon: Icon(
            _afficherMdp
                ? Icons.visibility_off
                : Icons.visibility,
            size: 18, color: Colors.grey,
          ),
          onPressed: () =>
              setState(() => _afficherMdp = !_afficherMdp),
        ),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
                color: Color(0xFF0D7377), width: 2)),
        filled:         true,
        fillColor:      const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 12),
      ),
    );
  }
}