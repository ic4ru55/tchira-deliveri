const jwt  = require('jsonwebtoken');
const User = require('../models/User');

// ─── proteger : vérifie que le token JWT est valide ───────────────────────────
exports.proteger = async (req, res, next) => {
  try {
    let token;

    // Le token est envoyé dans le header Authorization
    // Format standard : "Bearer eyJhbGciOiJIUzI1NiJ9..."
    if (req.headers.authorization &&
        req.headers.authorization.startsWith('Bearer ')) {
      token = req.headers.authorization.split(' ')[1];
      //                                         ^ on prend la partie après "Bearer "
    }

    if (!token) {
      return res.status(401).json({
        success: false,
        message: 'Accès refusé. Token manquant'
      });
    }

    // Vérifier et décoder le token
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    // Si le token est invalide ou expiré, jwt.verify() lance une erreur
    // → on tombe dans le catch

    // Récupérer le user depuis l'ID dans le token
    const user = await User.findById(decoded.id);

    if (!user || !user.actif) {
      return res.status(401).json({
        success: false,
        message: 'Token invalide ou compte suspendu'
      });
    }

    // Injecter le user dans req pour que les controllers y aient accès
    req.user = user;

    next(); // passer à la suite (le controller)

  } catch (error) {
    return res.status(401).json({
      success: false,
      message: 'Token invalide ou expiré'
    });
  }
};

// ─── autoriser : vérifie le rôle de l'utilisateur ────────────────────────────
// Utilisation : router.get('/admin', proteger, autoriser('admin'), controller)
exports.autoriser = (...roles) => {
  return (req, res, next) => {
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({
        success: false,
        message: `Accès refusé. Rôle requis : ${roles.join(', ')}`
      });
    }
    next();
  };
};