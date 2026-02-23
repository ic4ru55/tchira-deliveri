const express  = require('express');
const router   = express.Router();
const User     = require('../models/User');
const { proteger } = require('../middleware/auth');

// POST /api/notifications/token
// Appelé par Flutter au démarrage pour sauvegarder le token FCM
router.post('/token', proteger, async (req, res) => {
  try {
    const { fcm_token } = req.body;
    if (!fcm_token) {
      return res.status(400).json({ success: false, message: 'Token manquant' });
    }
    await User.findByIdAndUpdate(req.user.id, { fcm_token });
    res.json({ success: true, message: 'Token FCM sauvegardé' });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

module.exports = router;