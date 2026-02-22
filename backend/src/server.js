require('dotenv').config();
const http        = require('http');
const { Server }  = require('socket.io');
const app         = require('./app');
const connectDB   = require('./config/db');
const initSocket  = require('./config/socket');
const initDonnees = require('./config/initDonnees');

const PORT = process.env.PORT || 5000;

const serveurHTTP = http.createServer(app);

// ─── Socket.io ────────────────────────────────────────────────────────────────
// 📚 On reprend la même logique CORS que app.js
// En prod on accepte Railway + apps mobiles, en dev tout
const io = new Server(serveurHTTP, {
  cors: {
    origin:  process.env.NODE_ENV === 'production'
      ? [/^https:\/\/.*\.railway\.app$/, /^capacitor:\/\//, /^http:\/\/localhost/]
      : '*',
    methods: ['GET', 'POST'],
  },
});

initSocket(io);

// ─── Démarrage ────────────────────────────────────────────────────────────────
// 📚 .then() s'exécute si MongoDB se connecte avec succès
//    .catch() s'exécute si MongoDB échoue — on log et on quitte proprement
connectDB()
  .then(async () => {
    await initDonnees();

    serveurHTTP.listen(PORT, () => {
      console.log(`🚀 Serveur démarré sur le port ${PORT}`);
      console.log(`🌍 Environnement : ${process.env.NODE_ENV || 'development'}`);
      console.log(`🔌 Socket.io actif`);
    });
  })
  .catch((erreur) => {
    // 📚 process.exit(1) dit à Railway "le démarrage a échoué"
    // Railway va alors afficher les logs et ne pas router de trafic vers ce pod
    console.error('❌ Impossible de connecter MongoDB :', erreur.message);
    process.exit(1);
  });

// ─── Filet de sécurité global ─────────────────────────────────────────────────
// 📚 Attrape toutes les Promises rejetées non gérées dans TOUT le code
// Sans ça, Node affiche juste un warning et continue — comportement imprévisible
process.on('unhandledRejection', (erreur) => {
  console.error('❌ Promesse rejetée non gérée :', erreur.message);
  // On ferme proprement le serveur puis on quitte
  // Railway va automatiquement redémarrer le container
  serveurHTTP.close(() => process.exit(1));
});