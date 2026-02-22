const express = require('express');
const router  = express.Router();

const { proteger, autoriser } = require('../middleware/auth');

const {
  getTarifs,
  calculerPrix,
  modifierTarif,
  modifierZone,
} = require('../controllers/tarifController');

// ── Public — voir les tarifs
router.get('/', getTarifs);

// ── Utilisateur connecté — calcul prix
router.post('/calculer', proteger, calculerPrix);

// ── Admin seulement — modification
router.put('/tarif/:categorie', proteger, autoriser('admin'), modifierTarif);
router.put('/zone/:code',       proteger, autoriser('admin'), modifierZone);

module.exports = router;