const Delivery = require('../models/Delivery');
const User     = require('../models/User');
const { envoyerNotification } = require('../services/firebaseService');

// ─── CRÉER une livraison
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
      client_nom_tel:      client_nom       || '',
      client_telephone_tel: client_telephone || '',

      // ✅ PATCH AJOUTÉ
      mode_paiement:   req.body.mode_paiement || 'cash',
      statut_paiement: req.body.mode_paiement === 'om' ? 'non_requis' : 'non_requis',
    });

    await livraison.populate('client', 'nom email telephone');

    const livreurs = await User.find({
      role:      'livreur',
      actif:     true,
      fcm_token: { $ne: null },
    });

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

// ─── LIVRAISONS DISPONIBLES (livreur)
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

// ─── TOUTES LES LIVRAISONS (admin + réceptionniste)
exports.toutesLesLivraisons = async (req, res) => {
  try {
    const { statut, date } = req.query;
    const filtre = {};
    if (statut) filtre.statut = statut;
    if (date) {
      const debut = new Date(date); debut.setHours(0,0,0,0);
      const fin   = new Date(date); fin.setHours(23,59,59,999);
      filtre.createdAt = { $gte: debut, $lte: fin };
    }
    const livraisons = await Delivery
      .find(filtre)
      .populate('client', 'nom telephone')
      .populate('livreur', 'nom telephone')
      .sort({ createdAt: -1 });
    res.status(200).json({ success: true, nombre: livraisons.length, livraisons });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// ─── STATISTIQUES (admin)
exports.getStats = async (req, res) => {
  try {
    const { date } = req.query;
    let filtreDate = {};
    if (date) {
      const debut = new Date(date); debut.setHours(0,0,0,0);
      const fin   = new Date(date); fin.setHours(23,59,59,999);
      filtreDate  = { createdAt: { $gte: debut, $lte: fin } };
    }
    const total       = await Delivery.countDocuments(filtreDate);
    const enAttente   = await Delivery.countDocuments({ ...filtreDate, statut: 'en_attente' });
    const enCours     = await Delivery.countDocuments({ ...filtreDate, statut: 'en_cours' });
    const enLivraison = await Delivery.countDocuments({ ...filtreDate, statut: 'en_livraison' });
    const livrees     = await Delivery.countDocuments({ ...filtreDate, statut: 'livre' });
    const annulees    = await Delivery.countDocuments({ ...filtreDate, statut: 'annule' });
    const resultatCA  = await Delivery.aggregate([{ $match: { ...filtreDate, statut: 'livre' } }, { $group: { _id: null, total: { $sum: '$prix' } } }]);
    const chiffreAffaires = resultatCA[0]?.total || 0;
    const aujourd = new Date(); aujourd.setHours(0,0,0,0);
    const resultatCAJour = await Delivery.aggregate([{ $match: { statut: 'livre', createdAt: { $gte: aujourd } } }, { $group: { _id: null, total: { $sum: '$prix' } } }]);
    const caAujourdhui = resultatCAJour[0]?.total || 0;
    const livreursActifs = await User.countDocuments({ role: 'livreur', actif: true });
    res.status(200).json({ success: true, stats: { total, enAttente, enCours, enLivraison, livrees, annulees, chiffreAffaires, caAujourdhui, livreursActifs, dateFiltre: date || null } });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// ─── MES LIVRAISONS (client)
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

// ─── HISTORIQUE DU LIVREUR CONNECTÉ
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

// ─── DÉTAIL d'une livraison
exports.getLivraison = async (req, res) => {
  try {
    const livraison = await Delivery
      .findById(req.params.id)
      .populate('client', 'nom email telephone')
      .populate('livreur', 'nom email telephone');
    if (!livraison) return res.status(404).json({ success: false, message: 'Livraison introuvable' });
    const estConcerne = livraison.client._id.toString() === req.user.id ||
                        (livraison.livreur && livraison.livreur._id.toString() === req.user.id) ||
                        ['admin','receptionniste'].includes(req.user.role);
    if (!estConcerne) return res.status(403).json({ success: false, message: 'Accès non autorisé' });
    res.status(200).json({ success: true, livraison });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};