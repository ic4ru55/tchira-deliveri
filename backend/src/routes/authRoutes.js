const express  = require('express');
const router   = express.Router();
const {
  register,
  login,
  moi,
  mettreAJourProfil,
  changerMotDePasse,
} = require('../controllers/authController');
const { proteger } = require('../middleware/auth');

// ── Publiques ──────────────────────────────────────────────────────────────
router.post('/register', register);
router.post('/login',    login);

// ── Protégées ──────────────────────────────────────────────────────────────
router.get ('/moi',         proteger, moi);
router.put ('/profil',      proteger, mettreAJourProfil);   // mise à jour nom/tel/photo
router.put ('/changer-mdp', proteger, changerMotDePasse);   // changement mot de passe

module.exports = router;