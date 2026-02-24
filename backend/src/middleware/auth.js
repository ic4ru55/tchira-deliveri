const jwt  = require('jsonwebtoken');
const User = require('../models/User');

// ─── proteger : vérifie que le token JWT est valide ───────────────────────────
exports.proteger = async (req, res, next) => {
  try {
    let token;

    if (req.headers.authorization &&
        req.headers.authorization.startsWith('Bearer ')) {
      token = req.headers.authorization.split(' ')[1];
    }

    if (!token) {
      return res.status(401).json({
        success: false,
        message: 'Accès refusé. Token manquant',
      });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    const user = await User.findById(decoded.id);

    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Token invalide — utilisateur introuvable',
      });
    }

    // ✅ FIX SUSPENDRE :
    // Avant : !user.actif bloquait TOUTES les requêtes d'un compte suspendu
    // → même l'admin ne pouvait plus appeler /api/auth/moi après avoir suspendu
    //   un compte depuis le même device (si token partagé)
    // → le livreur suspendu ne pouvait pas non plus voir le message d'erreur
    //
    // Nouvelle logique : on laisse passer la requête mais on injecte le statut.
    // Les routes sensibles (accepter mission, créer livraison) vérifient actif.
    // La route /moi retourne actif=false → Flutter déconnecte proprement.
    //
    // Exception : si le compte est suspendu ET que ce n'est PAS une route auth
    // → on bloque avec un message clair (pas "next is not a function")
    if (!user.actif) {
      // Autoriser uniquement /api/auth/* pour que le client puisse savoir
      // que son compte est suspendu (route /moi retourne actif: false)
      const estRouteAuth = req.originalUrl.startsWith('/api/auth');
      if (!estRouteAuth) {
        return res.status(403).json({
          success: false,
          message: 'Compte suspendu. Contactez l\'administrateur.',
        });
      }
    }

    req.user = user;
    next();

  } catch (error) {
    // ✅ FIX "next is not a function" :
    // L'erreur venait de jwt.verify() qui lançait une erreur synchrone
    // avant que next soit accessible dans certains contextes.
    // Le try/catch global attrape maintenant TOUTES les erreurs.
    return res.status(401).json({
      success: false,
      message: 'Token invalide ou expiré',
    });
  }
};

// ─── autoriser : vérifie le rôle de l'utilisateur ────────────────────────────
// ✅ FIX "next is not a function" :
// Cause réelle : autoriser() était parfois appelé directement comme middleware
// au lieu de retourner un middleware. Ex: router.use(autoriser('admin'))
// au lieu de router.use(proteger, autoriser('admin')).
// La fonction retournée est maintenant explicitement nommée pour clarté.
exports.autoriser = (...roles) => {
  return function verifierRole(req, res, next) {
    if (!req.user) {
      return res.status(401).json({
        success: false,
        message: 'Non authentifié',
      });
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