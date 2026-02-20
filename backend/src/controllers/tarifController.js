const Tarif = require('../models/Tarif');
const Zone  = require('../models/Zone');

// ── GET tous les tarifs (public) ─────────────────────────────────────────────
exports.getTarifs = async (req, res) => {
  try {
    const tarifs = await Tarif.find({ actif: true }).sort({ prix_base: 1 });
    const zones  = await Zone.find({ actif: true }).sort({ frais_supplementaires: 1 });

    res.status(200).json({
      success: true,
      tarifs,
      zones,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// ── PUT modifier un tarif (admin seulement) ───────────────────────────────────
exports.modifierTarif = async (req, res) => {
  try {
    const { categorie }           = req.params;
    const { prix_base, sur_devis } = req.body;

    const tarif = await Tarif.findOneAndUpdate(
      { categorie },
      { prix_base, sur_devis },
      { new: true } // retourne le document mis à jour
    );

    if (!tarif) {
      return res.status(404).json({
        success: false,
        message: 'Tarif introuvable',
      });
    }

    res.status(200).json({ success: true, tarif });

  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// ── PUT modifier une zone (admin seulement) ───────────────────────────────────
exports.modifierZone = async (req, res) => {
  try {
    const { code }                  = req.params;
    const { frais_supplementaires } = req.body;

    const zone = await Zone.findOneAndUpdate(
      { code },
      { frais_supplementaires },
      { new: true }
    );

    if (!zone) {
      return res.status(404).json({
        success: false,
        message: 'Zone introuvable',
      });
    }

    res.status(200).json({ success: true, zone });

  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// ── POST calculer le prix d'une livraison ────────────────────────────────────
exports.calculerPrix = async (req, res) => {
  try {
    const { categorie, zone_code } = req.body;

    const tarif = await Tarif.findOne({ categorie, actif: true });
    if (!tarif) {
      return res.status(404).json({
        success: false,
        message: 'Catégorie introuvable',
      });
    }

    if (tarif.sur_devis) {
      return res.status(200).json({
        success:   true,
        sur_devis: true,
        message:   'Contactez l\'administrateur pour un devis',
      });
    }

    const zone = await Zone.findOne({ code: zone_code, actif: true });
    if (!zone) {
      return res.status(404).json({
        success: false,
        message: 'Zone introuvable',
      });
    }

    const prix_total = tarif.prix_base + zone.frais_supplementaires;

    res.status(200).json({
      success:     true,
      sur_devis:   false,
      prix_base:   tarif.prix_base,
      frais_zone:  zone.frais_supplementaires,
      prix_total,
      // Détail lisible pour l'affichage
      detail: `${tarif.label} + ${zone.nom} = ${prix_total} FCFA`,
    });

  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};