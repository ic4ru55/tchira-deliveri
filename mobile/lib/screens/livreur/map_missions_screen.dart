// ═══════════════════════════════════════════════════════════════════
// PHASE 28A — Vue carte des missions disponibles (livreur)
// Fichier : lib/screens/livreur/map_missions_screen.dart
//
// POURQUOI :
//   La liste seule ne donne aucune info géographique.
//   Le livreur ne sait pas quelle mission est proche de lui.
//   Cette vue carte lui permet de voir tous les points sur une carte
//   et d'accepter directement en tappant un pin.
//
// DÉPENDANCES DÉJÀ DANS pubspec.yaml :
//   google_maps_flutter, geolocator
// ═══════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../providers/livraison_provider.dart';
import '../../models/livraison.dart';
import '../livreur/mission_screen.dart';

class MapMissionsScreen extends StatefulWidget {
  const MapMissionsScreen({super.key});
  @override State<MapMissionsScreen> createState() => _MapMissionsScreenState();
}

class _MapMissionsScreenState extends State<MapMissionsScreen> {
  GoogleMapController? _mapCtrl;
  Livraison?           _selected;   // mission tapée sur la carte
  bool                 _loading = false;
  LatLng?              _myPos;

  static const _teal  = Color(0xFF0D7377);
  static const _navy  = Color(0xFF1B3A6B);
  static const _green = Color(0xFF16A34A);

  // Style carte sombre personnalisé (JSON réduit)
  static const String _mapStyle = '''[
    {"featureType":"water","stylers":[{"color":"#c9d3dc"}]},
    {"featureType":"landscape","stylers":[{"color":"#f2f6f8"}]},
    {"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
    {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
    {"featureType":"poi","stylers":[{"visibility":"off"}]},
    {"featureType":"transit","stylers":[{"visibility":"off"}]}
  ]''';

  @override
  void initState() {
    super.initState();
    _locateMe();
  }

  Future<void> _locateMe() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high));
      if (!mounted) return;
      setState(() => _myPos = LatLng(pos.latitude, pos.longitude));
      _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(
          _myPos!, 14));
    } catch (_) {}
  }

  Set<Marker> _buildMarkers(List<Livraison> livs) {
    final markers = <Marker>{};

    // Ma position
    if (_myPos != null) {
      markers.add(Marker(
        markerId: const MarkerId('moi'),
        position: _myPos!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'Vous'),
        zIndexInt: 2,
      ));
    }

    // Missions disponibles
    for (final liv in livs) {
      final lat = liv.coordonneesDepart?.lat ?? 0.0;
      final lng = liv.coordonneesDepart?.lng ?? 0.0;
      if (lat == 0 && lng == 0) continue;

      final isSelected = _selected?.id == liv.id;
      markers.add(Marker(
        markerId: MarkerId(liv.id),
        position: LatLng(lat, lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          isSelected ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueOrange),
        infoWindow: InfoWindow(
          title: '${_fmt(liv.prix)} FCFA',
          snippet: liv.adresseDepart),
        zIndexInt: isSelected ? 2 : 1,
        onTap: () => setState(() => _selected = liv),
      ));
    }
    return markers;
  }

  Future<void> _accepter(Livraison liv, LivraisonProvider prov) async {
    setState(() => _loading = true);
    final dynamic ret = await prov.accepterLivraison(liv.id);
    if (!mounted) return;
    setState(() => _loading = false);
    bool ok;
    String msg = '❌ Mission non disponible';
    if (ret is bool)     { ok = ret; }
    else if (ret is Map) { ok = ret['succes'] == true; msg = ret['message'] as String? ?? msg; }
    else                 { ok = false; }

    if (ok) {
      await GpsService.instance.demarrer(liv.id);
      if (!mounted) return;
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const MissionScreen()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg), backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<LivraisonProvider>();
    final livs = prov.livraisonsDisponibles;

    return Scaffold(
      body: Stack(children: [
        // ── Google Map ──────────────────────────────────────────────────────
        GoogleMap(
          onMapCreated: (ctrl) {
            _mapCtrl = ctrl;
            // ✅ style appliqué via GoogleMap.style (API moderne)
            if (_myPos != null) {
              ctrl.animateCamera(
                  CameraUpdate.newLatLngZoom(_myPos!, 14));
            } else if (livs.isNotEmpty) {
              final lat = livs.first.coordonneesDepart?.lat ?? 12.36;
              final lng = livs.first.coordonneesDepart?.lng ?? -1.53;
              ctrl.animateCamera(
                  CameraUpdate.newLatLngZoom(LatLng(lat, lng), 13));
            }
          },
          initialCameraPosition: CameraPosition(
            target: _myPos ?? const LatLng(12.36, -1.53), // Ouaga par défaut
            zoom: 13),
          style: _mapStyle,  // ✅ API moderne (GoogleMap.style)
          markers: _buildMarkers(livs),
          myLocationEnabled:       false,
          zoomControlsEnabled:     false,
          mapToolbarEnabled:       false,
          myLocationButtonEnabled: false,
          onTap: (_) => setState(() => _selected = null),
        ),

        // ── Header flottant ─────────────────────────────────────────────────
        Positioned(top: 0, left: 0, right: 0,
          child: SafeArea(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 8)]),
                  child: const Icon(Icons.arrow_back, color: _navy, size: 20))),
              const SizedBox(width: 10),
              Expanded(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8)]),
                child: Row(children: [
                  const Icon(Icons.location_on, color: _teal, size: 16),
                  const SizedBox(width: 6),
                  Text('${livs.length} mission${livs.length != 1 ? "s" : ""} sur la carte',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13, color: _navy)),
                  const Spacer(),
                  if (prov.isLoading)
                    const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: _teal)),
                ]))),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _locateMe,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _teal,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(
                        color: _teal.withValues(alpha: 0.35), blurRadius: 8)]),
                  child: const Icon(Icons.my_location, color: Colors.white, size: 20))),
            ]),
          ))),

        // ── Légende bas ─────────────────────────────────────────────────────
        if (_selected == null)
          Positioned(bottom: 24, left: 16, right: 16,
            child: _legendeCard(livs.length)),

        // ── Carte mini de la mission sélectionnée ───────────────────────────
        if (_selected != null)
          Positioned(bottom: 0, left: 0, right: 0,
            child: _carteSelection(_selected!, prov)),
      ]),
    );
  }

  Widget _legendeCard(int nb) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 12, offset: const Offset(0, 4))]),
    child: Row(children: [
      Container(width: 10, height: 10,
          decoration: const BoxDecoration(
              color: Colors.orange, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      const Text('Missions dispo', style: TextStyle(fontSize: 12, color: Colors.grey)),
      const SizedBox(width: 16),
      Container(width: 10, height: 10,
          decoration: const BoxDecoration(
              color: Colors.blue, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      const Text('Ma position', style: TextStyle(fontSize: 12, color: Colors.grey)),
      const Spacer(),
      Text('Tap = détails', style: TextStyle(
          fontSize: 11, color: Colors.grey.shade400,
          fontStyle: FontStyle.italic)),
    ]));

  Widget _carteSelection(Livraison liv, LivraisonProvider prov) => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, spreadRadius: 2)]),
    child: Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20,
          MediaQuery.of(context).padding.bottom + 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Poignée
        Center(child: Container(width: 36, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 14),
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_teal, _navy]),
              borderRadius: BorderRadius.circular(20)),
            child: Text('${_fmt(liv.prix)} FCFA',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15))),
          const SizedBox(width: 10),
          Expanded(child: Text(liv.client?['nom'] ?? 'Client',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
          GestureDetector(
            onTap: () => setState(() => _selected = null),
            child: const Icon(Icons.close, color: Colors.grey)),
        ]),
        const SizedBox(height: 12),
        _ligneAdresse(Icons.trip_origin, _green, 'Départ', liv.adresseDepart),
        const SizedBox(height: 6),
        _ligneAdresse(Icons.location_on, Colors.red, 'Arrivée', liv.adresseArrivee),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, height: 50,
          child: _loading
            ? const Center(child: CircularProgressIndicator(color: _teal))
            : ElevatedButton.icon(
                onPressed: () => _accepter(liv, prov),
                icon: const Icon(Icons.check_circle_outline, size: 20),
                label: const Text('Accepter cette mission',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green, foregroundColor: Colors.white,
                  elevation: 3, shadowColor: _green.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))))),
      ])));

  Widget _ligneAdresse(IconData icon, Color color, String label, String adresse) =>
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(
            fontSize: 10, color: Colors.grey.shade400, fontWeight: FontWeight.w500)),
        Text(adresse, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            maxLines: 2, overflow: TextOverflow.ellipsis),
      ])),
    ]);

  String _fmt(dynamic m) {
    if (m == null) return '0';
    final v = (m as num).toInt();
    return v.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (x) => '${x[1]} ');
  }
}