const User     = require('../models/User');
const Delivery = require('../models/Delivery');
const bcrypt   = require('bcryptjs');

// ─── GET tous les utilisateurs ───────────────────────────────────────────────
exports.getUtilisateurs = async (req, res) => {
  try {
    const { role } = req.query;
    const filtre   = {};
    if (role) filtre.role = role;

    const utilisateurs = await User
      .find(filtre)
      .select('-mot_de_passe')
      .sort({ createdAt: -1 });

    res.status(200).json({ success: true, nombre: utilisateurs.length, utilisateurs });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// ─── GET un utilisateur ──────────────────────────────────────────────────────
exports.getUtilisateur = async (req, res) => {
  try {
    const utilisateur = await User.findById(req.params.id).select('-mot_de_passe');
    if (!utilisateur) {
      return res.status(404).json({ success: false, message: 'Utilisateur introuvable' });
    }
    res.status(200).json({ success: true, utilisateur });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// ─── CRÉER un compte ─────────────────────────────────────────────────────────
exports.creerUtilisateur = async (req, res) => {
  try {
    const { nom, email, mot_de_passe, telephone, role } = req.body;

    const rolesAutorisés = ['livreur', 'receptionniste', 'admin'];
    if (!rolesAutorisés.includes(role)) {
      return res.status(400).json({
        success: false,
        message: 'Rôle invalide. Valeurs acceptées : livreur, receptionniste, admin',
      });
    }

    const existe = await User.findOne({ email });
    if (existe) {
      return res.status(400).json({ success: false, message: 'Cet email est déjà utilisé' });
    }

    const utilisateur = await User.create({ nom, email, mot_de_passe, telephone, role });

    res.status(201).json({
      success: true,
      utilisateur: {
        id: utilisateur._id, nom: utilisateur.nom,
        email: utilisateur.email, telephone: utilisateur.telephone,
        role: utilisateur.role, actif: utilisateur.actif,
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// ─── MODIFIER un compte ──────────────────────────────────────────────────────
exports.modifierUtilisateur = async (req, res) => {
  try {
    const { nom, email, telephone, role, mot_de_passe } = req.body;
    const utilisateur = await User.findById(req.params.id);
    if (!utilisateur) {
      return res.status(404).json({ success: false, message: 'Utilisateur introuvable' });
    }

    if (nom)       utilisateur.nom       = nom;
    if (email)     utilisateur.email     = email;
    if (telephone) utilisateur.telephone = telephone;
    if (role)      utilisateur.role      = role;
    if (mot_de_passe && mot_de_passe.length >= 6) {
      utilisateur.mot_de_passe = mot_de_passe;
    }

    await utilisateur.save();

    res.status(200).json({
      success: true,
      utilisateur: {
        id: utilisateur._id, nom: utilisateur.nom,
        email: utilisateur.email, telephone: utilisateur.telephone,
        role: utilisateur.role, actif: utilisateur.actif,
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// ─── SUSPENDRE / RÉACTIVER ───────────────────────────────────────────────────
exports.changerStatutCompte = async (req, res) => {
  try {
    const { actif } = req.body;
    const utilisateur = await User.findById(req.params.id);
    if (!utilisateur) {
      return res.status(404).json({ success: false, message: 'Utilisateur introuvable' });
    }
    if (utilisateur._id.toString() === req.user.id) {
      return res.status(400).json({
        success: false, message: 'Impossible de modifier votre propre statut',
      });
    }

    utilisateur.actif = actif;
    await utilisateur.save();

    res.status(200).json({
      success: true,
      message: actif ? 'Compte réactivé avec succès' : 'Compte suspendu avec succès',
      utilisateur: { id: utilisateur._id, nom: utilisateur.nom, actif: utilisateur.actif },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// ─── SUPPRIMER un compte ─────────────────────────────────────────────────────
exports.supprimerUtilisateur = async (req, res) => {
  try {
    const utilisateur = await User.findById(req.params.id);
    if (!utilisateur) {
      return res.status(404).json({ success: false, message: 'Utilisateur introuvable' });
    }
    if (utilisateur._id.toString() === req.user.id) {
      return res.status(400).json({
        success: false, message: 'Impossible de supprimer votre propre compte',
      });
    }

    await utilisateur.deleteOne();
    res.status(200).json({ success: true, message: 'Compte supprimé avec succès' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};