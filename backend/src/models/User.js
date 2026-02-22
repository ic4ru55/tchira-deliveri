const mongoose = require('mongoose');
const bcrypt   = require('bcryptjs');

const UserSchema = new mongoose.Schema(
  {
    nom: {
      type:     String,
      required: [true, 'Le nom est obligatoire'],
      trim:     true,
    },
    email: {
      type:      String,
      required:  [true, 'L\'email est obligatoire'],
      unique:    true,
      lowercase: true,
      match: [/^\S+@\S+\.\S+$/, 'Email invalide'],
    },
    mot_de_passe: {
      type:      String,
      required:  [true, 'Le mot de passe est obligatoire'],
      minlength: [6, 'Minimum 6 caractères'],
      select:    false,
    },
    role: {
      type:    String,
      enum:    ['client', 'livreur', 'receptionniste', 'admin'],
      default: 'client',
    },
    telephone: {
      type:    String,
      default: '',
    },
    actif: {
      type:    Boolean,
      default: true,
    },
  },
  { timestamps: true }
);

// ─── HOOK corrigé ─────────────────────────────────────────────────────────────
UserSchema.pre('save', async function () {
  if (!this.isModified('mot_de_passe')) return;
  const salt        = await bcrypt.genSalt(10);
  this.mot_de_passe = await bcrypt.hash(this.mot_de_passe, salt);
});

// ─── MÉTHODE : vérifier le mot de passe au login ──────────────────────────────
UserSchema.methods.verifierMotDePasse = async function (motDePasseSaisi) {
  return await bcrypt.compare(motDePasseSaisi, this.mot_de_passe);
};

module.exports = mongoose.model('User', UserSchema);