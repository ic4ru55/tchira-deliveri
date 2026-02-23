const admin = require('firebase-admin');

let initialise = false;

const initialiserFirebase = () => {
  if (initialise) return;
  try {
    // 🔹 Essaie d'abord la variable d'environnement
    const credentials = process.env.FIREBASE_CREDENTIALS
      ? JSON.parse(process.env.FIREBASE_CREDENTIALS)
      : require('../../firebase-credentials.json'); // fallback local pour dev

    admin.initializeApp({
      credential: admin.credential.cert(credentials),
    });
    initialise = true;
    console.log('🔔 Firebase Admin initialisé');
  } catch (e) {
    console.error('❌ Firebase credentials manquant :', e.message);
  }
};

// ─── Envoyer une notification à UN utilisateur via son fcm_token ──────────
const envoyerNotification = async ({ fcmToken, titre, corps, donnees = {} }) => {
  if (!fcmToken) return;
  try {
    const message = {
      token: fcmToken,
      notification: { title: titre, body: corps },
      data: Object.fromEntries(
        Object.entries(donnees).map(([k, v]) => [k, String(v)])
      ),
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'tchira_notifications',
          color: '#0D7377',
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