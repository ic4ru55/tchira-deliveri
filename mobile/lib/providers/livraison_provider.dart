import 'package:flutter/material.dart';
import '../models/livraison.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class LivraisonProvider extends ChangeNotifier {
  List<Livraison> _livraisonsDisponibles = [];
  List<Livraison> _mesLivraisons         = [];
  Livraison?      _livraisonActive;
  Livraison?      _livraisonSuivie;
  bool            _isLoading             = false;
  String?         _erreur;

  List<Livraison> get livraisonsDisponibles => _livraisonsDisponibles;
  List<Livraison> get mesLivraisons         => _mesLivraisons;
  Livraison?      get livraisonActive       => _livraisonActive;
  Livraison?      get livraisonSuivie       => _livraisonSuivie;
  bool            get isLoading             => _isLoading;
  String?         get erreur                => _erreur;

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  // ─── CLIENT : charger mes livraisons ──────────────────────────────────────
  Future<void> chargerMesLivraisons({bool silencieux = false}) async {
    if (!silencieux) _setLoading(true);
    try {
      final reponse = await ApiService.mesLivraisons();
      if (reponse['success'] == true) {
        final liste = reponse['livraisons'] as List? ?? [];
        _mesLivraisons = liste
            .map((j) => Livraison.fromJson(j as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    if (!silencieux) _setLoading(false);
    notifyListeners();
  }

  // ─── CLIENT : créer une livraison ─────────────────────────────────────────
  // Retourne l'ID de la livraison créée (null si échec)
  Future<String?> creerLivraison({
    required String adresseDepart,
    required String adresseArrivee,
    required String categorie,
    required String zoneCode,
    required double prix,
    required double prixBase,
    required double fraisZone,
    String description   = '',
    String modePaiement  = 'cash',
  }) async {
    _setLoading(true);
    try {
      final reponse = await ApiService.creerLivraisonComplete(
        adresseDepart:  adresseDepart,
        adresseArrivee: adresseArrivee,
        categorie:      categorie,
        zoneCode:       zoneCode,
        prix:           prix,
        prixBase:       prixBase,
        fraisZone:      fraisZone,
        description:    description,
        modePaiement:   modePaiement,
      );
      if (reponse['success'] == true) {
        await chargerMesLivraisons(silencieux: true);
        // Retourner l'ID pour redirection vers paiement OM si besoin
        final livraison = reponse['livraison'] as Map<String, dynamic>?;
        return livraison?['_id'] as String? ?? 'ok';
      }
      _erreur = reponse['message'];
      notifyListeners();
      return null;
    } catch (_) {
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // ─── CLIENT : suivre une livraison (tracking screen) ──────────────────────
  void suivreLivraison(Livraison livraison) {
    _livraisonSuivie = livraison;
    SocketService.rejoindrelivraison(livraison.id);
    notifyListeners();
  }

  // ─── LIVREUR : charger les livraisons disponibles ─────────────────────────
  Future<void> chargerLivraisonsDisponibles({bool silencieux = false}) async {
    if (!silencieux) _setLoading(true);
    try {
      final reponse = await ApiService.getLivraisonsDisponibles();
      if (reponse['success'] == true) {
        final liste = reponse['livraisons'] as List? ?? [];
        _livraisonsDisponibles = liste
            .map((j) => Livraison.fromJson(j as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    if (!silencieux) _setLoading(false);
    notifyListeners();
  }

  // ─── LIVREUR : restaurer la mission active au démarrage ───────────────────
  // Si le livreur ferme l'app et la rouvre, on retrouve sa mission en cours.
  Future<void> chargerMissionActive() async {
    try {
      // ✅ Utiliser l'endpoint DÉDIÉ /mission-active
      // (et non mon-historique qui retourne toutes les livraisons passées)
      final reponse = await ApiService.missionActiveLivreur();
      if (reponse['success'] == true) {
        final data = reponse['livraison'];
        if (data != null && data is Map<String, dynamic>) {
          // Il y a une mission active en cours
          _livraisonActive = Livraison.fromJson(data);
          SocketService.rejoindrelivraison(_livraisonActive!.id);
          SocketService.ecouterStatut((statut) {
            if (_livraisonActive != null) {
              _livraisonActive = _livraisonActive!.copyWith(statut: statut);
              notifyListeners();
            }
          });
        } else {
          // ✅ Aucune mission active → on reset explicitement
          _livraisonActive = null;
        }
        notifyListeners();
      } else {
        // Erreur API → on reset pour ne pas bloquer l'écran
        _livraisonActive = null;
        notifyListeners();
      }
    } catch (_) {
      // Erreur réseau → on reset
      _livraisonActive = null;
      notifyListeners();
    }
  }

  // ─── LIVREUR : accepter une livraison ─────────────────────────────────────
  // Retourne Map { 'succes': bool, 'message': String, 'dejaOccupe'?: bool }
  // Le widget affiche toujours le vrai message — jamais un générique.
  Future<Map<String, dynamic>> accepterLivraison(String id) async {
    // CAS 1 : livreur déjà occupé → bloquer localement
    if (_livraisonActive != null &&
        (_livraisonActive!.statut == 'en_cours' ||
         _livraisonActive!.statut == 'en_livraison')) {
      const msg =
          'Tu as déjà une mission en cours.\nTermine-la avant d\'en accepter une autre.';
      _erreur = msg;
      notifyListeners();
      return {'succes': false, 'message': msg, 'dejaOccupe': true};
    }

    _setLoading(true);
    try {
      final reponse = await ApiService.accepterLivraison(id);

      // CAS 2 : succès
      if (reponse['success'] == true) {
        _livraisonActive = Livraison.fromJson(reponse['livraison']);
        _livraisonsDisponibles.removeWhere((l) => l.id == id);
        SocketService.rejoindrelivraison(id);
        SocketService.ecouterStatut((statut) {
          if (_livraisonActive != null) {
            _livraisonActive = _livraisonActive!.copyWith(statut: statut);
            notifyListeners();
          }
        });
        _erreur = null;
        notifyListeners();
        return {'succes': true, 'message': 'Mission acceptée !'};
      }

      // CAS 3 : échec — propager le vrai message du serveur
      final msg = reponse['message'] as String? ?? 'Erreur inconnue';
      _erreur = msg;
      notifyListeners();
      return {'succes': false, 'message': msg};

    } catch (_) {
      const msg = 'Erreur réseau — vérifie ta connexion';
      _erreur = msg;
      notifyListeners();
      return {'succes': false, 'message': msg};
    } finally {
      _setLoading(false);
    }
  }

  // ─── LIVREUR : mettre à jour le statut ────────────────────────────────────
  Future<bool> mettreAJourStatut(String id, String statut) async {
    _setLoading(true);
    try {
      final reponse = await ApiService.mettreAJourStatut(id, statut);
      if (reponse['success'] == true) {
        if (_livraisonActive?.id == id) {
          _livraisonActive = Livraison.fromJson(reponse['livraison']);
        }
        notifyListeners();
        return true;
      }
      _erreur = reponse['message'];
      notifyListeners();
      return false;
    } catch (_) {
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ─── LIVREUR : réinitialiser après livraison terminée ─────────────────────
  void reinitialiserLivraisonActive() {
    _livraisonActive = null;
    notifyListeners();
  }
}