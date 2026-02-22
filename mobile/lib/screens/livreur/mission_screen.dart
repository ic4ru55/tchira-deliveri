import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../providers/livraison_provider.dart';
import '../../services/socket_service.dart';
import 'home_livreur.dart';

class MissionScreen extends StatefulWidget {
  const MissionScreen({super.key});

  @override
  State<MissionScreen> createState() => _MissionScreenState();
}

class _MissionScreenState extends State<MissionScreen> {
  bool                       _envoiPosition = false;
  StreamSubscription<Position>? _gpsStream;

  @override
  void dispose() {
    // ✅ Toujours annuler le stream GPS quand on quitte l'écran
    // sinon il continue de tourner en arrière-plan et vide la batterie
    _gpsStream?.cancel();
    super.dispose();
  }

  Future<void> _demarrerEnvoiPosition() async {
  // ✅ Capturer AVANT tout await
  final provider  = context.read<LivraisonProvider>();
  final livraison = provider.livraisonActive;
  if (livraison == null) return;

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      // ✅ mounted check puis utilisation du context
      if (!mounted) return;
      _snack('Permission GPS refusée', Colors.red);
      return;
    }
  }
  if (permission == LocationPermission.deniedForever) {
    if (!mounted) return;
    _snack('GPS bloqué — active-le dans les paramètres', Colors.red);
    return;
  }

  if (!mounted) return;
  setState(() => _envoiPosition = true);

  if (kIsWeb) {
    _demarrerGpsWeb(livraison.id);
    return;
  }

  const settings = LocationSettings(
    accuracy:       LocationAccuracy.high,
    distanceFilter: 10,
  );

  _gpsStream = Geolocator.getPositionStream(
    locationSettings: settings,
  ).listen((Position position) {
    if (!mounted) return;
    SocketService.envoyerPosition(
      livraisonId: livraison.id,
      lat:         position.latitude,
      lng:         position.longitude,
    );
  });
}

  // ── GPS Web : Timer toutes les 10s ────────────────────────────────────────
  // Sur Chrome, getPositionStream n'est pas fiable.
  // On récupère manuellement la position toutes les 10 secondes.
  Timer? _timerWeb;

  void _demarrerGpsWeb(String livraisonId) {
    _timerWeb = Timer.periodic(
      const Duration(seconds: 10),
      (_) async {
        if (!mounted) {
          _timerWeb?.cancel();
          return;
        }
        try {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          );
          SocketService.envoyerPosition(
            livraisonId: livraisonId,
            lat:         position.latitude,
            lng:         position.longitude,
          );
        } catch (_) {
          // Silencieux — si le GPS échoue on réessaie au prochain tick
        }
      },
    );
  }

  Future<void> _arreterEnvoiPosition() async {
    _gpsStream?.cancel();
    _timerWeb?.cancel();
    _gpsStream = null;
    _timerWeb  = null;
    setState(() => _envoiPosition = false);
  }

  Future<void> _changerStatut(String statut) async {
  // ✅ Capturer provider ET navigator AVANT tout await
  final provider  = context.read<LivraisonProvider>();
  final navigator = Navigator.of(context);
  final livraison = provider.livraisonActive;
  if (livraison == null) return;

  final succes = await provider.mettreAJourStatut(livraison.id, statut);

  if (!mounted) return;

  if (succes) {
    _snack(
      statut == 'en_livraison'
          ? '🚚 Livraison démarrée !'
          : '✅ Livraison terminée !',
      Colors.green,
    );

    if (statut == 'livre') {
      await _arreterEnvoiPosition();
      provider.reinitialiserLivraisonActive();
      // ✅ On utilise navigator capturé avant l'await
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
          title: const Text(
            'Mission',
            style: TextStyle(color: Colors.white),
          ),
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
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mission en cours',
              style: TextStyle(
                color:      Colors.white,
                fontSize:   16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Gérez votre livraison',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _carteStatut(livraison.statut),
            const SizedBox(height: 16),

            _conteneur(
              titre: '👤 Client',
              child: Row(
                children: [
                  const CircleAvatar(
                    radius:          24,
                    backgroundColor: Color(0xFFDBEAFE),
                    child: Icon(
                      Icons.person,
                      color: Color(0xFF2563EB),
                      size:  26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        livraison.client?['nom'] ?? 'Client',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize:   16,
                        ),
                      ),
                      Text(
                        livraison.client?['telephone'] ?? '',
                        style: const TextStyle(
                          color:    Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            _conteneur(
              titre: '📦 Détails de la livraison',
              child: Column(
                children: [
                  _lignInfo(
                    icone:   Icons.trip_origin,
                    couleur: Colors.green,
                    label:   'Départ',
                    valeur:  livraison.adresseDepart,
                  ),
                  const SizedBox(height: 12),
                  _lignInfo(
                    icone:   Icons.location_on,
                    couleur: Colors.red,
                    label:   'Arrivée',
                    valeur:  livraison.adresseArrivee,
                  ),
                  if (livraison.descriptionColis.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _lignInfo(
                      icone:   Icons.inventory_2_outlined,
                      couleur: Colors.grey,
                      label:   'Colis',
                      valeur:  livraison.descriptionColis,
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Rémunération',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      Text(
                        '${_formatPrix(livraison.prix)} FCFA',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize:   18,
                          color:      Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── GPS ──────────────────────────────────────────────────
            _conteneur(
              titre: '📍 Partage de position',
              child: Column(
                children: [
                  // ✅ Indicateur visuel de l'état du GPS
                  Row(
                    children: [
                      Container(
                        width:  10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _envoiPosition
                              ? Colors.green
                              : Colors.grey.shade300,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _envoiPosition
                              ? 'Position GPS en cours de partage avec le client'
                              : 'Partagez votre position pour que le client puisse vous suivre',
                          style: TextStyle(
                            color:    _envoiPosition
                                ? Colors.green
                                : Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Bouton démarrer
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: ElevatedButton.icon(
                            onPressed: _envoiPosition
                                ? null
                                : _demarrerEnvoiPosition,
                            icon: _envoiPosition
                                ? const SizedBox(
                                    width:  16,
                                    height: 16,
                                    child:  CircularProgressIndicator(
                                      color:       Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.my_location, size: 18),
                            label: Text(
                              _envoiPosition
                                  ? 'GPS actif'
                                  : 'Démarrer GPS',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // ✅ Bouton arrêter — nouveau
                      if (_envoiPosition) ...[
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 46,
                          child: OutlinedButton.icon(
                            onPressed: _arreterEnvoiPosition,
                            icon: const Icon(
                              Icons.stop_circle_outlined,
                              size: 18,
                            ),
                            label: const Text('Arrêter'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _boutonsAction(livraison.statut),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _carteStatut(String statut) {
    final couleur = _couleurStatut(statut);
    final label   = _labelStatut(statut);
    final icone   = _iconeStatut(statut);

    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:        couleur,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icone, color: Colors.white, size: 32),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Statut actuel',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                label,
                style: const TextStyle(
                  color:      Colors.white,
                  fontSize:   20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _boutonsAction(String statut) {
    if (statut == 'en_cours') {
      return SizedBox(
        width:  double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: () => _changerStatut('en_livraison'),
          icon:  const Icon(Icons.local_shipping, size: 20),
          label: const Text(
            'Démarrer la livraison',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    if (statut == 'en_livraison') {
      return SizedBox(
        width:  double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: () => _changerStatut('livre'),
          icon:  const Icon(Icons.check_circle, size: 20),
          label: const Text(
            'Confirmer la livraison',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF16A34A),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _conteneur({required String titre, required Widget child}) {
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titre,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize:   15,
              color:      Color(0xFF1B3A6B),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _lignInfo({
    required IconData icone,
    required Color    couleur,
    required String   label,
    required String   valeur,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, color: couleur, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
              Text(
                valeur,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatPrix(dynamic montant) {
    final val = (montant as num).toInt();
    return val.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]} ',
    );
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