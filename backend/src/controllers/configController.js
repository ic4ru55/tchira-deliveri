// ═══════════════════════════════════════════════════════════════════════════════
// CONFIG CONTROLLER — controllers/configController.js
//
// Gère la configuration globale de l'app (numéro OM, paramètres entreprise…)
// ═══════════════════════════════════════════════════════════════════════════════

const Config = require('../models/Config');

// ── Obtenir la config (accessible à tous les utilisateurs connectés) ──────────
// Le client en a besoin pour afficher le bon numéro OM au paiement
exports.getConfig = async (req, res) => {
  try {
    // findOneAndUpdate avec upsert: true → crée automatiquement si absente
    const config = await Config.findOneAndUpdate(
      { cle: 'global' },
      { $setOnInsert: { cle: 'global' } },  // ne rien écraser si elle existe
      { upsert: true, new: true, lean: true }
    );

    // Retourner uniquement les champs publics (pas modifie_par ni _id)
    res.json({
      success:       true,
      om_numero:     config.om_numero     || '72007342',
      om_nom_compte: config.om_nom_compte || 'Tchira Express',
      om_actif:      config.om_actif      !== false,
      entreprise_nom: config.entreprise_nom || 'Tchira Express',
      entreprise_tel: config.entreprise_tel || '',
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ── Modifier la config (ADMIN uniquement) ─────────────────────────────────────
exports.modifierConfig = async (req, res) => {
  try {
    const {
      om_numero,
      om_nom_compte,
      om_actif,
      entreprise_nom,
      entreprise_tel,
    } = req.body;

    // Validation du numéro OM : chiffres seulement, 8 chiffres minimum
    if (om_numero !== undefined) {
      const cleaned = om_numero.toString().replace(/\s/g, '');
      if (!/^\d{8,12}$/.test(cleaned)) {
        return res.status(400).json({
          success: false,
          message: 'Numéro OM invalide — doit contenir 8 à 12 chiffres',
        });
      }
    }

    // Construire l'objet de mise à jour avec seulement les champs fournis
    const update = { modifie_par: req.user._id };
    if (om_numero     !== undefined) update.om_numero     = om_numero.toString().trim();
    if (om_nom_compte !== undefined) update.om_nom_compte = om_nom_compte.toString().trim();
    if (om_actif      !== undefined) update.om_actif      = Boolean(om_actif);
    if (entreprise_nom !== undefined) update.entreprise_nom = entreprise_nom.toString().trim();
    if (entreprise_tel !== undefined) update.entreprise_tel = entreprise_tel.toString().trim();

    const config = await Config.findOneAndUpdate(
      { cle: 'global' },
      { $set: update },
      { upsert: true, new: true, lean: true }
    );

    res.json({
      success:       true,
      message:       'Configuration mise à jour ✅',
      om_numero:     config.om_numero,
      om_nom_compte: config.om_nom_compte,
      om_actif:      config.om_actif,
      entreprise_nom: config.entreprise_nom,
      entreprise_tel: config.entreprise_tel,
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};