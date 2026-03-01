// ═══════════════════════════════════════════════════════════════════════════════
// MODÈLE CONFIG — models/Config.js
//
// Stocke les paramètres globaux de l'application Tchira Express.
// Conception "singleton" : une seule entrée en base, identifiée par cle: 'global'
//
// POURQUOI UN MODÈLE DÉDIÉ plutôt que dans User ?
//   - Le numéro OM n'appartient pas à un utilisateur mais à l'entreprise
//   - Permet d'ajouter facilement d'autres paramètres (SMS, frais plateforme…)
//   - L'admin peut modifier sans toucher aux données utilisateurs
// ═══════════════════════════════════════════════════════════════════════════════

const mongoose = require('mongoose');

const ConfigSchema = new mongoose.Schema({
  // Clé unique pour identifier la config globale
  cle: {
    type:    String,
    default: 'global',
    unique:  true,
  },

  // ── Paiement Orange Money ──────────────────────────────────────────────────
  om_numero: {
    type:    String,
    default: '72007342',   // numéro de réception OM de Tchira Express
    trim:    true,
  },
  om_nom_compte: {
    type:    String,
    default: 'Tchira Express',
    trim:    true,
  },
  om_actif: {
    type:    Boolean,
    default: true,          // permet de désactiver l'option OM sans la supprimer
  },

  // ── Infos entreprise (extensible) ─────────────────────────────────────────
  entreprise_nom: {
    type:    String,
    default: 'Tchira Express',
  },
  entreprise_tel: {
    type:    String,
    default: '',
  },

  // Qui a modifié en dernier
  modifie_par: {
    type: mongoose.Schema.Types.ObjectId,
    ref:  'User',
  },
}, { timestamps: true });

module.exports = mongoose.model('Config', ConfigSchema);