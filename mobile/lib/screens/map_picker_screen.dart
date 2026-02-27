import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ─── Clé API Google Maps ───────────────────────────────────────────────────────
// Même clé que celle dans AndroidManifest.xml / local.properties
// On la lit via une constante de compilation pour ne pas la harcoder ici
// Si tu as une clé différente pour Places, remplace la valeur ci-dessous
import '../config/api_config.dart';

class MapPickerScreen extends StatefulWidget {
  final String titre;
  final LatLng? positionInitiale;

  const MapPickerScreen({
    super.key,
    required this.titre,
    this.positionInitiale,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  GoogleMapController? _mapCtrl;

  static const LatLng _bobo = LatLng(11.1771, -4.2979);

  late LatLng _positionSelectionnee;
  String      _adresse           = 'Appuyez sur la carte pour choisir';
  bool        _chargement        = false;
  bool        _gpsEnCours        = false;

  // ─── Recherche de lieu ──────────────────────────────────────────────────
  final _rechercheCtrl     = TextEditingController();
  final _rechercheFocus    = FocusNode();
  bool              _rechercheVisible  = false;
  bool              _rechercheEnCours  = false;
  List<_Suggestion> _suggestions       = [];
  Timer?            _debounceTimer;

  @override
  void initState() {
    super.initState();
    _positionSelectionnee = widget.positionInitiale ?? _bobo;
    if (widget.positionInitiale == null) {
      _recupererGPS();
    } else {
      _geocoderPosition(_positionSelectionnee);
    }
  }

  @override
  void dispose() {
    _mapCtrl?.dispose();
    _rechercheCtrl.dispose();
    _rechercheFocus.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // ─── Géocoder une position → adresse ────────────────────────────────────
  Future<void> _geocoderPosition(LatLng pos) async {
    setState(() => _chargement = true);
    try {
      if (kIsWeb) {
        setState(() => _adresse = '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}');
        return;
      }
      final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude)
          .timeout(const Duration(seconds: 5));
      if (!mounted) return;
      if (placemarks.isNotEmpty) {
        final p   = placemarks.first;
        final adr = [p.street, p.subLocality, p.locality]
            .where((e) => e != null && e.isNotEmpty).join(', ');
        setState(() => _adresse = adr.isNotEmpty
            ? adr
            : '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _adresse = '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}');
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  // ─── GPS ─────────────────────────────────────────────────────────────────
  Future<void> _recupererGPS() async {
    setState(() => _gpsEnCours = true);
    try {
      final serviceActif = await Geolocator.isLocationServiceEnabled();
      if (!serviceActif) { if (mounted) setState(() => _gpsEnCours = false); return; }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) setState(() => _gpsEnCours = false); return;
      }

      final pos    = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      if (!mounted) return;

      final latLng = LatLng(pos.latitude, pos.longitude);
      setState(() => _positionSelectionnee = latLng);
      _mapCtrl?.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(target: latLng, zoom: 16)));
      await _geocoderPosition(latLng);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _gpsEnCours = false);
    }
  }

  void _onTap(LatLng pos) {
    // Fermer la recherche si ouverte
    if (_rechercheVisible) {
      setState(() { _rechercheVisible = false; _suggestions = []; });
      _rechercheFocus.unfocus();
    }
    setState(() => _positionSelectionnee = pos);
    _geocoderPosition(pos);
  }

  void _onCameraIdle() {
    _mapCtrl?.getLatLng(ScreenCoordinate(
      x: MediaQuery.of(context).size.width ~/ 2,
      y: MediaQuery.of(context).size.height ~/ 2,
    )).then((pos) {
      if (!mounted) return;
      setState(() => _positionSelectionnee = pos);
      _geocoderPosition(pos);
    }).catchError((_) {});
  }

  // ─── RECHERCHE avec l'API Geocoding de Google ─────────────────────────────
  // On utilise l'API Geocoding (déjà activée avec la clé Maps)
  // Pas besoin d'activer Places API séparément
  void _onRechercheChanged(String texte) {
    _debounceTimer?.cancel();
    if (texte.trim().length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _rechercherLieux(texte.trim());
    });
  }

  Future<void> _rechercherLieux(String query) async {
    setState(() => _rechercheEnCours = true);
    try {
      // Geocoding API — même clé que Maps, pas de Places nécessaire
      final encodedQuery = Uri.encodeComponent('$query, Burkina Faso');
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?address=$encodedQuery'
        '&key=${ApiConfig.googleMapsKey}'
        '&region=bf'
        '&language=fr',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 8));
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final results = data['results'] as List? ?? [];

        setState(() {
          _suggestions = results.take(5).map((r) {
            final loc = r['geometry']['location'];
            return _Suggestion(
              nom:       r['formatted_address'] as String,
              position:  LatLng((loc['lat'] as num).toDouble(), (loc['lng'] as num).toDouble()),
            );
          }).toList();
        });
      }
    } catch (_) {
      // Silencieux — la carte reste utilisable
    } finally {
      if (mounted) setState(() => _rechercheEnCours = false);
    }
  }

  void _choisirSuggestion(_Suggestion s) {
    setState(() {
      _positionSelectionnee = s.position;
      _adresse              = s.nom;
      _suggestions          = [];
      _rechercheVisible     = false;
      _rechercheCtrl.clear();
    });
    _rechercheFocus.unfocus();
    _mapCtrl?.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(target: s.position, zoom: 16)));
  }

  void _confirmer() {
    Navigator.pop(context, MapPickerResult(
      position: _positionSelectionnee,
      adresse:  _adresse,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final estDepart = widget.titre.toLowerCase().contains('départ') ||
                      widget.titre.toLowerCase().contains('depart');

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [

        // ─── Carte ────────────────────────────────────────────────────────
        GoogleMap(
          initialCameraPosition: CameraPosition(target: _positionSelectionnee, zoom: 15),
          onMapCreated: (ctrl) { _mapCtrl = ctrl; },
          onTap: _onTap,
          onCameraIdle: _onCameraIdle,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          markers: {
            Marker(
              markerId: const MarkerId('selection'),
              position: _positionSelectionnee,
              draggable: true,
              onDragEnd: (pos) {
                setState(() => _positionSelectionnee = pos);
                _geocoderPosition(pos);
              },
              icon: BitmapDescriptor.defaultMarkerWithHue(
                estDepart ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed),
            ),
          },
        ),

        // ─── AppBar + Barre de recherche ──────────────────────────────────
        Positioned(top: 0, left: 0, right: 0, child:
          Container(
            padding: EdgeInsets.fromLTRB(8, MediaQuery.of(context).padding.top + 8, 8, 8),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.black87, Colors.transparent]),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Ligne titre + GPS
              Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context)),
                const SizedBox(width: 4),
                Expanded(child: Text(widget.titre,
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold))),
                // GPS
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D7377), borderRadius: BorderRadius.circular(12)),
                  child: _gpsEnCours
                      ? const Padding(padding: EdgeInsets.all(12),
                          child: SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                      : IconButton(
                          icon: const Icon(Icons.my_location, color: Colors.white),
                          onPressed: _recupererGPS),
                ),
                const SizedBox(width: 8),
                // Bouton loupe — ouvrir/fermer la recherche
                Container(
                  decoration: BoxDecoration(
                    color: _rechercheVisible
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12)),
                  child: IconButton(
                    icon: Icon(
                      _rechercheVisible ? Icons.close : Icons.search,
                      color: _rechercheVisible ? const Color(0xFF0D7377) : Colors.white),
                    onPressed: () {
                      setState(() {
                        _rechercheVisible = !_rechercheVisible;
                        _suggestions      = [];
                        _rechercheCtrl.clear();
                      });
                      if (_rechercheVisible) {
                        Future.delayed(const Duration(milliseconds: 100), () => _rechercheFocus.requestFocus());
                      } else {
                        _rechercheFocus.unfocus();
                      }
                    },
                  ),
                ),
              ]),

              // Barre de recherche (visible si activée)
              if (_rechercheVisible) ...[
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8)],
                  ),
                  child: TextField(
                    controller:   _rechercheCtrl,
                    focusNode:    _rechercheFocus,
                    onChanged:    _onRechercheChanged,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText:    'Rechercher un lieu, quartier...',
                      hintStyle:   const TextStyle(color: Colors.grey, fontSize: 13),
                      prefixIcon:  _rechercheEnCours
                          ? const Padding(padding: EdgeInsets.all(12),
                              child: SizedBox(width: 20, height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0D7377))))
                          : const Icon(Icons.search, color: Color(0xFF0D7377)),
                      border:      InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),

                // Liste des suggestions
                if (_suggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8)],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: _suggestions.asMap().entries.map((entry) {
                        final i = entry.key;
                        final s = entry.value;
                        return Column(children: [
                          ListTile(
                            dense: true,
                            leading: Icon(
                              Icons.location_on,
                              color: estDepart ? Colors.green : Colors.red,
                              size: 20),
                            title: Text(s.nom,
                                style: const TextStyle(fontSize: 13),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            onTap: () => _choisirSuggestion(s),
                          ),
                          if (i < _suggestions.length - 1)
                            const Divider(height: 1, indent: 48),
                        ]);
                      }).toList(),
                    ),
                  ),
              ],
            ]),
          )),

        // ─── Panneau bas : adresse + confirmer ───────────────────────────
        Positioned(bottom: 0, left: 0, right: 0, child:
          Container(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).padding.bottom),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24), topRight: Radius.circular(24)),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, -4))],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Icon(
                  estDepart ? Icons.trip_origin : Icons.location_on,
                  color: estDepart ? Colors.green : Colors.red,
                  size: 22),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Adresse sélectionnée',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                  _chargement
                      ? const SizedBox(height: 16, width: 120,
                          child: LinearProgressIndicator(color: Color(0xFF0D7377)))
                      : Text(_adresse,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                ])),
              ]),
              const SizedBox(height: 6),
              Text('📌 Tap sur la carte, déplace le marqueur ou utilise la recherche 🔍',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, height: 52,
                child: ElevatedButton.icon(
                  onPressed: _chargement ? null : _confirmer,
                  icon: const Icon(Icons.check_circle_outline, size: 20),
                  label: const Text('Confirmer ce point',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D7377),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                )),
            ]),
          )),
      ]),
    );
  }
}

// ─── Modèles ──────────────────────────────────────────────────────────────────
class MapPickerResult {
  final LatLng position;
  final String adresse;
  const MapPickerResult({required this.position, required this.adresse});
}

class _Suggestion {
  final String nom;
  final LatLng position;
  const _Suggestion({required this.nom, required this.position});
}