const mongoose = require('mongoose');

const TarifSchema = new mongoose.Schema(
  {
    categorie: {
      type:    String,
      enum:    ['leger', 'moyen', 'lourd', 'tres_lourd'],
      unique:  true,
      required: true,
    },
    label: {
      type:     String,
      required: true,
      // ex: "Léger (0-5 kg)"
    },
    poids_min: {
      type:    Number,
      default: 0,
    },
    poids_max: {
      type:    Number,
      default: null, // null = pas de limite (très lourd)
    },
    prix_base: {
      type:     Number,
      required: true,
    },
    sur_devis: {
      type:    Boolean,
      default: false, // true uniquement pour très lourd
    },
    actif: {
      type:    Boolean,
      default: true,
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model('Tarif', TarifSchema);