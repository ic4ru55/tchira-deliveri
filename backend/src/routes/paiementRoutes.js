const express         = require('express');
const router          = express.Router();
const paiementCtrl    = require('../controllers/paiementController');
const { proteger, autoriser } = require('../middleware/auth');

// ── CLIENT ───────────────────────────────────────────────────────────────────
// Soumettre preuve de paiement OM
router.post('/:id/preuve',           proteger, autoriser('client'), paiementCtrl.soumettrePreuve);

// ── LIVREUR ──────────────────────────────────────────────────────────────────
// Confirmer réception cash
router.post('/:id/cash',             proteger, autoriser('livreur'), paiementCtrl.confirmerCash);
// Soumettre photo preuve de livraison
router.post('/:id/preuve-livraison', proteger, autoriser('livreur'), paiementCtrl.soumettrePreuveLivraison);

// ── RÉCEP / ADMIN ─────────────────────────────────────────────────────────────
// Valider ou rejeter une preuve
router.put('/:id/valider',           proteger, autoriser('receptionniste', 'admin'), paiementCtrl.validerPreuve);
// Lister toutes les preuves en attente
router.get('/preuves-en-attente',    proteger, autoriser('receptionniste', 'admin'), paiementCtrl.preuvesEnAttente);

module.exports = router;