require('dotenv').config();
const http        = require('http');
const { Server }  = require('socket.io');
const app         = require('./app');
const connectDB   = require('./config/db');
const initSocket  = require('./config/socket');
const initDonnees = require('./config/initDonnees');

const PORT = process.env.PORT || 5000;

const serveurHTTP = http.createServer(app);

const io = new Server(serveurHTTP, {
  cors: {
    origin:  '*',
    methods: ['GET', 'POST'],
  },
});

initSocket(io);

connectDB().then(async () => {
  // Initialiser les données par défaut après connexion DB
  await initDonnees();

  serveurHTTP.listen(PORT, () => {
    console.log(`🚀 Serveur démarré sur http://localhost:${PORT}`);
    console.log(`🔌 Socket.io actif`);
  });
});