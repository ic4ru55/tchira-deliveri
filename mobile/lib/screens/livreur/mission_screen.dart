import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../../providers/livraison_provider.dart';
import '../../services/socket_service.dart';
import 'home_livreur.dart';

// ─── Service GPS global (singleton) ──────────────────────────────────────────
// Permet de maintenir le GPS actif même si MissionScreen est rebuildt/dépilé
class GpsService {
  static GpsService? _instance;
  static GpsService get instance => _instance ??= GpsService._();
  GpsService._();

  StreamSubscription<Position>? _stream;
  Timer?                        _timerWeb;
  String?                       _livraisonIdActif;
  bool                          get actif => _livraisonIdActif != null;

  // ─── Démarrer ou continuer le GPS ────────────────────────────────────────
  Future<bool> demarrer(String livraisonId) async {
    // Déjà actif pour cette livraison → rien à faire
    if (_livraisonIdActif == livraisonId && actif) return true;

    final serviceActif = await Geolocator.isLocationServiceEnabled();
    if (!serviceActif) { await Geolocator.openLocationSettings(); return false; }

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) { perm = await Geolocator.requestPermission(); }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return false;

    _livraisonIdActif = livraisonId;

    if (kIsWeb) {
      _demarrerWeb(livraisonId); return true;
    }

    await _stream?.cancel();
    _stream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen(
      (pos) => SocketService.envoyerPosition(livraisonId: livraisonId, lat: pos.latitude, lng: pos.longitude),
      onError: (_) { _livraisonIdActif = null; },
    );
    return true;
  }

  void _demarrerWeb(String livraisonId) {
    _timerWeb?.cancel();
    _timerWeb = Timer.periodic(const Duration(seconds: 10), (_) async {
      try {
        final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
        SocketService.envoyerPosition(livraisonId: livraisonId, lat: pos.latitude, lng: pos.longitude);
      } catch (_) {}
    });
  }

  void arreter() {
    _stream?.cancel(); _timerWeb?.cancel();
    _stream = null; _timerWeb = null; _livraisonIdActif = null;
  }
}

// ─── MissionScreen ────────────────────────────────────────────────────────────
class MissionScreen extends StatefulWidget {
  const MissionScreen({super.key});
  @override
  State<MissionScreen> createState() => _MissionScreenState();
}

class _MissionScreenState extends State<MissionScreen> {

  @override
  void initState() {
    super.initState();
    // Démarrer GPS automatiquement si livraison active
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final livraison = context.read<LivraisonProvider>().livraisonActive;
      if (livraison != null) { _demarrerGpsAuto(livraison.id); }
    });
  }

  // GPS auto — ne redemande jamais si déjà actif
  Future<void> _demarrerGpsAuto(String livraisonId) async {
    final succes = await GpsService.instance.demarrer(livraisonId);
    if (mounted) setState(() {});
    if (!succes && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('⚠️ Impossible d\'activer le GPS — vérifie les permissions'),
        backgroundColor: Colors.orange));
    }
  }

  // ─── Ouvrir itinéraire dans Google Maps ────────────────────────────────────
  Future<void> _ouvrirItineraire(String adresse) async {
    final encodee = Uri.encodeComponent(adresse);
    final uri     = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$encodee&travelmode=driving');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossible d\'ouvrir Google Maps'), backgroundColor: Colors.red));
    }
  }

  Future<void> _changerStatut(String statut) async {
    final provider  = context.read<LivraisonProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final livraison = provider.livraisonActive;
    if (livraison == null) return;

    final succes = await provider.mettreAJourStatut(livraison.id, statut);
    if (!mounted) return;

    if (succes) {
      messenger.showSnackBar(SnackBar(
        content: Text(statut == 'en_livraison' ? '🚚 Livraison démarrée !' : '✅ Livraison terminée !'),
        backgroundColor: Colors.green));
      if (statut == 'livre') {
        GpsService.instance.arreter();
        provider.reinitialiserLivraisonActive();
        navigator.pushReplacement(MaterialPageRoute(builder: (_) => const HomeLibreur()));
      } else if (mounted) {
        setState(() {});
      }
    } else {
      messenger.showSnackBar(const SnackBar(content: Text('❌ Erreur mise à jour statut'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider  = context.watch<LivraisonProvider>();
    final livraison = provider.livraisonActive;
    final gpsActif  = GpsService.instance.actif;

    if (livraison == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: const Color(0xFF1B3A6B),
            title: const Text('Mission', style: TextStyle(color: Colors.white))),
        body: const Center(child: Text('Aucune mission active')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B3A6B), elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Mission en cours', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          Row(children: [
            Container(width: 7, height: 7,
              decoration: BoxDecoration(color: gpsActif ? Colors.greenAccent : Colors.grey, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text(gpsActif ? 'GPS actif' : 'GPS inactif',
                style: TextStyle(color: gpsActif ? Colors.greenAccent : Colors.white60, fontSize: 11)),
          ]),
        ]),
        actions: [
          // Bouton GPS dans la barre — toujours visible
          Padding(padding: const EdgeInsets.only(right: 8), child:
            GestureDetector(
              onTap: () => _demarrerGpsAuto(livraison.id),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: gpsActif ? Colors.greenAccent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: gpsActif ? Colors.greenAccent : Colors.white60),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(gpsActif ? Icons.gps_fixed : Icons.gps_not_fixed,
                      color: gpsActif ? Colors.greenAccent : Colors.white70, size: 16),
                  const SizedBox(width: 4),
                  Text(gpsActif ? 'GPS ON' : 'GPS OFF',
                      style: TextStyle(color: gpsActif ? Colors.greenAccent : Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                ]),
              ),
            )),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // ── Statut ──────────────────────────────────────────────────────────
          _carteStatut(livraison.statut),
          const SizedBox(height: 16),

          // ── Client ──────────────────────────────────────────────────────────
          _conteneur(titre: '👤 Client', child: Row(children: [
            const CircleAvatar(radius: 24, backgroundColor: Color(0xFFDBEAFE),
                child: Icon(Icons.person, color: Color(0xFF2563EB), size: 26)),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(livraison.client?['nom'] ?? 'Client', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(livraison.client?['telephone'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 14)),
            ]),
          ])),
          const SizedBox(height: 12),

          // ── Itinéraires (style Yango) ─────────────────────────────────────
          _conteneur(titre: '🗺️ Itinéraire', child: Column(children: [
            // ── Étape 1 : Aller récupérer le colis ─────────────────────────
            _etapeItineraire(
              numero: '1',
              couleur: Colors.green,
              label: livraison.statut == 'en_livraison' ? '✅ Colis récupéré' : '📍 Récupérer le colis',
              adresse: livraison.adresseDepart,
              fait: livraison.statut == 'en_livraison' || livraison.statut == 'livre',
              boutonLabel: 'Ouvrir l\'itinéraire →',
              onBouton: livraison.statut == 'en_cours' ? () => _ouvrirItineraire(livraison.adresseDepart) : null,
            ),
            // Ligne verticale entre les deux étapes
            Padding(padding: const EdgeInsets.only(left: 14), child: Column(
              children: List.generate(3, (_) => Container(width: 2, height: 8, margin: const EdgeInsets.symmetric(vertical: 2), color: Colors.grey.shade300)),
            )),
            // ── Étape 2 : Aller livrer ──────────────────────────────────────
            _etapeItineraire(
              numero: '2',
              couleur: Colors.red,
              label: livraison.statut == 'livre' ? '✅ Livré' : '🏠 Livrer le colis',
              adresse: livraison.adresseArrivee,
              fait: livraison.statut == 'livre',
              boutonLabel: 'Ouvrir l\'itinéraire →',
              onBouton: livraison.statut == 'en_livraison' ? () => _ouvrirItineraire(livraison.adresseArrivee) : null,
            ),
          ])),
          const SizedBox(height: 12),

          // ── Rémunération + description ───────────────────────────────────
          _conteneur(titre: '📦 Détails', child: Column(children: [
            if (livraison.descriptionColis.isNotEmpty) ...[
              _lignInfo(icone: Icons.inventory_2_outlined, couleur: Colors.grey, label: 'Colis', valeur: livraison.descriptionColis),
              const SizedBox(height: 8),
            ],
            const Divider(),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Rémunération', style: TextStyle(color: Colors.grey, fontSize: 14)),
              Text('${_formatPrix(livraison.prix)} FCFA',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF16A34A))),
            ]),
          ])),
          const SizedBox(height: 24),

          // ── Bouton d'action principal ─────────────────────────────────────
          _boutonsAction(livraison.statut),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _etapeItineraire({
    required String numero, required Color couleur, required String label,
    required String adresse, required bool fait, required String boutonLabel,
    VoidCallback? onBouton,
  }) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Numéro/cercle
      Container(width: 28, height: 28, alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: fait ? Colors.grey.shade300 : couleur),
        child: fait
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : Text(numero, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: fait ? Colors.grey : Colors.black87)),
        const SizedBox(height: 2),
        Text(adresse, style: TextStyle(fontSize: 13, color: fait ? Colors.grey.shade400 : Colors.black54), maxLines: 2, overflow: TextOverflow.ellipsis),
        if (onBouton != null) ...[
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: onBouton,
            icon: Icon(Icons.directions, size: 16, color: couleur),
            label: Text(boutonLabel, style: TextStyle(fontSize: 13, color: couleur)),
            style: OutlinedButton.styleFrom(side: BorderSide(color: couleur), padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          )),
        ],
      ])),
    ]);
  }

  Widget _boutonsAction(String statut) {
    if (statut == 'en_cours') {
      return SizedBox(width: double.infinity, height: 52, child: ElevatedButton.icon(
        onPressed: () => _changerStatut('en_livraison'),
        icon: const Icon(Icons.local_shipping, size: 20),
        label: const Text('✅ Colis récupéré — Démarrer la livraison', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))));
    }
    if (statut == 'en_livraison') {
      return SizedBox(width: double.infinity, height: 52, child: ElevatedButton.icon(
        onPressed: () => _changerStatut('livre'),
        icon: const Icon(Icons.check_circle, size: 20),
        label: const Text('✅ Confirmer la livraison', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))));
    }
    return const SizedBox.shrink();
  }

  Widget _carteStatut(String statut) => Container(
    width: double.infinity, padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: _couleurStatut(statut), borderRadius: BorderRadius.circular(16)),
    child: Row(children: [
      Icon(_iconeStatut(statut), color: Colors.white, size: 32),
      const SizedBox(width: 16),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Statut actuel', style: TextStyle(color: Colors.white70, fontSize: 12)),
        Text(_labelStatut(statut), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      ]),
    ]));

  Widget _conteneur({required String titre, required Widget child}) => Container(
    width: double.infinity, padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(titre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1B3A6B))),
      const SizedBox(height: 12), child,
    ]));

  Widget _lignInfo({required IconData icone, required Color couleur, required String label, required String valeur}) =>
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icone, color: couleur, size: 18), const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        Text(valeur, style: const TextStyle(fontSize: 14, color: Colors.black87)),
      ])),
    ]);

  String _formatPrix(dynamic m) { final v = (m as num).toInt(); return v.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (x) => '${x[1]} '); }
  Color  _couleurStatut(String s) { switch (s) { case 'en_cours': return const Color(0xFF2563EB); case 'en_livraison': return Colors.purple; case 'livre': return const Color(0xFF16A34A); default: return Colors.grey; } }
  String _labelStatut(String s)  { switch (s) { case 'en_cours': return 'En cours'; case 'en_livraison': return 'En livraison'; case 'livre': return 'Livré ✅'; default: return s; } }
  IconData _iconeStatut(String s){ switch (s) { case 'en_cours': return Icons.hourglass_top; case 'en_livraison': return Icons.local_shipping; case 'livre': return Icons.check_circle; default: return Icons.info; } }
}