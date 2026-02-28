const jwt  = require('jsonwebtoken');
const User = require('../models/User');

const genererToken = (id) => jwt.sign({ id }, process.env.JWT_SECRET, { expiresIn: process.env.JWT_EXPIRE });

// ─── Normaliser numéro Burkina ─────────────────────────────────────────────────
// Accepte TOUTES les variantes : "76123456", "+22676123456", "0022676123456"
// Retourne TOUJOURS "+22676123456" ou null si invalide
const normaliserTelephone = (tel) => {
  if (!tel) return null;
  let t = tel.toString().trim().replace(/[\s\-().]/g, '');
  if      (t.startsWith('+226'))                    { t = t.slice(4);  }
  else if (t.startsWith('00226'))                   { t = t.slice(5);  }
  else if (t.startsWith('226') && t.length === 11)  { t = t.slice(3);  }
  // t doit maintenant être exactement 8 chiffres
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
      nom,
      email:      email.toLowerCase(),
      mot_de_passe,
      telephone:  telNormalise,
      role:       role || 'client',
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
// ✅ FIX : cherche le numéro avec ET sans +226 pour compatibilité
// avec les anciens comptes créés avant la normalisation
exports.login = async (req, res) => {
  try {
    const { email: identifiant, mot_de_passe } = req.body;

    if (!identifiant || !mot_de_passe) {
      return res.status(400).json({ success: false, message: 'Identifiant et mot de passe requis' });
    }

    let user = null;

    if (!identifiant.includes('@')) {
      // ─── Login par téléphone ───────────────────────────────────────────
      const telNormalise = normaliserTelephone(identifiant);

      if (telNormalise) {
        // Chercher avec +226 (format normalisé — nouveaux comptes)
        user = await User.findOne({ telephone: telNormalise }).select('+mot_de_passe');

        // ✅ Si pas trouvé, chercher sans +226 (anciens comptes)
        if (!user) {
          const telSans226 = telNormalise.replace('+226', ''); // "76XXXXXX"
          user = await User.findOne({ telephone: telSans226 }).select('+mot_de_passe');
        }

        // ✅ Aussi chercher avec juste les 8 chiffres bruts (autre format ancien)
        if (!user) {
          const chiffres = identifiant.replace(/\D/g, '').slice(-8);
          user = await User.findOne({ telephone: chiffres }).select('+mot_de_passe');
        }
      }
    } else {
      // ─── Login par email ────────────────────────────────────────────────
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

// ─── METTRE À JOUR PROFIL ─────────────────────────────────────────────────────
exports.mettreAJourProfil = async (req, res) => {
  try {
    const { nom, telephone, photo } = req.body;
    const updates = {};
    if (nom) updates.nom = nom.trim();
    if (photo) {
      // Valider taille base64 (max ~5MB)
      if (photo.length > 7_000_000)
        return res.status(400).json({ success: false, message: 'Photo trop lourde (max 5MB)' });
      updates.photo = photo;
    }
    if (telephone) {
      // Validation téléphone inline
      let t = telephone.toString().trim().replace(/[\s\-().]/g, '');
      if      (t.startsWith('+226'))                    { t = t.slice(4);  }
      else if (t.startsWith('00226'))                   { t = t.slice(5);  }
      else if (t.startsWith('226') && t.length === 11)  { t = t.slice(3);  }
      if (!/^\d{8}$/.test(t))
        return res.status(400).json({ success: false, message: 'Numéro invalide' });
      updates.telephone = `+226${t}`;
    }
    const user = await User.findByIdAndUpdate(
      req.user.id, updates, { new: true, select: '-mot_de_passe' }
    );
    res.json({ success: true, user });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// ─── CHANGER MOT DE PASSE ─────────────────────────────────────────────────────
exports.changerMotDePasse = async (req, res) => {
  try {
    const { ancien_mot_de_passe, nouveau_mot_de_passe } = req.body;
    if (!ancien_mot_de_passe || !nouveau_mot_de_passe)
      return res.status(400).json({ success: false, message: 'Les deux mots de passe sont requis' });
    if (nouveau_mot_de_passe.length < 6)
      return res.status(400).json({ success: false, message: 'Minimum 6 caractères' });

    const user = await User.findById(req.user.id).select('+mot_de_passe');
    const correct = await user.verifierMotDePasse(ancien_mot_de_passe);
    if (!correct)
      return res.status(401).json({ success: false, message: 'Ancien mot de passe incorrect' });

    user.mot_de_passe = nouveau_mot_de_passe;
    await user.save(); // le middleware pre-save hashera automatiquement
    res.json({ success: true, message: 'Mot de passe modifié avec succès' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};