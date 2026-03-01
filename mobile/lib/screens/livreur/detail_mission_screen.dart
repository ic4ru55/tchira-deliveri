// ═══════════════════════════════════════════════════════════════════
// ÉCRAN DÉTAIL MISSION — lib/screens/livreur/detail_mission_screen.dart
//
// Affiché quand le livreur tape sur une mission disponible
// Montre TOUS les détails avant qu'il accepte :
//   - Prix + mode paiement
//   - Adresses départ/arrivée complètes
//   - Infos client (nom + tel)
//   - Description et catégorie du colis
//   - Zone + frais
//   - Date de création
//   - Bouton "Accepter" en bas
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/livraison_provider.dart';
import '../../models/livraison.dart';
import 'mission_screen.dart';

class DetailMissionScreen extends StatefulWidget {
  final Livraison livraison;
  const DetailMissionScreen({super.key, required this.livraison});
  @override State<DetailMissionScreen> createState() => _DetailMissionScreenState();
}

class _DetailMissionScreenState extends State<DetailMissionScreen> {
  bool _loading = false;
  static const _teal  = Color(0xFF0D7377);
  static const _navy  = Color(0xFF1B3A6B);
  static const _green = Color(0xFF16A34A);

  Livraison get liv => widget.livraison;

  Future<void> _accepter() async {
    setState(() => _loading = true);
    HapticFeedback.mediumImpact();

    final prov      = context.read<LivraisonProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final dynamic ret = await prov.accepterLivraison(liv.id);
    if (!mounted) return;
    setState(() => _loading = false);

    bool ok; String msg = '❌ Mission non disponible';
    if (ret is bool)     { ok = ret; }
    else if (ret is Map) { ok = ret['succes'] == true; msg = ret['message'] as String? ?? msg; }
    else                 { ok = false; }

    if (ok) {
      messenger.showSnackBar(const SnackBar(
          content: Text('✅ Mission acceptée !'),
          backgroundColor: _green,
          behavior: SnackBarBehavior.floating));
      await GpsService.instance.demarrer(liv.id);
      if (!mounted) return;
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MissionScreen()),
        (route) => route.isFirst,
      );
    } else {
      messenger.showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating));
      navigator.pop(); // Retour à la liste (mission prise par quelqu'un d'autre)
    }
  }

  Future<void> _appeler(String tel) async {
    final uri = Uri.parse('tel:$tel');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F6F8),
      body: Column(children: [
        // ── Header ─────────────────────────────────────────────────
        _header(),

        // ── Contenu scrollable ──────────────────────────────────────
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Carte prix + mode paiement
            _sectionPrix(),
            const SizedBox(height: 14),

            // Itinéraire complet
            _sectionItineraire(),
            const SizedBox(height: 14),

            // Client
            _sectionClient(),
            const SizedBox(height: 14),

            // Détails colis
            _sectionColis(),
            const SizedBox(height: 14),

            // Infos supplémentaires
            _sectionInfos(),
            const SizedBox(height: 16),
          ]),
        )),

        // ── Bouton accepter fixe en bas ─────────────────────────────
        Container(
          padding: EdgeInsets.fromLTRB(16, 12, 16, safeBottom + 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16, offset: const Offset(0, -4))]),
          child: SizedBox(
            width: double.infinity, height: 54,
            child: ElevatedButton(
              onPressed: _loading ? null : _accepter,
              style: ElevatedButton.styleFrom(
                backgroundColor: _green, foregroundColor: Colors.white,
                elevation: 3, shadowColor: _green.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
              child: _loading
                ? const SizedBox(width: 24, height: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.check_circle_outline, size: 20),
                    const SizedBox(width: 8),
                    const Text('Accepter cette mission',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16)),
                  ]),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Header avec retour ──────────────────────────────────────────────────────
  Widget _header() {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(16, top + 12, 16, 16),
      decoration: const BoxDecoration(
        color: _teal,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24))),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20))),
        const SizedBox(width: 12),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Détails de la mission',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
          Text('Vérifiez tout avant d\'accepter',
              style: TextStyle(color: Colors.white60, fontSize: 12)),
        ])),
        // Badge date
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10)),
          child: Text(_dateRel(liv.createdAt),
              style: const TextStyle(
                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600))),
      ]),
    );
  }

  // ── Section prix + paiement ─────────────────────────────────────────────────
  Widget _sectionPrix() => _card(
    child: Row(children: [
      // Prix principal
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_teal, _navy]),
          borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          Text(_fmt(liv.prix),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
          const Text('FCFA', style: TextStyle(color: Colors.white70, fontSize: 11)),
        ])),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Mode paiement
        Row(children: [
          Icon(
            liv.modePaiement == 'cash'
                ? Icons.payments_outlined
                : Icons.phone_android_outlined,
            size: 16,
            color: liv.modePaiement == 'cash'
                ? const Color(0xFFF97316)
                : Colors.green.shade700),
          const SizedBox(width: 6),
          Text(
            liv.modePaiement == 'cash' ? 'Paiement Cash' : 'Orange Money',
            style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14,
                color: liv.modePaiement == 'cash'
                    ? const Color(0xFFF97316)
                    : Colors.green.shade700)),
        ]),
        const SizedBox(height: 4),
        if (liv.fraisZone > 0)
          Text('Dont ${_fmt(liv.fraisZone)} F de frais zone',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        Text('Zone : ${liv.zone.replaceAll('_', ' ')}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
      ])),
    ]),
  );

  // ── Section itinéraire ──────────────────────────────────────────────────────
  Widget _sectionItineraire() => _card(
    label: '📍 Itinéraire',
    child: Column(children: [
      // Départ
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          Container(width: 14, height: 14,
              decoration: const BoxDecoration(color: _green, shape: BoxShape.circle)),
          Container(width: 2, height: 36, color: Colors.grey.shade200),
        ]),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Départ', style: TextStyle(
              fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
          Text(liv.adresseDepart,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ])),
      ]),
      // Arrivée
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          Container(width: 14, height: 14,
              decoration: BoxDecoration(
                  color: Colors.red.shade500,
                  borderRadius: BorderRadius.circular(3))),
        ]),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Arrivée', style: TextStyle(
              fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
          Text(liv.adresseArrivee,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ])),
      ]),
    ]),
  );

  // ── Section client ──────────────────────────────────────────────────────────
  Widget _sectionClient() {
    final nom = liv.client?['nom'] as String? ?? 'Client';
    final tel = liv.client?['telephone'] as String? ?? '';
    return _card(
      label: '👤 Client',
      child: Row(children: [
        Container(width: 46, height: 46,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [_teal, _navy],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.person, color: Colors.white, size: 24)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(nom, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          if (tel.isNotEmpty) Text(tel,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        ])),
        // Bouton appel
        if (tel.isNotEmpty) GestureDetector(
          onTap: () => _appeler(tel),
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _green.withValues(alpha: 0.3))),
            child: const Icon(Icons.call, color: _green, size: 20))),
      ]),
    );
  }

  // ── Section colis ───────────────────────────────────────────────────────────
  Widget _sectionColis() {
    final hasDesc = liv.descriptionColis.isNotEmpty;
    final hasCat  = liv.categorieColis.isNotEmpty;
    if (!hasDesc && !hasCat) return const SizedBox.shrink();
    return _card(
      label: '📦 Colis',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (hasCat) Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: _teal.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8)),
            child: Text(_labelCategorie(liv.categorieColis),
                style: const TextStyle(
                    color: _teal, fontWeight: FontWeight.w700, fontSize: 12))),
        ]),
        if (hasCat && hasDesc) const SizedBox(height: 8),
        if (hasDesc) Text(liv.descriptionColis,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.4)),
      ]),
    );
  }

  // ── Section infos supplémentaires ──────────────────────────────────────────
  Widget _sectionInfos() => _card(
    label: 'ℹ️ Informations',
    child: Column(children: [
      _ligneInfo('Créée', _dateComplete(liv.createdAt)),
      _ligneInfo('Mission ID', '#${liv.id.substring(liv.id.length > 8 ? liv.id.length - 8 : 0)}'),
      if (liv.prixBase > 0 && liv.fraisZone > 0) ...[
        _ligneInfo('Prix de base', '${_fmt(liv.prixBase)} FCFA'),
        _ligneInfo('Frais de zone', '${_fmt(liv.fraisZone)} FCFA'),
      ],
    ]),
  );

  // ── Helpers layout ──────────────────────────────────────────────────────────
  Widget _card({String? label, required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10, offset: const Offset(0, 3)),
      ]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (label != null) ...[
        Text(label, style: const TextStyle(
            fontWeight: FontWeight.w800, fontSize: 15, color: _navy)),
        const SizedBox(height: 12),
        Container(height: 1, color: const Color(0xFFF0F4F8)),
        const SizedBox(height: 12),
      ],
      child,
    ]),
  );

  Widget _ligneInfo(String label, String valeur) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Text(label, style: TextStyle(
          fontSize: 13, color: Colors.grey.shade400, fontWeight: FontWeight.w500)),
      const Spacer(),
      Text(valeur, style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600, color: _navy)),
    ]),
  );

  String _labelCategorie(String c) {
    switch (c) {
      case 'leger':    return '🪶 Léger';
      case 'moyen':    return '📦 Moyen';
      case 'lourd':    return '🏋️ Lourd';
      case 'fragile':  return '🔮 Fragile';
      case 'urgent':   return '⚡ Urgent';
      default:         return c;
    }
  }

  String _fmt(dynamic m) {
    if (m == null) return '0';
    final v = (m as num).toInt();
    return v.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (x) => '${x[1]} ');
  }

  String _dateRel(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1)  return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes}min';
    if (diff.inHours < 24)   return 'Il y a ${diff.inHours}h';
    return '${d.day}/${d.month}';
  }

  String _dateComplete(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}