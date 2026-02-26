import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../providers/livraison_provider.dart';
import '../../models/livraison.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/profil_screen.dart';
import '../../services/api_service.dart';
import 'tracking_screen.dart';
import '../map_picker_screen.dart';
import '../info_screen.dart';

class HomeClient extends StatefulWidget {
  const HomeClient({super.key});
  @override
  State<HomeClient> createState() => _HomeClientState();
}

class _HomeClientState extends State<HomeClient> {
  int _ongletActif = 0;

  final _departCtrl  = TextEditingController();
  final _arriveeCtrl = TextEditingController();
  final _descCtrl    = TextEditingController();

  Timer? _timer;
  bool   _formVisible      = false;
  bool   _chargementTarifs = true;
  bool   _gpsEnCours       = false;
  bool   _calculEnCours    = false;
  bool   _surDevis         = false;

  List<dynamic> _tarifs = [];
  List<dynamic> _zones  = [];
  String? _categorieSelectionnee;
  String? _zoneSelectionnee;
  double? _prixBase;
  double? _fraisZone;
  double? _prixTotal;

  // Coordonnées pour transmission au backend
  LatLng? _coordDepart;
  LatLng? _coordArrivee;

  @override
  void initState() {
    super.initState();
    _chargerTarifs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LivraisonProvider>().chargerMesLivraisons();
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (mounted) context.read<LivraisonProvider>().chargerMesLivraisons(silencieux: true);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _departCtrl.dispose(); _arriveeCtrl.dispose(); _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _chargerTarifs() async {
    try {
      final r = await ApiService.getTarifs();
      if (!mounted) return;
      if (r['success'] == true) {
        setState(() { _tarifs = r['tarifs']; _zones = r['zones']; _chargementTarifs = false; });
      }
    } catch (_) { if (mounted) setState(() => _chargementTarifs = false); }
  }

  Future<void> _calculerPrix() async {
    if (_categorieSelectionnee == null || _zoneSelectionnee == null) return;
    setState(() => _calculEnCours = true);
    try {
      final r = await ApiService.calculerPrix(categorie: _categorieSelectionnee!, zoneCode: _zoneSelectionnee!);
      if (!mounted) return;
      if (r['success'] == true) {
        setState(() {
          _surDevis  = r['sur_devis'] ?? false;
          _prixBase  = (r['prix_base']  ?? 0).toDouble();
          _fraisZone = (r['frais_zone'] ?? 0).toDouble();
          _prixTotal = (r['prix_total'] ?? 0).toDouble();
        });
      }
    } finally { if (mounted) setState(() => _calculEnCours = false); }
  }

  // ─── GPS classique pour le point de départ ─────────────────────────────────
  Future<void> _recupererPositionGPS() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _gpsEnCours = true);
    try {
      final serviceActif = await Geolocator.isLocationServiceEnabled();
      if (!serviceActif) {
        messenger.showSnackBar(const SnackBar(content: Text('Active le GPS dans les paramètres'), backgroundColor: Colors.red));
        await Geolocator.openLocationSettings(); return;
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) { perm = await Geolocator.requestPermission(); }
      if (perm == LocationPermission.denied) {
        messenger.showSnackBar(const SnackBar(content: Text('Permission GPS refusée'), backgroundColor: Colors.red)); return;
      }
      if (perm == LocationPermission.deniedForever) {
        messenger.showSnackBar(const SnackBar(content: Text('GPS bloqué — Paramètres > Apps > Tchira > Permissions'), backgroundColor: Colors.red));
        await Geolocator.openAppSettings(); return;
      }
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      if (!mounted) return;
      _coordDepart = LatLng(pos.latitude, pos.longitude);
      if (kIsWeb) {
        setState(() => _departCtrl.text = '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}');
        messenger.showSnackBar(const SnackBar(content: Text('✅ Position récupérée !'), backgroundColor: Colors.green));
        return;
      }
      try {
        final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (!mounted) return;
        if (placemarks.isNotEmpty) {
          final p   = placemarks.first;
          final adr = [p.street, p.subLocality, p.locality].where((e) => e != null && e.isNotEmpty).join(', ');
          setState(() => _departCtrl.text = adr.isNotEmpty ? adr : '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}');
        }
        messenger.showSnackBar(const SnackBar(content: Text('✅ Position récupérée !'), backgroundColor: Colors.green));
      } catch (_) {
        if (!mounted) return;
        setState(() => _departCtrl.text = '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}');
        messenger.showSnackBar(const SnackBar(content: Text('✅ Position récupérée !'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur GPS : $e'), backgroundColor: Colors.red));
    } finally { if (mounted) setState(() => _gpsEnCours = false); }
  }

  // ─── NOUVEAU : Ouvrir la carte pour choisir un point ──────────────────────
  Future<void> _ouvrirCartePicker({required bool estDepart}) async {
    if (kIsWeb) {
      // Sur web, pas de Maps natif — fallback sur le GPS ou la saisie manuelle
      _snack('Sélection carte non disponible sur web — utilisez le GPS ou saisissez l\'adresse', Colors.orange);
      return;
    }
    final resultat = await Navigator.push<MapPickerResult>(
      context,
      MaterialPageRoute(builder: (_) => MapPickerScreen(
        titre: estDepart ? 'Point de départ' : 'Point de livraison',
        positionInitiale: estDepart ? _coordDepart : _coordArrivee,
      )),
    );
    if (!mounted || resultat == null) return;
    setState(() {
      if (estDepart) {
        _departCtrl.text = resultat.adresse;
        _coordDepart     = resultat.position;
      } else {
        _arriveeCtrl.text = resultat.adresse;
        _coordArrivee     = resultat.position;
      }
    });
  }

  Future<void> _creerLivraison() async {
    if (_departCtrl.text.isEmpty || _arriveeCtrl.text.isEmpty) { _snack('Remplis les adresses', Colors.red); return; }
    if (_categorieSelectionnee == null) { _snack('Sélectionne une catégorie', Colors.red); return; }
    if (_zoneSelectionnee == null) { _snack('Sélectionne une zone', Colors.red); return; }
    if (_surDevis) { _snack("Contacte l'admin pour ce type de colis", Colors.orange); return; }

    final provider  = context.read<LivraisonProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final succes    = await provider.creerLivraison(
      adresseDepart: _departCtrl.text.trim(), adresseArrivee: _arriveeCtrl.text.trim(),
      categorie: _categorieSelectionnee!, zoneCode: _zoneSelectionnee!,
      prix: _prixTotal ?? 0, prixBase: _prixBase ?? 0, fraisZone: _fraisZone ?? 0,
      description: _descCtrl.text.trim(),
    );
    if (!mounted) return;
    if (succes) {
      _departCtrl.clear(); _arriveeCtrl.clear(); _descCtrl.clear();
      setState(() {
        _formVisible = false; _categorieSelectionnee = null; _zoneSelectionnee = null;
        _prixTotal = null; _prixBase = null; _fraisZone = null;
        _coordDepart = null; _coordArrivee = null;
      });
      messenger.showSnackBar(const SnackBar(content: Text('✅ Livraison créée !'), backgroundColor: Colors.green));
      setState(() => _ongletActif = 1);
    } else {
      messenger.showSnackBar(const SnackBar(content: Text('❌ Erreur lors de la création'), backgroundColor: Colors.red));
    }
  }

  void _snack(String msg, Color c) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: c));

  @override
  Widget build(BuildContext context) {
    final auth     = context.watch<AuthProvider>();
    final provider = context.watch<LivraisonProvider>();
    final user     = auth.user;

    final pages = [
      _pageAccueil(provider, user),
      _pageLivraisons(provider),
      _pageProfil(auth),
    ];

    // ✅ FIX RETOUR : PopScope intercepte le bouton retour Android
    // Si on est sur un onglet non-zéro → revenir à l'accueil
    // Si on est sur l'accueil → demander confirmation avant de quitter
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_ongletActif != 0) {
          setState(() => _ongletActif = 0);
          return;
        }
        // Sur l'accueil → dialog de confirmation
        final quitter = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Quitter Tchira ?', style: TextStyle(fontWeight: FontWeight.bold)),
            content: const Text("Voulez-vous vraiment quitter l'application ?"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D7377), foregroundColor: Colors.white),
                child: const Text('Quitter'),
              ),
            ],
          ),
        );
        if (quitter == true && context.mounted) {
          // ignore: use_build_context_synchronously
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: pages[_ongletActif],
        bottomNavigationBar: _navbar(),
      ),
    );
  }

  // ─── NAVBAR ────────────────────────────────────────────────────────────────
  Widget _navbar() {
    const items = [
      {'icon': Icons.home_outlined,       'iconSel': Icons.home,         'label': 'Accueil'},
      {'icon': Icons.inventory_2_outlined, 'iconSel': Icons.inventory_2, 'label': 'Livraisons'},
      {'icon': Icons.person_outline,      'iconSel': Icons.person,       'label': 'Profil'},
    ];
    return Container(
      decoration: BoxDecoration(color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, -4))],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: SafeArea(top: false, child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (i) {
            final sel = _ongletActif == i;
            return GestureDetector(
              onTap: () => setState(() => _ongletActif = i),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? const Color(0xFF0D7377).withValues(alpha: 0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(sel ? items[i]['iconSel'] as IconData : items[i]['icon'] as IconData,
                      color: sel ? const Color(0xFF0D7377) : Colors.grey, size: 24),
                  const SizedBox(height: 2),
                  Text(items[i]['label'] as String,
                      style: TextStyle(fontSize: 11, fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                          color: sel ? const Color(0xFF0D7377) : Colors.grey)),
                ]),
              ),
            );
          }),
        ),
      )),
    );
  }

  // ─── PAGE ACCUEIL ──────────────────────────────────────────────────────────
  Widget _pageAccueil(LivraisonProvider provider, user) {
    return Column(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 56, 24, 28),
        decoration: const BoxDecoration(color: Color(0xFF0D7377),
            borderRadius: BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Bonjour, ${user?.nom?.split(' ').first ?? ''} 👋', style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 4),
          const Text('Envoyer un colis', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const Text('Bobo-Dioulasso & environs', style: TextStyle(color: Colors.white60, fontSize: 13)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => setState(() { _formVisible = !_formVisible; _ongletActif = 0; }),
            icon: Icon(_formVisible ? Icons.close : Icons.add, size: 18),
            label: Text(_formVisible ? 'Annuler' : 'Nouvelle livraison'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF97316), foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          ),
        ]),
      ),
      if (_formVisible)
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _carteFormulaire(), const SizedBox(height: 12),
            _carteCategories(), const SizedBox(height: 12),
            _carteZones(),      const SizedBox(height: 12),
            if (_prixTotal != null) _cartePrix(),
            const SizedBox(height: 16),
            _boutonCreer(provider), const SizedBox(height: 80),
          ]),
        ))
      else
        Expanded(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Livraisons récentes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0D7377))),
              GestureDetector(onTap: () => setState(() => _ongletActif = 1),
                  child: const Text('Voir tout', style: TextStyle(color: Color(0xFFF97316), fontSize: 13, fontWeight: FontWeight.w600))),
            ]),
            const SizedBox(height: 12),
            if (provider.mesLivraisons.isEmpty) _etatVide()
            else Expanded(child: ListView.builder(
              itemCount: provider.mesLivraisons.take(3).length,
              itemBuilder: (_, i) => _carteLivraison(provider.mesLivraisons[i]),
            )),
          ]),
        )),
    ]);
  }

  // ─── PAGE LIVRAISONS ───────────────────────────────────────────────────────
  Widget _pageLivraisons(LivraisonProvider provider) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(24, 56, 24, 20),
        decoration: const BoxDecoration(color: Color(0xFF0D7377),
            borderRadius: BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28))),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Mes livraisons', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          Row(children: [
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            const Text('Live', style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.w600)),
          ]),
        ]),
      ),
      Expanded(child: provider.isLoading && provider.mesLivraisons.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : provider.mesLivraisons.isEmpty
              ? _etatVide()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.mesLivraisons.length,
                  itemBuilder: (_, i) => _carteLivraison(provider.mesLivraisons[i]),
                )),
    ]);
  }

  // ─── PAGE PROFIL ───────────────────────────────────────────────────────────
  Widget _pageProfil(AuthProvider auth) {
    final user = auth.user;
    return SingleChildScrollView(child: Column(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(0, 56, 0, 32),
        decoration: const BoxDecoration(color: Color(0xFF0D7377),
            borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32))),
        child: Column(children: [
          Stack(alignment: Alignment.bottomRight, children: [
            Container(width: 90, height: 90,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), color: Colors.white.withValues(alpha: 0.2)),
              child: ClipOval(child: _buildPhoto(user?.photoBase64))),
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilScreen())).then((_) => auth.rafraichirProfil()),
              child: Container(padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(color: Color(0xFFF97316), shape: BoxShape.circle),
                  child: const Icon(Icons.edit, size: 14, color: Colors.white))),
          ]),
          const SizedBox(height: 12),
          Text(user?.nom ?? '', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(color: const Color(0xFFF97316), borderRadius: BorderRadius.circular(20)),
              child: const Text('👤 Client', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
        ]),
      ),
      Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        _ligneInfo(Icons.email_outlined, 'Email', user?.email ?? ''),
        _ligneInfo(Icons.phone_outlined, 'Téléphone', user?.telephone ?? ''),
        const SizedBox(height: 16),
        _boutonProfil('✏️  Modifier mon profil', const Color(0xFF0D7377), () =>
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilScreen())).then((_) => auth.rafraichirProfil())),
        const SizedBox(height: 10),
                      _boutonProfil('📞  Nous contacter', const Color(0xFF0D7377), () {
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const InfoScreen(ongletInitial: 0)));
              }),
              const SizedBox(height: 8),
              _boutonProfil('ℹ️  À propos', const Color(0xFF1B3A6B), () {
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const InfoScreen(ongletInitial: 1)));
              }),
              const SizedBox(height: 8),
              _boutonProfil('🛡️  Politique de confidentialité', Colors.grey, () {
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const InfoScreen(ongletInitial: 2)));
              }),
              const SizedBox(height: 8),
              _boutonProfil('🚪  Déconnexion', Colors.red, () async {
          final navigator = Navigator.of(context);
          _timer?.cancel();
          await auth.deconnecter();
          if (!mounted) return;
          navigator.pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
        }),
      ])),
    ]));
  }

  // ─── FORMULAIRE ADRESSES ────────────────────────────────────────────────────
  Widget _carteFormulaire() {
    return _conteneur(titre: '📍 Adresses', child: Column(children: [
      // ── Départ ──────────────────────────────────────────────────────────────
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _champTexte(ctrl: _departCtrl, label: 'Adresse de départ', icone: Icons.trip_origin, couleurIcone: Colors.green)),
        const SizedBox(width: 8),
        // GPS instantané
        Container(height: 54, width: 54,
          decoration: BoxDecoration(color: const Color(0xFF0D7377), borderRadius: BorderRadius.circular(10)),
          child: _gpsEnCours
              ? const Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : IconButton(icon: const Icon(Icons.my_location, color: Colors.white, size: 22), onPressed: _recupererPositionGPS, tooltip: 'Ma position GPS'),
        ),
        const SizedBox(width: 8),
        // Sélecteur carte
        Container(height: 54, width: 54,
          decoration: BoxDecoration(color: const Color(0xFFF97316), borderRadius: BorderRadius.circular(10)),
          child: IconButton(icon: const Icon(Icons.map_outlined, color: Colors.white, size: 22),
              onPressed: () => _ouvrirCartePicker(estDepart: true), tooltip: 'Choisir sur la carte')),
      ]),
      const SizedBox(height: 6),
      Row(children: [
        const SizedBox(width: 4),
        Icon(Icons.my_location, size: 12, color: Colors.grey.shade400),
        const SizedBox(width: 4),
        Text('GPS', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
        const SizedBox(width: 12),
        Icon(Icons.map_outlined, size: 12, color: Colors.grey.shade400),
        const SizedBox(width: 4),
        Text('Carte', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
      ]),
      const SizedBox(height: 12),

      // ── Arrivée ──────────────────────────────────────────────────────────────
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _champTexte(ctrl: _arriveeCtrl, label: "Adresse d'arrivée", icone: Icons.location_on, couleurIcone: Colors.red)),
        const SizedBox(width: 8),
        // Sélecteur carte arrivée
        Container(height: 54, width: 54,
          decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(10)),
          child: IconButton(icon: const Icon(Icons.map_outlined, color: Colors.white, size: 22),
              onPressed: () => _ouvrirCartePicker(estDepart: false), tooltip: 'Choisir sur la carte')),
      ]),
      const SizedBox(height: 12),
      _champTexte(ctrl: _descCtrl, label: 'Description du colis (optionnel)', icone: Icons.inventory_2_outlined, couleurIcone: Colors.grey),
    ]));
  }

  Widget _carteCategories() {
    if (_chargementTarifs) return const Center(child: CircularProgressIndicator());
    return _conteneur(titre: '📦 Catégorie du colis', child: Column(children: _tarifs.map((tarif) {
      final sel = _categorieSelectionnee == tarif['categorie'];
      return GestureDetector(
        onTap: () { setState(() => _categorieSelectionnee = tarif['categorie']); _calculerPrix(); },
        child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: sel ? const Color(0xFF0D7377) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Icon(Icons.inventory_2, color: sel ? Colors.white : Colors.grey, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(tarif['label'], style: TextStyle(color: sel ? Colors.white : Colors.black87, fontWeight: FontWeight.w600, fontSize: 14))),
            Text(tarif['sur_devis'] == true ? 'Sur devis' : '${_fmt(tarif['prix_base'])} FCFA',
                style: TextStyle(color: sel ? Colors.white70 : const Color(0xFF0D7377), fontWeight: FontWeight.bold, fontSize: 13)),
          ])),
      );
    }).toList()));
  }

  Widget _carteZones() {
    if (_chargementTarifs) return const SizedBox.shrink();
    return _conteneur(titre: '🗺️ Zone de livraison', child: Column(children: _zones.map((zone) {
      final sel   = _zoneSelectionnee == zone['code'];
      final frais = (zone['frais_supplementaires'] as num?)?.toInt() ?? 0;
      return GestureDetector(
        onTap: () { setState(() => _zoneSelectionnee = zone['code']); _calculerPrix(); },
        child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: sel ? const Color(0xFF0D7377) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Icon(Icons.map_outlined, color: sel ? Colors.white : Colors.grey, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(zone['nom'], style: TextStyle(color: sel ? Colors.white : Colors.black87, fontWeight: FontWeight.w600, fontSize: 14)),
              Text(zone['description'], style: TextStyle(color: sel ? Colors.white60 : Colors.grey, fontSize: 12)),
            ])),
            Text(frais == 0 ? 'Inclus' : '+${_fmt(frais)} FCFA',
                style: TextStyle(color: sel ? Colors.white70 : const Color(0xFF0D7377), fontWeight: FontWeight.bold, fontSize: 13)),
          ])),
      );
    }).toList()));
  }

  Widget _cartePrix() {
    if (_calculEnCours) return const Center(child: CircularProgressIndicator());
    if (_surDevis) {
      return Container(padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFFFEF9C3), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF59E0B))),
          child: const Row(children: [Icon(Icons.info_outline, color: Color(0xFFF59E0B)), SizedBox(width: 10), Expanded(child: Text("Ce type de colis nécessite un devis. Contactez l'admin.", style: TextStyle(color: Color(0xFF92400E))))]));
    }
    return Container(padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF0D7377))),
        child: Column(children: [
          _lignePrix('Prix de base', _prixBase ?? 0), _lignePrix('Frais de zone', _fraisZone ?? 0),
          const Divider(color: Color(0xFF0D7377)),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D7377))),
            Text('${_fmt(_prixTotal ?? 0)} FCFA', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0D7377))),
          ]),
        ]));
  }

  Widget _lignePrix(String l, double m) => Padding(padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(l, style: const TextStyle(color: Colors.grey)),
        Text('${_fmt(m)} FCFA', style: const TextStyle(color: Color(0xFF0D7377))),
      ]));

  Widget _boutonCreer(LivraisonProvider p) => SizedBox(width: double.infinity, height: 52,
      child: ElevatedButton.icon(
        onPressed: p.isLoading ? null : _creerLivraison,
        icon: p.isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send),
        label: const Text('Envoyer la demande', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D7377), foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))));

  Widget _carteLivraison(Livraison liv) {
    final c = _couleur(liv.statut); final l = _label(liv.statut);
    return Container(margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
              child: Text(l, style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 12))),
          Text('${_fmt(liv.prix)} FCFA', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D7377))),
        ]),
        const SizedBox(height: 12),
        Row(children: [const Icon(Icons.trip_origin, color: Colors.green, size: 16), const SizedBox(width: 8), Expanded(child: Text(liv.adresseDepart, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))]),
        Row(children: [const Icon(Icons.location_on, color: Colors.red, size: 16), const SizedBox(width: 8), Expanded(child: Text(liv.adresseArrivee, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))]),
        if (liv.statut == 'en_cours' || liv.statut == 'en_livraison') ...[
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: () { context.read<LivraisonProvider>().suivreLivraison(liv); Navigator.push(context, MaterialPageRoute(builder: (_) => const TrackingScreen())); },
            icon: const Icon(Icons.map_outlined, size: 16),
            label: const Text('Suivre le livreur'),
            style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF0D7377), side: const BorderSide(color: Color(0xFF0D7377)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          )),
        ],
      ])),
    );
  }

  // ─── Helpers UI ────────────────────────────────────────────────────────────
  Widget _ligneInfo(IconData ic, String label, String val) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))]),
    child: Row(children: [Icon(ic, size: 18, color: const Color(0xFF0D7377)), const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(val, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      ])]));

  Widget _boutonProfil(String label, Color couleur, VoidCallback onTap) => SizedBox(width: double.infinity, height: 50,
    child: ElevatedButton(onPressed: onTap,
      style: ElevatedButton.styleFrom(backgroundColor: couleur, foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))));

  Widget _buildPhoto(String? b64) {
    if (b64 != null && b64.isNotEmpty) {
      try {
        final data = b64.replaceFirst(RegExp(r'data:image/[^;]+;base64,'), '');
        return Image.memory(base64Decode(data), fit: BoxFit.cover, width: 90, height: 90);
      } catch (_) {}
    }
    return const Icon(Icons.person, size: 48, color: Colors.white70);
  }

  Widget _conteneur({required String titre, required Widget child}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(titre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0D7377))),
      const SizedBox(height: 14), child,
    ]));

  Widget _champTexte({required TextEditingController ctrl, required String label, required IconData icone, required Color couleurIcone}) =>
    TextField(controller: ctrl,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icone, color: couleurIcone, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF0D7377), width: 2)),
        filled: true, fillColor: const Color(0xFFF8FAFC), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)));

  Widget _etatVide() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const SizedBox(height: 40), Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300),
    const SizedBox(height: 12), Text('Aucune livraison pour l\'instant', style: TextStyle(color: Colors.grey.shade400)),
  ]));

  String _fmt(dynamic m)   { final v = (m as num).toInt(); return v.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (x) => '${x[1]} '); }
  Color  _couleur(String s){ switch (s) { case 'en_attente': return Colors.orange; case 'en_cours': return const Color(0xFF0D7377); case 'en_livraison': return Colors.purple; case 'livre': return Colors.green; case 'annule': return Colors.red; default: return Colors.grey; } }
  String _label(String s)  { switch (s) { case 'en_attente': return '⏳ En attente'; case 'en_cours': return '🔄 En cours'; case 'en_livraison': return '🚚 En livraison'; case 'livre': return '✅ Livré'; case 'annule': return '❌ Annulé'; default: return s; } }
}