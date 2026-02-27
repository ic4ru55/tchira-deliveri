import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PAIEMENT CLIENT SCREEN
// Affiché après création d'une commande avec mode_paiement = 'om'
// Montre le code USSD + montant, permet upload de la preuve
// ═══════════════════════════════════════════════════════════════════════════════

class PaiementClientScreen extends StatefulWidget {
  final String livraisonId;
  final double montant;
  final String numeroOM; // numéro OM de Tchira Express

  const PaiementClientScreen({
    super.key,
    required this.livraisonId,
    required this.montant,
    this.numeroOM = '72007342', // numéro WhatsApp/OM Tchira Express
  });

  @override
  State<PaiementClientScreen> createState() => _PaiementClientScreenState();
}

class _PaiementClientScreenState extends State<PaiementClientScreen> {
  String?  _preuveBase64;
  String?  _previewPath;
  bool     _envoi        = false;
  bool     _envoye       = false;
  final    _picker       = ImagePicker();

  String get _codeUSSD =>
      '*144*4*1*${widget.numeroOM}*${widget.montant.toInt()}#';

  Future<void> _choisirImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source:        source,
      imageQuality:  70,
      maxWidth:      1200,
    );
    if (picked == null) return;

    final bytes  = await picked.readAsBytes();
    final base64 = base64Encode(bytes);
    setState(() {
      _preuveBase64 = base64;
      _previewPath  = picked.path;
    });
  }

  Future<void> _soumettre() async {
    if (_preuveBase64 == null) {
      _snack('Veuillez d\'abord ajouter la capture de votre paiement', couleur: Colors.red);
      return;
    }
    setState(() => _envoi = true);
    final r = await ApiService.soumettrePreuvePaiement(
      livraisonId:  widget.livraisonId,
      preuveBase64: _preuveBase64!,
    );
    if (!mounted) return;
    setState(() => _envoi = false);

    if (r['success'] == true) {
      setState(() => _envoye = true);
    } else {
      _snack(r['message'] ?? 'Erreur envoi', couleur: Colors.red);
    }
  }

  void _snack(String msg, {Color couleur = const Color(0xFF0D7377)}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: couleur));
  }

  void _copierCode() {
    Clipboard.setData(ClipboardData(text: _codeUSSD));
    _snack('✅ Code USSD copié !');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D7377),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Paiement Orange Money',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _envoye ? _ecranSucces() : _ecranPaiement(),
    );
  }

  // ─── Écran succès ──────────────────────────────────────────────────────────
  Widget _ecranSucces() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 100, height: 100,
            decoration: const BoxDecoration(
              color: Color(0xFF10B981), shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 56)),
          const SizedBox(height: 24),
          const Text('Preuve envoyée !',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text(
            'Votre preuve de paiement a été transmise.\n'
            'Notre équipe va vérifier et confirmer sous peu.\n'
            'Vous serez notifié dès la validation.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.6)),
          const SizedBox(height: 32),
          SizedBox(width: double.infinity, height: 52,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
              icon: const Icon(Icons.home_outlined),
              label: const Text('Retour à l\'accueil',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D7377), foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            )),
        ]),
      ),
    );
  }

  // ─── Écran principal paiement ──────────────────────────────────────────────
  Widget _ecranPaiement() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [

        // ── Étape 1 : Composer le code USSD ──────────────────────────────────
        _carteEtape(
          numero: '1',
          titre: 'Composez ce code sur votre téléphone',
          couleur: const Color(0xFFF97316),
          child: Column(children: [
            // Code USSD dans un container cliquable
            GestureDetector(
              onTap: _copierCode,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B3A6B),
                  borderRadius: BorderRadius.circular(14)),
                child: Column(children: [
                  Text(_codeUSSD,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 22,
                          fontWeight: FontWeight.bold, letterSpacing: 2),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.copy, color: Colors.white60, size: 14),
                    const SizedBox(width: 4),
                    Text('Appuyez pour copier',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                  ]),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            // Montant mis en évidence
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFF97316).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.3))),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Montant exact à payer :',
                    style: TextStyle(fontSize: 14, color: Colors.black87)),
                Text('${widget.montant.toInt()} FCFA',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFF97316))),
              ]),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10)),
              child: const Row(children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 16),
                SizedBox(width: 8),
                Expanded(child: Text(
                  'Le montant doit correspondre exactement pour validation.',
                  style: TextStyle(fontSize: 12, color: Colors.blue))),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // ── Étape 2 : Capture d'écran ─────────────────────────────────────────
        _carteEtape(
          numero: '2',
          titre: 'Prenez une capture de la confirmation',
          couleur: const Color(0xFF0D7377),
          child: Column(children: [
            const Text(
              'Après le paiement, Orange Money affiche un message de confirmation. '
              'Faites une capture d\'écran de ce message.',
              style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.5)),
          ]),
        ),
        const SizedBox(height: 16),

        // ── Étape 3 : Upload de la preuve ─────────────────────────────────────
        _carteEtape(
          numero: '3',
          titre: 'Envoyez la capture ici',
          couleur: const Color(0xFF8B5CF6),
          child: Column(children: [
            if (_previewPath != null) ...[
              // Preview de l'image
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(File(_previewPath!),
                    width: double.infinity, height: 200, fit: BoxFit.cover)),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => _choisirImage(ImageSource.gallery),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Changer l\'image'),
              ),
            ] else ...[
              // Boutons de sélection
              Row(children: [
                Expanded(child: _boutonSource(
                  icone: Icons.photo_library_outlined,
                  label: 'Galerie',
                  onTap: () => _choisirImage(ImageSource.gallery),
                )),
                const SizedBox(width: 12),
                Expanded(child: _boutonSource(
                  icone: Icons.camera_alt_outlined,
                  label: 'Appareil photo',
                  onTap: () => _choisirImage(ImageSource.camera),
                )),
              ]),
            ],
          ]),
        ),
        const SizedBox(height: 28),

        // ── Bouton envoyer ────────────────────────────────────────────────────
        SizedBox(width: double.infinity, height: 56,
          child: ElevatedButton.icon(
            onPressed: (_envoi || _preuveBase64 == null) ? null : _soumettre,
            icon: _envoi
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.send_rounded),
            label: Text(
              _envoi ? 'Envoi en cours...' : 'Envoyer la preuve de paiement',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _preuveBase64 != null
                  ? const Color(0xFF0D7377) : Colors.grey.shade300,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          )),

        const SizedBox(height: 16),
        // Note info
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.2))),
          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline, color: Colors.orange, size: 16),
            SizedBox(width: 8),
            Expanded(child: Text(
              'Votre livraison est déjà visible par nos livreurs. '
              'Si le paiement n\'est pas encore vérifié au moment de la livraison, '
              'vous pourrez régler en espèces.',
              style: TextStyle(fontSize: 12, color: Colors.orange, height: 1.5))),
          ]),
        ),
        const SizedBox(height: 32),
      ]),
    );
  }

  Widget _carteEtape({
    required String numero,
    required String titre,
    required Color couleur,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(color: couleur, shape: BoxShape.circle),
            child: Center(child: Text(numero,
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 14)))),
          const SizedBox(width: 10),
          Expanded(child: Text(titre,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
        ]),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }

  Widget _boutonSource({
    required IconData icone,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF0D7377).withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF0D7377).withValues(alpha: 0.2))),
        child: Column(children: [
          Icon(icone, color: const Color(0xFF0D7377), size: 28),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(
              color: Color(0xFF0D7377), fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
      ),
    );
  }
}