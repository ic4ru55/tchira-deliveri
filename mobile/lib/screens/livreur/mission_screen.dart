import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/livraison_provider.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import 'home_livreur.dart';

// ─── GpsService singleton ─────────────────────────────────────────────────────
class GpsService {
  static GpsService? _instance;
  static GpsService get instance => _instance ??= GpsService._();
  GpsService._();

  StreamSubscription<Position>? _stream;
  Timer?   _timerWeb;
  String?  _livraisonIdActif;
  bool get actif => _livraisonIdActif != null;

  Future<bool> demarrer(String livraisonId) async {
    if (_livraisonIdActif == livraisonId && actif) return true;
    final ok = await Geolocator.isLocationServiceEnabled();
    if (!ok) { await Geolocator.openLocationSettings(); return false; }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return false;
    _livraisonIdActif = livraisonId;
    if (kIsWeb) { _demarrerWeb(livraisonId); return true; }
    await _stream?.cancel();
    _stream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen(
      (p) => SocketService.envoyerPosition(livraisonId: livraisonId, lat: p.latitude, lng: p.longitude),
      onError: (_) => _livraisonIdActif = null,
    );
    return true;
  }

  void _demarrerWeb(String id) {
    _timerWeb?.cancel();
    _timerWeb = Timer.periodic(const Duration(seconds: 10), (_) async {
      try {
        final p = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
        SocketService.envoyerPosition(livraisonId: id, lat: p.latitude, lng: p.longitude);
      } catch (_) {}
    });
  }

  void arreter() { _stream?.cancel(); _timerWeb?.cancel(); _stream = null; _timerWeb = null; _livraisonIdActif = null; }
}

// ─── MissionScreen ─────────────────────────────────────────────────────────────
class MissionScreen extends StatefulWidget {
  const MissionScreen({super.key});
  @override State<MissionScreen> createState() => _MissionScreenState();
}

class _MissionScreenState extends State<MissionScreen> with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  bool    _uploading = false;
  bool    _saving    = false;
  String? _photoB64;

  static const _teal   = Color(0xFF0D7377);
  static const _navy   = Color(0xFF1B3A6B);
  static const _green  = Color(0xFF16A34A);

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 450))..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final liv = context.read<LivraisonProvider>().livraisonActive;
      if (liv != null) _startGps(liv.id);
    });
  }
  @override void dispose() { _anim.dispose(); super.dispose(); }

  // ── GPS ────────────────────────────────────────────────────────────────────
  Future<void> _startGps(String id) async {
    final ok = await GpsService.instance.demarrer(id);
    if (mounted) setState(() {});
    if (!ok && mounted) _snack('GPS indisponible', Colors.orange);
  }

  // ── Navigation ─────────────────────────────────────────────────────────────
  void _openNav(String adresse) {
    final enc = Uri.encodeComponent(adresse);
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (_) => _NavSheet(adresse: adresse, enc: enc),
    );
  }

  // ── Appel ──────────────────────────────────────────────────────────────────
  Future<void> _call(String? tel) async {
    if (tel == null || tel.isEmpty) return;
    final uri = Uri.parse('tel:$tel');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  // ── Photo preuve ───────────────────────────────────────────────────────────
  Future<void> _pickPhoto() async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context, backgroundColor: Colors.transparent,
      builder: (_) => _PhotoSheet(),
    );
    if (src == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final img = await ImagePicker().pickImage(source: src, imageQuality: 60, maxWidth: 1100);
      if (img != null) {
        final bytes = await img.readAsBytes();
        if (mounted) setState(() => _photoB64 = base64Encode(bytes));
      }
    } finally { if (mounted) setState(() => _uploading = false); }
  }

  // ── Dialog confirmation sans photo (méthode sync-safe) ──────────────────────
  Future<bool> _confirmerSansPhoto() {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmer sans photo ?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Aucune photo prise. Vous êtes sûr de vouloir confirmer la livraison ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Confirmer quand même', style: TextStyle(color: Colors.white))),
        ],
      ),
    ).then((v) => v ?? false);
  }

  // ── Changer statut ─────────────────────────────────────────────────────────
  Future<void> _changeStatus(String statut) async {
    if (statut == 'livre' && _photoB64 == null) {
      // Dialog appelé en premier — context encore synchrone ici
      final go = await _confirmerSansPhoto();
      if (!go) return;
    }
    if (!mounted) return;
    // Capturer les refs context après le guard mounted
    final provider  = context.read<LivraisonProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    final liv = provider.livraisonActive;
    if (liv == null) return;
    try {
      if (statut == 'livre' && _photoB64 != null) {
        await ApiService.soumettrePreuveLivraison(livraisonId: liv.id, photoBase64: _photoB64!);
      }
      final ok = await provider.mettreAJourStatut(liv.id, statut);
      if (!mounted) return;
      if (ok) {
        messenger.showSnackBar(SnackBar(content: Text(statut == 'en_livraison' ? '🚚 C\'est parti !' : '✅ Livraison confirmée !'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
        if (statut == 'livre') {
          GpsService.instance.arreter();
          provider.reinitialiserLivraisonActive();
          navigator.pushReplacement(MaterialPageRoute(builder: (_) => const HomeLibreur()));
        } else setState(() {});
      } else messenger.showSnackBar(const SnackBar(content: Text('❌ Erreur, réessaie'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
    } finally { if (mounted) setState(() => _saving = false); }
  }

  void _snack(String m, Color c) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(m), backgroundColor: c, behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LivraisonProvider>();
    final liv      = provider.livraisonActive;
    final gpsOn    = GpsService.instance.actif;

    if (liv == null) {
      return Scaffold(backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(backgroundColor: _navy, foregroundColor: Colors.white, title: const Text('Mission')),
        body: const Center(child: Text('Aucune mission active')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _anim, curve: Curves.easeOut),
        child: CustomScrollView(slivers: [
          // ── AppBar gradient ────────────────────────────────────────────────
          SliverAppBar(
            pinned: true, expandedHeight: 96,
            backgroundColor: _navy,
            leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
            actions: [
              GestureDetector(
                onTap: () => _startGps(liv.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: gpsOn ? Colors.greenAccent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: gpsOn ? Colors.greenAccent : Colors.white30)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(gpsOn ? Icons.gps_fixed : Icons.gps_not_fixed,
                        color: gpsOn ? Colors.greenAccent : Colors.white54, size: 14),
                    const SizedBox(width: 4),
                    Text(gpsOn ? 'GPS ON' : 'OFF',
                        style: TextStyle(color: gpsOn ? Colors.greenAccent : Colors.white54,
                            fontSize: 11, fontWeight: FontWeight.bold)),
                  ]),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [_navy, Color(0xFF0D4A6B)])),
                child: SafeArea(child: Padding(
                  padding: const EdgeInsets.fromLTRB(64, 8, 80, 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text('Mission en cours', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 3),
                    Row(children: [
                      Container(width: 7, height: 7, decoration: BoxDecoration(
                          color: gpsOn ? Colors.greenAccent : Colors.white30, shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      Text(gpsOn ? 'Position partagée en temps réel' : 'GPS inactif — appuie pour activer',
                          style: TextStyle(color: gpsOn ? Colors.greenAccent : Colors.white38, fontSize: 11)),
                    ]),
                  ]),
                )),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            sliver: SliverList(delegate: SliverChildListDelegate([

              // ── Badge statut ───────────────────────────────────────────────
              _StatusBadge(statut: liv.statut),
              const SizedBox(height: 14),

              // ── Client ─────────────────────────────────────────────────────
              _Card(
                label: 'Client', icon: Icons.person_outline, iconColor: _navy,
                child: Row(children: [
                  Container(width: 48, height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF2563EB), _teal]),
                      borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.person, color: Colors.white, size: 26)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(liv.client?['nom'] ?? 'Client',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(liv.client?['telephone'] ?? '',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                  ])),
                  if ((liv.client?['telephone'] ?? '').isNotEmpty)
                    _ActionChip(icon: Icons.phone, label: 'Appeler', color: _green,
                        onTap: () => _call(liv.client?['telephone'])),
                ]),
              ),
              const SizedBox(height: 12),

              // ── Itinéraire ─────────────────────────────────────────────────
              _Card(
                label: 'Itinéraire', icon: Icons.alt_route, iconColor: _navy,
                child: Column(children: [
                  _StepRow(
                    num: '1', color: Colors.green,
                    label: (liv.statut == 'en_livraison' || liv.statut == 'livre')
                        ? '✅ Colis récupéré' : 'Récupérer le colis',
                    address: liv.adresseDepart,
                    done: liv.statut == 'en_livraison' || liv.statut == 'livre',
                    active: liv.statut == 'en_cours',
                    onNav: liv.statut == 'en_cours' ? () => _openNav(liv.adresseDepart) : null,
                  ),
                  Padding(padding: const EdgeInsets.only(left: 14),
                    child: Column(children: List.generate(3, (_) =>
                        Container(width: 2, height: 7, margin: const EdgeInsets.symmetric(vertical: 2),
                            color: Colors.grey.shade200)))),
                  _StepRow(
                    num: '2', color: Colors.red,
                    label: liv.statut == 'livre' ? '✅ Livré !' : 'Livrer le colis',
                    address: liv.adresseArrivee,
                    done: liv.statut == 'livre',
                    active: liv.statut == 'en_livraison',
                    onNav: liv.statut == 'en_livraison' ? () => _openNav(liv.adresseArrivee) : null,
                  ),
                ]),
              ),
              const SizedBox(height: 12),

              // ── Détails ────────────────────────────────────────────────────
              _Card(
                label: 'Colis & Paiement', icon: Icons.inventory_2_outlined, iconColor: _navy,
                child: Column(children: [
                  if (liv.descriptionColis.isNotEmpty) ...[
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(Icons.inventory_2_outlined, size: 15, color: Colors.grey.shade400),
                      const SizedBox(width: 8),
                      Expanded(child: Text(liv.descriptionColis,
                          style: const TextStyle(fontSize: 13, color: Colors.black87))),
                    ]),
                    Divider(height: 18, color: Colors.grey.shade100),
                  ],
                  Row(children: [
                    Expanded(child: _InfoPill(label: 'Rémunération',
                        value: '${_fmt(liv.prix)} FCFA',
                        bg: const Color(0xFFDCFCE7), fg: _green)),
                  ]),
                ]),
              ),
              const SizedBox(height: 12),

              // ── Photo preuve (seulement si en_livraison) ───────────────────
              if (liv.statut == 'en_livraison') ...[
                _Card(
                  label: 'Photo de livraison', icon: Icons.camera_alt_outlined, iconColor: _navy,
                  child: Column(children: [
                    if (_photoB64 != null) ...[
                      ClipRRect(borderRadius: BorderRadius.circular(10),
                          child: Image.memory(base64Decode(_photoB64!),
                              height: 170, width: double.infinity, fit: BoxFit.cover)),
                      const SizedBox(height: 8),
                      TextButton.icon(onPressed: _pickPhoto,
                        icon: const Icon(Icons.refresh, size: 14),
                        label: const Text('Reprendre'),
                        style: TextButton.styleFrom(foregroundColor: _teal)),
                    ] else
                      InkWell(
                        onTap: _uploading ? null : _pickPhoto,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          height: 96,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade200, width: 1.5)),
                          child: _uploading
                              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                              : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  Icon(Icons.add_a_photo_outlined, size: 28, color: Colors.grey.shade400),
                                  const SizedBox(height: 6),
                                  Text('Ajouter une photo preuve (recommandé)',
                                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                                ]),
                        ),
                      ),
                  ]),
                ),
                const SizedBox(height: 12),
              ],

              // ── Bouton principal ───────────────────────────────────────────
              if (_saving)
                const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
              else if (liv.statut == 'en_cours')
                _BigButton(label: 'Colis récupéré — Démarrer', icon: Icons.local_shipping,
                    color: Colors.purple, onTap: () => _changeStatus('en_livraison'))
              else if (liv.statut == 'en_livraison')
                Column(children: [
                  _BigButton(label: '✅ Confirmer la livraison', icon: Icons.check_circle,
                      color: _green, onTap: () => _changeStatus('livre')),
                  if (_photoB64 == null) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(onPressed: _pickPhoto,
                      icon: const Icon(Icons.camera_alt, size: 15),
                      label: const Text('Prendre la photo avant de confirmer'),
                      style: TextButton.styleFrom(foregroundColor: _teal)),
                  ],
                ]),
            ])),
          ),
        ]),
      ),
    );
  }

  static String _fmt(dynamic m) => (m as num).toInt().toString()
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (x) => '${x[1]} ');
}

// ─── Widgets réutilisables ────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String statut;
  const _StatusBadge({required this.statut});

  Color    get _color => switch (statut) { 'en_cours' => const Color(0xFF2563EB), 'en_livraison' => Colors.purple, 'livre' => const Color(0xFF16A34A), _ => Colors.grey };
  IconData get _icon  => switch (statut) { 'en_cours' => Icons.hourglass_top, 'en_livraison' => Icons.local_shipping, 'livre' => Icons.check_circle, _ => Icons.info };
  String   get _label => switch (statut) { 'en_cours' => 'Récupération en cours', 'en_livraison' => 'Livraison en cours', 'livre' => 'Livré ✅', _ => statut };

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [_color, _color.withValues(alpha: 0.78)]),
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: _color.withValues(alpha: 0.28), blurRadius: 10, offset: const Offset(0, 4))]),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
          child: Icon(_icon, color: Colors.white, size: 22)),
      const SizedBox(width: 14),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Statut actuel', style: TextStyle(color: Colors.white60, fontSize: 11)),
        Text(_label, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ]),
    ]));
}

class _Card extends StatelessWidget {
  final String label; final IconData icon; final Color iconColor; final Widget child;
  const _Card({required this.label, required this.icon, required this.iconColor, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, size: 15, color: iconColor), const SizedBox(width: 6),
        Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: iconColor))]),
      const SizedBox(height: 12), child,
    ]));
}

class _StepRow extends StatelessWidget {
  final String num, label, address;
  final Color color;
  final bool done, active;
  final VoidCallback? onNav;
  const _StepRow({required this.num, required this.label, required this.address,
    required this.color, required this.done, required this.active, this.onNav});
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    AnimatedContainer(
      duration: const Duration(milliseconds: 300), width: 28, height: 28, alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle,
          color: done ? Colors.grey.shade200 : (active ? color : color.withValues(alpha: 0.25)),
          boxShadow: active ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 8, spreadRadius: 1)] : []),
      child: done ? const Icon(Icons.check, size: 15, color: Colors.white)
          : Text(num, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
    const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14,
          color: done ? Colors.grey.shade400 : Colors.black87)),
      const SizedBox(height: 1),
      Text(address, style: TextStyle(fontSize: 12, color: done ? Colors.grey.shade300 : Colors.black54),
          maxLines: 2, overflow: TextOverflow.ellipsis),
      if (onNav != null) ...[
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: onNav,
          icon: const Icon(Icons.navigation, size: 15, color: Colors.white),
          label: const Text('Ouvrir la navigation', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10), elevation: 2,
              shadowColor: color.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),
      ],
    ])),
  ]);
}

class _ActionChip extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  const _ActionChip({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 20), const SizedBox(height: 2),
        Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
      ])));
}

class _InfoPill extends StatelessWidget {
  final String label, value; final Color bg, fg;
  const _InfoPill({required this.label, required this.value, required this.bg, required this.fg});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: fg.withValues(alpha: 0.65), fontSize: 10)),
      const SizedBox(height: 1),
      Text(value, style: TextStyle(color: fg, fontSize: 14, fontWeight: FontWeight.bold)),
    ]));
}

class _BigButton extends StatelessWidget {
  final String label; final IconData icon; final Color color; final VoidCallback onTap;
  const _BigButton({required this.label, required this.icon, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => SizedBox(width: double.infinity, height: 54,
    child: ElevatedButton.icon(onPressed: onTap, icon: Icon(icon, size: 21),
      label: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white,
          elevation: 3, shadowColor: color.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))));
}

// ── Sheet navigation ──────────────────────────────────────────────────────────
class _NavSheet extends StatelessWidget {
  final String adresse, enc;
  const _NavSheet({required this.adresse, required this.enc});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 36, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
      Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(children: [
            const Icon(Icons.navigation, color: Color(0xFF0D7377)),
            const SizedBox(width: 10),
            const Expanded(child: Text('Ouvrir avec…', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          ])),
      const Divider(height: 1),
      _item(context, emoji: '🗺️', title: 'Google Maps', subtitle: 'Navigation guidée', onTap: () async {
        Navigator.pop(context);
        await launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$enc&travelmode=driving'),
            mode: LaunchMode.externalApplication);
      }),
      _item(context, emoji: '🔵', title: 'Waze', subtitle: 'Trafic temps réel', onTap: () async {
        Navigator.pop(context);
        final u = Uri.parse('waze://?q=$enc&navigate=yes');
        if (await canLaunchUrl(u)) await launchUrl(u, mode: LaunchMode.externalApplication);
        else if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Waze non installé')));
      }),
      _item(context, emoji: '📋', title: 'Copier l\'adresse', subtitle: adresse, onTap: () {
        Navigator.pop(context);
        Clipboard.setData(ClipboardData(text: adresse));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Adresse copiée !'), backgroundColor: Color(0xFF0D7377)));
      }),
      const SizedBox(height: 16),
    ]),
  );

  Widget _item(BuildContext ctx, {required String emoji, required String title, required String subtitle, required VoidCallback onTap}) =>
    ListTile(
      leading: Container(width: 40, height: 40,
          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22)))),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 13, color: Colors.grey),
      onTap: onTap);
}

// ── Sheet photo ────────────────────────────────────────────────────────────────
class _PhotoSheet extends StatelessWidget {
  const _PhotoSheet();
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 36, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
      const Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text('Photo de livraison', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
      const Divider(height: 1),
      ListTile(leading: const Icon(Icons.camera_alt, color: Color(0xFF0D7377)),
          title: const Text('Appareil photo'), onTap: () => Navigator.pop(context, ImageSource.camera)),
      ListTile(leading: const Icon(Icons.photo_library, color: Color(0xFF0D7377)),
          title: const Text('Galerie'), onTap: () => Navigator.pop(context, ImageSource.gallery)),
      const SizedBox(height: 16),
    ]),
  );
}