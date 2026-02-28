const express      = require('express');
const cors         = require('cors');
const helmet       = require('helmet');
const compression  = require('compression');

const authRoutes          = require('./routes/authRoutes');
const livraisonRoutes     = require('./routes/livraisonRoutes');
const tarifRoutes         = require('./routes/tarifRoutes');
const adminRoutes         = require('./routes/adminRoutes');
const notificationsRoutes = require('./routes/notifications');
const profilRoutes        = require('./routes/profilRoutes');
const paiementRoutes      = require('./routes/paiementRoutes');

// ✅ Initialiser Firebase Admin au démarrage du serveur
const { initialiserFirebase } = require('./services/firebaseService');
initialiserFirebase();

// ── Timer : alerter si mission non assignée après 30min ───────────────────────
const { verifierTimerAssignation } = require('./controllers/paiementController');
setInterval(verifierTimerAssignation, 5 * 60 * 1000); // toutes les 5 min
verifierTimerAssignation(); // vérifier au démarrage aussi

const app = express();

// ─── Sécurité ─────────────────────────────────────────────────────────────────
app.use(helmet());

// ─── Compression ──────────────────────────────────────────────────────────────
app.use(compression());

// ─── CORS ─────────────────────────────────────────────────────────────────────
const originesAutorisees = process.env.NODE_ENV === 'production'
  ? [
      /^https:\/\/.*\.railway\.app$/,
      /^capacitor:\/\//,
      /^http:\/\/localhost/,
    ]
  : '*';

app.use(cors({
  origin:      originesAutorisees,
  credentials: true,
  methods:     ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));

// ─── Parsers ──────────────────────────────────────────────────────────────────
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: false, limit: '10mb' }));

// ─── Routes ───────────────────────────────────────────────────────────────────
app.use('/api/auth',          authRoutes);
app.use('/api/livraisons',    livraisonRoutes);
app.use('/api/tarifs',        tarifRoutes);
app.use('/api/admin',         adminRoutes);
app.use('/api/notifications', notificationsRoutes);
app.use('/api/profil',        profilRoutes);
app.use('/api/paiements',     paiementRoutes);
// ✅ AJOUT — était manquant → crash profil

// ─── Route de santé ───────────────────────────────────────────────────────────
app.get('/', (req, res) => {
  res.json({
    success: true,
    message: '🚀 Tchira Express API — En ligne !',
    version: '1.0.0',
    env:     process.env.NODE_ENV,
  });
});

// ─── 404 ──────────────────────────────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: `Route ${req.originalUrl} introuvable`,
  });
});

// ─── Erreur globale ───────────────────────────────────────────────────────────
app.use((err, req, res, next) => {
  const message = process.env.NODE_ENV === 'production'
    ? 'Erreur serveur interne'
    : err.message;
  console.error(`[ERREUR] ${err.message}`);
  res.status(err.status || 500).json({ success: false, message });
});

module.exports = app;