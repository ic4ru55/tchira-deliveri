const mongoose = require('mongoose');

const DeliverySchema = new mongoose.Schema(
  {
    client: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },

    livreur: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
    },

    adresse_depart: {
      type: String,
      required: [true, "L'adresse de départ est obligatoire"],
      trim: true,
    },

    adresse_arrivee: {
      type: String,
      required: [true, "L'adresse d'arrivée est obligatoire"],
      trim: true,
    },

    coordonnees_depart: {
      lat: { type: Number, default: 0 },
      lng: { type: Number, default: 0 },
    },

    coordonnees_arrivee: {
      lat: { type: Number, default: 0 },
      lng: { type: Number, default: 0 },
    },

    categorie_colis: {
      type: String,
      enum: ['leger', 'moyen', 'lourd', 'tres_lourd'],
      default: 'leger',
    },

    zone: {
      type: String,
      enum: ['zone_1', 'zone_2', 'zone_3'],
      default: 'zone_1',
    },

    description_colis: {
      type: String,
      default: '',
      trim: true,
    },

    client_nom_tel: {
      type: String,
      default: '',
    },

    client_telephone_tel: {
      type: String,
      default: '',
    },

    statut: {
      type: String,
      enum: ['en_attente', 'en_cours', 'en_livraison', 'livre', 'annule'],
      default: 'en_attente',
    },

    prix_base: {
      type: Number,
      default: 0,
    },

    frais_zone: {
      type: Number,
      default: 0,
    },

    prix: {
      type: Number,
      default: 0,
    },

    // ───────────── PATCH AJOUTÉ ─────────────

    mode_paiement: {
    type:    String,
    enum:    ['om', 'cash'],
    default: 'cash',
  },

  statut_paiement: {
    type:    String,
    enum:    ['non_requis', 'preuve_soumise', 'verifie', 'rejete'],
    default: 'non_requis',
  },

  preuve_paiement: {
    data:        { type: String },   // base64 capture OM ou photo cash
    soumis_le:   { type: Date },
    verifie_le:  { type: Date },
    verifie_par: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    motif_rejet: { type: String },
  },

  preuve_livraison: {
    data:     { type: String },      // base64 photo prise par le livreur à la remise
    prise_le: { type: Date },
  },

  alerte_timer_envoyee: {
    type:    Boolean,
    default: false,
  },

    // ───────────── FIN PATCH ─────────────

    position_livreur: {
      lat: { type: Number, default: 0 },
      lng: { type: Number, default: 0 },
    },
  },
  {
    timestamps: true,
  }
);

module.exports = mongoose.model('Delivery', DeliverySchema);