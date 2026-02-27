import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/profil_screen.dart';
import '../screens/info_screen.dart';
import '../screens/parametres_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PROFIL PAGE — Widget réutilisable dans tous les HomeScreens (client, livreur, etc.)
// Remplace la section profil actuelle dans home_*.dart
//
// Usage dans home_client.dart / home_livreur.dart / etc. :
//   ProfilPage(role: 'client', couleurRole: Color(0xFFF97316), onDeconnexion: () { ... })
// ═══════════════════════════════════════════════════════════════════════════════

class ProfilPage extends StatelessWidget {
  final String role;
  final Color  couleurRole;
  final VoidCallback? onDeconnexion;

  const ProfilPage({
    super.key,
    required this.role,
    required this.couleurRole,
    this.onDeconnexion,
  });

  String get _labelRole => switch (role) {
    'client'         => '👤 Client',
    'livreur'        => '🚴 Livreur',
    'admin'          => '⚙️ Administrateur',
    'receptionniste' => '🏢 Réceptionniste',
    _                => role,
  };

  String get _emojiRole => switch (role) {
    'client'         => '👤',
    'livreur'        => '🚴',
    'admin'          => '⚙️',
    'receptionniste' => '🏢',
    _                => '👤',
  };

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: CustomScrollView(
        slivers: [

          // ─── Header hero ───────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: const Color(0xFF0D7377),
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0D7377), Color(0xFF1B3A6B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 8),
                      // Avatar + bouton modifier
                      Stack(alignment: Alignment.bottomRight, children: [
                        GestureDetector(
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const ProfilScreen()))
                              .then((_) => auth.rafraichirProfil()),
                          child: Container(
                            width: 90, height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                            child: ClipOval(child: _buildAvatar(user?.photoBase64)),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const ProfilScreen()))
                              .then((_) => auth.rafraichirProfil()),
                          child: Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: couleurRole,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.edit, size: 14, color: Colors.white),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      Text(user?.nom ?? '',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(user?.email ?? '',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
                      const SizedBox(height: 8),
                      // Badge rôle
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: couleurRole.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(_labelRole,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ─── Corps ─────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // ── Infos rapides ─────────────────────────────────────────────
                _carteInfos(context, user),
                const SizedBox(height: 16),

                // ── Mon compte ───────────────────────────────────────────────
                _titreSectionn('👤  Mon compte'),
                const SizedBox(height: 8),
                _carteListe([
                  _ItemMenu(
                    icone: Icons.person_outline,
                    couleur: const Color(0xFF0D7377),
                    titre: 'Modifier mon profil',
                    sousTitre: 'Nom, téléphone, photo',
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const ProfilScreen()))
                        .then((_) => auth.rafraichirProfil()),
                  ),
                  _ItemMenu(
                    icone: Icons.settings_outlined,
                    couleur: const Color(0xFF6366F1),
                    titre: 'Paramètres',
                    sousTitre: 'Langue, thème, notifications',
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const ParametresScreen())),
                  ),
                ]),
                const SizedBox(height: 16),

                // ── Informations ─────────────────────────────────────────────
                _titreSectionn('ℹ️  Informations'),
                const SizedBox(height: 8),
                _carteListe([
                  _ItemMenu(
                    icone: Icons.headset_mic_outlined,
                    couleur: const Color(0xFF10B981),
                    titre: 'Nous contacter',
                    sousTitre: 'Email, WhatsApp, téléphone',
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const InfoScreen(ongletInitial: 0))),
                  ),
                  _ItemMenu(
                    icone: Icons.info_outline,
                    couleur: const Color(0xFF3B82F6),
                    titre: 'À propos',
                    sousTitre: 'Version, mission, réseaux sociaux',
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const InfoScreen(ongletInitial: 1))),
                  ),
                  _ItemMenu(
                    icone: Icons.shield_outlined,
                    couleur: const Color(0xFF8B5CF6),
                    titre: 'Politique de confidentialité',
                    sousTitre: 'Données, droits, sécurité',
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const InfoScreen(ongletInitial: 2))),
                  ),
                ]),
                const SizedBox(height: 16),

                // ── Déconnexion ───────────────────────────────────────────────
                _carteListe([
                  _ItemMenu(
                    icone: Icons.logout_rounded,
                    couleur: Colors.red,
                    titre: 'Se déconnecter',
                    sousTitre: 'Quitter votre session',
                    destructif: true,
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: const Text('Déconnexion', style: TextStyle(fontWeight: FontWeight.bold)),
                          content: const Text("Voulez-vous vraiment vous déconnecter ?"),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                              child: const Text('Déconnecter'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true && context.mounted) {
                        if (onDeconnexion != null) {
                          onDeconnexion!();
                        } else {
                          await auth.deconnecter();
                          if (context.mounted) {
                            Navigator.of(context).pushReplacement(
                                MaterialPageRoute(builder: (_) => const LoginScreen()));
                          }
                        }
                      }
                    },
                  ),
                ]),

                const SizedBox(height: 32),
                // Version
                Center(child: Text('Tchira Express v1.0.0',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400))),
                const SizedBox(height: 8),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String? base64) {
    if (base64 != null && base64.isNotEmpty) {
      try {
        final bytes = base64Decode(base64.contains(',') ? base64.split(',').last : base64);
        return Image.memory(bytes, fit: BoxFit.cover, width: 90, height: 90);
      } catch (_) {}
    }
    return Center(child: Text(_emojiRole, style: const TextStyle(fontSize: 36)));
  }

  Widget _carteInfos(BuildContext context, dynamic user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        _ligneInfoCompact(Icons.email_outlined, 'Email', user?.email ?? '—', const Color(0xFF0D7377)),
        const Divider(height: 20),
        _ligneInfoCompact(Icons.phone_outlined, 'Téléphone', user?.telephone ?? '—', const Color(0xFFF97316)),
      ]),
    );
  }

  Widget _ligneInfoCompact(IconData icone, String label, String valeur, Color couleur) {
    return Row(children: [
      Container(width: 36, height: 36,
        decoration: BoxDecoration(color: couleur.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icone, size: 18, color: couleur)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(valeur, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
            overflow: TextOverflow.ellipsis),
      ])),
    ]);
  }

  Widget _titreSectionn(String titre) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(titre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
        color: Colors.black54, letterSpacing: 0.3)));

  Widget _carteListe(List<_ItemMenu> items) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
    ),
    child: Column(children: [
      for (int i = 0; i < items.length; i++) ...[
        _tuileMenu(items[i]),
        if (i < items.length - 1) const Divider(height: 1, indent: 60),
      ],
    ]),
  );

  Widget _tuileMenu(_ItemMenu item) => InkWell(
    onTap: item.onTap,
    borderRadius: BorderRadius.circular(16),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Container(width: 40, height: 40,
          decoration: BoxDecoration(
            color: item.destructif
                ? Colors.red.withValues(alpha: 0.1)
                : item.couleur.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12)),
          child: Icon(item.icone, size: 20,
            color: item.destructif ? Colors.red : item.couleur)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.titre, style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w600,
            color: item.destructif ? Colors.red : Colors.black87)),
          if (item.sousTitre != null)
            Text(item.sousTitre!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ])),
        Icon(Icons.chevron_right, size: 20,
          color: item.destructif ? Colors.red.withValues(alpha: 0.5) : Colors.grey.shade300),
      ]),
    ),
  );
}

class _ItemMenu {
  final IconData icone;
  final Color couleur;
  final String titre;
  final String? sousTitre;
  final bool destructif;
  final VoidCallback? onTap;

  const _ItemMenu({
    required this.icone,
    required this.couleur,
    required this.titre,
    this.sousTitre,
    this.destructif = false,
    this.onTap,
  });
}