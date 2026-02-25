const jwt  = require('jsonwebtoken');
const User = require('../models/User');

// ─── proteger ─────────────────────────────────────────────────────────────────
exports.proteger = async (req, res, next) => {
  try {
    let token;

    if (
      req.headers.authorization &&
      req.headers.authorization.startsWith('Bearer ')
    ) {
      token = req.headers.authorization.split(' ')[1];
    }

    if (!token) {
      return res.status(401).json({
        success: false,
        message: 'Accès refusé. Token manquant',
      });
    }

    let decoded;
    try {
      decoded = jwt.verify(token, process.env.JWT_SECRET);
    } catch (err) {
      return res.status(401).json({
        success: false,
        message: 'Token invalide ou expiré',
      });
    }

    const user = await User.findById(decoded.id);

    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Utilisateur introuvable',
      });
    }

    // Compte suspendu : bloque tout SAUF /api/auth/*
    // Flutter appelle /api/auth/moi → détecte actif=false → déconnecte proprement
    if (!user.actif && !req.originalUrl.startsWith('/api/auth')) {
      return res.status(403).json({
        success:  false,
        message:  "Compte suspendu. Contactez l'administrateur.",
        suspendu: true,
      });
    }

    req.user = user;
    next();

  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Erreur serveur authentification',
    });
  }
};

// ─── autoriser ────────────────────────────────────────────────────────────────
exports.autoriser = (...roles) => {
  return function verifierRole(req, res, next) {
    if (!req.user) {
      return res.status(401).json({ success: false, message: 'Non authentifié' });
    }
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({
        success: false,
        message: `Accès refusé. Rôle requis : ${roles.join(', ')}`,
      });
    }
    next();
  };
};