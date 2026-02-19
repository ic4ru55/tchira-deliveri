require('dotenv').config();
const http      = require('http');       // module natif Node.js
const { Server } = require('socket.io');
const app       = require('./app');
const connectDB = require('./config/db');
const initSocket = require('./config/socket');

const PORT = process.env.PORT || 5000;

// On crée un serveur HTTP "classique" à partir de l'app Express
// Socket.io a besoin de ce serveur pour s'y greffer
const serveurHTTP = http.createServer(app);

// On attache Socket.io au serveur HTTP
const io = new Server(serveurHTTP, {
  cors: {
    origin: '*',       // en dev on accepte tout, en prod on restreindra
    methods: ['GET', 'POST']
  }
});

// Initialiser toute la logique Socket.io
initSocket(io);

// Démarrage
connectDB().then(() => {
  serveurHTTP.listen(PORT, () => {
    console.log(`🚀 Serveur démarré sur http://localhost:${PORT}`);
    console.log(`🔌 Socket.io actif`);
  });
});