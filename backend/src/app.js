const express      = require('express');
const cors         = require('cors');
const helmet       = require('helmet');
const compression  = require('compression');

const authRoutes      = require('./routes/authRoutes');
const livraisonRoutes = require('./routes/livraisonRoutes');
const tarifRoutes     = require('./routes/tarifRoutes');
const adminRoutes     = require('./routes/adminRoutes');

const app = express();

// ─── Sécurité ─────────────────────────────────────────────────────────────────
// 📚 helmet() ajoute ~15 headers HTTP de sécurité en une ligne
app.use(helmet());

// ─── Compression ──────────────────────────────────────────────────────────────
// 📚 Compresse toutes les réponses JSON automatiquement
// Très utile sur connexions mobiles lentes
app.use(compression());

// ─── CORS ─────────────────────────────────────────────────────────────────────
// 📚 CORS = Cross-Origin Resource Sharing
// Contrôle quels domaines peuvent appeler ton API
// En développement on accepte tout, en production on restreint
const originesAutorisees = process.env.NODE_ENV === 'production'
  ? [
      // ✅ Ajoute ici ton domaine Railway une fois déployé
      // ex: 'https://tchira-backend.up.railway.app'
      /^https:\/\/.*\.railway\.app$/,  // accepte tous les sous-domaines Railway
      /^capacitor:\/\//,               // Flutter mobile (Capacitor)
      /^http:\/\/localhost/,           // dev local
    ]
  : '*';  // En développement : tout accepter

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
app.use('/api/auth',       authRoutes);
app.use('/api/livraisons', livraisonRoutes);
app.use('/api/tarifs',     tarifRoutes);
app.use('/api/admin',      adminRoutes);

// ─── Route de santé ───────────────────────────────────────────────────────────
// 📚 Railway ping cette route pour savoir si l'app est vivante
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
// 📚 Ce middleware attrape TOUTES les erreurs non gérées dans les routes
// Le "4 paramètres" (err, req, res, next) est obligatoire pour qu'Express
// le reconnaisse comme middleware d'erreur
app.use((err, req, res, next) => {
  // En production : message générique (pas de fuite d'info)
  // En développement : message complet pour débugger
  const message = process.env.NODE_ENV === 'production'
    ? 'Erreur serveur interne'
    : err.message;

  console.error(`[ERREUR] ${err.message}`);

  res.status(err.status || 500).json({
    success: false,
    message,
  });
});

module.exports = app;