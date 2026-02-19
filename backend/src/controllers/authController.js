const jwt  = require('jsonwebtoken');
const User = require('../models/User');

// ─── Utilitaire : générer un token JWT ────────────────────────────────────────
// On crée une fonction réutilisable plutôt que de répéter ce code partout
const genererToken = (id) => {
  return jwt.sign(
    { id },                        // payload : ce qu'on met dans le token
    process.env.JWT_SECRET,        // clé secrète pour signer
    { expiresIn: process.env.JWT_EXPIRE }  // durée de validité
  );
};

// ─── REGISTER : créer un nouveau compte ───────────────────────────────────────
// POST /api/auth/register
exports.register = async (req, res) => {
  try {
    // 1. Extraire les données envoyées par le mobile
    const { nom, email, mot_de_passe, telephone, role } = req.body;

    // 2. Vérifier si l'email existe déjà
    const userExistant = await User.findOne({ email });
    if (userExistant) {
      return res.status(400).json({
        success: false,
        message: 'Cet email est déjà utilisé'
      });
    }

    // 3. Créer le user — le hook pre('save') hashera le mdp automatiquement
    const user = await User.create({
      nom,
      email,
      mot_de_passe,
      telephone,
      role: role || 'client',   // client par défaut si non précisé
    });

    // 4. Générer le token avec l'ID du user créé
    const token = genererToken(user._id);

    // 5. Renvoyer la réponse (sans le mot de passe)
    res.status(201).json({
      success: true,
      token,
      user: {
        id:        user._id,
        nom:       user.nom,
        email:     user.email,
        role:      user.role,
        telephone: user.telephone,
      }
    });

  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// ─── LOGIN : se connecter ─────────────────────────────────────────────────────
// POST /api/auth/login
exports.login = async (req, res) => {
  try {
    // 1. Extraire email et mot de passe
    const { email, mot_de_passe } = req.body;

    // 2. Vérifier que les deux champs sont présents
    if (!email || !mot_de_passe) {
      return res.status(400).json({
        success: false,
        message: 'Email et mot de passe requis'
      });
    }

    // 3. Chercher le user — on ajoute .select('+mot_de_passe')
    //    car on avait mis select:false sur ce champ dans le modèle
    const user = await User.findOne({ email }).select('+mot_de_passe');

    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Email ou mot de passe incorrect'  // message volontairement vague
      });
    }

    // 4. Vérifier le mot de passe avec la méthode du modèle
    const mdpCorrect = await user.verifierMotDePasse(mot_de_passe);
    if (!mdpCorrect) {
      return res.status(401).json({
        success: false,
        message: 'Email ou mot de passe incorrect'
      });
    }

    // 5. Vérifier que le compte est actif
    if (!user.actif) {
      return res.status(403).json({
        success: false,
        message: 'Compte suspendu. Contactez l\'administrateur'
      });
    }

    // 6. Tout est bon — générer et renvoyer le token
    const token = genererToken(user._id);

    res.status(200).json({
      success: true,
      token,
      user: {
        id:        user._id,
        nom:       user.nom,
        email:     user.email,
        role:      user.role,
        telephone: user.telephone,
      }
    });

  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// ─── MOI : récupérer le profil connecté ───────────────────────────────────────
// GET /api/auth/moi  (route protégée — nécessite le token)
exports.moi = async (req, res) => {
  try {
    // req.user est injecté par le middleware proteger (qu'on va créer juste après)
    const user = await User.findById(req.user.id);

    res.status(200).json({
      success: true,
      user
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};