const express    = require('express');
const router     = express.Router();
const {
  creerLivraison,
  getLivraisonsDisponibles,
  mesLivraisons,
  getLivraison,
  accepterLivraison,
  mettreAJourStatut,
  annulerLivraison,
} = require('../controllers/livraisonController');
const { proteger, autoriser } = require('../middleware/auth');

// Toutes les routes nécessitent un token — on met proteger une fois pour toutes
router.use(proteger);

// Routes client
router.post('/',        autoriser('client'),          creerLivraison);
router.get('/mes',      autoriser('client'),           mesLivraisons);
router.delete('/:id',   autoriser('client'),           annulerLivraison);

// Routes livreur
router.get('/',         autoriser('livreur', 'admin'), getLivraisonsDisponibles);
router.put('/:id/accepter', autoriser('livreur'),      accepterLivraison);
router.put('/:id/statut',   autoriser('livreur'),      mettreAJourStatut);

// Route commune (client + livreur + admin)
router.get('/:id',      getLivraison);

module.exports = router;