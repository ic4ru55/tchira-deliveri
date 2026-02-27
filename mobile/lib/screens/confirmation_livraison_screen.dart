import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// CONFIRMATION LIVRAISON SCREEN — Livreur
// Affiché quand le livreur arrive à destination
// Permet : voir statut paiement OM + confirmer cash + photo preuve livraison
// ═══════════════════════════════════════════════════════════════════════════════

class ConfirmationLivraisonScreen extends StatefulWidget {
  final Map<String, dynamic> livraison;
  final VoidCallback onConfirme;

  const ConfirmationLivraisonScreen({
    super.key,
    required this.livraison,
    required this.onConfirme,
  });

  @override
  State<ConfirmationLivraisonScreen> createState() =>
      _ConfirmationLivraisonScreenState();
}

class _ConfirmationLivraisonScreenState
    extends State<ConfirmationLivraisonScreen> {
  String?  _photoPreuvePath;
  String?  _photoPreuveBase64;
  String?  _photoCashPath;
  String?  _photoCashBase64;
  bool     _envoi          = false;
  final    _picker         = ImagePicker();

  String get _modePaiement =>
      widget.livraison['mode_paiement'] as String? ?? 'cash';
  String get _statutPaiement =>
      widget.livraison['statut_paiement'] as String? ?? 'non_requis';
  double get _prix =>
      (widget.livraison['prix'] as num?)?.toDouble() ?? 0;
  String get _livraisonId => widget.livraison['_id'] as String? ?? '';

  bool get _paiementOMVerifie =>
      _modePaiement == 'om' && _statutPaiement == 'verifie';
  bool get _paiementOMEnAttente =>
      _modePaiement == 'om' && _statutPaiement != 'verifie';

  Future<void> _prendrePhoto(bool estPreuveLivraison) async {
    final picked = await _picker.pickImage(
      source:       ImageSource.camera,
      imageQuality: 70,
      maxWidth:     1200,
    );
    if (picked == null) return;
    final bytes  = await picked.readAsBytes();
    final base64 = base64Encode(bytes);
    setState(() {
      if (estPreuveLivraison) {
        _photoPreuvePath  = picked.path;
        _photoPreuveBase64 = base64;
      } else {
        _photoCashPath    = picked.path;
        _photoCashBase64  = base64;
      }
    });
  }

  Future<void> _confirmerLivraison() async {
    setState(() => _envoi = true);

    try {
      // 1. Photo preuve de livraison (optionnel mais fortement recommandé)
      if (_photoPreuveBase64 != null) {
        await ApiService.soumettrePreuveLivraison(
          livraisonId:  _livraisonId,
          photoBase64:  _photoPreuveBase64!,
        );
      }

      // 2. Si cash → confirmer paiement cash
      if (_modePaiement == 'cash') {
        await ApiService.confirmerCash(
          livraisonId: _livraisonId,
          photoBase64: _photoCashBase64,
        );
      }

      // 3. Marquer la livraison comme livrée
      await ApiService.mettreAJourStatut(_livraisonId, 'livre');

      if (!mounted) return;
      widget.onConfirme();
      Navigator.pop(context);
      _snack('✅ Livraison confirmée avec succès !', couleur: const Color(0xFF10B981));
    } catch (e) {
      if (!mounted) return;
      _snack('Erreur lors de la confirmation', couleur: Colors.red);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  void _snack(String msg, {Color couleur = const Color(0xFF0D7377)}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: couleur,
          duration: const Duration(seconds: 3)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B3A6B),
        title: const Text('Confirmer la livraison',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [

          // ── Badge statut paiement ─────────────────────────────────────────
          _badgeStatutPaiement(),
          const SizedBox(height: 20),

          // ── Section photo preuve livraison (toujours affiché) ─────────────
          _section(
            icone: Icons.camera_alt_outlined,
            titre: 'Photo preuve de livraison',
            sousTitre: 'Prenez une photo du colis remis au destinataire (optionnel mais recommandé)',
            couleur: const Color(0xFF0D7377),
            child: _photoPreuvePath != null
                ? _apercuPhoto(_photoPreuvePath!, () => _prendrePhoto(true))
                : _boutonPhoto('Prendre une photo', () => _prendrePhoto(true),
                    icone: Icons.photo_camera_outlined),
          ),
          const SizedBox(height: 16),

          // ── Section paiement cash (si mode cash) ──────────────────────────
          if (_modePaiement == 'cash') ...[
            _section(
              icone: Icons.payments_outlined,
              titre: 'Confirmer le paiement cash',
              sousTitre: 'Demandez ${_prix.toInt()} FCFA au destinataire et confirmez la réception',
              couleur: const Color(0xFFF97316),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('À encaisser :',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    Text('${_prix.toInt()} FCFA',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18,
                            color: Color(0xFFF97316))),
                  ]),
                ),
                const SizedBox(height: 12),
                _photoCashPath != null
                    ? _apercuPhoto(_photoCashPath!, () => _prendrePhoto(false))
                    : _boutonPhoto('Photo de l\'argent reçu (optionnel)',
                        () => _prendrePhoto(false),
                        icone: Icons.attach_money_outlined),
              ]),
            ),
            const SizedBox(height: 16),
          ],

          // ── Message paiement OM en attente ────────────────────────────────
          if (_paiementOMEnAttente) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3))),
              child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.warning_amber_outlined, color: Colors.orange),
                SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Paiement OM non encore vérifié',
                      style: TextStyle(fontWeight: FontWeight.bold,
                          color: Colors.orange)),
                  SizedBox(height: 4),
                  Text(
                    'Le paiement Orange Money du client est en attente de vérification. '
                    'Vous pouvez quand même confirmer la livraison. '
                    'Si non réglé, le client pourra payer en espèces.',
                    style: TextStyle(fontSize: 12, color: Colors.orange, height: 1.5)),
                ])),
              ]),
            ),
            const SizedBox(height: 16),
          ],

          // ── Bouton confirmer ──────────────────────────────────────────────
          SizedBox(width: double.infinity, height: 56,
            child: ElevatedButton.icon(
              onPressed: _envoi ? null : _confirmerLivraison,
              icon: _envoi
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : const Icon(Icons.check_circle_outline_rounded),
              label: Text(_envoi ? 'Confirmation...' : 'Confirmer la livraison',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
            )),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  // ── Badge statut paiement ──────────────────────────────────────────────────
  Widget _badgeStatutPaiement() {
    Color  couleur;
    IconData icone;
    String texte;
    String detail;

    if (_modePaiement == 'cash') {
      couleur = const Color(0xFFF97316);
      icone   = Icons.payments_outlined;
      texte   = 'Paiement cash à la livraison';
      detail  = 'Encaissez ${_prix.toInt()} FCFA auprès du destinataire';
    } else if (_paiementOMVerifie) {
      couleur = const Color(0xFF10B981);
      icone   = Icons.verified_outlined;
      texte   = 'Paiement Orange Money vérifié ✅';
      detail  = 'Le paiement a été confirmé par notre équipe';
    } else {
      couleur = Colors.orange;
      icone   = Icons.hourglass_empty_rounded;
      texte   = 'Paiement OM en attente de vérification';
      detail  = 'La preuve soumise par le client est en cours de traitement';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: couleur.withValues(alpha: 0.3))),
      child: Row(children: [
        Container(width: 44, height: 44,
          decoration: BoxDecoration(color: couleur, shape: BoxShape.circle),
          child: Icon(icone, color: Colors.white, size: 22)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(texte, style: TextStyle(
              fontWeight: FontWeight.bold, color: couleur, fontSize: 13)),
          const SizedBox(height: 2),
          Text(detail, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ])),
      ]),
    );
  }

  Widget _section({
    required IconData icone,
    required String titre,
    required String sousTitre,
    required Color couleur,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 34, height: 34,
            decoration: BoxDecoration(
                color: couleur.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icone, color: couleur, size: 18)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titre, style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 14)),
            Text(sousTitre, style: const TextStyle(
                fontSize: 11, color: Colors.grey, height: 1.4)),
          ])),
        ]),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }

  Widget _apercuPhoto(String path, VoidCallback onChange) {
    return Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(File(path),
            width: double.infinity, height: 160, fit: BoxFit.cover)),
      const SizedBox(height: 8),
      TextButton.icon(
        onPressed: onChange,
        icon: const Icon(Icons.refresh, size: 16),
        label: const Text('Reprendre'),
      ),
    ]);
  }

  Widget _boutonPhoto(String label, VoidCallback onTap,
      {required IconData icone}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: const Color(0xFF0D7377).withValues(alpha: 0.2),
              style: BorderStyle.solid)),
        child: Column(children: [
          Icon(icone, size: 32, color: Colors.grey),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ]),
      ),
    );
  }
}