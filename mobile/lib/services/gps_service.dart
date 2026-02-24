import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'socket_service.dart';

// ✅ SERVICE GPS SINGLETON
//
// Problème précédent : le stream GPS était dans le State de MissionScreen.
// Quand le livreur appuyait sur "retour", le widget était détruit → dispose()
// annulait le stream → la position ne se partageait plus.
//
// Solution : GPS dans un singleton qui vit indépendamment des widgets.
// MissionScreen lit juste l'état (actif ou non) depuis ce service.
// Quand le livreur revient sur MissionScreen, le GPS est toujours actif.

class GpsService {
  GpsService._();
  static final GpsService instance = GpsService._();

  StreamSubscription<Position>? _stream;
  Timer?                        _timerWeb;
  String?                       _livraisonIdActif;
  bool                          get estActif => _livraisonIdActif != null;
  String?                       get livraisonIdActif => _livraisonIdActif;

  // ─── Démarrer le partage GPS ──────────────────────────────────────────────
  // Retourne null si succès, sinon un message d'erreur à afficher
  Future<String?> demarrer(String livraisonId) async {
    // Déjà actif pour cette livraison → rien à faire
    if (_livraisonIdActif == livraisonId) return null;

    // Stopper un éventuel stream précédent
    await arreter();

    // Vérifier GPS activé
    final serviceActif = await Geolocator.isLocationServiceEnabled();
    if (!serviceActif) {
      return 'Active le GPS dans les paramètres du téléphone';
    }

    // Vérifier permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return 'Permission GPS refusée';
      }
    }
    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return 'GPS bloqué — va dans Paramètres > Apps > Tchira > Permissions';
    }

    _livraisonIdActif = livraisonId;

    if (kIsWeb) {
      _demarrerWeb(livraisonId);
    } else {
      _demarrerMobile(livraisonId);
    }

    debugPrint('📍 GPS démarré pour livraison $livraisonId');
    return null; // succès
  }

  void _demarrerMobile(String livraisonId) {
    const settings = LocationSettings(
      accuracy:       LocationAccuracy.high,
      distanceFilter: 10, // émet seulement si bougé de 10m
    );

    _stream = Geolocator.getPositionStream(locationSettings: settings).listen(
      (Position position) {
        SocketService.envoyerPosition(
          livraisonId: livraisonId,
          lat:         position.latitude,
          lng:         position.longitude,
        );
      },
      onError: (e) {
        debugPrint('❌ Erreur GPS stream : $e');
        _livraisonIdActif = null;
        _stream = null;
      },
    );
  }

  void _demarrerWeb(String livraisonId) {
    _timerWeb = Timer.periodic(const Duration(seconds: 10), (_) async {
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
        SocketService.envoyerPosition(
          livraisonId: livraisonId,
          lat:         position.latitude,
          lng:         position.longitude,
        );
      } catch (_) {
        // Silencieux — réessai au prochain tick
      }
    });
  }

  // ─── Arrêter le partage GPS ───────────────────────────────────────────────
  Future<void> arreter() async {
    await _stream?.cancel();
    _timerWeb?.cancel();
    _stream           = null;
    _timerWeb         = null;
    _livraisonIdActif = null;
    debugPrint('📍 GPS arrêté');
  }
}