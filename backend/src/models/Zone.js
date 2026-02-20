const mongoose = require('mongoose');

const ZoneSchema = new mongoose.Schema(
  {
    nom: {
      type:     String,
      required: true,
      // ex: "Intra Bobo"
    },
    code: {
      type:   String,
      unique: true,
      // ex: "zone_1"
    },
    description: {
      type: String,
      default: '',
    },
    frais_supplementaires: {
      type:    Number,
      default: 0,
    },
    actif: {
      type:    Boolean,
      default: true,
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model('Zone', ZoneSchema);