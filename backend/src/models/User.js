// ═══════════════════════════════════════════════════════════════
// Ajouter fcm_token dans ton modèle User existant
// backend/src/models/User.js — ajouter ce champ dans le schema
// ═══════════════════════════════════════════════════════════════

// Dans le UserSchema, ajouter :
// fcm_token: { type: String, default: null }

// Exemple de schema complet :
const mongoose = require('mongoose');
const bcrypt   = require('bcryptjs');

const UserSchema = new mongoose.Schema({
  nom:          { type: String, required: true, trim: true },
  email:        { type: String, required: true, unique: true, lowercase: true },
  mot_de_passe: { type: String, required: true },
  telephone:    { type: String, default: '' },
  role: {
    type:    String,
    enum:    ['client', 'livreur', 'receptionniste', 'admin'],
    default: 'client',
  },
  actif:     { type: Boolean, default: true },
  // ✅ Token FCM pour les push notifications
  // Mis à jour à chaque ouverture de l'app via POST /api/notifications/token
  fcm_token: { type: String, default: null },
}, { timestamps: true });

UserSchema.pre('save', async function (next) {
  if (!this.isModified('mot_de_passe')) return next();
  this.mot_de_passe = await bcrypt.hash(this.mot_de_passe, 12);
  next();
});

UserSchema.methods.verifierMotDePasse = async function (mdp) {
  return bcrypt.compare(mdp, this.mot_de_passe);
};

module.exports = mongoose.model('User', UserSchema);