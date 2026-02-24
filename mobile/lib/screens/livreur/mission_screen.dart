import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/livraison_provider.dart';
import '../../services/gps_service.dart';
import 'home_livreur.dart';

// ✅ MissionScreen ne gère PLUS le GPS directement.
// GpsService.instance est un singleton qui survit à la navigation.
// Quand le livreur revient sur cet écran, le GPS est toujours actif.
// initState() démarre automatiquement le GPS si ce n'est pas déjà fait.

class MissionScreen extends StatefulWidget {
  const MissionScreen({super.key});

  @override
  State<MissionScreen> createState() => _MissionScreenState();
}

class _MissionScreenState extends State<MissionScreen> {

  // Lecture seule de l'état GPS — le service gère tout
  bool get _gpsActif => GpsService.instance.estActif;

  @override
  void initState() {
    super.initState();
    // ✅ Démarrage automatique du GPS à l'ouverture de l'écran
    // Si déjà actif pour cette livraison → GpsService ignore l'appel
    // Si revient en arrière et revient → GPS toujours actif, rien ne change
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _demarrerGpsAuto();
    });
  }

  // Démarre automatiquement sans interaction livreur
  Future<void> _demarrerGpsAuto() async {
    final livraison = context.read<LivraisonProvider>().livraisonActive;
    if (livraison == null) return;

    final erreur = await GpsService.instance.demarrer(livraison.id);
    if (!mounted) return;

    if (erreur != null) {
      // GPS refusé ou désactivé → on affiche le message mais pas de blocage
      _snack(erreur, Colors.orange);
    }

    setState(() {}); // rafraîchir l'indicateur GPS
  }

  Future<void> _arreterGps() async {
    await GpsService.instance.arreter();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _changerStatut(String statut) async {
    final provider  = context.read<LivraisonProvider>();
    final navigator = Navigator.of(context);
    final livraison = provider.livraisonActive;
    if (livraison == null) return;

    final succes = await provider.mettreAJourStatut(livraison.id, statut);
    if (!mounted) return;

    if (succes) {
      _snack(
        statut == 'en_livraison' ? '🚚 Livraison démarrée !' : '✅ Livraison terminée !',
        Colors.green,
      );
      if (statut == 'livre') {
        // ✅ Arrêter le GPS quand la livraison est terminée
        await GpsService.instance.arreter();
        provider.reinitialiserLivraisonActive();
        if (!mounted) return;
        navigator.pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeLibreur()),
        );
      }
    } else {
      _snack('❌ Erreur mise à jour statut', Colors.red);
    }
  }

  void _snack(String msg, Color couleur) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: couleur),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider  = context.watch<LivraisonProvider>();
    final livraison = provider.livraisonActive;

    if (livraison == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF1B3A6B),
          title: const Text('Mission', style: TextStyle(color: Colors.white)),
        ),
        body: const Center(child: Text('Aucune mission active')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B3A6B),
        elevation: 0,
        leading: IconButton(
          icon:      const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
          // ✅ Retour en arrière → GPS continue à tourner dans GpsService
          // Pas d'arrêt ici — le livreur peut revenir et le GPS est toujours actif
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mission en cours',
                style: TextStyle(
                    color: Colors.white, fontSize: 16,
                    fontWeight: FontWeight.bold)),
            Text('Gérez votre livraison',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          _carteStatut(livraison.statut),
          const SizedBox(height: 16),

          // ── Client ───────────────────────────────────────────────────────
          _conteneur(
            titre: '👤 Client',
            child: Row(children: [
              const CircleAvatar(
                radius:          24,
                backgroundColor: Color(0xFFDBEAFE),
                child: Icon(Icons.person, color: Color(0xFF2563EB), size: 26),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(livraison.client?['nom'] ?? 'Client',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                Text(livraison.client?['telephone'] ?? '',
                    style: const TextStyle(color: Colors.grey, fontSize: 14)),
              ]),
            ]),
          ),
          const SizedBox(height: 12),

          // ── Détails ───────────────────────────────────────────────────────
          _conteneur(
            titre: '📦 Détails de la livraison',
            child: Column(children: [
              _lignInfo(icone: Icons.trip_origin, couleur: Colors.green,
                  label: 'Départ', valeur: livraison.adresseDepart),
              const SizedBox(height: 12),
              _lignInfo(icone: Icons.location_on, couleur: Colors.red,
                  label: 'Arrivée', valeur: livraison.adresseArrivee),
              if (livraison.descriptionColis.isNotEmpty) ...[
                const SizedBox(height: 12),
                _lignInfo(icone: Icons.inventory_2_outlined, couleur: Colors.grey,
                    label: 'Colis', valeur: livraison.descriptionColis),
              ],
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Rémunération',
                      style: TextStyle(color: Colors.grey, fontSize: 14)),
                  Text('${_formatPrix(livraison.prix)} FCFA',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18, color: Color(0xFF16A34A))),
                ],
              ),
            ]),
          ),
          const SizedBox(height: 12),

          // ── GPS ───────────────────────────────────────────────────────────
          _conteneur(
            titre: '📍 Partage de position',
            child: Column(children: [
              Row(children: [
                // ✅ Indicateur animé quand GPS actif
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  width:  10, height: 10,
                  decoration: BoxDecoration(
                    color: _gpsActif ? Colors.green : Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  _gpsActif
                      ? 'Position GPS partagée en temps réel'
                      : 'GPS non actif — activation automatique en cours...',
                  style: TextStyle(
                    color:    _gpsActif ? Colors.green : Colors.grey,
                    fontSize: 13,
                  ),
                )),
              ]),
              const SizedBox(height: 12),

              // ✅ Le GPS démarre auto — bouton visible uniquement si inactif
              // pour permettre de relancer manuellement en cas d'erreur
              if (!_gpsActif)
                SizedBox(
                  width: double.infinity, height: 46,
                  child: ElevatedButton.icon(
                    onPressed: _demarrerGpsAuto,
                    icon:  const Icon(Icons.my_location, size: 18),
                    label: const Text('Activer le GPS manuellement'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),

              // Bouton arrêter visible seulement si GPS actif
              if (_gpsActif)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _arreterGps,
                    icon:  const Icon(Icons.stop_circle_outlined,
                        color: Colors.red, size: 16),
                    label: const Text('Arrêter le GPS',
                        style: TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 24),

          _boutonsAction(livraison.statut),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  // ─── Widgets ──────────────────────────────────────────────────────────────
  Widget _carteStatut(String statut) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _couleurStatut(statut),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        Icon(_iconeStatut(statut), color: Colors.white, size: 32),
        const SizedBox(width: 16),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Statut actuel',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          Text(_labelStatut(statut),
              style: const TextStyle(
                  color: Colors.white, fontSize: 20,
                  fontWeight: FontWeight.bold)),
        ]),
      ]),
    );
  }

  Widget _boutonsAction(String statut) {
    if (statut == 'en_cours') {
      return SizedBox(
        width: double.infinity, height: 52,
        child: ElevatedButton.icon(
          onPressed: () => _changerStatut('en_livraison'),
          icon:  const Icon(Icons.local_shipping, size: 20),
          label: const Text('Démarrer la livraison',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
    }
    if (statut == 'en_livraison') {
      return SizedBox(
        width: double.infinity, height: 52,
        child: ElevatedButton.icon(
          onPressed: () => _changerStatut('livre'),
          icon:  const Icon(Icons.check_circle, size: 20),
          label: const Text('Confirmer la livraison',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF16A34A),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _conteneur({required String titre, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(titre, style: const TextStyle(
            fontWeight: FontWeight.bold, fontSize: 15,
            color: Color(0xFF1B3A6B))),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }

  Widget _lignInfo({required IconData icone, required Color couleur,
      required String label, required String valeur}) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icone, color: couleur, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        Text(valeur, style: const TextStyle(fontSize: 14, color: Colors.black87)),
      ])),
    ]);
  }

  String _formatPrix(dynamic montant) {
    final val = (montant as num).toInt();
    return val.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
  }

  Color _couleurStatut(String statut) {
    switch (statut) {
      case 'en_cours':     return const Color(0xFF2563EB);
      case 'en_livraison': return Colors.purple;
      case 'livre':        return const Color(0xFF16A34A);
      default:             return Colors.grey;
    }
  }

  String _labelStatut(String statut) {
    switch (statut) {
      case 'en_cours':     return 'En cours';
      case 'en_livraison': return 'En livraison';
      case 'livre':        return 'Livré ✅';
      default:             return statut;
    }
  }

  IconData _iconeStatut(String statut) {
    switch (statut) {
      case 'en_cours':     return Icons.hourglass_top;
      case 'en_livraison': return Icons.local_shipping;
      case 'livre':        return Icons.check_circle;
      default:             return Icons.info;
    }
  }
}