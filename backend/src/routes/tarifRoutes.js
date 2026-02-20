const express    = require('express');
const router     = express.Router();
const {
  getTarifs,
  modifierTarif,
  modifierZone,
  calculerPrix,
} = require('../controllers/tarifController');
const { proteger, autoriser } = require('../middleware/auth');

// Public — tout le monde peut voir les tarifs
router.get('/', getTarifs);

// Public — calculer le prix avant de créer la livraison
router.post('/calculer', proteger, calculerPrix);

// Admin seulement — modifier les tarifs et zones
router.put('/categorie/:categorie', proteger, autoriser('admin'), modifierTarif);
router.put('/zone/:code',           proteger, autoriser('admin'), modifierZone);

module.exports = router;