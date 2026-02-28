const admin = require('firebase-admin');
const path  = require('path');

let initialise = false;

const initialiserFirebase = () => {
  if (initialise) return;
  try {
    let credentials;

    // ✅ Production (Railway) → variable d'environnement FIREBASE_CREDENTIALS
    // ✅ Développement local  → fichier firebase-credentials.json
    if (process.env.FIREBASE_CREDENTIALS) {
      credentials = JSON.parse(process.env.FIREBASE_CREDENTIALS);
    } else {
      credentials = require(
        path.join(__dirname, '../../firebase-credentials.json')
      );
    }

    admin.initializeApp({
      credential: admin.credential.cert(credentials),
    });

    initialise = true;
    console.log('🔔 Firebase Admin initialisé');
  } catch (e) {
    console.error('❌ Firebase credentials manquant :', e.message);
  }
};

const envoyerNotification = async ({ fcmToken, titre, corps, donnees = {} }) => {
  if (!fcmToken) return;
  try {
    const message = {
      token: fcmToken,
      notification: { title: titre, body: corps },
      // ✅ Dupliquer titre/corps dans data pour le fallback data-only Flutter
      data: {
        titre,
        corps,
        ...Object.fromEntries(
          Object.entries(donnees).map(([k, v]) => [k, String(v)])
        ),
      },
      android: {
        priority: 'high',
        notification: {
          sound:        'default',
          channelId:    'tchira_notifications',   // ✅ doit matcher Flutter
          color:        '#0D7377',
          // ✅ Forcer heads-up même foreground
          visibility:   'public',
          defaultSound: true,
        },
      },
      // ✅ Assurer la livraison même si l'app est fermée
      apns: {
        payload: {
          aps: { sound: 'default', badge: 1 },
        },
      },
    };
    const reponse = await admin.messaging().send(message);
    console.log(`🔔 Notification envoyée : ${reponse}`);
    return true;
  } catch (e) {
    if (
      e.code === 'messaging/invalid-registration-token' ||
      e.code === 'messaging/registration-token-not-registered'
    ) {
      return 'token_invalide';
    }
    console.error('❌ Erreur notification :', e.message);
    return false;
  }
};

module.exports = { initialiserFirebase, envoyerNotification };