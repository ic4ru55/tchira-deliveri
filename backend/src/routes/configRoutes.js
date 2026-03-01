// ═══════════════════════════════════════════════════════════════════════════════
// CONFIG ROUTES — routes/configRoutes.js
//
// AJOUTER dans app.js :
//   const configRoutes = require('./routes/configRoutes');
//   app.use('/api/config', configRoutes);
// ═══════════════════════════════════════════════════════════════════════════════

const express    = require('express');
const router     = express.Router();
const configCtrl = require('../controllers/configController');
const { proteger, autoriser } = require('../middleware/auth');

// Lecture de la config — tous les users connectés (client a besoin du numéro OM)
router.get('/', proteger, configCtrl.getConfig);

// Modification — admin uniquement
router.put('/', proteger, autoriser('admin'), configCtrl.modifierConfig);

module.exports = router;