import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// ─── Handler background/fermé — DOIT être top-level (pas dans une classe) ────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase est déjà initialisé dans main.dart
  // On n'affiche pas de notification ici — Android le fait automatiquement
  // quand l'app est en arrière-plan ou fermée si le message a une section
  // "notification" (pas seulement "data")
  debugPrint('📩 Notification background : ${message.notification?.title}');
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _canal = AndroidNotificationChannel(
    'tchira_notifications',
    'Tchira Express',
    description: 'Notifications de livraison Tchira Express',
    importance:  Importance.max, // ✅ max au lieu de high → heads-up garanti
  );

  // ─── Initialiser au démarrage ─────────────────────────────────────────────
  static Future<void> initialiser() async {
    // ✅ Canal Android 8+ (obligatoire)
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_canal);

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Tap sur notif → on peut naviguer ici si besoin
        debugPrint('📲 Notif tappée : ${details.payload}');
      },
    );

    // ✅ Demander permission explicite Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // ✅ FOREGROUND — app ouverte : Firebase ne montre rien automatiquement
    // On intercepte et on affiche via flutter_local_notifications
    // Gère les messages avec "notification" ET les messages data-only
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📩 Notif foreground reçue : ${message.notification?.title} | data: ${message.data}');

      final notif  = message.notification;
      final data   = message.data;

      // ── Cas 1 : message classique avec section notification ──────────────
      if (notif != null) {
        afficher(
          titre:   notif.title ?? data['titre'] ?? 'Tchira Express',
          corps:   notif.body  ?? data['corps']  ?? '',
          payload: data['type'] ?? '',
        );
        return;
      }

      // ── Cas 2 : message data-only (pas de section notification) ──────────
      // Le backend envoie parfois uniquement data: { type, titre, corps, ... }
      if (data.containsKey('titre') || data.containsKey('type')) {
        afficher(
          titre:   data['titre'] ?? _titrePourType(data['type'] ?? ''),
          corps:   data['corps'] ?? data['body'] ?? '',
          payload: data['type']  ?? '',
        );
      }
    });

    // ✅ BACKGROUND — app minimisée, notification tappée
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('📲 App ouverte depuis notif : ${message.data}');
    });

    // ✅ APP FERMÉE — vérifier si ouverte depuis une notification
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('🚀 App lancée depuis notif : ${initialMessage.data}');
    }

    // ✅ Forcer Firebase à afficher les notifs en foreground sur iOS (inutile ici
    // mais bonne pratique si iOS ajouté plus tard)
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  // ─── Titre par défaut selon le type ─────────────────────────────────────
  static String _titrePourType(String type) {
    switch (type) {
      case 'nouvelle_livraison': return '📦 Nouvelle mission !';
      case 'livreur_assigne':   return '🚴 Livreur assigné';
      case 'statut_change':     return '📬 Mise à jour livraison';
      case 'paiement':          return '💰 Paiement';
      default:                  return '🔔 Tchira Express';
    }
  }

  // ─── Afficher une notification locale ────────────────────────────────────
  static Future<void> afficher({
    required String titre,
    required String corps,
    String payload = '',
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
          importance:         Importance.max,
          priority:           Priority.high,
          icon:               '@mipmap/ic_launcher',
          color:              const Color(0xFF0D7377),
          // ✅ Heads-up notification (popup en haut même app ouverte)
          fullScreenIntent:   false,
          playSound:          true,
          enableVibration:    true,
        ),
      ),
      payload: payload,
    );
  }
}