import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/livraison_provider.dart';
import '../../models/livraison.dart';
import '../../screens/auth/login_screen.dart';
import '../../services/api_service.dart';
import 'mission_screen.dart';
import '../profil_page.dart';

class HomeLibreur extends StatefulWidget {
  const HomeLibreur({super.key});
  @override State<HomeLibreur> createState() => _HomeLibreurState();
}

class _HomeLibreurState extends State<HomeLibreur> with TickerProviderStateMixin {
  int           _onglet            = 0;
  Timer?        _timer;
  List<dynamic> _historique        = [];
  bool          _loadingHistorique = false;
  String        _filtre            = 'tous'; // tous | cash | om | top
  late AnimationController _pulseCtrl;

  static const _teal  = Color(0xFF0D7377);
  static const _navy  = Color(0xFF1B3A6B);
  static const _green = Color(0xFF16A34A);

  // ── Filtres disponibles ──────────────────────────────────────────────────
  static const _filtres = [
    ('tous',  'Toutes',     Icons.apps_outlined),
    ('top',   '> 2 000 F',  Icons.trending_up_outlined),
    ('cash',  'Cash',       Icons.payments_outlined),
    ('om',    'Orange Money', Icons.phone_android_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final prov = context.read<LivraisonProvider>();
      await Future.wait([
        prov.chargerLivraisonsDisponibles(),
        prov.chargerMissionActive(),
      ]);
      _reprendreGps();
      _timer = Timer.periodic(const Duration(seconds: 6), (_) {
        if (!mounted) return;
        final p = context.read<LivraisonProvider>();
        p.chargerLivraisonsDisponibles(silencieux: true);
        p.chargerMissionActive();
        if (_onglet == 1 && !_loadingHistorique) _chargerHistorique();
      });
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // ── Filtrage des missions ─────────────────────────────────────────────────
  List<Livraison> _filtrer(List<Livraison> all) {
    switch (_filtre) {
      case 'cash': return all.where((l) {
        final mode = (l as dynamic).modePaiement as String? ?? 'cash';
        return mode == 'cash';
      }).toList();
      case 'om': return all.where((l) {
        final mode = (l as dynamic).modePaiement as String? ?? 'cash';
        return mode == 'om' || mode == 'orange_money';
      }).toList();
      case 'top': return all.where((l) => l.prix > 2000).toList()
        ..sort((a, b) => b.prix.compareTo(a.prix));
      default: return all;
    }
  }

  Future<void> _reprendreGps() async {
    final liv = context.read<LivraisonProvider>().livraisonActive;
    if (liv == null) return;
    if (liv.statut == 'en_cours' || liv.statut == 'en_livraison') {
      await GpsService.instance.demarrer(liv.id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _chargerHistorique() async {
    setState(() => _loadingHistorique = true);
    try {
      final r = await ApiService.mesLivraisonsLivreur();
      if (!mounted) return;
      setState(() {
        if (r['success'] == true) _historique = r['livraisons'] ?? [];
        _loadingHistorique = false;
      });
    } catch (_) { if (mounted) setState(() => _loadingHistorique = false); }
  }

  Future<void> _accepter(String id) async {
    final prov      = context.read<LivraisonProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final dynamic ret = await prov.accepterLivraison(id);
    if (!mounted) return;
    bool ok; String msg = '❌ Mission non disponible';
    if (ret is bool)     { ok = ret; }
    else if (ret is Map) { ok = ret['succes'] == true; msg = ret['message'] as String? ?? msg; }
    else                 { ok = false; }
    if (ok) {
      messenger.showSnackBar(const SnackBar(
          content: Text('✅ Mission acceptée !'), backgroundColor: _green,
          behavior: SnackBarBehavior.floating));
      await GpsService.instance.demarrer(id);
      navigator.push(MaterialPageRoute(builder: (_) => const MissionScreen()));
    } else {
      messenger.showSnackBar(SnackBar(
          content: Text(msg), backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth  = context.watch<AuthProvider>();
    final prov  = context.watch<LivraisonProvider>();
    final actif = prov.livraisonActive;
    final missionOk = actif != null &&
        (actif.statut == 'en_cours' || actif.statut == 'en_livraison');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_onglet != 0) { setState(() => _onglet = 0); return; }
        final quit = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Quitter ?', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Voulez-vous vraiment quitter Tchira Express ?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white),
              child: const Text('Quitter')),
          ],
        ));
        if (quit == true) SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F6F8),
        body: IndexedStack(
          index: _onglet,
          children: [
            _pageMissions(prov, missionOk),
            _pageHistorique(),
            ProfilPage(
              role: 'livreur', couleurRole: _navy,
              onDeconnexion: () async {
                _timer?.cancel();
                final nav = Navigator.of(context);
                await auth.deconnecter();
                if (!mounted) return;
                nav.pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
              },
            ),
          ],
        ),
        bottomNavigationBar: _navbar(missionOk),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // NAVBAR
  // ══════════════════════════════════════════════════════════════════════════
  Widget _navbar(bool missionOk) {
    final items = [
      (Icons.delivery_dining_outlined, Icons.delivery_dining, 'Missions'),
      (Icons.history_outlined, Icons.history, 'Historique'),
      (Icons.person_outline, Icons.person, 'Profil'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 20, offset: const Offset(0, -5))]),
      child: SafeArea(top: false, child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (i) {
            final sel = _onglet == i;
            final (iconOff, iconOn, label) = items[i];
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() => _onglet = i);
                if (i == 1) _chargerHistorique();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? _teal.withValues(alpha: 0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Stack(children: [
                    Icon(sel ? iconOn : iconOff,
                        color: sel ? _teal : Colors.grey.shade400, size: 24),
                    if (i == 0 && missionOk)
                      Positioned(right: 0, top: 0,
                        child: AnimatedBuilder(
                          animation: _pulseCtrl,
                          builder: (_, _) => Container(
                            width: 9, height: 9,
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(
                                  alpha: 0.6 + 0.4 * _pulseCtrl.value),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5))))),
                  ]),
                  const SizedBox(height: 3),
                  Text(label, style: TextStyle(
                      fontSize: 11,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
                      color: sel ? _teal : Colors.grey.shade400)),
                ]),
              ),
            );
          }),
        ),
      )),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PAGE MISSIONS — Column + Expanded = pas de bug d'affichage
  // ══════════════════════════════════════════════════════════════════════════
  Widget _pageMissions(LivraisonProvider prov, bool missionOk) {
    final safeTop = MediaQuery.of(context).padding.top;
    final toutesDispos = prov.livraisonsDisponibles;
    final dispo = _filtrer(toutesDispos);

    return Column(children: [
      // ── Header ─────────────────────────────────────────────────────────────
      if (missionOk)
        _headerMissionEnCours(prov, safeTop)
      else
        _headerNormal(prov, safeTop, toutesDispos.length),

      // ── Filtres ─────────────────────────────────────────────────────────────
      if (!missionOk) _barresFiltres(),

      // ── Titre section ────────────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        child: Row(children: [
          const Icon(Icons.delivery_dining, color: _teal, size: 17),
          const SizedBox(width: 6),
          Text('${dispo.length} mission${dispo.length != 1 ? "s" : ""}'
              '${_filtre != "tous" ? " filtrées" : " disponibles"}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _navy)),
          const Spacer(),
          if (prov.isLoading && dispo.isNotEmpty)
            const SizedBox(width: 13, height: 13,
                child: CircularProgressIndicator(strokeWidth: 2, color: _teal)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => prov.chargerLivraisonsDisponibles(),
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: _teal.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(9)),
              child: const Icon(Icons.refresh, color: _teal, size: 16))),
        ]),
      ),

      // ── Liste missions ────────────────────────────────────────────────────────
      Expanded(
        child: prov.isLoading && toutesDispos.isEmpty
          // Loading: skeleton shimmer
          ? _skeletonListe()
          : dispo.isEmpty
            ? _etatVide(filtre: _filtre != 'tous')
            : RefreshIndicator(
                color: _teal,
                onRefresh: () async {
                  await prov.chargerLivraisonsDisponibles();
                },
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: dispo.length,
                  itemBuilder: (_, i) => _carteMission(dispo[i], prov, i),
                ),
              ),
      ),
    ]);
  }

  // ── Header mission en cours (orange) ────────────────────────────────────────
  Widget _headerMissionEnCours(LivraisonProvider prov, double top) =>
    GestureDetector(
      onTap: () async {
        final liv = context.read<LivraisonProvider>().livraisonActive;
        if (liv != null) await GpsService.instance.demarrer(liv.id);
        if (!mounted) return;
        Navigator.push(context, MaterialPageRoute(builder: (_) => const MissionScreen()));
      },
      child: Container(
        padding: EdgeInsets.fromLTRB(18, top + 14, 18, 16),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              colors: [Color(0xFFEA580C), Color(0xFFF97316)],
              begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: Row(children: [
          AnimatedBuilder(animation: _pulseCtrl, builder: (_, _) => Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15 + 0.1 * _pulseCtrl.value),
              borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.local_shipping, color: Colors.white, size: 22))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('🚚 Mission en cours',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
            Text(prov.livraisonActive!.adresseArrivee,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                overflow: TextOverflow.ellipsis),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Text('Continuer',
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
              SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios, color: Colors.white, size: 11),
            ])),
        ]),
      ),
    );

  // ── Header normal (teal) ─────────────────────────────────────────────────────
  Widget _headerNormal(LivraisonProvider prov, double top, int total) => Container(
    padding: EdgeInsets.fromLTRB(18, top + 14, 18, 18),
    decoration: const BoxDecoration(
      color: _teal,
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(24))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Bonjour 👋',
              style: TextStyle(color: Colors.white60, fontSize: 12)),
          const Text('Missions disponibles',
              style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
        ])),
        // Chip GPS pulsant
        AnimatedBuilder(animation: _pulseCtrl, builder: (_, _) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 7, height: 7,
              decoration: BoxDecoration(
                color: GpsService.instance.actif
                    ? Color.lerp(Colors.greenAccent, Colors.white, _pulseCtrl.value * 0.3)
                    : Colors.white38,
                shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text(GpsService.instance.actif ? 'GPS ON' : 'GPS OFF',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
        )),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        _statPill(icon: Icons.inbox_outlined, value: '$total', label: 'En attente'),
        const SizedBox(width: 10),
        _statPill(
          icon: Icons.trending_up_outlined,
          value: '${prov.livraisonsDisponibles.where((l) => l.prix > 2000).length}',
          label: '> 2 000 F'),
      ]),
    ]),
  );

  // ── Barre de filtres ──────────────────────────────────────────────────────────
  Widget _barresFiltres() => SizedBox(
    height: 40,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filtres.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final (code, label, icon) = _filtres[i];
        final sel = _filtre == code;
        return GestureDetector(
          onTap: () => setState(() => _filtre = code),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
            decoration: BoxDecoration(
              color: sel ? _teal : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: sel ? _teal : Colors.grey.shade200, width: 1.5),
              boxShadow: sel ? [BoxShadow(
                  color: _teal.withValues(alpha: 0.25),
                  blurRadius: 8, offset: const Offset(0, 2))] : []),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 13,
                  color: sel ? Colors.white : Colors.grey.shade500),
              const SizedBox(width: 5),
              Text(label, style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: sel ? Colors.white : Colors.grey.shade600)),
            ]),
          ),
        );
      },
    ),
  );

  // ── Skeleton shimmer ──────────────────────────────────────────────────────────
  Widget _skeletonListe() => ListView.builder(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
    itemCount: 3,
    itemBuilder: (_, i) => _skeletonCarte(i),
  );

  Widget _skeletonCarte(int i) => AnimatedBuilder(
    animation: _pulseCtrl,
    builder: (_, _) {
      final alpha = 0.05 + 0.04 * _pulseCtrl.value;
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8, offset: const Offset(0, 2))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: alpha * 2),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)))),
          Padding(padding: const EdgeInsets.all(14), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _skel(width: 90, height: 28, radius: 20, alpha: alpha),
              const SizedBox(width: 8),
              _skel(width: 50, height: 22, radius: 10, alpha: alpha),
              const Spacer(),
              _skel(width: 40, height: 16, radius: 4, alpha: alpha),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _skel(width: 36, height: 36, radius: 10, alpha: alpha),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _skel(width: 120, height: 14, radius: 4, alpha: alpha),
                const SizedBox(height: 4),
                _skel(width: 80, height: 11, radius: 4, alpha: alpha),
              ]),
            ]),
            const SizedBox(height: 12),
            _skel(width: double.infinity, height: 52, radius: 10, alpha: alpha),
            const SizedBox(height: 10),
            _skel(width: double.infinity, height: 44, radius: 12, alpha: alpha),
          ])),
        ]),
      );
    },
  );

  Widget _skel({required double width, required double height,
    required double radius, required double alpha}) =>
    Container(
      width: width, height: height,
      decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: alpha),
          borderRadius: BorderRadius.circular(radius)));

  // ══════════════════════════════════════════════════════════════════════════
  // CARTE MISSION
  // ══════════════════════════════════════════════════════════════════════════
  Widget _carteMission(Livraison liv, LivraisonProvider prov, int index) =>
    TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + index * 55),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.translate(
              offset: Offset(0, 18 * (1 - v)), child: child)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: _teal.withValues(alpha: 0.07),
                blurRadius: 16, offset: const Offset(0, 4)),
            BoxShadow(color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 5, offset: const Offset(0, 2)),
          ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Barre colorée en haut
          Container(height: 4,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [_teal, Color(0xFF0A8A90)]),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18)))),
          Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Ligne 1 — prix, badge paiement, ETA, date
            Row(children: [
              _prixBadge(liv.prix),
              const SizedBox(width: 7),
              _badgePaiement(liv),
              const Spacer(),
              _etaBadge(),
              const SizedBox(width: 7),
              Text(_dateRel(liv.createdAt),
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
            ]),
            const SizedBox(height: 12),

            // Ligne 2 — client
            Row(children: [
              Container(width: 36, height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [_teal, _navy],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.person, color: Colors.white, size: 18)),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(liv.client?['nom'] ?? 'Client',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                if ((liv.client?['telephone'] ?? '').isNotEmpty)
                  Text(liv.client!['telephone'],
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 12)),
              ])),
            ]),
            const SizedBox(height: 12),

            // Ligne 3 — itinéraire
            _itineraireCard(liv.adresseDepart, liv.adresseArrivee),

            // Ligne 4 — description colis (si présente)
            if (liv.descriptionColis.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 13, color: Colors.grey.shade400),
                  const SizedBox(width: 7),
                  Expanded(child: Text(liv.descriptionColis,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                ])),
            ],
            const SizedBox(height: 12),

            // Bouton accepter
            SizedBox(
              width: double.infinity, height: 48,
              child: ElevatedButton.icon(
                onPressed: prov.isLoading ? null : () {
                  HapticFeedback.mediumImpact();
                  _accepter(liv.id);
                },
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Accepter cette mission',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green, foregroundColor: Colors.white,
                  elevation: 2,
                  shadowColor: _green.withValues(alpha: 0.35),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))))),
          ])),
        ]),
      ),
    );

  // ── Itinéraire compact ────────────────────────────────────────────────────────
  Widget _itineraireCard(String dep, String arr) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFF5F9F9),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _teal.withValues(alpha: 0.08))),
    child: Column(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(width: 10, height: 10,
            decoration: const BoxDecoration(color: _green, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(child: Text(dep,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
      Row(children: [
        Padding(padding: const EdgeInsets.only(left: 4, top: 2, bottom: 2),
          child: Container(width: 2, height: 14,
              color: Colors.grey.shade300)),
      ]),
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(width: 10, height: 10,
            decoration: BoxDecoration(
                color: Colors.red.shade400,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Expanded(child: Text(arr,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
    ]),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // PAGE HISTORIQUE
  // ══════════════════════════════════════════════════════════════════════════
  Widget _pageHistorique() {
    final top = MediaQuery.of(context).padding.top;
    return Column(children: [
      Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(18, top + 14, 18, 20),
        decoration: const BoxDecoration(
            color: _navy,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24))),
        child: Row(children: [
          const Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Mon historique',
                style: TextStyle(color: Colors.white, fontSize: 18,
                    fontWeight: FontWeight.w800)),
            Text('Toutes vos livraisons',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
          ])),
          GestureDetector(onTap: _chargerHistorique,
            child: Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.refresh, color: Colors.white, size: 18))),
        ]),
      ),
      Expanded(child: _loadingHistorique
        ? const Center(child: CircularProgressIndicator(color: _teal))
        : _historique.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center,
              children: [
              Icon(Icons.history, size: 64, color: Colors.grey.shade200),
              const SizedBox(height: 12),
              Text('Aucune livraison effectuée',
                  style: TextStyle(color: Colors.grey.shade400,
                      fontSize: 15, fontWeight: FontWeight.w500))]))
          : RefreshIndicator(color: _teal, onRefresh: _chargerHistorique,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _resumeStats(),
                  const SizedBox(height: 16),
                  for (final l in _historique)
                    _carteHistorique(Map<String, dynamic>.from(l as Map)),
                ]))),
    ]);
  }

  Widget _resumeStats() {
    final livrees  = _historique.where((l) => l['statut'] == 'livre').length;
    final annulees = _historique.where((l) => l['statut'] == 'annule').length;
    final ca = _historique.where((l) => l['statut'] == 'livre')
        .fold<double>(0, (s, l) => s + ((l['prix'] as num?)?.toDouble() ?? 0));
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [_teal, _navy],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: _teal.withValues(alpha: 0.3),
            blurRadius: 14, offset: const Offset(0, 4))]),
      child: Row(children: [
        _resumeStat('${_historique.length}', 'Total', Colors.white),
        _resumeStat('$livrees', 'Livrées', Colors.greenAccent),
        _resumeStat('$annulees', 'Annulées', Colors.redAccent),
        _resumeStat('${_fmt(ca)}F', 'Gagné', Colors.orangeAccent),
      ]));
  }

  Widget _resumeStat(String v, String l, Color c) =>
    Expanded(child: Column(children: [
      Text(v, style: TextStyle(
          color: c, fontWeight: FontWeight.w800, fontSize: 18)),
      Text(l, style: const TextStyle(
          color: Colors.white60, fontSize: 10)),
    ]));

  Widget _carteHistorique(Map<String, dynamic> liv) {
    final s = liv['statut'] as String? ?? '';
    final c = _couleur(s);
    final lb = _label(s);
    final client = liv['client'];
    final date = liv['createdAt'] != null
        ? DateTime.tryParse(liv['createdAt'].toString()) : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8, offset: const Offset(0, 2))]),
      child: Padding(padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: c.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20)),
            child: Text(lb, style: TextStyle(
                color: c, fontWeight: FontWeight.w700, fontSize: 11))),
          const Spacer(),
          Text('${_fmt(liv["prix"])} FCFA',
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 14, color: _teal)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.trip_origin, color: Colors.green, size: 12),
          const SizedBox(width: 5),
          Expanded(child: Text(liv['adresse_depart'] ?? '',
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis))]),
        const SizedBox(height: 3),
        Row(children: [
          const Icon(Icons.location_on, color: Colors.red, size: 12),
          const SizedBox(width: 5),
          Expanded(child: Text(liv['adresse_arrivee'] ?? '',
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis))]),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.person, size: 11, color: Colors.grey),
          const SizedBox(width: 4),
          Text(client is Map ? (client['nom'] ?? '') : '',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
          const Spacer(),
          if (date != null)
            Text('${date.day}/${date.month}/${date.year}',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
        ]),
      ])));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PETITS WIDGETS RÉUTILISABLES
  // ══════════════════════════════════════════════════════════════════════════
  Widget _prixBadge(dynamic prix) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [_teal, Color(0xFF0A8A90)]),
      borderRadius: BorderRadius.circular(20)),
    child: Text('${_fmt(prix)} FCFA',
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)));

  Widget _etaBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8)),
    child: const Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.schedule, size: 11, color: Colors.orange),
      SizedBox(width: 3),
      Text('~15 min',
          style: TextStyle(
              fontSize: 10, color: Colors.orange, fontWeight: FontWeight.w600)),
    ]));

  Widget _statPill({required IconData icon, required String value,
    required String label}) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white70, size: 15),
        const SizedBox(width: 7),
        Column(crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, children: [
          Text(value, style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800,
              fontSize: 17, height: 1.1)),
          Text(label, style: const TextStyle(
              color: Colors.white60, fontSize: 10)),
        ]),
      ]));

  Widget _badgePaiement(Livraison liv) {
    final mode = (liv as dynamic).modePaiement as String? ?? 'cash';
    final stat = (liv as dynamic).statutPaiement as String? ?? '';
    Color c; IconData ic; String lb;
    if (mode == 'cash') {
      c = const Color(0xFFF97316); ic = Icons.payments_outlined; lb = 'Cash';
    } else if (stat == 'verifie') {
      c = const Color(0xFF10B981); ic = Icons.verified_outlined; lb = 'OM ✓';
    } else if (stat == 'preuve_soumise') {
      c = Colors.orange; ic = Icons.hourglass_top_rounded; lb = 'OM…';
    } else {
      c = Colors.grey; ic = Icons.phone_android_outlined; lb = 'OM';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
          color: c.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.withValues(alpha: 0.3))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(ic, size: 10, color: c),
        const SizedBox(width: 3),
        Text(lb, style: TextStyle(
            fontSize: 10, color: c, fontWeight: FontWeight.w700)),
      ]));
  }

  Widget _etatVide({bool filtre = false}) =>
    Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: _teal.withValues(alpha: 0.05),
            shape: BoxShape.circle),
        child: Icon(
            filtre ? Icons.filter_list_off : Icons.delivery_dining,
            size: 56, color: _teal.withValues(alpha: 0.22))),
      const SizedBox(height: 16),
      Text(filtre ? 'Aucune mission pour ce filtre' : 'Aucune mission disponible',
          style: TextStyle(fontSize: 15, color: Colors.grey.shade400,
              fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text(filtre ? 'Essaie un autre filtre' : 'Mise à jour toutes les 6 secondes',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade300)),
      if (filtre) ...[
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () => setState(() => _filtre = 'tous'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
            decoration: BoxDecoration(
                color: _teal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20)),
            child: const Text('Voir toutes les missions',
                style: TextStyle(color: _teal,
                    fontSize: 13, fontWeight: FontWeight.w700)))),
      ],
    ]));

  String _fmt(dynamic m) {
    if (m == null) return '0';
    final v = (m as num).toInt();
    return v.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (x) => '${x[1]} ');
  }

  Color _couleur(String s) {
    switch (s) {
      case 'en_cours':     return _teal;
      case 'en_livraison': return Colors.purple;
      case 'livre':        return _green;
      case 'annule':       return Colors.red;
      default:             return Colors.orange;
    }
  }

  String _label(String s) {
    switch (s) {
      case 'en_attente':   return '⏳ Attente';
      case 'en_cours':     return '🔄 En cours';
      case 'en_livraison': return '🚚 Livraison';
      case 'livre':        return '✅ Livré';
      case 'annule':       return '❌ Annulé';
      default:             return s;
    }
  }

  String _dateRel(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes}min';
    if (diff.inHours < 24)  return '${diff.inHours}h';
    return '${d.day}/${d.month}';
  }
}