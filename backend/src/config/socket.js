const jwt      = require('jsonwebtoken');
const Delivery = require('../models/Delivery');

module.exports = (io) => {

  // ─── Middleware Socket.io : vérifier le token JWT ──────────────────────────
  // Même logique que notre middleware HTTP, mais pour les connexions WebSocket
  io.use((socket, next) => {
    const token = socket.handshake.auth.token;
    //                              ^ le mobile envoie le token ici à la connexion

    if (!token) {
      return next(new Error('Token manquant'));
    }

    try {
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      socket.userId   = decoded.id;   // on attache l'userId au socket
      next();
    } catch {
      next(new Error('Token invalide'));
    }
  });

  // ─── Gestion des connexions ─────────────────────────────────────────────────
  io.on('connection', (socket) => {
    console.log(`🔌 Connecté : ${socket.userId}`);

    // ── Rejoindre la room d'une livraison ────────────────────────────────────
    // Le mobile (client ou livreur) émet cet événement pour rejoindre la room
    socket.on('rejoindre_livraison', async (livraisonId) => {
      try {
        // Vérifier que la livraison existe et que l'user est concerné
        const livraison = await Delivery.findById(livraisonId);

        if (!livraison) {
          socket.emit('erreur', { message: 'Livraison introuvable' });
          return;
        }

        const estConcerne =
          livraison.client.toString()  === socket.userId ||
          (livraison.livreur && livraison.livreur.toString() === socket.userId);

        if (!estConcerne) {
          socket.emit('erreur', { message: 'Accès non autorisé' });
          return;
        }

        // Rejoindre la room — format : "livraison_<id>"
        const nomRoom = `livraison_${livraisonId}`;
        socket.join(nomRoom);
        console.log(`📦 User ${socket.userId} a rejoint ${nomRoom}`);

        socket.emit('rejoint', { room: nomRoom, message: 'Connecté à la livraison' });

      } catch (error) {
        socket.emit('erreur', { message: error.message });
      }
    });

    // ── Livreur envoie sa position GPS ───────────────────────────────────────
    socket.on('position_livreur', async (data) => {
      // data = { livraisonId: "...", lat: 48.8566, lng: 2.3522 }
      try {
        const { livraisonId, lat, lng } = data;
        const nomRoom = `livraison_${livraisonId}`;

        // Mettre à jour la position en base de données
        await Delivery.findByIdAndUpdate(livraisonId, {
          position_livreur: { lat, lng }
        });

        // Diffuser la nouvelle position à TOUS dans la room
        // sauf le livreur lui-même (il n'a pas besoin de recevoir sa propre position)
        socket.to(nomRoom).emit('position_mise_a_jour', {
          livraisonId,
          lat,
          lng,
          timestamp: new Date(),
        });

        console.log(`📍 Position reçue pour ${livraisonId} : ${lat}, ${lng}`);

      } catch (error) {
        socket.emit('erreur', { message: error.message });
      }
    });

    // ── Livreur met à jour le statut via Socket ───────────────────────────────
    socket.on('statut_change', async (data) => {
      // data = { livraisonId: "...", statut: "en_livraison" }
      try {
        const { livraisonId, statut } = data;
        const nomRoom = `livraison_${livraisonId}`;

        // Mettre à jour en base
        await Delivery.findByIdAndUpdate(livraisonId, { statut });

        // Notifier tout le monde dans la room (client + livreur)
        io.to(nomRoom).emit('statut_mis_a_jour', {
          livraisonId,
          statut,
          timestamp: new Date(),
        });

        console.log(`🔄 Statut ${livraisonId} → ${statut}`);

      } catch (error) {
        socket.emit('erreur', { message: error.message });
      }
    });

    // ── Déconnexion ───────────────────────────────────────────────────────────
    socket.on('disconnect', () => {
      console.log(`❌ Déconnecté : ${socket.userId}`);
    });
  });

};