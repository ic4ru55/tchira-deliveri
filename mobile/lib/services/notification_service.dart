import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// 📚 Firebase en foreground ne montre PAS les notifications automatiquement
// flutter_local_notifications permet de les afficher manuellement
// quand l'app est ouverte et visible

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // ─── Canal Android — doit correspondre à channelId du backend ────────────
  static const AndroidNotificationChannel _canal = AndroidNotificationChannel(
    'tchira_notifications',       // ← même valeur que dans firebaseService.js
    'Tchira Express',
    description: 'Notifications de livraison Tchira Express',
    importance: Importance.high,
  );

  // ─── Initialiser au démarrage de l'app ───────────────────────────────────
  static Future<void> initialiser() async {
    // ✅ Créer le canal Android (obligatoire Android 8+)
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_canal);

    // ✅ Configurer l'icône de notification
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(initSettings);

    // ✅ Écouter les notifications Firebase quand l'app est EN AVANT-PLAN
    // Sans ça, les notifications Firebase sont silencieuses en foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification == null) return;

      afficher(
        titre: notification.title ?? '',
        corps: notification.body  ?? '',
      );
    });
  }

  // ─── Afficher une notification locale ────────────────────────────────────
  static Future<void> afficher({
    required String titre,
    required String corps,
  }) async {
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000, // ID unique
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