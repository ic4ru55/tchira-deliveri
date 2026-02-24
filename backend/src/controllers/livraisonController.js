const Delivery = require('../models/Delivery');
const User     = require('../models/User');
const { envoyerNotification } = require('../services/firebaseService');

// ─── CRÉER une livraison ──────────────────────────────────────────────────────
exports.creerLivraison = async (req, res) => {
  try {
    const {
      adresse_depart, adresse_arrivee, coordonnees_depart, coordonnees_arrivee,
      description_colis, categorie_colis, zone, prix, prix_base, frais_zone,
      client_nom, client_telephone, client_id,
    } = req.body;

    let clientId = req.user.id;
    if (req.user.role === 'receptionniste' && client_id) clientId = client_id;

    const livraison = await Delivery.create({
      client:              clientId,
      adresse_depart,      adresse_arrivee,
      coordonnees_depart:  coordonnees_depart  || { lat: 0, lng: 0 },
      coordonnees_arrivee: coordonnees_arrivee || { lat: 0, lng: 0 },
      description_colis:   description_colis   || '',
      categorie_colis:     categorie_colis     || 'leger',
      zone:                zone                || 'zone_1',
      prix:                prix                || 0,
      prix_base:           prix_base           || 0,
      frais_zone:          frais_zone          || 0,
      client_nom_tel:       client_nom       || '',
      client_telephone_tel: client_telephone || '',
    });

    await livraison.populate('client', 'nom email telephone');

    const livreurs = await User.find({ role: 'livreur', actif: true, fcm_token: { $ne: null } });
    for (const livreur of livreurs) {
      await envoyerNotification({
        fcmToken: livreur.fcm_token,
        titre:    '📦 Nouvelle mission disponible !',
        corps:    `${adresse_depart} → ${adresse_arrivee} — ${prix} FCFA`,
        donnees:  { type: 'nouvelle_livraison', livraison_id: livraison._id.toString() },
      });
    }

    res.status(201).json({ success: true, livraison });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// ─── LIVRAISONS DISPONIBLES (livreur) ────────────────────────────────────────
exports.getLivraisonsDisponibles = async (req, res) => {
  try {
    const livraisons = await Delivery
      .find({ statut: 'en_attente', livreur: null })
      .populate('client', 'nom telephone')
      .sort({ createdAt: -1 });
    res.status(200).json({ success: true, nombre: livraisons.length, livraisons });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// ─── TOUTES LES LIVRAISONS (admin + réceptionniste) ──────────────────────────
exports.toutesLesLivraisons = async (req, res) => {
  try {
    const { statut, date } = req.query;
    const filtre = {};
    if (statut) filtre.statut = statut;
    if (date) {
      const debut = new Date(date); debut.setHours(0,  0,  0,   0);
      const fin   = new Date(date); fin.setHours(23, 59, 59, 999);
      filtre.createdAt = { $gte: debut, $lte: fin };
    }
    const livraisons = await Delivery
      .find(filtre)
      .populate('client',  'nom telephone')
      .populate('livreur', 'nom telephone')
      .sort({ createdAt: -1 });
    res.status(200).json({ success: true, nombre: livraisons.length, livraisons });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// ─── STATISTIQUES avec filtre date (admin) ───────────────────────────────────
// GET /api/livraisons/stats          → stats globales
// GET /api/livraisons/stats?date=2026-02-23 → stats du jour
exports.getStats = async (req, res) => {
  try {
    const { date } = req.query;

    let filtreDate = {};
    if (date) {
      const debut = new Date(date); debut.setHours(0,  0,  0,   0);
      const fin   = new Date(date); fin.setHours(23, 59, 59, 999);
      filtreDate  = { createdAt: { $gte: debut, $lte: fin } };
    }

    const total       = await Delivery.countDocuments(filtreDate);
    const enAttente   = await Delivery.countDocuments({ ...filtreDate, statut: 'en_attente' });
    const enCours     = await Delivery.countDocuments({ ...filtreDate, statut: 'en_cours' });
    const enLivraison = await Delivery.countDocuments({ ...filtreDate, statut: 'en_livraison' });
    const livrees     = await Delivery.countDocuments({ ...filtreDate, statut: 'livre' });
    const annulees    = await Delivery.countDocuments({ ...filtreDate, statut: 'annule' });

    // CA selon filtre (date ou tout)
    const resultatCA = await Delivery.aggregate([
      { $match: { ...filtreDate, statut: 'livre' } },
      { $group: { _id: null, total: { $sum: '$prix' } } },
    ]);
    const chiffreAffaires = resultatCA[0]?.total || 0;

    // CA aujourd'hui (toujours affiché)
    const aujourd = new Date(); aujourd.setHours(0, 0, 0, 0);
    const resultatCAJour = await Delivery.aggregate([
      { $match: { statut: 'livre', createdAt: { $gte: aujourd } } },
      { $group: { _id: null, total: { $sum: '$prix' } } },
    ]);
    const caAujourdhui = resultatCAJour[0]?.total || 0;

    // CA total tous les temps
    const resultatCATotal = await Delivery.aggregate([
      { $match: { statut: 'livre' } },
      { $group: { _id: null, total: { $sum: '$prix' } } },
    ]);
    const caTotal = resultatCATotal[0]?.total || 0;

    const livreursActifs = await User.countDocuments({ role: 'livreur', actif: true });

    res.status(200).json({
      success: true,
      stats: {
        total, enAttente, enCours, enLivraison, livrees, annulees,
        chiffreAffaires, caAujourdhui, caTotal, livreursActifs,
        dateFiltre: date || null,
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// ─── MES LIVRAISONS (client) ──────────────────────────────────────────────────
exports.mesLivraisons = async (req, res) => {
  try {
    const livraisons = await Delivery
      .find({ client: req.user.id })
      .populate('livreur', 'nom telephone')
      .sort({ createdAt: -1 });
    res.status(200).json({ success: true, nombre: livraisons.length, livraisons });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// ─── HISTORIQUE DU LIVREUR CONNECTÉ ──────────────────────────────────────────
// GET /api/livraisons/mon-historique
exports.monHistorique = async (req, res) => {
  try {
    const livraisons = await Delivery
      .find({ livreur: req.user.id })
      .populate('client', 'nom telephone')
      .sort({ createdAt: -1 });
    res.status(200).json({ success: true, nombre: livraisons.length, livraisons });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// ─── DÉTAIL d'une livraison ───────────────────────────────────────────────────
exports.getLivraison = async (req, res) => {
  try {
    const livraison = await Delivery
      .findById(req.params.id)
      .populate('client',  'nom email telephone')
      .populate('livreur', 'nom email telephone');

    if (!livraison) {
      return res.status(404).json({ success: false, message: 'Livraison introuvable' });
    }

    const estConcerne =
      livraison.client._id.toString() === req.user.id ||
      (livraison.livreur && livraison.livreur._id.toString() === req.user.id) ||
      req.user.role === 'admin' ||
      req.user.role === 'receptionniste';

    if (!estConcerne) {
      return res.status(403).json({ success: false, message: 'Accès non autorisé' });
    }

    res.status(200).json({ success: true, livraison });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// ─── ACCEPTER une livraison (livreur) ────────────────────────────────────────
exports.accepterLivraison = async (req, res) => {
  try {
    // Vérifier que le livreur n'a pas déjà une mission active
    const dejaOccupe = await Delivery.findOne({
      livreur: req.user.id,
      statut:  { $in: ['en_cours', 'en_livraison'] },
    });
    if (dejaOccupe) {
      return res.status(400).json({
        success: false,
        message: "Tu as déjà une mission en cours. Termine-la avant d'en accepter une autre.",
      });
    }

    let livraison = await Delivery.findById(req.params.id);
    if (!livraison) {
      return res.status(404).json({ success: false, message: 'Livraison introuvable' });
    }
    if (livraison.statut !== 'en_attente') {
      return res.status(400).json({ success: false, message: "Cette livraison n'est plus disponible" });
    }

    livraison.livreur = req.user.id;
    livraison.statut  = 'en_cours';
    await livraison.save();

    await livraison.populate('client',  'nom telephone fcm_token');
    await livraison.populate('livreur', 'nom telephone');

    if (livraison.client?.fcm_token) {
      await envoyerNotification({
        fcmToken: livraison.client.fcm_token,
        titre:    '🚴 Livreur assigné !',
        corps:    `${livraison.livreur.nom} prend en charge votre livraison`,
        donnees:  { type: 'livreur_assigne', livraison_id: livraison._id.toString() },
      });
    }

    res.status(200).json({ success: true, livraison });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// ─── ASSIGNER un livreur (réceptionniste + admin) ────────────────────────────
exports.assignerLivreur = async (req, res) => {
  try {
    const { livreur_id } = req.body;
    if (!livreur_id) {
      return res.status(400).json({ success: false, message: 'livreur_id est requis' });
    }

    const livraison = await Delivery.findById(req.params.id);
    if (!livraison) {
      return res.status(404).json({ success: false, message: 'Livraison introuvable' });
    }
    if (livraison.statut !== 'en_attente') {
      return res.status(400).json({ success: false, message: "Cette livraison n'est plus disponible" });
    }

    const livreur = await User.findById(livreur_id);
    if (!livreur || livreur.role !== 'livreur') {
      return res.status(404).json({ success: false, message: 'Livreur introuvable' });
    }

    livraison.livreur = livreur_id;
    livraison.statut  = 'en_cours';
    await livraison.save();

    await livraison.populate('client',  'nom telephone fcm_token');
    await livraison.populate('livreur', 'nom telephone fcm_token');

    if (livraison.client?.fcm_token) {
      await envoyerNotification({
        fcmToken: livraison.client.fcm_token,
        titre:    '🚴 Livreur assigné !',
        corps:    `${livreur.nom} prend en charge votre livraison`,
        donnees:  { type: 'livreur_assigne', livraison_id: livraison._id.toString() },
      });
    }

    if (livreur.fcm_token) {
      await envoyerNotification({
        fcmToken: livreur.fcm_token,
        titre:    '📋 Mission assignée !',
        corps:    `Nouvelle mission : ${livraison.adresse_depart} → ${livraison.adresse_arrivee}`,
        donnees:  { type: 'mission_assignee', livraison_id: livraison._id.toString() },
      });
    }

    res.status(200).json({ success: true, livraison });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// ─── METTRE À JOUR le statut (livreur) ───────────────────────────────────────
exports.mettreAJourStatut = async (req, res) => {
  try {
    const { statut } = req.body;
    const transitionsValides = {
      'en_cours':     ['en_livraison', 'annule'],
      'en_livraison': ['livre'],
    };

    const livraison = await Delivery.findById(req.params.id);
    if (!livraison) {
      return res.status(404).json({ success: false, message: 'Livraison introuvable' });
    }
    if (livraison.livreur.toString() !== req.user.id) {
      return res.status(403).json({ success: false, message: "Vous n'êtes pas le livreur de cette commande" });
    }

    const statutsAutorises = transitionsValides[livraison.statut] || [];
    if (!statutsAutorises.includes(statut)) {
      return res.status(400).json({
        success: false,
        message: `Transition invalide : ${livraison.statut} → ${statut}`,
        autorises: statutsAutorises,
      });
    }

    livraison.statut = statut;
    await livraison.save();

    const client = await User.findById(livraison.client).select('fcm_token');
    const messagesStatut = {
      'en_livraison': { titre: '🚚 Livraison en cours !', corps: 'Votre livreur est en route vers vous' },
      'livre':        { titre: '✅ Colis livré !',         corps: 'Votre colis a été livré avec succès. Merci !' },
      'annule':       { titre: '❌ Livraison annulée',     corps: 'Votre livraison a été annulée' },
    };

    const notif = messagesStatut[statut];
    if (notif && client?.fcm_token) {
      await envoyerNotification({
        fcmToken: client.fcm_token,
        titre:    notif.titre,
        corps:    notif.corps,
        donnees:  { type: 'statut_change', statut, livraison_id: livraison._id.toString() },
      });
    }

    res.status(200).json({ success: true, livraison });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// ─── MODIFIER une livraison ───────────────────────────────────────────────────
exports.modifierLivraison = async (req, res) => {
  try {
    const { adresse_depart, adresse_arrivee, description_colis,
            categorie_colis, zone, prix } = req.body;

    const livraison = await Delivery.findById(req.params.id);
    if (!livraison) {
      return res.status(404).json({ success: false, message: 'Livraison introuvable' });
    }
    if (livraison.statut !== 'en_attente') {
      return res.status(400).json({
        success: false, message: 'Impossible de modifier — livraison déjà prise en charge',
      });
    }

    if (adresse_depart)    livraison.adresse_depart    = adresse_depart;
    if (adresse_arrivee)   livraison.adresse_arrivee   = adresse_arrivee;
    if (description_colis) livraison.description_colis = description_colis;
    if (categorie_colis)   livraison.categorie_colis   = categorie_colis;
    if (zone)              livraison.zone              = zone;
    if (prix)              livraison.prix              = prix;

    await livraison.save();
    await livraison.populate('client',  'nom telephone');
    await livraison.populate('livreur', 'nom telephone');

    res.status(200).json({ success: true, livraison });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// ─── ANNULER une livraison ────────────────────────────────────────────────────
exports.annulerLivraison = async (req, res) => {
  try {
    const livraison = await Delivery.findById(req.params.id);
    if (!livraison) {
      return res.status(404).json({ success: false, message: 'Livraison introuvable' });
    }

    const estAutorise =
      livraison.client.toString() === req.user.id ||
      req.user.role === 'admin' ||
      req.user.role === 'receptionniste';

    if (!estAutorise) {
      return res.status(403).json({ success: false, message: 'Action non autorisée' });
    }
    if (livraison.statut !== 'en_attente') {
      return res.status(400).json({
        success: false, message: "Impossible d'annuler — un livreur a déjà pris en charge",
      });
    }

    livraison.statut = 'annule';
    await livraison.save();

    // ✅ Notifier le client si c'est la réceptionniste ou l'admin qui annule
    if (req.user.role === 'receptionniste' || req.user.role === 'admin') {
      const client = await User.findById(livraison.client).select('fcm_token nom');
      if (client?.fcm_token) {
        await envoyerNotification({
          fcmToken: client.fcm_token,
          titre:    '❌ Livraison annulée',
          corps:    `Votre livraison de ${livraison.adresse_depart} vers ${livraison.adresse_arrivee} a été annulée.`,
          donnees:  { type: 'statut_change', statut: 'annule', livraison_id: livraison._id.toString() },
        });
      }
    }

    res.status(200).json({ success: true, message: 'Livraison annulée' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// ─── TOUS LES LIVREURS avec leur statut (dispo / en mission) ─────────────────
// Utilisé par la réceptionniste pour voir qui est libre
exports.getLivreursDisponibles = async (req, res) => {
  try {
    // IDs des livreurs actuellement en mission
    const livreursOccupes = await Delivery.distinct('livreur', {
      statut:  { $in: ['en_cours', 'en_livraison'] },
      livreur: { $ne: null },
    });

    // Tous les livreurs actifs
    const tousLivreurs = await User.find({ role: 'livreur' })
      .select('nom telephone email');

    // Enrichir avec le statut
    const livreurs = tousLivreurs.map((l) => ({
      _id:       l._id,
      nom:       l.nom,
      telephone: l.telephone,
      email:     l.email,
      // ✅ statut calculé selon si l'ID est dans la liste des occupés
      disponible: !livreursOccupes.some(
        (id) => id && id.toString() === l._id.toString()
      ),
    }));

    // Pour compatibilité : livreurs filtrés (seulement dispos) dans 'livreurs'
    // ET tous dans 'tousLivreurs' pour affichage avec statut
    res.status(200).json({
      success:       true,
      nombre:        livreurs.filter((l) => l.disponible).length,
      livreurs:      livreurs.filter((l) => l.disponible), // rétrocompat
      tousLivreurs:  livreurs,                              // avec statut
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};