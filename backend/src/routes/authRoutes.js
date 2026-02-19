const express    = require('express');
const router     = express.Router();
const { register, login, moi } = require('../controllers/authController');
const { proteger }              = require('../middleware/auth');

// Routes publiques (pas besoin de token)
router.post('/register', register);
router.post('/login',    login);

// Route protégée (token obligatoire)
router.get('/moi', proteger, moi);

module.exports = router;