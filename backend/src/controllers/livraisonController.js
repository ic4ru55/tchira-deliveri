const Delivery = require('../models/Delivery');
const User     = require('../models/User');

// ─── CRÉER une livraison (client ou réceptionniste) ───────────────────────────
// POST /api/livraisons
exports.creerLivraison = async (req, res) => {
  try {
    const {
      adresse_depart,
      adresse_arrivee,
      coordonnees_depart,
      coordonnees_arrivee,
      description_colis,
      categorie_colis,
      zone,
      prix,
      prix_base,
      frais_zone,
      // Champs spécifiques réceptionniste
      client_nom,
      client_telephone,
      client_id,
    } = req.body;

    let clientId = req.user.id;

    // Si c'est la réceptionniste qui crée pour un client
    if (req.user.role === 'receptionniste') {
      if (client_id) {
        // Client existant
        clientId = client_id;
      } else {
        // Créer un client temporaire sans compte
        // On utilise un user système ou on stocke les infos dans la livraison
        clientId = req.user.id; // fallback
      }
    }

    const livraison = await Delivery.create({
      client:              clientId,
      adresse_depart,
      adresse_arrivee,
      coordonnees_depart:  coordonnees_depart  || { lat: 0, lng: 0 },
      coordonnees_arrivee: coordonnees_arrivee || { lat: 0, lng: 0 },
      description_colis:   description_colis   || '',
      categorie_colis:     categorie_colis     || 'leger',
      zone:                zone                || 'zone_1',
      prix:                prix                || 0,
      prix_base:           prix_base           || 0,
      frais_zone:          frais_zone          || 0,
      // Infos client téléphone (pour commandes sans compte)
      client_nom_tel:      client_nom      || '',
      client_telephone_tel: client_telephone || '',
    });

    await livraison.populate('client', 'nom email telephone');

    res.status(201).json({ success: true, livraison });

  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// ─── LIVRAISONS DISPONIBLES (livreur) ────────────────────────────────────────
// GET /api/livraisons
exports.getLivraisonsDisponibles = async (req, res) => {
  try {
    const livraisons = await Delivery
      .find({ statut: 'en_attente', livreur: null })
      .populate('client', 'nom telephone')
      .sort({ createdAt: -1 });

    res.status(200).json({
      success:   true,
      nombre:    livraisons.length,
      livraisons,
    });

  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// ─── TOUTES LES LIVRAISONS (admin + réceptionniste) ──────────────────────────
// GET /api/livraisons/toutes
exports.toutesLesLivraisons = async (req, res) => {
  try {
    const { statut, date } = req.query;

    const filtre = {};
    if (statut) filtre.statut = statut;
    if (date) {
      const debut = new Date(date);
      debut.setHours(0, 0, 0, 0);
      const fin = new Date(date);
      fin.setHours(23, 59, 59, 999);
      filtre.createdAt = { $gte: debut, $lte: fin };
    }

    const livraisons = await Delivery
      .find(filtre)
      .populate('client',  'nom telephone')
      .populate('livreur', 'nom telephone')
      .sort({ createdAt: -1 });

    res.status(200).json({
      success:   true,
      nombre:    livraisons.length,
      livraisons,
    });

  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// ─── STATISTIQUES (admin) ─────────────────────────────────────────────────────
// GET /api/livraisons/stats
exports.getStats = async (req, res) => {
  try {
    const total      = await Delivery.countDocuments();
    const enAttente  = await Delivery.countDocuments({ statut: 'en_attente' });
    const enCours    = await Delivery.countDocuments({ statut: 'en_cours' });
    const enLivraison = await Delivery.countDocuments({ statut: 'en_livraison' });
    const livrees    = await Delivery.countDocuments({ statut: 'livre' });
    const annulees   = await Delivery.countDocuments({ statut: 'annule' });

    // Chiffre d'affaires total (livraisons livrées)
    const resultatCA = await Delivery.aggregate([
      { $match: { statut: 'livre' } },
      { $group: { _id: null, total: { $sum: '$prix' } } },
    ]);
    const chiffreAffaires = resultatCA[0]?.total || 0;

    // CA du jour
    const aujourd = new Date();
    aujourd.setHours(0, 0, 0, 0);
    const resultatCAJour = await Delivery.aggregate([
      {
        $match: {
          statut:    'livre',
          createdAt: { $gte: aujourd },
        },
      },
      { $group: { _id: null, total: { $sum: '$prix' } } },
    ]);
    const caAujourdhui = resultatCAJour[0]?.total || 0;

    // Nombre de livreurs actifs
    const livreursActifs = await User.countDocuments({
      role:   'livreur',
      actif:  true,
    });

    res.status(200).json({
      success: true,
      stats: {
        total,
        enAttente,
        enCours,
        enLivraison,
        livrees,
        annulees,
        chiffreAffaires,
        caAujourdhui,
        livreursActifs,
      },
    });

  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// ─── MES LIVRAISONS (client) ──────────────────────────────────────────────────
// GET /api/livraisons/mes
exports.mesLivraisons = async (req, res) => {
  try {
    const livraisons = await Delivery
      .find({ client: req.user.id })
      .populate('livreur', 'nom telephone')
      .sort({ createdAt: -1 });

    res.status(200).json({
      success:   true,
      nombre:    livraisons.length,
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

    const estConcerne =
      livraison.client._id.toString()   === req.user.id ||
      (livraison.livreur &&
       livraison.livreur._id.toString() === req.user.id) ||
      req.user.role === 'admin'          ||
      req.user.role === 'receptionniste';

    if (!estConcerne) {
      return res.status(403).json({
        success: false,
        message: 'Accès non autorisé',
      });
    }

    res.status(200).json({ success: true, livraison });

  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// ─── ACCEPTER une livraison (livreur) ────────────────────────────────────────
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

    if (livraison.statut !== 'en_attente') {
      return res.status(400).json({
        success: false,
        message: 'Cette livraison n\'est plus disponible',
      });
    }

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

// ─── ASSIGNER un livreur (réceptionniste + admin) ────────────────────────────
// PUT /api/livraisons/:id/assigner
exports.assignerLivreur = async (req, res) => {
  try {
    const { livreur_id } = req.body;

    if (!livreur_id) {
      return res.status(400).json({
        success: false,
        message: 'livreur_id est requis',
      });
    }

    const livraison = await Delivery.findById(req.params.id);
    if (!livraison) {
      return res.status(404).json({
        success: false,
        message: 'Livraison introuvable',
      });
    }

    if (livraison.statut !== 'en_attente') {
      return res.status(400).json({
        success: false,
        message: 'Cette livraison n\'est plus disponible',
      });
    }

    const livreur = await User.findById(livreur_id);
    if (!livreur || livreur.role !== 'livreur') {
      return res.status(404).json({
        success: false,
        message: 'Livreur introuvable',
      });
    }

    livraison.livreur = livreur_id;
    livraison.statut  = 'en_cours';
    await livraison.save();

    await livraison.populate('client',  'nom telephone');
    await livraison.populate('livreur', 'nom telephone');

    res.status(200).json({ success: true, livraison });

  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// ─── METTRE À JOUR le statut (livreur) ───────────────────────────────────────
// PUT /api/livraisons/:id/statut
exports.mettreAJourStatut = async (req, res) => {
  try {
    const { statut } = req.body;

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

    if (livraison.livreur.toString() !== req.user.id) {
      return res.status(403).json({
        success: false,
        message: 'Vous n\'êtes pas le livreur de cette commande',
      });
    }

    const statutsAutorises = transitionsValides[livraison.statut] || [];
    if (!statutsAutorises.includes(statut)) {
      return res.status(400).json({
        success:   false,
        message:   `Transition invalide : ${livraison.statut} → ${statut}`,
        autorises: statutsAutorises,
      });
    }

    livraison.statut = statut;
    await livraison.save();

    res.status(200).json({ success: true, livraison });

  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// ─── MODIFIER une livraison (réceptionniste + admin) ─────────────────────────
// PUT /api/livraisons/:id/modifier
exports.modifierLivraison = async (req, res) => {
  try {
    const {
      adresse_depart,
      adresse_arrivee,
      description_colis,
      categorie_colis,
      zone,
      prix,
    } = req.body;

    const livraison = await Delivery.findById(req.params.id);

    if (!livraison) {
      return res.status(404).json({
        success: false,
        message: 'Livraison introuvable',
      });
    }

    // On peut modifier seulement si en_attente
    if (livraison.statut !== 'en_attente') {
      return res.status(400).json({
        success: false,
        message: 'Impossible de modifier — livraison déjà prise en charge',
      });
    }

    if (adresse_depart)   livraison.adresse_depart   = adresse_depart;
    if (adresse_arrivee)  livraison.adresse_arrivee  = adresse_arrivee;
    if (description_colis) livraison.description_colis = description_colis;
    if (categorie_colis)  livraison.categorie_colis  = categorie_colis;
    if (zone)             livraison.zone             = zone;
    if (prix)             livraison.prix             = prix;

    await livraison.save();
    await livraison.populate('client',  'nom telephone');
    await livraison.populate('livreur', 'nom telephone');

    res.status(200).json({ success: true, livraison });

  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// ─── ANNULER une livraison ────────────────────────────────────────────────────
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

    const estAutorise =
      livraison.client.toString() === req.user.id ||
      req.user.role === 'admin'                    ||
      req.user.role === 'receptionniste';

    if (!estAutorise) {
      return res.status(403).json({
        success: false,
        message: 'Action non autorisée',
      });
    }

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

// ─── LIVREURS DISPONIBLES (réceptionniste + admin) ───────────────────────────
// GET /api/livraisons/livreurs-disponibles
exports.getLivreursDisponibles = async (req, res) => {
  try {
    // Un livreur est disponible s'il n'a pas de livraison en_cours ou en_livraison
    const livreursOccupes = await Delivery.distinct('livreur', {
      statut: { $in: ['en_cours', 'en_livraison'] },
      livreur: { $ne: null },
    });

    const livreursDisponibles = await User.find({
      role:  'livreur',
      _id:   { $nin: livreursOccupes },
    }).select('nom telephone email');

    res.status(200).json({
      success:  true,
      nombre:   livreursDisponibles.length,
      livreurs: livreursDisponibles,
    });

  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};