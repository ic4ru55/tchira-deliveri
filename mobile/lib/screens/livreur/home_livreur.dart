import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/livraison_provider.dart';
import '../../models/livraison.dart';
import '../../screens/auth/login_screen.dart';
import 'mission_screen.dart';

class HomeLibreur extends StatefulWidget {
  const HomeLibreur({super.key});

  @override
  State<HomeLibreur> createState() => _HomeLibreurState();
}

class _HomeLibreurState extends State<HomeLibreur> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LivraisonProvider>().chargerLivraisonsDisponibles();

      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (mounted) {
          context.read<LivraisonProvider>()
              .chargerLivraisonsDisponibles(silencieux: true);
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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

  Future<void> _accepterLivraison(String id) async {
    final provider  = context.read<LivraisonProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final succes = await provider.accepterLivraison(id);
    if (!mounted) return;

    if (succes) {
      messenger.showSnackBar(const SnackBar(
        content:         Text('✅ Mission acceptée !'),
        backgroundColor: Colors.green,
      ));
      navigator.push(
        MaterialPageRoute(builder: (_) => const MissionScreen()),
      );
    } else {
      messenger.showSnackBar(const SnackBar(
        content:         Text('❌ Mission non disponible'),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth     = context.watch<AuthProvider>();
    final provider = context.watch<LivraisonProvider>();

    // ✅ Si une mission est en cours → on affiche le bandeau "Reprendre"
    // C'était le bug : quand le livreur revenait en arrière,
    // livraisonActive existait encore mais rien ne le montrait
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
            const Text(
              'Tchira Express',
              style: TextStyle(
                color: Colors.white, fontSize: 16,
                fontWeight: FontWeight.bold),
            ),
            Text(
              'Livreur : ${auth.user?.nom ?? ""}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(
              child: Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.greenAccent, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  const Text('Live',
                      style: TextStyle(
                        color: Colors.greenAccent, fontSize: 11,
                        fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          IconButton(
            icon:      const Icon(Icons.refresh, color: Colors.white),
            onPressed: provider.isLoading
                ? null
                : () => provider.chargerLivraisonsDisponibles(),
          ),
          IconButton(
            icon:      const Icon(Icons.logout, color: Colors.white),
            onPressed: _deconnecter,
          ),
        ],
      ),

      body: Column(
        children: [

          // ✅ Bandeau "Mission en cours" — visible quand le livreur
          // est revenu en arrière par accident pendant une livraison
          // Un simple tap le renvoie directement sur MissionScreen
          if (missionEnCours)
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MissionScreen()),
              ),
              child: Container(
                width:   double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                color: Colors.orange.shade700,
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_shipping,
                      color: Colors.white, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '🚚 Mission en cours !',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            provider.livraisonActive!.adresseArrivee,
                            style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white, size: 16),
                  ],
                ),
              ),
            ),

          // ── Bannière stats ────────────────────────────────────────────
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
            child: Row(
              children: [
                _statCard(
                  label:  'Missions dispo',
                  valeur: '${provider.livraisonsDisponibles.length}',
                  icone:  Icons.inbox_outlined,
                ),
                const SizedBox(width: 12),
                _statCard(
                  label:        'Statut',
                  valeur:       missionEnCours ? 'En mission' : 'Disponible',
                  icone:        Icons.circle,
                  couleurIcone: missionEnCours
                      ? Colors.orange
                      : Colors.greenAccent,
                ),
              ],
            ),
          ),

          // ── Titre liste ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Row(
              children: [
                const Icon(
                  Icons.delivery_dining,
                  color: Color(0xFF0D7377), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Livraisons disponibles',
                  style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold,
                    color: Color(0xFF0D7377)),
                ),
              ],
            ),
          ),

          // ── Liste ─────────────────────────────────────────────────────
          Expanded(
            child: provider.isLoading &&
                    provider.livraisonsDisponibles.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : provider.livraisonsDisponibles.isEmpty
                    ? _etatVide()
                    : RefreshIndicator(
                        onRefresh: () =>
                            provider.chargerLivraisonsDisponibles(),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16),
                          itemCount:
                              provider.livraisonsDisponibles.length,
                          itemBuilder: (context, index) => _carteMission(
                            provider.livraisonsDisponibles[index],
                            provider,
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _carteMission(Livraison livraison, LivraisonProvider provider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10, offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D7377),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_formatPrix(livraison.prix)} FCFA',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Text(
                  _formatDate(livraison.createdAt),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0xFFD1FAE5),
                  child: Icon(Icons.person,
                      color: Color(0xFF0D7377), size: 18),
                ),
                const SizedBox(width: 8),
                Text(
                  livraison.client?['nom'] ?? 'Client',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(width: 6),
                Text(
                  livraison.client?['telephone'] ?? '',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 14),

            _adresseLigne(
              icone: Icons.trip_origin, couleur: Colors.green,
              texte: livraison.adresseDepart, label: 'Départ',
            ),
            const SizedBox(height: 6),
            _adresseLigne(
              icone: Icons.location_on, couleur: Colors.red,
              texte: livraison.adresseArrivee, label: 'Arrivée',
            ),

            if (livraison.descriptionColis.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined,
                        size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(livraison.descriptionColis,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.grey)),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity, height: 46,
              child: ElevatedButton.icon(
                onPressed: provider.isLoading
                    ? null
                    : () => _accepterLivraison(livraison.id),
                icon:  const Icon(Icons.check_circle_outline, size: 18),
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
          ],
        ),
      ),
    );
  }

  Widget _etatVide() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.delivery_dining, size: 80, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text('Aucune mission disponible',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade400)),
          const SizedBox(height: 8),
          Text('Mise à jour automatique en cours...',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  Widget _statCard({
    required String   label,
    required String   valeur,
    required IconData icone,
    Color             couleurIcone = Colors.white,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icone, color: couleurIcone, size: 22),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(valeur,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 18)),
                Text(label,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _adresseLigne({
    required IconData icone,
    required Color    couleur,
    required String   texte,
    required String   label,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, color: couleur, size: 16),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 10, color: Colors.grey)),
            SizedBox(
              width: 260,
              child: Text(texte,
                  style: const TextStyle(
                      fontSize: 13, color: Colors.black87),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ],
    );
  }

  String _formatPrix(dynamic montant) {
    if (montant == null) return '0';
    final val = (montant as num).toInt();
    return val.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]} ',
    );
  }

  String _formatDate(DateTime date) {
    final now  = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours   < 24) return 'Il y a ${diff.inHours}h';
    return '${date.day}/${date.month}/${date.year}';
  }
}