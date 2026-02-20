const Tarif = require('../models/Tarif');
const Zone  = require('../models/Zone');

const initDonnees = async () => {
  try {

    // ── Tarifs ──────────────────────────────────────────────────────────────
    const tarifCount = await Tarif.countDocuments();

    if (tarifCount === 0) {
      await Tarif.insertMany([
        {
          categorie: 'leger',
          label:     'Léger (0 – 5 kg)',
          poids_min: 0,
          poids_max: 5,
          prix_base: 1000,
          sur_devis: false,
        },
        {
          categorie: 'moyen',
          label:     'Moyen (5 – 15 kg)',
          poids_min: 5,
          poids_max: 15,
          prix_base: 2500,
          sur_devis: false,
        },
        {
          categorie: 'lourd',
          label:     'Lourd (15 – 30 kg)',
          poids_min: 15,
          poids_max: 30,
          prix_base: 5000,
          sur_devis: false,
        },
        {
          categorie: 'tres_lourd',
          label:     'Très lourd (30 kg+)',
          poids_min: 30,
          poids_max: null,
          prix_base: 0,
          sur_devis: true,
        },
      ]);
      console.log('✅ Tarifs initialisés');
    }

    // ── Zones ────────────────────────────────────────────────────────────────
    const zoneCount = await Zone.countDocuments();

    if (zoneCount === 0) {
      await Zone.insertMany([
        {
          nom:                   'Intra Bobo-Dioulasso',
          code:                  'zone_1',
          description:           'Livraison dans Bobo-Dioulasso',
          frais_supplementaires: 0,
        },
        {
          nom:                   'Périphérie Bobo-Dioulasso',
          code:                  'zone_2',
          description:           'Communes environnantes de Bobo',
          frais_supplementaires: 500,
        },
        {
          nom:                   'Hors Bobo-Dioulasso',
          code:                  'zone_3',
          description:           'Autres villes du Burkina Faso',
          frais_supplementaires: 1500,
        },
      ]);
      console.log('✅ Zones initialisées');
    }

  } catch (error) {
    console.error('❌ Erreur init données :', error.message);
  }
};

module.exports = initDonnees;