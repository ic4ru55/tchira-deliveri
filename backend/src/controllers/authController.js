const jwt  = require('jsonwebtoken');
const User = require('../models/User');

const genererToken = (id) => jwt.sign({ id }, process.env.JWT_SECRET, { expiresIn: process.env.JWT_EXPIRE });

// ─── Normaliser numéro Burkina ─────────────────────────────────────────────────
// Accepte: "76123456", "+22676123456", "0022676123456"
// Retourne: "+22676123456" ou null si invalide
const normaliserTelephone = (tel) => {
  if (!tel) return null;
  let t = tel.toString().trim().replace(/[\s\-().]/g, '');
  if (t.startsWith('+226'))      { t = t.slice(4); }
  else if (t.startsWith('00226')){ t = t.slice(5); }
  else if (t.startsWith('226') && t.length === 11) { t = t.slice(3); }
  if (!/^\d{8}$/.test(t)) return null;
  return `+226${t}`;
};

// ─── REGISTER ─────────────────────────────────────────────────────────────────
exports.register = async (req, res) => {
  try {
    const { nom, email, mot_de_passe, telephone, role } = req.body;

    const emailExistant = await User.findOne({ email: email.toLowerCase() });
    if (emailExistant) {
      return res.status(400).json({ success: false, message: 'Cet email est déjà utilisé' });
    }

    const telNormalise = normaliserTelephone(telephone);
    if (!telNormalise) {
      return res.status(400).json({ success: false, message: 'Numéro invalide — 8 chiffres Burkina requis' });
    }

    const telExistant = await User.findOne({ telephone: telNormalise });
    if (telExistant) {
      return res.status(400).json({ success: false, message: 'Ce numéro est déjà utilisé' });
    }

    const user = await User.create({
      nom, email: email.toLowerCase(), mot_de_passe, telephone: telNormalise, role: role || 'client',
    });

    const token = genererToken(user._id);
    res.status(201).json({
      success: true, token,
      user: { id: user._id, nom: user.nom, email: user.email, role: user.role, telephone: user.telephone },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// ─── LOGIN : email OU téléphone ────────────────────────────────────────────────
exports.login = async (req, res) => {
  try {
    const { email: identifiant, mot_de_passe } = req.body;
    if (!identifiant || !mot_de_passe) {
      return res.status(400).json({ success: false, message: 'Identifiant et mot de passe requis' });
    }

    let user = null;
    // Si pas de @, c'est un numéro de téléphone
    if (!identifiant.includes('@')) {
      const telNormalise = normaliserTelephone(identifiant);
      if (telNormalise) {
        user = await User.findOne({ telephone: telNormalise }).select('+mot_de_passe');
      }
    } else {
      user = await User.findOne({ email: identifiant.toLowerCase() }).select('+mot_de_passe');
    }

    if (!user) {
      return res.status(401).json({ success: false, message: 'Identifiant ou mot de passe incorrect' });
    }

    const mdpCorrect = await user.verifierMotDePasse(mot_de_passe);
    if (!mdpCorrect) {
      return res.status(401).json({ success: false, message: 'Identifiant ou mot de passe incorrect' });
    }

    if (!user.actif) {
      return res.status(403).json({ success: false, message: "Compte suspendu. Contactez l'administrateur" });
    }

    const token = genererToken(user._id);
    res.status(200).json({
      success: true, token,
      user: { id: user._id, nom: user.nom, email: user.email, role: user.role, telephone: user.telephone },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// ─── MOI ──────────────────────────────────────────────────────────────────────
exports.moi = async (req, res) => {
  try {
    const user = await User.findById(req.user.id).select('-mot_de_passe');
    res.status(200).json({ success: true, user });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};