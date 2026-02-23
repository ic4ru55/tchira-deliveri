import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class SocketService {
  static io.Socket? _socket;

  // ✅ Même logique que api_service.dart — 3 cas clairs
  // kReleaseMode → APK final → Railway
  // kIsWeb       → Chrome dev → localhost direct
  // sinon        → émulateur Android dev → 10.0.2.2
  static String get _serverUrl {
    if (kReleaseMode) {
      return 'https://celebrated-upliftment-production-00fa.up.railway.app';
    }
    if (kIsWeb) return 'http://localhost:5000';
    return 'http://10.0.2.2:5000';
  }

  static io.Socket get socket {
    if (_socket == null) throw Exception('Socket non initialisé');
    return _socket!;
  }

  static void connecter(String token) {
    _socket = io.io(
      _serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );

    _socket!.connect();

    _socket!.onConnect((_) {
      debugPrint('🔌 Socket connecté : ${_socket!.id}');
    });

    _socket!.onDisconnect((_) {
      debugPrint('❌ Socket déconnecté');
    });

    _socket!.on('erreur', (data) {
      debugPrint('❌ Erreur socket : $data');
    });
  }

  static void rejoindrelivraison(String livraisonId) {
    _socket?.emit('rejoindre_livraison', livraisonId);
  }

  static void envoyerPosition({
    required String livraisonId,
    required double lat,
    required double lng,
  }) {
    _socket?.emit('position_livreur', {
      'livraisonId': livraisonId,
      'lat':         lat,
      'lng':         lng,
    });
  }

  static void ecouterPosition(Function(double lat, double lng) callback) {
    _socket?.on('position_mise_a_jour', (data) {
      callback(data['lat'], data['lng']);
    });
  }

  static void arreterEcoutePosition() {
    _socket?.off('position_mise_a_jour');
  }

  static void ecouterStatut(Function(String statut) callback) {
    _socket?.on('statut_mis_a_jour', (data) {
      callback(data['statut']);
    });
  }

  static void deconnecter() {
    _socket?.disconnect();
    _socket = null;
  }
}