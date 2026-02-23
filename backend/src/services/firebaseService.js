const admin = require('firebase-admin');
const path  = require('path');

let initialise = false;

const initialiserFirebase = () => {
  if (initialise) return;
  try {
    const credentials = require(
      path.join(__dirname, '../../firebase-credentials.json')
    );
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
      // 📚 data = données silencieuses reçues par l'app
      // permet de naviguer vers le bon écran quand l'user tape la notif
      data: Object.fromEntries(
        Object.entries(donnees).map(([k, v]) => [k, String(v)])
      ),
      android: {
        priority: 'high',
        notification: {
          sound:     'default',
          channelId: 'tchira_notifications',
          color:     '#0D7377',
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