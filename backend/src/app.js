const express         = require('express');
const cors            = require('cors');
const authRoutes      = require('./routes/authRoutes');
const livraisonRoutes = require('./routes/livraisonRoutes');
const tarifRoutes = require('./routes/tarifRoutes');

//    ^ tous les require() EN HAUT du fichier, avant tout app.use()

const app = express();

// ─── Middlewares globaux ───────────────────────────────────────────────────────
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: false }));

// ─── Routes ───────────────────────────────────────────────────────────────────
app.use('/api/auth',       authRoutes);
app.use('/api/livraisons', livraisonRoutes);
app.use('/api/tarifs', tarifRoutes);
// ─── Route de test ────────────────────────────────────────────────────────────
app.get('/', (req, res) => {
  res.json({
    success: true,
    message: '🚀 Tchira Delivery API — En ligne !',
    version: '1.0.0'
  });
});

// ─── Middleware 404 ───────────────────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: `Route ${req.originalUrl} introuvable`
  });
});

module.exports = app;