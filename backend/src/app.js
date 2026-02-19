const express    = require('express');
const cors       = require('cors');
const authRoutes = require('./routes/authRoutes');

const app = express();

// Middlewares globaux
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: false }));

// Routes
// Toutes les routes de authRoutes seront préfixées par /api/auth
app.use('/api/auth', authRoutes);

// Route de test
app.get('/', (req, res) => {
  res.json({
    success: true,
    message: '🚀 Tchira Delivery API — En ligne !',
    version: '1.0.0'
  });
});

// Middleware 404 — si aucune route ne correspond
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: `Route ${req.originalUrl} introuvable`
  });
});

module.exports = app;
