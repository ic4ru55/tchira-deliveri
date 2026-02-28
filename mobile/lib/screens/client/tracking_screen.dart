import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/livraison_provider.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double>   _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync:    this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // ✅ Le provider a déjà appelé suivreLivraison() depuis home_client.dart
    // qui fait rejoindrelivraison() + _ecouterTempsReel() en interne
    // Le tracking screen n'a donc besoin de rien faire ici —
    // il observe juste le provider avec context.watch()
    // Quand le livreur envoie sa position → provider met à jour positionLivreur
    // → notifyListeners() → le widget se reconstruit automatiquement ✅
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider  = context.watch<LivraisonProvider>();
    final livraison = provider.livraisonActive;

    if (livraison == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D7377),
          leading: IconButton(
            icon:      const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Suivi', style: TextStyle(color: Colors.white)),
        ),
        body: const Center(child: Text('Aucune livraison active')),
      );
    }

    final position = livraison.positionLivreur;
    final hasGps   = position.lat != 0 || position.lng != 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D7377),
        elevation: 0,
        leading: IconButton(
          icon:      const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Suivi en temps réel',
              style: TextStyle(
                color: Colors.white, fontSize: 16,
                fontWeight: FontWeight.bold),
            ),
            Text(
              'Mise à jour automatique',
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
            _carteGPS(hasGps, position),
            const SizedBox(height: 16),

            _conteneur(
              titre: '📍 Itinéraire',
              child: Column(
                children: [
                  _lignItineraire(
                    icone: Icons.trip_origin, couleur: Colors.green,
                    label: 'Départ', adresse: livraison.adresseDepart,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 11),
                    child: Column(
                      children: List.generate(3, (_) => Container(
                        width: 2, height: 8,
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        color: Colors.grey.shade300,
                      )),
                    ),
                  ),
                  _lignItineraire(
                    icone: Icons.location_on, couleur: Colors.red,
                    label: 'Arrivée', adresse: livraison.adresseArrivee,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (livraison.livreur is Map)
              _conteneur(
                titre: '🚴 Votre livreur',
                child: Row(
                  children: [
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) => Transform.scale(
                        scale: _pulseAnimation.value, child: child),
                      child: Container(
                        width: 50, height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D7377),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: const Icon(
                          Icons.delivery_dining,
                          color: Colors.white, size: 28),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (livraison.livreur as Map)['nom'] ?? 'Livreur',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            (livraison.livreur as Map)['telephone'] ?? '',
                            style: const TextStyle(
                              color: Colors.grey, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 8, height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'En route vers vous',
                                style: TextStyle(
                                  color: Colors.green, fontSize: 12,
                                  fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.phone, color: Color(0xFF0D7377)),
                        onPressed: () async {
                          final tel = (livraison.livreur as Map)['telephone'] as String? ?? '';
                          if (tel.isEmpty) return;
                          final uri = Uri.parse('tel:$tel');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri);
                          } else if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Impossible d\'appeler $tel'),
                              backgroundColor: Colors.red));
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            if (hasGps)
              _conteneur(
                titre: '🛰️ Position en direct',
                child: Column(children: [
                  Row(children: [
                    Expanded(child: _infoTile(
                      icon: Icons.near_me, color: const Color(0xFF0D7377),
                      label: 'Coordonnées',
                      value: '${position.lat.toStringAsFixed(4)}, ${position.lng.toStringAsFixed(4)}')),
                    const SizedBox(width: 12),
                    Expanded(child: _infoTile(
                      icon: Icons.update, color: Colors.green,
                      label: 'Mise à jour',
                      value: 'Il y a < 10s')),
                  ]),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      const Icon(Icons.circle, color: Colors.green, size: 10),
                      const SizedBox(width: 8),
                      const Text('Livreur actif et en déplacement',
                          style: TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.w600)),
                    ])),
                ]),
              ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _carteStatut(String statut) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _couleurStatut(statut),
        borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_iconeStatut(statut), color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Statut de votre livraison',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text(_labelStatut(statut),
                  style: const TextStyle(
                    color: Colors.white, fontSize: 20,
                    fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _carteGPS(bool hasGps, dynamic position) {
    if (!kIsWeb && hasGps) {
      final livreurLatLng = LatLng(
        position.lat as double,
        position.lng as double,
      );
      return Container(
        width: double.infinity, height: 280,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8, offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: livreurLatLng, zoom: 15),
                markers: {
                  Marker(
                    markerId: const MarkerId('livreur'),
                    position: livreurLatLng,
                    infoWindow: const InfoWindow(title: 'Livreur'),
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueOrange),
                  ),
                },
                myLocationButtonEnabled: false,
                zoomControlsEnabled:     false,
                mapToolbarEnabled:       false,
              ),
              Positioned(
                top: 12, right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.circle, color: Colors.white, size: 8),
                      SizedBox(width: 4),
                      Text('LIVE',
                          style: TextStyle(
                            color: Colors.white, fontSize: 11,
                            fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Carte simulée — émulateur / Chrome / pas encore de GPS
    return Container(
      width: double.infinity, height: 220,
      decoration: BoxDecoration(
        color: const Color(0xFF1B3A6B),
        borderRadius: BorderRadius.circular(16)),
      child: Stack(
        children: [
          CustomPaint(
            size: const Size(double.infinity, 220),
            painter: _CartePainter(),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) => Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width:  60 * _pulseAnimation.value,
                        height: 60 * _pulseAnimation.value,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF97316)
                              .withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Container(
                        width: 44, height: 44,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF97316), shape: BoxShape.circle),
                        child: const Icon(
                          Icons.delivery_dining,
                          color: Colors.white, size: 24),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    hasGps
                        ? 'Livreur localisé'
                        : 'En attente de localisation...',
                    style: TextStyle(
                      color: hasGps
                          ? const Color(0xFF0D7377)
                          : Colors.grey,
                      fontWeight: FontWeight.w600, fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 12, left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.map, color: Colors.white70, size: 14),
                  SizedBox(width: 4),
                  Text('Bobo-Dioulasso',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ),
          Positioned(
            top: 12, right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF97316),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.circle, color: Colors.white, size: 8),
                  SizedBox(width: 4),
                  Text('LIVE',
                      style: TextStyle(
                        color: Colors.white, fontSize: 11,
                        fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _conteneur({required String titre, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titre,
              style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15,
                color: Color(0xFF0D7377))),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _lignItineraire({
    required IconData icone,
    required Color    couleur,
    required String   label,
    required String   adresse,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, color: couleur, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 11)),
              Text(adresse,
                  style: const TextStyle(
                    fontSize: 14, color: Colors.black87,
                    fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoTile({required IconData icon, required Color color, required String label, required String value}) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, size: 13, color: color), const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500))]),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
            overflow: TextOverflow.ellipsis),
      ]));


  Color _couleurStatut(String statut) {
    switch (statut) {
      case 'en_attente':   return Colors.orange;
      case 'en_cours':     return const Color(0xFF0D7377);
      case 'en_livraison': return Colors.purple;
      case 'livre':        return Colors.green;
      default:             return Colors.grey;
    }
  }

  String _labelStatut(String statut) {
    switch (statut) {
      case 'en_attente':   return '⏳ En attente';
      case 'en_cours':     return '🔄 Livreur en route';
      case 'en_livraison': return '🚚 En livraison';
      case 'livre':        return '✅ Livré !';
      default:             return statut;
    }
  }

  IconData _iconeStatut(String statut) {
    switch (statut) {
      case 'en_attente':   return Icons.hourglass_top;
      case 'en_cours':     return Icons.delivery_dining;
      case 'en_livraison': return Icons.local_shipping;
      case 'livre':        return Icons.check_circle;
      default:             return Icons.info;
    }
  }
}

class _CartePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color       = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    final routePaint = Paint()
      ..color       = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = 3
      ..strokeCap   = StrokeCap.round;
    canvas.drawLine(
      Offset(0, size.height * 0.4),
      Offset(size.width, size.height * 0.4), routePaint);
    canvas.drawLine(
      Offset(size.width * 0.3, 0),
      Offset(size.width * 0.3, size.height), routePaint);
    canvas.drawLine(
      Offset(size.width * 0.7, 0),
      Offset(size.width * 0.7, size.height), routePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}