const express = require('express');
const router  = express.Router();
const {
  getUtilisateurs,
  getUtilisateur,
  creerUtilisateur,
  modifierUtilisateur,
  changerStatutCompte,
  supprimerUtilisateur,
} = require('../controllers/adminController');
const { proteger, autoriser } = require('../middleware/auth');

// Toutes les routes admin sont protégées
router.use(proteger, autoriser('admin'));

router.get('/utilisateurs',              getUtilisateurs);
router.get('/utilisateurs/:id',          getUtilisateur);
router.post('/utilisateurs',             creerUtilisateur);
router.put('/utilisateurs/:id',          modifierUtilisateur);
router.put('/utilisateurs/:id/statut',   changerStatutCompte);
router.delete('/utilisateurs/:id',       supprimerUtilisateur);

module.exports = router;