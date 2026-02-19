const Delivery = require('../models/Delivery');

// ─── CRÉER une livraison (client seulement) ───────────────────────────────────
// POST /api/livraisons
exports.creerLivraison = async (req, res) => {
  try {
    const {
      adresse_depart,
      adresse_arrivee,
      coordonnees_depart,
      coordonnees_arrivee,
      description_colis,
      prix,
    } = req.body;

    const livraison = await Delivery.create({
      client:              req.user.id,  // injecté par le middleware proteger
      adresse_depart,
      adresse_arrivee,
      coordonnees_depart,
      coordonnees_arrivee,
      description_colis,
      prix: prix || 0,
    });

    // populate() remplace l'ObjectId par les vraies données du user
    await livraison.populate('client', 'nom email telephone');

    res.status(201).json({
      success: true,
      livraison,
    });

  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// ─── LIVRAISONS DISPONIBLES (livreur seulement) ───────────────────────────────
// GET /api/livraisons
// Renvoie toutes les livraisons en_attente qu'aucun livreur n'a encore pris
exports.getLivraisonsDisponibles = async (req, res) => {
  try {
    const livraisons = await Delivery
      .find({ statut: 'en_attente', livreur: null })
      .populate('client', 'nom telephone')
      .sort({ createdAt: -1 });  // les plus récentes en premier

    res.status(200).json({
      success: true,
      nombre:  livraisons.length,
      livraisons,
    });

  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// ─── MES LIVRAISONS (client voit les siennes) ─────────────────────────────────
// GET /api/livraisons/mes
exports.mesLivraisons = async (req, res) => {
  try {
    const livraisons = await Delivery
      .find({ client: req.user.id })
      .populate('livreur', 'nom telephone')
      .sort({ createdAt: -1 });

    res.status(200).json({
      success: true,
      nombre: livraisons.length,
      livraisons,
    });

  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// ─── DÉTAIL d'une livraison ───────────────────────────────────────────────────
// GET /api/livraisons/:id
exports.getLivraison = async (req, res) => {
  try {
    const livraison = await Delivery
      .findById(req.params.id)
      .populate('client',  'nom email telephone')
      .populate('livreur', 'nom email telephone');

    if (!livraison) {
      return res.status(404).json({
        success: false,
        message: 'Livraison introuvable',
      });
    }

    // Vérifier que c'est bien son client, son livreur, ou un admin
    const estConcerne =
      livraison.client._id.toString()    === req.user.id ||
      (livraison.livreur &&
       livraison.livreur._id.toString()  === req.user.id) ||
      req.user.role === 'admin';

    if (!estConcerne) {
      return res.status(403).json({
        success: false,
        message: 'Accès non autorisé à cette livraison',
      });
    }

    res.status(200).json({ success: true, livraison });

  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// ─── ACCEPTER une livraison (livreur seulement) ───────────────────────────────
// PUT /api/livraisons/:id/accepter
exports.accepterLivraison = async (req, res) => {
  try {
    let livraison = await Delivery.findById(req.params.id);

    if (!livraison) {
      return res.status(404).json({
        success: false,
        message: 'Livraison introuvable',
      });
    }

    // Vérifier que la livraison est encore disponible
    if (livraison.statut !== 'en_attente') {
      return res.status(400).json({
        success: false,
        message: 'Cette livraison n\'est plus disponible',
      });
    }

    // Assigner le livreur et changer le statut
    livraison.livreur = req.user.id;
    livraison.statut  = 'en_cours';
    await livraison.save();

    await livraison.populate('client',  'nom telephone');
    await livraison.populate('livreur', 'nom telephone');

    res.status(200).json({ success: true, livraison });

  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// ─── METTRE À JOUR le statut (livreur seulement) ─────────────────────────────
// PUT /api/livraisons/:id/statut
exports.mettreAJourStatut = async (req, res) => {
  try {
    const { statut } = req.body;

    // Définir les transitions autorisées — on ne peut pas sauter d'étapes
    const transitionsValides = {
      'en_cours':     ['en_livraison', 'annule'],
      'en_livraison': ['livre'],
    };

    const livraison = await Delivery.findById(req.params.id);

    if (!livraison) {
      return res.status(404).json({
        success: false,
        message: 'Livraison introuvable',
      });
    }

    // Vérifier que c'est bien son livreur
    if (livraison.livreur.toString() !== req.user.id) {
      return res.status(403).json({
        success: false,
        message: 'Vous n\'êtes pas le livreur de cette commande',
      });
    }

    // Vérifier que la transition est valide
    const statutsAutorisés = transitionsValides[livraison.statut] || [];
    if (!statutsAutorisés.includes(statut)) {
      return res.status(400).json({
        success:  false,
        message: `Transition invalide : ${livraison.statut} → ${statut}`,
        autorisés: statutsAutorisés,
      });
    }

    livraison.statut = statut;
    await livraison.save();

    res.status(200).json({ success: true, livraison });

  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// ─── ANNULER une livraison (client seulement, si encore en_attente) ───────────
// DELETE /api/livraisons/:id
exports.annulerLivraison = async (req, res) => {
  try {
    const livraison = await Delivery.findById(req.params.id);

    if (!livraison) {
      return res.status(404).json({
        success: false,
        message: 'Livraison introuvable',
      });
    }

    // Seul le client propriétaire peut annuler
    if (livraison.client.toString() !== req.user.id) {
      return res.status(403).json({
        success: false,
        message: 'Action non autorisée',
      });
    }

    // On peut annuler seulement si personne n'a encore accepté
    if (livraison.statut !== 'en_attente') {
      return res.status(400).json({
        success: false,
        message: 'Impossible d\'annuler — un livreur a déjà pris en charge',
      });
    }

    livraison.statut = 'annule';
    await livraison.save();

    res.status(200).json({
      success: true,
      message: 'Livraison annulée',
    });

  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};