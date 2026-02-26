import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/livraison_provider.dart';
import '../../models/livraison.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/profil_screen.dart';
import '../../services/api_service.dart';
import 'mission_screen.dart';
import '../info_screen.dart';

class HomeLibreur extends StatefulWidget {
  const HomeLibreur({super.key});
  @override
  State<HomeLibreur> createState() => _HomeLibreurState();
}

class _HomeLibreurState extends State<HomeLibreur> {
  int    _ongletActif         = 0; // 0=Missions 1=Historique 2=Profil
  Timer? _timer;
  List<dynamic> _historique   = [];
  bool _chargementHistorique  = true;
  bool _historiqueCharge      = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<LivraisonProvider>();
      provider.chargerLivraisonsDisponibles();
      provider.chargerMissionActive();
      // ✅ Reprendre le GPS auto si mission en cours (ex: retour depuis MissionScreen)
      _reprendreGpsAuto();
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (mounted && _ongletActif == 0) {
          context.read<LivraisonProvider>().chargerLivraisonsDisponibles(silencieux: true);
        }
      });
    });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  // ─── Reprendre GPS si mission déjà active ──────────────────────────────────
  Future<void> _reprendreGpsAuto() async {
    final livraison = context.read<LivraisonProvider>().livraisonActive;
    if (livraison == null) return;
    if (livraison.statut == 'en_cours' || livraison.statut == 'en_livraison') {
      await GpsService.instance.demarrer(livraison.id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _chargerHistorique() async {
    setState(() => _chargementHistorique = true);
    try {
      final r = await ApiService.mesLivraisonsLivreur();
      if (!mounted) return;
      if (r['success'] == true) setState(() { _historique = r['livraisons'] ?? []; _chargementHistorique = false; _historiqueCharge = true; });
      else setState(() => _chargementHistorique = false);
    } catch (_) { if (mounted) setState(() => _chargementHistorique = false); }
  }

  Future<void> _accepterLivraison(String id) async {
    final provider  = context.read<LivraisonProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    // ✅ Compatibilité : le provider peut retourner Map OU bool selon la version
    final dynamic retour = await provider.accepterLivraison(id);
    if (!mounted) return;

    bool succes;
    String msg = '❌ Mission non disponible';

    if (retour is bool) {
      // Ancienne signature : Future<bool>
      succes = retour;
    } else if (retour is Map) {
      // Nouvelle signature : Future<Map<String, dynamic>>
      succes = retour['succes'] == true;
      msg    = (retour['message'] as String?) ?? msg;
    } else {
      succes = false;
    }

    if (succes) {
      messenger.showSnackBar(const SnackBar(content: Text('✅ Mission acceptée !'), backgroundColor: Colors.green));
      await GpsService.instance.demarrer(id);
      navigator.push(MaterialPageRoute(builder: (_) => const MissionScreen()));
    } else {
      messenger.showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth     = context.watch<AuthProvider>();
    final provider = context.watch<LivraisonProvider>();
    final missionEnCours = provider.livraisonActive != null &&
        (provider.livraisonActive!.statut == 'en_cours' || provider.livraisonActive!.statut == 'en_livraison');

    // Charger historique si onglet activé
    if (_ongletActif == 1 && !_historiqueCharge && !_chargementHistorique) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _chargerHistorique());
    }

    final pages = [
      _pageMissions(provider, missionEnCours),
      _pageHistorique(),
      _pageProfil(auth),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_ongletActif != 0) {
          setState(() => _ongletActif = 0);
          return;
        }
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
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B3A6B), foregroundColor: Colors.white),
                child: const Text('Quitter'),
              ),
            ],
          ),
        );
        if (quitter == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: pages[_ongletActif],
        bottomNavigationBar: _navbar(missionEnCours),
      ),
    );
  }

  Widget _navbar(bool missionEnCours) {
    final items = [
      {'icon': Icons.delivery_dining_outlined, 'iconSel': Icons.delivery_dining, 'label': 'Missions'},
      {'icon': Icons.history_outlined,          'iconSel': Icons.history,          'label': 'Historique'},
      {'icon': Icons.person_outline,            'iconSel': Icons.person,           'label': 'Profil'},
    ];
    return Container(
      decoration: BoxDecoration(color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, -4))],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: SafeArea(top: false, child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: List.generate(items.length, (i) {
          final sel = _ongletActif == i;
          return GestureDetector(
            onTap: () => setState(() => _ongletActif = i),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? const Color(0xFF0D7377).withValues(alpha: 0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(16)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Stack(children: [
                  Icon(sel ? items[i]['iconSel'] as IconData : items[i]['icon'] as IconData,
                      color: sel ? const Color(0xFF0D7377) : Colors.grey, size: 24),
                  // Badge mission en cours sur l'onglet Missions
                  if (i == 0 && missionEnCours)
                    Positioned(right: 0, top: 0, child: Container(width: 8, height: 8,
                        decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle))),
                ]),
                const SizedBox(height: 2),
                Text(items[i]['label'] as String,
                    style: TextStyle(fontSize: 11, fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                        color: sel ? const Color(0xFF0D7377) : Colors.grey)),
              ]),
            ),
          );
        })),
      )),
    );
  }

  // ─── PAGE MISSIONS ────────────────────────────────────────────────────────
  Widget _pageMissions(LivraisonProvider provider, bool missionEnCours) {
    return Column(children: [
      if (missionEnCours)
        GestureDetector(
          onTap: () async {
              final livraison = context.read<LivraisonProvider>().livraisonActive;
              if (livraison != null) { await GpsService.instance.demarrer(livraison.id); }
              if (!mounted) return;
              Navigator.push(context, MaterialPageRoute(builder: (_) => const MissionScreen()));
            },
          child: Container(
            margin: const EdgeInsets.only(top: 0),
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 14),
            color: Colors.orange.shade700,
            child: Row(children: [
              const Icon(Icons.local_shipping, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('🚚 Mission en cours !', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                Text(provider.livraisonActive!.adresseArrivee, style: const TextStyle(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis),
              ])),
              const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
            ]),
          ),
        )
      else
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 56, 24, 28),
          decoration: const BoxDecoration(color: Color(0xFF0D7377),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28))),
          child: Row(children: [
            _statCard(label: 'Dispo', valeur: '${provider.livraisonsDisponibles.length}', icone: Icons.inbox_outlined),
            const SizedBox(width: 12),
            _statCard(label: 'Statut', valeur: 'Disponible', icone: Icons.circle, couleurIcone: Colors.greenAccent),
          ]),
        ),

      Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(children: [
          const Icon(Icons.delivery_dining, color: Color(0xFF0D7377), size: 20), const SizedBox(width: 8),
          const Text('Missions disponibles', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0D7377))),
          const Spacer(),
          IconButton(icon: const Icon(Icons.refresh, color: Color(0xFF0D7377), size: 20),
              onPressed: () => provider.chargerLivraisonsDisponibles()),
        ]),
      ),
      Expanded(child: provider.isLoading && provider.livraisonsDisponibles.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : provider.livraisonsDisponibles.isEmpty
              ? _etatVide()
              : RefreshIndicator(
                  onRefresh: () => provider.chargerLivraisonsDisponibles(),
                  child: ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: provider.livraisonsDisponibles.length,
                      itemBuilder: (_, i) => _carteMission(provider.livraisonsDisponibles[i], provider)))),
    ]);
  }

  // ─── PAGE HISTORIQUE ──────────────────────────────────────────────────────
  Widget _pageHistorique() {
    return Column(children: [
      Container(width: double.infinity, padding: const EdgeInsets.fromLTRB(24, 56, 24, 20),
          decoration: const BoxDecoration(color: Color(0xFF0D7377),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28))),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Mon historique', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            IconButton(icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
                onPressed: () { _historiqueCharge = false; _chargerHistorique(); }),
          ])),
      Expanded(child: _chargementHistorique
          ? const Center(child: CircularProgressIndicator())
          : _historique.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.history, size: 80, color: Colors.grey.shade200), const SizedBox(height: 16),
                  Text('Aucune livraison effectuée', style: TextStyle(fontSize: 16, color: Colors.grey.shade400))]))
              : RefreshIndicator(
                  onRefresh: () async { _historiqueCharge = false; await _chargerHistorique(); },
                  child: ListView(padding: const EdgeInsets.all(16), children: [
                    _resumeStats(),
                    const SizedBox(height: 16),
                    for (final l in _historique) _carteHistorique(Map<String, dynamic>.from(l as Map)),
                  ]))),
    ]);
  }

  Widget _resumeStats() {
    final livrees  = _historique.where((l) => l['statut'] == 'livre').length;
    final annulees = _historique.where((l) => l['statut'] == 'annule').length;
    final ca       = _historique.where((l) => l['statut'] == 'livre').fold<double>(0, (s, l) => s + ((l['prix'] as num?)?.toDouble() ?? 0));
    return Container(padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFF0D7377), borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          _resumeStat('${_historique.length}', 'Total', Colors.white),
          _resumeStat('$livrees', 'Livrées', Colors.greenAccent),
          _resumeStat('$annulees', 'Annulées', Colors.redAccent),
          _resumeStat('${_fmt(ca)} F', 'Gagné', Colors.orangeAccent),
        ]));
  }

  Widget _resumeStat(String val, String lbl, Color c) => Expanded(child: Column(children: [
    Text(val, style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 16)),
    Text(lbl, style: const TextStyle(color: Colors.white70, fontSize: 10)),
  ]));

  // ─── PAGE PROFIL ──────────────────────────────────────────────────────────
  Widget _pageProfil(AuthProvider auth) {
    final user = auth.user;
    return SingleChildScrollView(child: Column(children: [
      Container(width: double.infinity, padding: const EdgeInsets.fromLTRB(0, 56, 0, 32),
          decoration: const BoxDecoration(color: Color(0xFF0D7377),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32))),
          child: Column(children: [
            Stack(alignment: Alignment.bottomRight, children: [
              Container(width: 90, height: 90,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
                  child: ClipOval(child: _buildPhoto(user?.photoBase64))),
              GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilScreen())).then((_) => auth.rafraichirProfil()),
                  child: Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Color(0xFFF97316), shape: BoxShape.circle),
                      child: const Icon(Icons.edit, size: 14, color: Colors.white))),
            ]),
            const SizedBox(height: 12),
            Text(user?.nom ?? '', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(color: const Color(0xFF0D9488), borderRadius: BorderRadius.circular(20)),
                child: const Text('🚴 Livreur', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
          ])),
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
          _timer?.cancel();
          final navigator = Navigator.of(context);
          await auth.deconnecter();
          if (!mounted) return;
          navigator.pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
        }),
      ])),
    ]));
  }

  Widget _buildPhoto(String? b64) {
    if (b64 != null && b64.isNotEmpty) {
      try { return Image.memory(base64Decode(b64.replaceFirst(RegExp(r'data:image/[^;]+;base64,'), '')), fit: BoxFit.cover, width: 90, height: 90); } catch (_) {}
    }
    return const Icon(Icons.person, size: 48, color: Colors.white70);
  }

  Widget _ligneInfo(IconData icone, String label, String valeur) => Container(
    margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))]),
    child: Row(children: [Icon(icone, size: 18, color: const Color(0xFF0D7377)), const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(valeur, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      ])]),
  );

  Widget _boutonProfil(String label, Color couleur, VoidCallback onTap) => SizedBox(width: double.infinity, height: 50,
    child: ElevatedButton(onPressed: onTap,
        style: ElevatedButton.styleFrom(backgroundColor: couleur, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))));

  Widget _carteMission(Livraison liv, LivraisonProvider provider) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))]),
    child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFF0D7377), borderRadius: BorderRadius.circular(20)),
            child: Text('${_fmt(liv.prix)} FCFA', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
        Text(_formatDate(liv.createdAt), style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        const CircleAvatar(radius: 16, backgroundColor: Color(0xFFD1FAE5), child: Icon(Icons.person, color: Color(0xFF0D7377), size: 18)),
        const SizedBox(width: 8),
        Text(liv.client?['nom'] ?? 'Client', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(width: 6),
        Text(liv.client?['telephone'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ]),
      const SizedBox(height: 14),
      Row(children: [const Icon(Icons.trip_origin, color: Colors.green, size: 16), const SizedBox(width: 8), Expanded(child: Text(liv.adresseDepart, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))]),
      const SizedBox(height: 4),
      Row(children: [const Icon(Icons.location_on, color: Colors.red, size: 16), const SizedBox(width: 8), Expanded(child: Text(liv.adresseArrivee, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))]),
      if (liv.descriptionColis.isNotEmpty) ...[
        const SizedBox(height: 10),
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
            child: Row(children: [const Icon(Icons.inventory_2_outlined, size: 16, color: Colors.grey), const SizedBox(width: 8), Expanded(child: Text(liv.descriptionColis, style: const TextStyle(fontSize: 13, color: Colors.grey)))])),
      ],
      const SizedBox(height: 14),
      SizedBox(width: double.infinity, height: 46, child: ElevatedButton.icon(
        onPressed: provider.isLoading ? null : () => _accepterLivraison(liv.id),
        icon: const Icon(Icons.check_circle_outline, size: 18),
        label: const Text('Accepter cette mission', style: TextStyle(fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      )),
    ])),
  );

  Widget _carteHistorique(Map<String, dynamic> liv) {
    final statut  = liv['statut'] as String? ?? '';
    final couleur = _couleur(statut); final label = _label(statut);
    final client  = liv['client'];
    final date    = liv['createdAt'] != null ? DateTime.tryParse(liv['createdAt'].toString()) : null;
    return Container(margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: couleur.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
              child: Text(label, style: TextStyle(color: couleur, fontWeight: FontWeight.w600, fontSize: 12))),
          Text('${_fmt(liv['prix'])} FCFA', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0D7377))),
        ]),
        const SizedBox(height: 10),
        Row(children: [const Icon(Icons.trip_origin, color: Colors.green, size: 14), const SizedBox(width: 6), Expanded(child: Text(liv['adresse_depart'] ?? '', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))]),
        const SizedBox(height: 4),
        Row(children: [const Icon(Icons.location_on, color: Colors.red, size: 14), const SizedBox(width: 6), Expanded(child: Text(liv['adresse_arrivee'] ?? '', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))]),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.person, size: 13, color: Colors.grey), const SizedBox(width: 4),
          Text(client is Map ? (client['nom'] ?? '') : '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const Spacer(),
          if (date != null) Text('${date.day}/${date.month}/${date.year}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ]),
      ])),
    );
  }

  Widget _etatVide() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.delivery_dining, size: 80, color: Colors.grey.shade200), const SizedBox(height: 16),
    Text('Aucune mission disponible', style: TextStyle(fontSize: 16, color: Colors.grey.shade400)),
    const SizedBox(height: 8), Text('Mise à jour automatique...', style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
  ]));

  Widget _statCard({required String label, required String valeur, required IconData icone, Color couleurIcone = Colors.white}) =>
    Expanded(child: Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [Icon(icone, color: couleurIcone, size: 22), const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(valeur, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ])])));

  String _fmt(dynamic m) { if (m == null) return '0'; final v = (m as num).toInt(); return v.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (x) => '${x[1]} '); }
  Color  _couleur(String s) { switch (s) { case 'en_attente': return Colors.orange; case 'en_cours': return const Color(0xFF0D7377); case 'en_livraison': return Colors.purple; case 'livre': return Colors.green; case 'annule': return Colors.red; default: return Colors.grey; } }
  String _label(String s)   { switch (s) { case 'en_attente': return '⏳ Attente'; case 'en_cours': return '🔄 En cours'; case 'en_livraison': return '🚚 Livraison'; case 'livre': return '✅ Livré'; case 'annule': return '❌ Annulé'; default: return s; } }
  String _formatDate(DateTime d) { final diff = DateTime.now().difference(d); if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min'; if (diff.inHours < 24) return 'Il y a ${diff.inHours}h'; return '${d.day}/${d.month}/${d.year}'; }
}