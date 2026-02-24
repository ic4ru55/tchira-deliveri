import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ✅ FILTRE PAR RÔLE :
// Le backend envoie les notifs "nouvelle_livraison" uniquement aux livreurs.
// Mais si un client a un fcm_token et se retrouve dans la liste par erreur,
// on filtre aussi côté Flutter selon le rôle stocké en local.
//
// Types de notifications et qui doit les voir :
//   nouvelle_livraison → livreur uniquement
//   livreur_assigne    → client uniquement
//   mission_assignee   → livreur uniquement
//   statut_change      → client uniquement

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _canal = AndroidNotificationChannel(
    'tchira_notifications',
    'Tchira Express',
    description: 'Notifications de livraison Tchira Express',
    importance: Importance.high,
  );

  // Types de notifs autorisés par rôle
  static const Map<String, List<String>> _typesParRole = {
    'livreur':        ['nouvelle_livraison', 'mission_assignee'],
    'client':         ['livreur_assigne',    'statut_change'],
    'receptionniste': ['nouvelle_livraison', 'livreur_assigne', 'statut_change'],
    'admin':          ['nouvelle_livraison', 'livreur_assigne', 'mission_assignee', 'statut_change'],
  };

  static Future<void> initialiser() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_canal);

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(initSettings);

    // ✅ Écouter les notifications Firebase en foreground avec filtre rôle
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final notification = message.notification;
      if (notification == null) return;

      // Lire le type de notif dans les données
      final type = message.data['type'] as String?;

      // Lire le rôle de l'utilisateur connecté
      final prefs = await SharedPreferences.getInstance();
      final role  = prefs.getString('role') ?? '';

      // ✅ Filtrer — afficher seulement si le type correspond au rôle
      if (type != null && role.isNotEmpty) {
        final typesAutorises = _typesParRole[role] ?? [];
        if (!typesAutorises.contains(type)) {
          debugPrint('🔕 Notif ignorée pour rôle $role : type=$type');
          return; // on n'affiche pas
        }
      }

      await afficher(
        titre: notification.title ?? '',
        corps: notification.body  ?? '',
      );
    });
  }

  static Future<void> afficher({
    required String titre,
    required String corps,
  }) async {
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      titre,
      corps,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _canal.id,
          _canal.name,
          channelDescription: _canal.description,
          importance:         Importance.high,
          priority:           Priority.high,
          icon:               '@mipmap/ic_launcher',
          color:              const Color(0xFF0D7377),
        ),
      ),
    );
  }
}