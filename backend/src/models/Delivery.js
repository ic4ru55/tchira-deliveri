const mongoose = require('mongoose');

const DeliverySchema = new mongoose.Schema(
  {
    client: {
      type:     mongoose.Schema.Types.ObjectId,  // référence vers un User
      ref:      'User',                           // nom du modèle lié
      required: true,
    },

    livreur: {
      type: mongoose.Schema.Types.ObjectId,
      ref:  'User',
      default: null,   // pas encore assigné quand la livraison est créée
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

    // Coordonnées GPS du départ
    coordonnees_depart: {
      lat: { type: Number, default: 0 },
      lng: { type: Number, default: 0 },
    },

    // Coordonnées GPS de l'arrivée
    coordonnees_arrivee: {
      lat: { type: Number, default: 0 },
      lng: { type: Number, default: 0 },
    },

    statut: {
      type:    String,
      enum:    ['en_attente', 'en_cours', 'en_livraison', 'livre', 'annule'],
      default: 'en_attente',
    },

    prix: {
      type:    Number,
      default: 0,
    },

    description_colis: {
      type:    String,
      default: '',
      trim:    true,
    },

    // Position GPS live du livreur (mise à jour en temps réel via Socket.io)
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