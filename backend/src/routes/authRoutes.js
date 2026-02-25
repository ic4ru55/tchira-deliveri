const express            = require('express');
const router             = express.Router();
const { register, login, moi } = require('../controllers/authController');
const { proteger }             = require('../middleware/auth');

// Publiques — sans token
router.post('/register', register);
router.post('/login',    login);

// Protégée — accessible même si actif=false (auth.js laisse passer /api/auth/*)
router.get('/moi', proteger, moi);

module.exports = router;