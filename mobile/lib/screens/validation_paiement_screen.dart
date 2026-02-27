import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// VALIDATION PAIEMENT SCREEN — Réceptionniste / Admin
// Liste toutes les preuves OM en attente + boutons Valider / Rejeter
// ═══════════════════════════════════════════════════════════════════════════════

class ValidationPaiementScreen extends StatefulWidget {
  const ValidationPaiementScreen({super.key});

  @override
  State<ValidationPaiementScreen> createState() => _ValidationPaiementScreenState();
}

class _ValidationPaiementScreenState extends State<ValidationPaiementScreen> {
  List<dynamic> _preuves   = [];
  bool          _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _chargement = true);
    final r = await ApiService.getPreuvesEnAttente();
    if (!mounted) return;
    setState(() {
      _preuves    = r['livraisons'] ?? [];
      _chargement = false;
    });
  }

  Future<void> _agir(String id, String action, {String? motif}) async {
    final r = await ApiService.validerPreuvePaiement(
        livraisonId: id, action: action, motif: motif);
    if (!mounted) return;
    if (r['success'] == true) {
      _snack(action == 'valider' ? '✅ Paiement validé !' : '❌ Preuve rejetée',
          couleur: action == 'valider' ? const Color(0xFF10B981) : Colors.red);
      _charger();
    } else {
      _snack(r['message'] ?? 'Erreur', couleur: Colors.red);
    }
  }

  Future<void> _confirmerRejet(String id) async {
    final motifCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rejeter la preuve'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Indiquez le motif du rejet (visible par le client) :'),
          const SizedBox(height: 12),
          TextField(
            controller: motifCtrl,
            decoration: const InputDecoration(
              hintText: 'ex: Montant incorrect, image floue...',
              border: OutlineInputBorder()),
            maxLines: 2,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rejeter', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) _agir(id, 'rejeter', motif: motifCtrl.text.trim());
  }

  void _voirPreuve(BuildContext context, String base64Data) {
    final Uint8List bytes = base64Decode(base64Data);
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(bytes, fit: BoxFit.contain)),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white),
            label: const Text('Fermer', style: TextStyle(color: Colors.white))),
        ]),
      ),
    );
  }

  void _snack(String msg, {Color couleur = const Color(0xFF0D7377)}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: couleur));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D7377),
        title: const Text('Preuves de paiement',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _charger),
        ],
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D7377)))
          : _preuves.isEmpty
              ? _ecranVide()
              : RefreshIndicator(
                  onRefresh: _charger,
                  color: const Color(0xFF0D7377),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _preuves.length,
                    itemBuilder: (_, i) => _cartePreuve(_preuves[i]),
                  ),
                ),
    );
  }

  Widget _ecranVide() {
    return const Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.check_circle_outline, size: 64, color: Color(0xFF10B981)),
        SizedBox(height: 16),
        Text('Aucune preuve en attente',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        SizedBox(height: 8),
        Text('Toutes les preuves ont été traitées.',
            style: TextStyle(color: Colors.grey)),
      ]),
    );
  }

  Widget _cartePreuve(Map<String, dynamic> liv) {
    final id       = liv['_id'] as String;
    final client   = liv['client']  as Map<String, dynamic>? ?? {};
    final preuve   = liv['preuve_paiement'] as Map<String, dynamic>? ?? {};
    final prix     = (liv['prix'] as num?)?.toDouble() ?? 0;
    final depart   = liv['adresse_depart']  as String? ?? '';
    final arrivee  = liv['adresse_arrivee'] as String? ?? '';
    final soumisLe = preuve['soumis_le'] != null
        ? DateTime.tryParse(preuve['soumis_le'] as String)
        : null;
    final preuveData = preuve['data'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header ──────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF97316).withValues(alpha: 0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: const BoxDecoration(
                color: Color(0xFFF97316), shape: BoxShape.circle),
              child: const Icon(Icons.receipt_long, color: Colors.white, size: 18)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('#${id.substring(id.length - 6).toUpperCase()}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
              if (soumisLe != null)
                Text('Soumis le ${soumisLe.day}/${soumisLe.month} à ${soumisLe.hour}h${soumisLe.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20)),
              child: const Text('En attente',
                  style: TextStyle(color: Colors.orange,
                      fontWeight: FontWeight.w600, fontSize: 11))),
          ]),
        ),

        // ── Infos ────────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _ligne(Icons.person_outline, client['nom'] ?? 'Client', Colors.blue),
            if ((client['telephone'] ?? '').isNotEmpty)
              _ligne(Icons.phone_outlined, client['telephone'] as String, Colors.grey),
            const SizedBox(height: 8),
            _ligne(Icons.trip_origin, depart, Colors.green),
            _ligne(Icons.location_on_outlined, arrivee, Colors.red),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF0D7377).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Montant à valider :',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                Text('${prix.toInt()} FCFA',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16,
                        color: Color(0xFF0D7377))),
              ]),
            ),

            // ── Preuve ────────────────────────────────────────────────────────
            if (preuveData != null) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => _voirPreuve(context, preuveData),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(children: [
                    Image.memory(base64Decode(preuveData),
                        width: double.infinity, height: 180, fit: BoxFit.cover),
                    Positioned.fill(child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: [Colors.transparent,
                              Colors.black.withValues(alpha: 0.4)])),
                    )),
                    const Positioned(
                      bottom: 8, right: 8,
                      child: Row(children: [
                        Icon(Icons.zoom_in, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text('Agrandir',
                            style: TextStyle(color: Colors.white, fontSize: 12)),
                      ])),
                  ]),
                ),
              ),
            ],

            // ── Boutons action ────────────────────────────────────────────────
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () => _confirmerRejet(id),
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('Rejeter'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              )),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton.icon(
                onPressed: () => _agir(id, 'valider'),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Valider',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              )),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _ligne(IconData icone, String texte, Color couleur) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Icon(icone, size: 14, color: couleur),
        const SizedBox(width: 6),
        Expanded(child: Text(texte,
            style: const TextStyle(fontSize: 13),
            overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}