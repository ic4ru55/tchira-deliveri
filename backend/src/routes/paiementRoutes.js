const express         = require('express');
const router          = express.Router();
const paiementCtrl    = require('../controllers/paiementController');
const { auth, roles } = require('../middleware/auth');

// ── CLIENT ───────────────────────────────────────────────────────────────────
// Soumettre preuve de paiement OM
router.post('/:id/preuve',           auth, roles('client'), paiementCtrl.soumettrePreuve);

// ── LIVREUR ──────────────────────────────────────────────────────────────────
// Confirmer réception cash
router.post('/:id/cash',             auth, roles('livreur'), paiementCtrl.confirmerCash);
// Soumettre photo preuve de livraison
router.post('/:id/preuve-livraison', auth, roles('livreur'), paiementCtrl.soumettrePreuveLivraison);

// ── RÉCEP / ADMIN ─────────────────────────────────────────────────────────────
// Valider ou rejeter une preuve
router.put('/:id/valider',           auth, roles('receptionniste', 'admin'), paiementCtrl.validerPreuve);
// Lister toutes les preuves en attente
router.get('/preuves-en-attente',    auth, roles('receptionniste', 'admin'), paiementCtrl.preuvesEnAttente);

module.exports = router;