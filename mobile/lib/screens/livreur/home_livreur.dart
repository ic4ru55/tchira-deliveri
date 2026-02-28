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

class _HomeLibreurState extends State<HomeLibreur> with SingleTickerProviderStateMixin {
  int           _onglet             = 0;
  Timer?        _timer;
  List<dynamic> _historique         = [];
  bool          _loadingHistorique  = false;

  static const _teal = Color(0xFF0D7377);
  static const _navy = Color(0xFF1B3A6B);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prov = context.read<LivraisonProvider>();
      prov.chargerLivraisonsDisponibles();
      prov.chargerMissionActive();
      _reprendreGps();
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted) return;
        if (_onglet == 0) prov.chargerLivraisonsDisponibles(silencieux: true);
        if (_onglet == 1 && !_loadingHistorique) _chargerHistorique();
      });
    });
  }

  @override void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _reprendreGps() async {
    final liv = context.read<LivraisonProvider>().livraisonActive;
    if (liv != null && (liv.statut == 'en_cours' || liv.statut == 'en_livraison')) {
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
    if (ret is bool)      { ok = ret; }
    else if (ret is Map)  { ok = ret['succes'] == true; msg = ret['message'] as String? ?? msg; }
    else                  { ok = false; }

    if (ok) {
      messenger.showSnackBar(const SnackBar(content: Text('✅ Mission acceptée !'), backgroundColor: Colors.green));
      await GpsService.instance.demarrer(id);
      navigator.push(MaterialPageRoute(builder: (_) => const MissionScreen()));
    } else {
      messenger.showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth  = context.watch<AuthProvider>();
    final prov  = context.watch<LivraisonProvider>();
    final actif = prov.livraisonActive;
    final missionOk = actif != null && (actif.statut == 'en_cours' || actif.statut == 'en_livraison');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_onglet != 0) { setState(() => _onglet = 0); return; }
        final quit = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Quitter Tchira ?', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Voulez-vous vraiment quitter l\'application ?'),
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
        backgroundColor: const Color(0xFFF8FAFC),
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

  // ── Navbar ────────────────────────────────────────────────────────────────
  Widget _navbar(bool missionOk) {
    final tabs = [
      (Icons.delivery_dining_outlined, Icons.delivery_dining, 'Missions'),
      (Icons.history_outlined,         Icons.history,         'Historique'),
      (Icons.person_outline,           Icons.person,          'Profil'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, -4))]),
      child: SafeArea(top: false, child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(tabs.length, (i) {
            final sel = _onglet == i;
            final (iconOff, iconOn, label) = tabs[i];
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() => _onglet = i);
                if (i == 1) _chargerHistorique();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? _teal.withValues(alpha: 0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Stack(children: [
                    Icon(sel ? iconOn : iconOff, color: sel ? _teal : Colors.grey, size: 24),
                    if (i == 0 && missionOk)
                      Positioned(right: 0, top: 0, child: Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle))),
                  ]),
                  const SizedBox(height: 3),
                  Text(label, style: TextStyle(fontSize: 11,
                      fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                      color: sel ? _teal : Colors.grey)),
                ]),
              ),
            );
          }),
        ),
      )),
    );
  }

  // ── Page Missions ─────────────────────────────────────────────────────────
  Widget _pageMissions(LivraisonProvider prov, bool missionOk) {
    final top = MediaQuery.of(context).padding.top;
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // ── Header compact avec SafeArea correcte ─────────────────────────
        SliverToBoxAdapter(child: missionOk
          // Banner mission en cours (orange) ──────────────────────────────
          ? GestureDetector(
              onTap: () async {
                final liv = context.read<LivraisonProvider>().livraisonActive;
                if (liv != null) await GpsService.instance.demarrer(liv.id);
                if (!mounted) return;
                Navigator.push(context, MaterialPageRoute(builder: (_) => const MissionScreen()));
              },
              child: Container(
                padding: EdgeInsets.fromLTRB(20, top + 14, 20, 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFEA580C), Color(0xFFF97316)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  boxShadow: [BoxShadow(color: Colors.orange.withValues(alpha: 0.3),
                      blurRadius: 10, offset: const Offset(0, 4))]),
                child: Row(children: [
                  Container(padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.local_shipping, color: Colors.white, size: 22)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Mission en cours', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(prov.livraisonActive!.adresseArrivee,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                        overflow: TextOverflow.ellipsis),
                  ])),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('Voir', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios, color: Colors.white, size: 12),
                    ])),
                ]),
              ),
            )
          // Header teal normal ─────────────────────────────────────────────
          : Container(
              padding: EdgeInsets.fromLTRB(20, top + 14, 20, 20),
              decoration: const BoxDecoration(
                color: _teal,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Bonjour 👋', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const Text('Missions disponibles', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ])),
                  // Badge statut
                  Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 8, height: 8,
                          decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      const Text('Disponible', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    ])),
                ]),
                const SizedBox(height: 12),
                // Stats rapides
                Row(children: [
                  _statPill(
                    icon: Icons.inbox_outlined,
                    value: '${prov.livraisonsDisponibles.length}',
                    label: 'Missions dispo'),
                  const SizedBox(width: 10),
                  _statPill(
                    icon: Icons.gps_fixed,
                    value: GpsService.instance.actif ? 'ON' : 'OFF',
                    label: 'GPS'),
                ]),
              ]),
            ),
        ),

        // ── Titre section + refresh ────────────────────────────────────────
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(children: [
            const Icon(Icons.delivery_dining, color: _teal, size: 20),
            const SizedBox(width: 8),
            const Text('Missions disponibles',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _navy)),
            const Spacer(),
            // Indicateur de chargement silencieux
            if (prov.isLoading && prov.livraisonsDisponibles.isNotEmpty)
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => prov.chargerLivraisonsDisponibles(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _teal.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.refresh, color: _teal, size: 18))),
          ]),
        )),

        // ── Liste missions ──────────────────────────────────────────────────
        if (prov.isLoading && prov.livraisonsDisponibles.isEmpty)
          const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
        else if (prov.livraisonsDisponibles.isEmpty)
          SliverFillRemaining(child: _etatVide())
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            sliver: SliverList(delegate: SliverChildBuilderDelegate(
              (_, i) => _carteMission(prov.livraisonsDisponibles[i], prov),
              childCount: prov.livraisonsDisponibles.length))),
      ],
    );
  }

  // ── Page Historique ───────────────────────────────────────────────────────
  Widget _pageHistorique() {
    final top = MediaQuery.of(context).padding.top;
    return Column(children: [
      Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(20, top + 14, 20, 20),
        decoration: const BoxDecoration(color: _navy,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24))),
        child: Row(children: [
          const Expanded(child: Text('Mon historique',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
          GestureDetector(onTap: _chargerHistorique,
            child: Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.refresh, color: Colors.white, size: 18))),
        ]),
      ),
      Expanded(child: _loadingHistorique
        ? const Center(child: CircularProgressIndicator())
        : _historique.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.history, size: 72, color: Colors.grey.shade200),
              const SizedBox(height: 12),
              Text('Aucune livraison effectuée',
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade400))]))
          : RefreshIndicator(
              onRefresh: _chargerHistorique,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                _resumeStats(),
                const SizedBox(height: 16),
                for (final l in _historique)
                  _carteHistorique(Map<String, dynamic>.from(l as Map)),
              ]))),
    ]);
  }

  // ── Widgets ───────────────────────────────────────────────────────────────
  Widget _statPill({required IconData icon, required String value, required String label}) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(width: 6),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, height: 1.1)),
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
        ]),
      ]));

  Widget _carteMission(Livraison liv, LivraisonProvider prov) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))]),
    child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Prix + badge paiement + date ─────────────────────────────────────
      Row(children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_teal, Color(0xFF0A5C60)]),
            borderRadius: BorderRadius.circular(20)),
          child: Text('${_fmt(liv.prix)} FCFA',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
        const SizedBox(width: 8),
        _badgePaiement(liv),
        const Spacer(),
        Text(_dateRel(liv.createdAt), style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
      ]),
      const SizedBox(height: 14),

      // ── Client ────────────────────────────────────────────────────────────
      Row(children: [
        Container(width: 34, height: 34,
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [_teal, _navy]),
              borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.person, color: Colors.white, size: 18)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(liv.client?['nom'] ?? 'Client',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          Text(liv.client?['telephone'] ?? '',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        ])),
      ]),
      const SizedBox(height: 12),

      // ── Itinéraire ─────────────────────────────────────────────────────────
      _adresseRow(Icons.trip_origin, Colors.green, liv.adresseDepart, 'Départ'),
      const Padding(padding: EdgeInsets.only(left: 10),
        child: Column(children: [SizedBox(height: 3), _DotLine(), SizedBox(height: 3)])),
      _adresseRow(Icons.location_on, Colors.red, liv.adresseArrivee, 'Arrivée'),

      if (liv.descriptionColis.isNotEmpty) ...[
        const SizedBox(height: 10),
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            Icon(Icons.inventory_2_outlined, size: 14, color: Colors.grey.shade500),
            const SizedBox(width: 8),
            Expanded(child: Text(liv.descriptionColis,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
          ])),
      ],
      const SizedBox(height: 14),

      // ── Bouton accepter ────────────────────────────────────────────────────
      SizedBox(width: double.infinity, height: 48,
        child: ElevatedButton.icon(
          onPressed: prov.isLoading ? null : () => _accepter(liv.id),
          icon: const Icon(Icons.check_circle_outline, size: 18),
          label: const Text('Accepter cette mission', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white,
            elevation: 2, shadowColor: Colors.green.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
    ])),
  );

  Widget _adresseRow(IconData icon, Color color, String adresse, String label) =>
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
        Text(adresse, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
      ])),
    ]);

  Widget _badgePaiement(Livraison liv) {
    final mode   = (liv as dynamic).modePaiement   as String? ?? 'cash';
    final statut = (liv as dynamic).statutPaiement as String? ?? '';
    Color c; IconData ic; String lb;
    if (mode == 'cash') { c = const Color(0xFFF97316); ic = Icons.payments_outlined; lb = 'Cash'; }
    else if (statut == 'verifie') { c = const Color(0xFF10B981); ic = Icons.verified_outlined; lb = 'OM ✓'; }
    else if (statut == 'preuve_soumise') { c = Colors.orange; ic = Icons.hourglass_top_rounded; lb = 'OM…'; }
    else { c = Colors.grey; ic = Icons.phone_android_outlined; lb = 'OM'; }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.withValues(alpha: 0.3))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(ic, size: 11, color: c), const SizedBox(width: 3),
        Text(lb, style: TextStyle(fontSize: 10, color: c, fontWeight: FontWeight.w600)),
      ]));
  }

  Widget _resumeStats() {
    final livrees  = _historique.where((l) => l['statut'] == 'livre').length;
    final annulees = _historique.where((l) => l['statut'] == 'annule').length;
    final ca       = _historique.where((l) => l['statut'] == 'livre')
        .fold<double>(0, (s, l) => s + ((l['prix'] as num?)?.toDouble() ?? 0));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_teal, _navy]),
        borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        _resumeStat('${_historique.length}', 'Total', Colors.white),
        _resumeStat('$livrees', 'Livrées', Colors.greenAccent),
        _resumeStat('$annulees', 'Annulées', Colors.redAccent),
        _resumeStat('${_fmt(ca)}F', 'Gagné', Colors.orangeAccent),
      ]));
  }

  Widget _resumeStat(String v, String l, Color c) => Expanded(child: Column(children: [
    Text(v, style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 17)),
    Text(l, style: const TextStyle(color: Colors.white60, fontSize: 10)),
  ]));

  Widget _carteHistorique(Map<String, dynamic> liv) {
    final s = liv['statut'] as String? ?? '';
    final c = _couleur(s); final lb = _label(s);
    final client = liv['client'];
    final date   = liv['createdAt'] != null ? DateTime.tryParse(liv['createdAt'].toString()) : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
              child: Text(lb, style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 12))),
          const Spacer(),
          Text('${_fmt(liv['prix'])} FCFA',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _teal)),
        ]),
        const SizedBox(height: 10),
        Row(children: [const Icon(Icons.trip_origin, color: Colors.green, size: 13), const SizedBox(width: 6),
          Expanded(child: Text(liv['adresse_depart'] ?? '', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))]),
        const SizedBox(height: 3),
        Row(children: [const Icon(Icons.location_on, color: Colors.red, size: 13), const SizedBox(width: 6),
          Expanded(child: Text(liv['adresse_arrivee'] ?? '', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))]),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.person, size: 12, color: Colors.grey), const SizedBox(width: 4),
          Text(client is Map ? (client['nom'] ?? '') : '', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          const Spacer(),
          if (date != null) Text('${date.day}/${date.month}/${date.year}',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
        ]),
      ])));
  }

  Widget _etatVide() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: _teal.withValues(alpha: 0.06), shape: BoxShape.circle),
      child: Icon(Icons.delivery_dining, size: 56, color: _teal.withValues(alpha: 0.3))),
    const SizedBox(height: 16),
    Text('Aucune mission disponible', style: TextStyle(fontSize: 16, color: Colors.grey.shade400, fontWeight: FontWeight.w500)),
    const SizedBox(height: 6),
    Text('Mise à jour automatique toutes les 5s', style: TextStyle(fontSize: 12, color: Colors.grey.shade300)),
  ]));

  String _fmt(dynamic m) { if (m == null) return '0'; final v = (m as num).toInt(); return v.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (x) => '${x[1]} '); }
  Color  _couleur(String s) { switch (s) { case 'en_attente': return Colors.orange; case 'en_cours': return _teal; case 'en_livraison': return Colors.purple; case 'livre': return Colors.green; case 'annule': return Colors.red; default: return Colors.grey; } }
  String _label(String s)   { switch (s) { case 'en_attente': return '⏳ Attente'; case 'en_cours': return '🔄 En cours'; case 'en_livraison': return '🚚 Livraison'; case 'livre': return '✅ Livré'; case 'annule': return '❌ Annulé'; default: return s; } }
  String _dateRel(DateTime d) { final diff = DateTime.now().difference(d); if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes}min'; if (diff.inHours < 24) return 'Il y a ${diff.inHours}h'; return '${d.day}/${d.month}'; }
}

// ── Widget ligne pointillée entre départ et arrivée ────────────────────────────
class _DotLine extends StatelessWidget {
  const _DotLine();
  @override
  Widget build(BuildContext context) => Row(children: List.generate(
    8, (_) => Expanded(child: Container(
        height: 1.5, margin: const EdgeInsets.symmetric(horizontal: 1.5),
        color: Colors.grey.shade200))));
}