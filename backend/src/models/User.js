const mongoose = require('mongoose');
const bcrypt   = require('bcryptjs');

const UserSchema = new mongoose.Schema({
  nom: {
    type:     String,
    required: true,
    trim:     true,
  },
  email: {
    type:      String,
    required:  true,
    unique:    true,
    lowercase: true,
  },
  mot_de_passe: {
    type:     String,
    required: true,
    select:   false,
  },
  telephone: {
    type:    String,
    default: '',
  },
  role: {
    type:    String,
    enum:    ['client', 'livreur', 'receptionniste', 'admin'],
    default: 'client',
  },
  actif: {
    type:    Boolean,
    default: true,
  },
  fcm_token: {
    type:    String,
    default: null,
  },
  // ✅ Photo de profil en base64
  photo_base64: {
    type:    String,
    default: null,
  },
}, { timestamps: true });

// ✅ Hook sans next() — Mongoose moderne gère automatiquement
UserSchema.pre('save', async function () {
  if (!this.isModified('mot_de_passe')) return;
  this.mot_de_passe = await bcrypt.hash(this.mot_de_passe, 12);
});

UserSchema.methods.verifierMotDePasse = async function (mdp) {
  return bcrypt.compare(mdp, this.mot_de_passe);
};

module.exports = mongoose.model('User', UserSchema);