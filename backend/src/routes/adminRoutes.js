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

// ✅ FIX "next is not a function" :
// router.use(proteger, autoriser('admin')) cause un bug dans certaines
// versions d'Express — le next() du routeur parent est passé à tort.
// Solution : déclarer proteger + autoriser explicitement sur chaque route.

router.get('/utilisateurs',
  proteger, autoriser('admin'), getUtilisateurs);

router.get('/utilisateurs/:id',
  proteger, autoriser('admin'), getUtilisateur);

router.post('/utilisateurs',
  proteger, autoriser('admin'), creerUtilisateur);

router.put('/utilisateurs/:id',
  proteger, autoriser('admin'), modifierUtilisateur);

router.put('/utilisateurs/:id/statut',
  proteger, autoriser('admin'), changerStatutCompte);

router.delete('/utilisateurs/:id',
  proteger, autoriser('admin'), supprimerUtilisateur);

module.exports = router;