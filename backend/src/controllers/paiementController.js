const Livraison    = require('../models/Livraison');
const User         = require('../models/User');
const notifService = require('../services/notificationService');

// ── CLIENT : soumettre preuve paiement OM ────────────────────────────────────
exports.soumettrePreuve = async (req, res) => {
  try {
    const { id }     = req.params;
    const { preuve } = req.body;

    if (!preuve)
      return res.status(400).json({ success: false, message: 'Preuve requise' });
    if (preuve.length > 7_000_000)
      return res.status(400).json({ success: false, message: 'Image trop lourde (max 5MB)' });

    const liv = await Livraison.findOne({ _id: id, client: req.user._id });
    if (!liv)
      return res.status(404).json({ success: false, message: 'Livraison introuvable' });
    if (liv.mode_paiement !== 'om')
      return res.status(400).json({ success: false, message: 'Mode de paiement non OM' });

    liv.preuve_paiement = { data: preuve, soumis_le: new Date() };
    liv.statut_paiement = 'preuve_soumise';
    await liv.save();

    // Notifier réceptionnistes + admins
    const staff = await User.find({ role: { $in: ['receptionniste', 'admin'] }, actif: true });
    const promesses = staff
      .filter(s => s.fcm_token)
      .map(s => notifService.envoyerNotification(s.fcm_token, {
        title: '📸 Preuve de paiement reçue',
        body:  `Livraison #${id.slice(-6).toUpperCase()} — vérification requise`,
        data:  { type: 'preuve_paiement', livraison_id: id },
      }).catch(() => {}));
    await Promise.all(promesses);

    res.json({ success: true, message: 'Preuve soumise avec succès' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ── RÉCEP/ADMIN : valider ou rejeter la preuve ────────────────────────────────
exports.validerPreuve = async (req, res) => {
  try {
    const { id }            = req.params;
    const { action, motif } = req.body;

    if (!['valider', 'rejeter'].includes(action))
      return res.status(400).json({ success: false, message: 'Action invalide' });

    const liv = await Livraison.findById(id).populate('client', 'nom fcm_token');
    if (!liv)
      return res.status(404).json({ success: false, message: 'Livraison introuvable' });
    if (liv.statut_paiement !== 'preuve_soumise')
      return res.status(400).json({ success: false, message: 'Aucune preuve en attente' });

    if (action === 'valider') {
      liv.statut_paiement             = 'verifie';
      liv.preuve_paiement.verifie_le  = new Date();
      liv.preuve_paiement.verifie_par = req.user._id;

      // Notifier le client
      if (liv.client?.fcm_token) {
        await notifService.envoyerNotification(liv.client.fcm_token, {
          title: '✅ Paiement confirmé !',
          body:  'Votre paiement a été vérifié. Un livreur va prendre en charge votre colis.',
          data:  { type: 'paiement_verifie', livraison_id: id },
        }).catch(() => {});
      }

    } else {
      liv.statut_paiement             = 'rejete';
      liv.preuve_paiement.motif_rejet = motif || 'Preuve non conforme';

      // Notifier le client avec motif
      if (liv.client?.fcm_token) {
        await notifService.envoyerNotification(liv.client.fcm_token, {
          title: '❌ Preuve de paiement rejetée',
          body:  motif || "La preuve soumise n'est pas valide. Veuillez en soumettre une nouvelle.",
          data:  { type: 'paiement_rejete', livraison_id: id },
        }).catch(() => {});
      }
    }

    await liv.save();
    res.json({
      success: true,
      message: action === 'valider' ? 'Paiement validé' : 'Preuve rejetée',
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ── LIVREUR : confirmer réception paiement cash ───────────────────────────────
exports.confirmerCash = async (req, res) => {
  try {
    const { id }    = req.params;
    const { photo } = req.body;

    const liv = await Livraison.findOne({ _id: id, livreur: req.user._id });
    if (!liv)
      return res.status(404).json({ success: false, message: 'Livraison introuvable' });
    if (liv.mode_paiement !== 'cash')
      return res.status(400).json({ success: false, message: 'Non applicable pour ce mode de paiement' });

    liv.statut_paiement = 'verifie';
    if (photo) liv.preuve_paiement = { data: photo, soumis_le: new Date() };
    await liv.save();

    // Notifier admins
    const admins = await User.find({ role: 'admin', actif: true });
    await Promise.all(
      admins.filter(a => a.fcm_token).map(a =>
        notifService.envoyerNotification(a.fcm_token, {
          title: '💵 Paiement cash confirmé',
          body:  `Livraison #${id.slice(-6).toUpperCase()} — cash reçu par le livreur`,
          data:  { type: 'cash_confirme', livraison_id: id },
        }).catch(() => {})
      )
    );

    res.json({ success: true, message: 'Paiement cash confirmé' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ── LIVREUR : soumettre photo preuve de livraison ─────────────────────────────
exports.soumettrePreuveLivraison = async (req, res) => {
  try {
    const { id }    = req.params;
    const { photo } = req.body;

    if (!photo)
      return res.status(400).json({ success: false, message: 'Photo requise' });
    if (photo.length > 7_000_000)
      return res.status(400).json({ success: false, message: 'Image trop lourde (max 5MB)' });

    const liv = await Livraison.findOne({ _id: id, livreur: req.user._id });
    if (!liv)
      return res.status(404).json({ success: false, message: 'Livraison introuvable' });

    liv.preuve_livraison = { data: photo, prise_le: new Date() };
    await liv.save();

    res.json({ success: true, message: 'Preuve de livraison enregistrée' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ── ADMIN/RÉCEP : lister toutes les preuves en attente ───────────────────────
exports.preuvesEnAttente = async (req, res) => {
  try {
    const livs = await Livraison.find({ statut_paiement: 'preuve_soumise' })
      .populate('client', 'nom telephone email')
      .select('client adresse_depart adresse_arrivee prix mode_paiement preuve_paiement statut_paiement createdAt')
      .sort({ 'preuve_paiement.soumis_le': 1 }); // Plus ancienne d'abord

    res.json({ success: true, livraisons: livs });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ── TIMER : vérifier missions non assignées > 30min ──────────────────────────
// Appelé automatiquement par app.js toutes les 5 minutes
exports.verifierTimerAssignation = async () => {
  try {
    const il_y_a_30min = new Date(Date.now() - 30 * 60 * 1000);
    const livsNonAssignees = await Livraison.find({
      statut:               { $in: ['en_attente', 'validee'] },
      livreur:              null,
      alerte_timer_envoyee: false,
      createdAt:            { $lt: il_y_a_30min },
    });

    for (const liv of livsNonAssignees) {
      const receps = await User.find({ role: { $in: ['receptionniste', 'admin'] }, actif: true });
      await Promise.all(
        receps.filter(r => r.fcm_token).map(r =>
          notifService.envoyerNotification(r.fcm_token, {
            title: '⚠️ Mission non assignée depuis 30 min',
            body:  `Livraison #${liv._id.toString().slice(-6).toUpperCase()} attend toujours un livreur`,
            data:  { type: 'timer_assignation', livraison_id: liv._id.toString() },
          }).catch(() => {})
        )
      );
      liv.alerte_timer_envoyee = true;
      await liv.save();
    }
    if (livsNonAssignees.length > 0)
      console.log(`⚠️ Timer: ${livsNonAssignees.length} mission(s) non assignées > 30min`);
  } catch (err) {
    console.error('Timer assignation error:', err.message);
  }
};