import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/livraison_provider.dart';
import '../../models/livraison.dart';
import '../../screens/auth/login_screen.dart';
import '../../services/api_service.dart';
import 'mission_screen.dart';

class HomeLibreur extends StatefulWidget {
  const HomeLibreur({super.key});

  @override
  State<HomeLibreur> createState() => _HomeLibreurState();
}

class _HomeLibreurState extends State<HomeLibreur>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _timer;

  List<dynamic> _historique           = [];
  bool          _chargementHistorique = true;
  bool          _historiqueCharge     = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && !_historiqueCharge) {
        _chargerHistorique();
      }
      setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LivraisonProvider>().chargerLivraisonsDisponibles();
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (mounted && _tabController.index == 0) {
          context.read<LivraisonProvider>()
              .chargerLivraisonsDisponibles(silencieux: true);
        }
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _chargerHistorique() async {
    setState(() => _chargementHistorique = true);
    try {
      final reponse = await ApiService.mesLivraisonsLivreur();
      if (reponse['success'] == true) {
        setState(() {
          _historique           = reponse['livraisons'] ?? [];
          _chargementHistorique = false;
          _historiqueCharge     = true;
        });
      } else {
        setState(() => _chargementHistorique = false);
      }
    } catch (e) {
      setState(() => _chargementHistorique = false);
    }
  }

  Future<void> _deconnecter() async {
    _timer?.cancel();
    final auth      = context.read<AuthProvider>();
    final navigator = Navigator.of(context);
    await auth.deconnecter();
    if (!mounted) return;
    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  // ✅ FIX MISSIONS LIÉES :
  // Avant : provider.isLoading était global → désactivait TOUS les boutons
  // simultanément → l'utilisateur pouvait cliquer sur 2 missions "en même temps"
  // car les deux boutons répondaient au même état.
  // Solution : tracker localement l'ID de la mission en cours d'acceptation.
  String? _idEnCoursAcceptation;

  Future<void> _accepterLivraison(String id) async {
    // Bloquer si une acceptation est déjà en cours (n'importe laquelle)
    if (_idEnCoursAcceptation != null) return;
    setState(() => _idEnCoursAcceptation = id);

    final provider  = context.read<LivraisonProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final succes    = await provider.accepterLivraison(id);
    if (mounted) setState(() => _idEnCoursAcceptation = null);
    if (!mounted) return;
    if (succes) {
      messenger.showSnackBar(const SnackBar(
          content: Text('✅ Mission acceptée !'),
          backgroundColor: Colors.green));
      navigator.push(MaterialPageRoute(builder: (_) => const MissionScreen()));
    } else {
      messenger.showSnackBar(const SnackBar(
          content: Text('❌ Mission non disponible'),
          backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth     = context.watch<AuthProvider>();
    final provider = context.watch<LivraisonProvider>();

    final missionEnCours = provider.livraisonActive != null &&
        (provider.livraisonActive!.statut == 'en_cours' ||
         provider.livraisonActive!.statut == 'en_livraison');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D7377),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tchira Express',
                style: TextStyle(color: Colors.white, fontSize: 16,
                    fontWeight: FontWeight.bold)),
            Text(auth.user?.nom ?? '',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(
              child: Row(children: [
                Container(width: 8, height: 8,
                    decoration: const BoxDecoration(
                        color: Colors.greenAccent, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                const Text('Live', style: TextStyle(
                    color: Colors.greenAccent, fontSize: 11,
                    fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              if (_tabController.index == 0) {
                provider.chargerLivraisonsDisponibles();
              } else {
                _historiqueCharge = false;
                _chargerHistorique();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _deconnecter,
          ),
        ],
        bottom: TabBar(
          controller:           _tabController,
          indicatorColor:       const Color(0xFFF97316),
          labelColor:           Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.delivery_dining), text: 'Missions'),
            Tab(icon: Icon(Icons.history),          text: 'Historique'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ongletMissions(provider, missionEnCours),
          _ongletHistorique(),
        ],
      ),
    );
  }

  // ─── Onglet Missions ──────────────────────────────────────────────────────
  Widget _ongletMissions(LivraisonProvider provider, bool missionEnCours) {
    return Column(children: [
      // Bandeau mission en cours
      if (missionEnCours)
        GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const MissionScreen())),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            color: Colors.orange.shade700,
            child: Row(children: [
              const Icon(Icons.local_shipping, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🚚 Mission en cours !',
                      style: TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(provider.livraisonActive!.adresseArrivee,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                ],
              )),
              const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
            ]),
          ),
        ),

      // Bannière stats
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        decoration: const BoxDecoration(
          color: Color(0xFF0D7377),
          borderRadius: BorderRadius.only(
            bottomLeft:  Radius.circular(28),
            bottomRight: Radius.circular(28),
          ),
        ),
        child: Row(children: [
          _statCard(
            label: 'Missions dispo',
            valeur: '${provider.livraisonsDisponibles.length}',
            icone: Icons.inbox_outlined,
          ),
          const SizedBox(width: 12),
          _statCard(
            label: 'Statut',
            valeur: missionEnCours ? 'En mission' : 'Disponible',
            icone: Icons.circle,
            couleurIcone: missionEnCours ? Colors.orange : Colors.greenAccent,
          ),
        ]),
      ),

      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Row(children: [
          const Icon(Icons.delivery_dining, color: Color(0xFF0D7377), size: 20),
          const SizedBox(width: 8),
          const Text('Livraisons disponibles',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                  color: Color(0xFF0D7377))),
        ]),
      ),

      Expanded(
        child: provider.isLoading && provider.livraisonsDisponibles.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : provider.livraisonsDisponibles.isEmpty
                ? _etatVide()
                : RefreshIndicator(
                    onRefresh: () => provider.chargerLivraisonsDisponibles(),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: provider.livraisonsDisponibles.length,
                      itemBuilder: (context, index) => _carteMission(
                          provider.livraisonsDisponibles[index], provider),
                    ),
                  ),
      ),
    ]);
  }

  // ─── Onglet Historique ────────────────────────────────────────────────────
  Widget _ongletHistorique() {
    if (_chargementHistorique) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_historique.isEmpty) {
      return Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 80, color: Colors.grey.shade200),
            const SizedBox(height: 16),
            Text('Aucune livraison effectuée',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade400)),
          ]));
    }

    final livrees  = _historique.where((l) => l['statut'] == 'livre').length;
    final annulees = _historique.where((l) => l['statut'] == 'annule').length;
    final caTotal  = _historique
        .where((l) => l['statut'] == 'livre')
        .fold<double>(0.0, (sum, l) => sum + ((l['prix'] as num?)?.toDouble() ?? 0.0));

    return RefreshIndicator(
      onRefresh: () async {
        _historiqueCharge = false;
        await _chargerHistorique();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Résumé stats
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0D7377),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(children: [
              _resumeStat('${_historique.length}', 'Total',    Colors.white),
              _resumeStat('$livrees',              'Livrées',  Colors.greenAccent),
              _resumeStat('$annulees',             'Annulées', Colors.redAccent),
              _resumeStat('${_formatPrix(caTotal)} F', 'Gagné', Colors.orangeAccent),
            ]),
          ),
          const SizedBox(height: 16),

          for (final l in _historique)
            _carteHistorique(Map<String, dynamic>.from(l as Map)),
        ],
      ),
    );
  }

  Widget _resumeStat(String valeur, String label, Color couleur) {
    return Expanded(child: Column(children: [
      Text(valeur, style: TextStyle(
          color: couleur, fontWeight: FontWeight.bold, fontSize: 16)),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
    ]));
  }

  Widget _carteHistorique(Map<String, dynamic> livraison) {
    final statut  = livraison['statut'] as String? ?? '';
    final couleur = _couleurStatut(statut);
    final label   = _labelStatut(statut);
    final client  = livraison['client'];
    final dateStr = livraison['createdAt']?.toString();
    final date    = dateStr != null ? DateTime.tryParse(dateStr) : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: couleur.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(label, style: TextStyle(
                  color: couleur, fontWeight: FontWeight.w600, fontSize: 12)),
            ),
            Text('${_formatPrix(livraison['prix'])} FCFA',
                style: const TextStyle(fontWeight: FontWeight.bold,
                    fontSize: 14, color: Color(0xFF0D7377))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.trip_origin, color: Colors.green, size: 14),
            const SizedBox(width: 6),
            Expanded(child: Text(livraison['adresse_depart'] ?? '',
                style: const TextStyle(fontSize: 12, color: Colors.black87),
                overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.location_on, color: Colors.red, size: 14),
            const SizedBox(width: 6),
            Expanded(child: Text(livraison['adresse_arrivee'] ?? '',
                style: const TextStyle(fontSize: 12, color: Colors.black87),
                overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.person, size: 13, color: Colors.grey),
            const SizedBox(width: 4),
            Text(client is Map ? (client['nom'] ?? '') : '',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const Spacer(),
            if (date != null)
              Text('${date.day}/${date.month}/${date.year}',
                  style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ]),
        ]),
      ),
    );
  }

  // ─── Carte mission disponible ─────────────────────────────────────────────
  Widget _carteMission(Livraison livraison, LivraisonProvider provider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFF0D7377),
                  borderRadius: BorderRadius.circular(20)),
              child: Text('${_formatPrix(livraison.prix)} FCFA',
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            Text(_formatDate(livraison.createdAt),
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            const CircleAvatar(radius: 16,
                backgroundColor: Color(0xFFD1FAE5),
                child: Icon(Icons.person, color: Color(0xFF0D7377), size: 18)),
            const SizedBox(width: 8),
            Text(livraison.client?['nom'] ?? 'Client',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(width: 6),
            Text(livraison.client?['telephone'] ?? '',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ]),
          const SizedBox(height: 14),
          _adresseLigne(icone: Icons.trip_origin, couleur: Colors.green,
              texte: livraison.adresseDepart, label: 'Départ'),
          const SizedBox(height: 6),
          _adresseLigne(icone: Icons.location_on, couleur: Colors.red,
              texte: livraison.adresseArrivee, label: 'Arrivée'),
          if (livraison.descriptionColis.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.inventory_2_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(child: Text(livraison.descriptionColis,
                    style: const TextStyle(fontSize: 13, color: Colors.grey))),
              ]),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity, height: 46,
            child: ElevatedButton.icon(
              onPressed: _idEnCoursAcceptation != null
                  ? null : () => _accepterLivraison(livraison.id),
              icon: _idEnCoursAcceptation == livraison.id
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Accepter cette mission',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _etatVide() {
    return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.delivery_dining, size: 80, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text('Aucune mission disponible',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade400)),
          const SizedBox(height: 8),
          Text('Mise à jour automatique en cours...',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
        ]));
  }

  Widget _statCard({
    required String label, required String valeur,
    required IconData icone, Color couleurIcone = Colors.white,
  }) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Icon(icone, color: couleurIcone, size: 22),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(valeur, style: const TextStyle(color: Colors.white,
              fontWeight: FontWeight.bold, fontSize: 18)),
          Text(label, style: const TextStyle(
              color: Colors.white70, fontSize: 11)),
        ]),
      ]),
    ));
  }

  Widget _adresseLigne({
    required IconData icone, required Color couleur,
    required String texte,   required String label,
  }) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icone, color: couleur, size: 16),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        SizedBox(width: 260, child: Text(texte,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
            overflow: TextOverflow.ellipsis)),
      ]),
    ]);
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  Color _couleurStatut(String statut) {
    switch (statut) {
      case 'en_attente':   return Colors.orange;
      case 'en_cours':     return const Color(0xFF0D7377);
      case 'en_livraison': return Colors.purple;
      case 'livre':        return Colors.green;
      case 'annule':       return Colors.red;
      default:             return Colors.grey;
    }
  }

  String _labelStatut(String statut) {
    switch (statut) {
      case 'en_attente':   return '⏳ Attente';
      case 'en_cours':     return '🔄 En cours';
      case 'en_livraison': return '🚚 Livraison';
      case 'livre':        return '✅ Livré';
      case 'annule':       return '❌ Annulé';
      default:             return statut;
    }
  }

  String _formatPrix(dynamic montant) {
    if (montant == null) return '0';
    final val = (montant as num).toInt();
    return val.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours   < 24) return 'Il y a ${diff.inHours}h';
    return '${date.day}/${date.month}/${date.year}';
  }
}