const mongoose = require('mongoose');

const DeliverySchema = new mongoose.Schema(
  {
    client: {
      type:     mongoose.Schema.Types.ObjectId,
      ref:      'User',
      required: true,
    },

    livreur: {
      type:    mongoose.Schema.Types.ObjectId,
      ref:     'User',
      default: null,
    },

    adresse_depart: {
      type:     String,
      required: [true, 'L\'adresse de départ est obligatoire'],
      trim:     true,
    },

    adresse_arrivee: {
      type:     String,
      required: [true, 'L\'adresse d\'arrivée est obligatoire'],
      trim:     true,
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
      type:    String,
      enum:    ['leger', 'moyen', 'lourd', 'tres_lourd'],
      default: 'leger',
    },

    zone: {
      type:    String,
      enum:    ['zone_1', 'zone_2', 'zone_3'],
      default: 'zone_1',
    },

    description_colis: {
      type:    String,
      default: '',
      trim:    true,
    },

    statut: {
      type:    String,
      enum:    ['en_attente', 'en_cours', 'en_livraison', 'livre', 'annule'],
      default: 'en_attente',
    },

    prix_base: {
      type:    Number,
      default: 0,
    },

    frais_zone: {
      type:    Number,
      default: 0,
    },

    prix: {
      type:    Number,
      default: 0,
    },

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
