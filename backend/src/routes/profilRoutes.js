const express = require('express');
const router  = express.Router();
const User    = require('../models/User');
const { proteger } = require('../middleware/auth');

// ─── GET profil complet ───────────────────────────────────────────────────────
// GET /api/profil
router.get('/', proteger, async (req, res) => {
  try {
    const user = await User.findById(req.user.id).select('-mot_de_passe');
    res.status(200).json({ success: true, user });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ─── MODIFIER nom / téléphone / photo ────────────────────────────────────────
// PUT /api/profil
router.put('/', proteger, async (req, res) => {
  try {
    const { nom, telephone, photo_base64 } = req.body;
    const user = await User.findById(req.user.id);
    if (!user) {
      return res.status(404).json({ success: false, message: 'Utilisateur introuvable' });
    }

    if (nom)          user.nom          = nom.trim();
    if (telephone)    user.telephone    = telephone.trim();
    if (photo_base64 !== undefined) user.photo_base64 = photo_base64;

    await user.save();

    res.status(200).json({
      success: true,
      message: 'Profil mis à jour',
      user: {
        id:           user._id,
        nom:          user.nom,
        email:        user.email,
        telephone:    user.telephone,
        role:         user.role,
        actif:        user.actif,
        photo_base64: user.photo_base64,
      },
    });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ─── CHANGER mot de passe ─────────────────────────────────────────────────────
// PUT /api/profil/mot-de-passe
router.put('/mot-de-passe', proteger, async (req, res) => {
  try {
    const { ancien_mdp, nouveau_mdp } = req.body;

    if (!ancien_mdp || !nouveau_mdp) {
      return res.status(400).json({
        success: false, message: 'Ancien et nouveau mot de passe requis',
      });
    }
    if (nouveau_mdp.length < 6) {
      return res.status(400).json({
        success: false, message: 'Minimum 6 caractères',
      });
    }

    const user = await User.findById(req.user.id).select('+mot_de_passe');
    const correct = await user.verifierMotDePasse(ancien_mdp);
    if (!correct) {
      return res.status(401).json({
        success: false, message: 'Ancien mot de passe incorrect',
      });
    }

    user.mot_de_passe = nouveau_mdp;
    await user.save(); // hook pre-save hashera automatiquement

    res.status(200).json({ success: true, message: 'Mot de passe changé avec succès' });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

module.exports = router;