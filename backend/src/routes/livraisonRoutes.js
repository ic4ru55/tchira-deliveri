const express = require('express');
const router  = express.Router();
const {
  creerLivraison,
  getLivraisonsDisponibles,
  toutesLesLivraisons,
  getStats,
  mesLivraisons,
  monHistorique,
  getLivraison,
  accepterLivraison,
  assignerLivreur,
  mettreAJourStatut,
  modifierLivraison,
  annulerLivraison,
  getLivreursDisponibles,
} = require('../controllers/livraisonController');
const { proteger, autoriser } = require('../middleware/auth');

// ── Routes spécifiques — AVANT /:id ──────────────────────────────────────────
router.get('/mes',
  proteger,
  autoriser('client'),
  mesLivraisons
);

// ✅ Historique du livreur connecté
router.get('/mon-historique',
  proteger,
  autoriser('livreur'),
  monHistorique
);

router.get('/toutes',
  proteger,
  autoriser('admin', 'receptionniste'),
  toutesLesLivraisons
);

router.get('/stats',
  proteger,
  autoriser('admin'),
  getStats
);

router.get('/livreurs-disponibles',
  proteger,
  autoriser('admin', 'receptionniste'),
  getLivreursDisponibles
);

// ── CRUD principal ────────────────────────────────────────────────────────────
router.post('/',
  proteger,
  autoriser('client', 'receptionniste'),
  creerLivraison
);

router.get('/',
  proteger,
  autoriser('livreur'),
  getLivraisonsDisponibles
);

router.get('/:id',
  proteger,
  getLivraison
);

router.put('/:id/accepter',
  proteger,
  autoriser('livreur'),
  accepterLivraison
);

router.put('/:id/assigner',
  proteger,
  autoriser('admin', 'receptionniste'),
  assignerLivreur
);

router.put('/:id/statut',
  proteger,
  autoriser('livreur'),
  mettreAJourStatut
);

router.put('/:id/modifier',
  proteger,
  autoriser('admin', 'receptionniste'),
  modifierLivraison
);

router.delete('/:id',
  proteger,
  annulerLivraison
);

module.exports = router;