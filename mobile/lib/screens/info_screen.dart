import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// INFO SCREEN — Contient 3 onglets : Nous Contacter / À Propos / Politique
// Accessible depuis le menu profil de chaque rôle
// ═══════════════════════════════════════════════════════════════════════════════

class InfoScreen extends StatefulWidget {
  final int ongletInitial; // 0=Contact 1=À propos 2=Politique
  const InfoScreen({super.key, this.ongletInitial = 0});

  @override
  State<InfoScreen> createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this, initialIndex: widget.ongletInitial);
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D7377),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Tchira Express', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: const Color(0xFFF97316),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.headset_mic_outlined, size: 18), text: 'Contact'),
            Tab(icon: Icon(Icons.info_outline, size: 18), text: 'À propos'),
            Tab(icon: Icon(Icons.shield_outlined, size: 18), text: 'Confidentialité'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: const [
          _PageContact(),
          _PageAPropos(),
          _PagePolitique(),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PAGE CONTACT
// ═══════════════════════════════════════════════════════════════════════════════
class _PageContact extends StatefulWidget {
  const _PageContact();
  @override
  State<_PageContact> createState() => _PageContactState();
}

class _PageContactState extends State<_PageContact> {
  final _nomCtrl     = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool  _envoiEnCours = false;

  @override
  void dispose() { _nomCtrl.dispose(); _messageCtrl.dispose(); super.dispose(); }

  Future<void> _ouvrir(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible d'ouvrir cette application"), backgroundColor: Colors.red));
    }
  }

  Future<void> _envoyerMessage() async {
    if (_nomCtrl.text.trim().isEmpty || _messageCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Remplis tous les champs'), backgroundColor: Colors.red));
      return;
    }
    setState(() => _envoiEnCours = true);

    final sujet  = Uri.encodeComponent('Message de ${_nomCtrl.text.trim()} via Tchira Express');
    final corps  = Uri.encodeComponent(
      'Nom : ${_nomCtrl.text.trim()}\n\nMessage :\n${_messageCtrl.text.trim()}'
    );
    final mailUrl = 'mailto:contact@tchiraexpress.com?subject=$sujet&body=$corps';

    await _ouvrir(mailUrl);
    if (!mounted) return;
    setState(() => _envoiEnCours = false);
    _nomCtrl.clear();
    _messageCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header ──────────────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D7377), Color(0xFF0FA3A8)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Nous contacter', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('On est là pour toi 7j/7 🙌',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14)),
          ]),
        ),
        const SizedBox(height: 24),

        // ── Boutons de contact rapide ────────────────────────────────────────
        const Text('Contact rapide', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1B3A6B))),
        const SizedBox(height: 12),

        _boutonContact(
          icone: Icons.phone_outlined,
          couleur: const Color(0xFF0D7377),
          label: 'Appeler',
          sousTitre: '+226 64 80 49 64',
          onTap: () => _ouvrir('tel:+22664804964'),
        ),
        const SizedBox(height: 10),
        _boutonContact(
          iconeWidget: Image.asset('assets/images/whatsapp.png',
              width: 24, height: 24,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.chat, color: Colors.white, size: 22)),
          couleur: const Color(0xFF25D366),
          label: 'WhatsApp',
          sousTitre: '+226 72 00 73 42',
          onTap: () => _ouvrir('https://wa.me/22672007342'),
        ),
        const SizedBox(height: 10),
        _boutonContact(
          icone: Icons.email_outlined,
          couleur: const Color(0xFFF97316),
          label: 'Email',
          sousTitre: 'contact@tchiraexpress.com',
          onTap: () => _ouvrir('mailto:contact@tchiraexpress.com'),
          onLongPress: () {
            Clipboard.setData(const ClipboardData(text: 'contact@tchiraexpress.com'));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('📋 Email copié !'), backgroundColor: Color(0xFF0D7377)));
          },
        ),
        const SizedBox(height: 28),

        // ── Formulaire de message ────────────────────────────────────────────
        const Text('Envoyer un message', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1B3A6B))),
        const SizedBox(height: 12),
        _champ(_nomCtrl, 'Votre nom', Icons.person_outline),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))]),
          child: TextField(
            controller: _messageCtrl,
            maxLines: 5, minLines: 4,
            decoration: InputDecoration(
              labelText: 'Votre message',
              alignLabelWithHint: true,
              prefixIcon: const Padding(padding: EdgeInsets.only(bottom: 60), child: Icon(Icons.message_outlined, color: Color(0xFF0D7377))),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0D7377), width: 2)),
              filled: true, fillColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, height: 52,
          child: ElevatedButton.icon(
            onPressed: _envoiEnCours ? null : _envoyerMessage,
            icon: _envoiEnCours
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.send_rounded),
            label: const Text('Envoyer via Email', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D7377), foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          )),
        const SizedBox(height: 8),
        Center(child: Text('Le message s\'ouvrira dans votre application email',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500))),
        const SizedBox(height: 32),
      ]),
    );
  }

  Widget _boutonContact({
    IconData? icone, Widget? iconeWidget, required Color couleur,
    required String label, required String sousTitre,
    required VoidCallback onTap, VoidCallback? onLongPress,
  }) {
    return GestureDetector(
      onTap: onTap, onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))]),
        child: Row(children: [
          Container(width: 48, height: 48,
            decoration: BoxDecoration(color: couleur, borderRadius: BorderRadius.circular(12)),
            child: Center(child: iconeWidget ?? Icon(icone!, color: Colors.white, size: 22))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text(sousTitre, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ])),
          Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400),
        ]),
      ),
    );
  }

  Widget _champ(TextEditingController ctrl, String label, IconData icone) =>
    Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))]),
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icone, color: const Color(0xFF0D7377), size: 18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0D7377), width: 2)),
          filled: true, fillColor: Colors.white,
        ),
      ));
}

// ═══════════════════════════════════════════════════════════════════════════════
// PAGE À PROPOS
// ═══════════════════════════════════════════════════════════════════════════════
class _PageAPropos extends StatelessWidget {
  const _PageAPropos();

  Future<void> _ouvrir(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [

        // ── Logo + identité ──────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D7377), Color(0xFF1B3A6B)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(children: [
            // Logo
            Container(width: 88, height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                color: Colors.white.withValues(alpha: 0.1)),
              child: ClipOval(child: Image.asset('assets/images/logo.jpg', fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.local_shipping, color: Colors.white, size: 44)))),
            const SizedBox(height: 16),
            const Text('Tchira Express', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF97316).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20)),
              child: const Text(
                '« Rapide comme l\'éclair, fiable comme une promesse »',
                style: TextStyle(color: Colors.white, fontSize: 12, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              )),
            const SizedBox(height: 12),
            Text('Version 1.0.0', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
          ]),
        ),
        const SizedBox(height: 24),

        // ── Infos entreprise ────────────────────────────────────────────────
        _section('🏢 L\'entreprise', [
          _ligne('Fondée en', '2026'),
          _ligne('Ville', 'Bobo-Dioulasso, Burkina Faso'),
          _ligne('Secteur', 'Livraison express & logistique'),
          _ligne('Spécialité', 'Colis, documents, courses urgentes'),
        ]),
        const SizedBox(height: 16),

        // ── Ce qu'on fait ────────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('🚀 Notre mission', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0D7377))),
            const SizedBox(height: 12),
            const Text(
              'Tchira Express connecte les habitants de Bobo-Dioulasso à un service de livraison rapide, fiable et abordable. '
              'Nous mettons la technologie au service de votre quotidien : '
              'suivez votre colis en temps réel, recevez des notifications à chaque étape et communiquez directement avec votre livreur.',
              style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.6)),
          ]),
        ),
        const SizedBox(height: 16),

        // ── Chiffres clés ────────────────────────────────────────────────────
        Row(children: [
          Expanded(child: _carteChiffre('🚴', 'Livreurs', 'formés & équipés')),
          const SizedBox(width: 12),
          Expanded(child: _carteChiffre('⚡', 'Livraison', 'en moins de 2h')),
          const SizedBox(width: 12),
          Expanded(child: _carteChiffre('📍', 'Bobo', '& environs')),
        ]),
        const SizedBox(height: 16),

        // ── Réseaux sociaux ──────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('📱 Retrouvez-nous', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0D7377))),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => _ouvrir('https://facebook.com/tchiraexpress'),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1877F2).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1877F2).withValues(alpha: 0.2))),
                child: Row(children: [
                  Container(width: 40, height: 40,
                    decoration: BoxDecoration(color: const Color(0xFF1877F2), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.facebook, color: Colors.white, size: 22)),
                  const SizedBox(width: 12),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Facebook', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('Suivez nos actualités', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ])),
                  const Icon(Icons.open_in_new, size: 16, color: Color(0xFF1877F2)),
                ]),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 32),
      ]),
    );
  }

  Widget _section(String titre, List<Widget> lignes) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(titre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0D7377))),
      const SizedBox(height: 12),
      ...lignes,
    ]));

  Widget _ligne(String label, String valeur) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      SizedBox(width: 110, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
      Expanded(child: Text(valeur, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87))),
    ]));

  Widget _carteChiffre(String emoji, String titre, String sousTitre) => Container(
    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))]),
    child: Column(children: [
      Text(emoji, style: const TextStyle(fontSize: 28)),
      const SizedBox(height: 8),
      Text(titre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0D7377))),
      Text(sousTitre, style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center),
    ]));
}

// ═══════════════════════════════════════════════════════════════════════════════
// PAGE POLITIQUE DE CONFIDENTIALITÉ
// ═══════════════════════════════════════════════════════════════════════════════
class _PagePolitique extends StatelessWidget {
  const _PagePolitique();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1B3A6B),
            borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.shield_outlined, color: Colors.white, size: 28),
              SizedBox(width: 10),
              Text('Politique de confidentialité',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 8),
            Text('Dernière mise à jour : janvier 2026',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
          ]),
        ),
        const SizedBox(height: 20),

        _article('1. Qui sommes-nous ?',
          'Tchira Express est une entreprise de livraison express basée à Bobo-Dioulasso, Burkina Faso. '
          'Nous exploitons l\'application mobile "Tchira Express" permettant la mise en relation entre clients et livreurs. '
          'Pour toute question : contact@tchiraexpress.com'),

        _article('2. Données collectées',
          'Nous collectons uniquement les données nécessaires au fonctionnement du service :\n\n'
          '• Données d\'identification : nom complet, adresse email, numéro de téléphone\n'
          '• Données de localisation : position GPS du livreur pendant une mission active (uniquement)\n'
          '• Données de livraison : adresses de départ et d\'arrivée, description des colis\n'
          '• Photo de profil : optionnelle, stockée de manière sécurisée\n'
          '• Token de notification : pour l\'envoi de notifications push'),

        _article('3. Utilisation des données',
          'Vos données sont utilisées exclusivement pour :\n\n'
          '• Permettre la création et la gestion de votre compte\n'
          '• Traiter et suivre vos demandes de livraison\n'
          '• Mettre en relation les clients avec les livreurs disponibles\n'
          '• Vous envoyer des notifications relatives à vos livraisons\n'
          '• Améliorer nos services\n\n'
          'Nous ne vendons, ne louons et ne partageons jamais vos données personnelles avec des tiers à des fins commerciales.'),

        _article('4. Localisation GPS',
          'La géolocalisation des livreurs est activée uniquement pendant une mission en cours. '
          'Elle permet au client de suivre sa livraison en temps réel. '
          'Le livreur peut activer ou désactiver le partage de position à tout moment. '
          'Aucune position n\'est conservée une fois la livraison terminée.'),

        _article('5. Sécurité des données',
          'Vos données sont protégées par :\n\n'
          '• Chiffrement SSL/TLS pour toutes les communications\n'
          '• Mots de passe hashés (bcrypt) — jamais stockés en clair\n'
          '• Authentification par token JWT avec expiration automatique\n'
          '• Accès restreint aux données selon le rôle (client, livreur, réceptionniste, admin)'),

        _article('6. Conservation des données',
          'Vos données personnelles sont conservées tant que votre compte est actif. '
          'En cas de suppression de compte, toutes vos données personnelles sont effacées sous 30 jours. '
          'Les données de livraison anonymisées peuvent être conservées à des fins statistiques.'),

        _article('7. Vos droits',
          'Conformément aux lois applicables, vous disposez des droits suivants :\n\n'
          '• Droit d\'accès : consulter les données que nous détenons sur vous\n'
          '• Droit de rectification : corriger des données inexactes\n'
          '• Droit à l\'effacement : demander la suppression de votre compte\n'
          '• Droit d\'opposition : refuser certains traitements\n\n'
          'Pour exercer ces droits, contactez-nous à : contact@tchiraexpress.com'),

        _article('8. Cookies et technologies similaires',
          'L\'application Tchira Express n\'utilise pas de cookies publicitaires. '
          'Nous utilisons uniquement le stockage local (SharedPreferences) pour maintenir votre session de connexion et vos préférences.'),

        _article('9. Modifications de cette politique',
          'Nous pouvons mettre à jour cette politique à tout moment. '
          'Toute modification importante sera notifiée via l\'application. '
          'L\'utilisation continue de l\'application après notification vaut acceptation des nouvelles conditions.'),

        _article('10. Contact',
          'Pour toute question relative à la confidentialité de vos données :\n\n'
          '📧 contact@tchiraexpress.com\n'
          '📞 +226 64 80 49 64\n'
          '📍 Bobo-Dioulasso, Burkina Faso'),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(top: 8, bottom: 32),
          decoration: BoxDecoration(
            color: const Color(0xFF0D7377).withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF0D7377).withValues(alpha: 0.2))),
          child: const Text(
            '© 2026 Tchira Express — Tous droits réservés\nBobo-Dioulasso, Burkina Faso',
            style: TextStyle(color: Color(0xFF0D7377), fontSize: 12),
            textAlign: TextAlign.center)),
      ]),
    );
  }

  Widget _article(String titre, String contenu) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(titre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1B3A6B))),
      const SizedBox(height: 10),
      Text(contenu, style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.65)),
    ]));
}