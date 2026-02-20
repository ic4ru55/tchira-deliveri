import 'package:flutter/material.dart';
import '../models/livraison.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class LivraisonProvider extends ChangeNotifier {
  List<Livraison> _mesLivraisons          = [];
  List<Livraison> _livraisonsDisponibles  = [];
  Livraison?      _livraisonActive;
  bool            _isLoading = false;
  String?         _erreur;

  List<Livraison> get mesLivraisons         => _mesLivraisons;
  List<Livraison> get livraisonsDisponibles => _livraisonsDisponibles;
  Livraison?      get livraisonActive       => _livraisonActive;
  bool            get isLoading             => _isLoading;
  String?         get erreur                => _erreur;

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  // ─── CLIENT : créer une livraison ────────────────────────────────────────────
  Future<bool> creerLivraison({
    required String adresseDepart,
    required String adresseArrivee,
    required double prix,
    String description = '',
  }) async {
    _setLoading(true);
    try {
      final reponse = await ApiService.creerLivraison(
        adresseDepart:  adresseDepart,
        adresseArrivee: adresseArrivee,
        prix:           prix,
        description:    description,
      );
      if (reponse['success'] == true) {
        // Ajouter la nouvelle livraison en tête de liste
        _mesLivraisons.insert(0, Livraison.fromJson(reponse['livraison']));
        notifyListeners();
        return true;
      }
      _erreur = reponse['message'];
      notifyListeners();
      return false;
    } catch (e) {
      _erreur = 'Erreur réseau';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ─── CLIENT : charger ses livraisons ─────────────────────────────────────────
  Future<void> chargerMesLivraisons() async {
    _setLoading(true);
    try {
      final reponse = await ApiService.mesLivraisons();
      if (reponse['success'] == true) {
        _mesLivraisons = (reponse['livraisons'] as List)
            .map((json) => Livraison.fromJson(json))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      _erreur = 'Erreur chargement livraisons';
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  // ─── LIVREUR : charger les livraisons disponibles ────────────────────────────
  Future<void> chargerLivraisonsDisponibles() async {
    _setLoading(true);
    try {
      final reponse = await ApiService.getLivraisonsDisponibles();
      if (reponse['success'] == true) {
        _livraisonsDisponibles = (reponse['livraisons'] as List)
            .map((json) => Livraison.fromJson(json))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      _erreur = 'Erreur chargement';
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  // ─── LIVREUR : accepter une livraison ────────────────────────────────────────
  Future<bool> accepterLivraison(String id) async {
    _setLoading(true);
    try {
      final reponse = await ApiService.accepterLivraison(id);
      if (reponse['success'] == true) {
        _livraisonActive = Livraison.fromJson(reponse['livraison']);

        // Retirer de la liste des disponibles
        _livraisonsDisponibles.removeWhere((l) => l.id == id);

        // Rejoindre la room Socket.io
        SocketService.rejoindrelivraison(id);
        _ecouterTempsReel(id);

        notifyListeners();
        return true;
      }
      _erreur = reponse['message'];
      notifyListeners();
      return false;
    } catch (e) {
      _erreur = 'Erreur réseau';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ─── CLIENT : suivre une livraison en temps réel ─────────────────────────────
  void suivreLivraison(Livraison livraison) {
    _livraisonActive = livraison;
    SocketService.rejoindrelivraison(livraison.id);
    _ecouterTempsReel(livraison.id);
    notifyListeners();
  }

  // ─── Écouter les événements Socket.io en temps réel ──────────────────────────
  void _ecouterTempsReel(String livraisonId) {
    // Position GPS du livreur
    SocketService.ecouterPosition((lat, lng) {
      if (_livraisonActive?.id == livraisonId) {
        _livraisonActive = _livraisonActive!.copyWith(
          positionLivreur: Coordonnees(lat: lat, lng: lng),
        );
        notifyListeners();
      }
    });

    // Changement de statut
    SocketService.ecouterStatut((statut) {
      if (_livraisonActive?.id == livraisonId) {
        _livraisonActive = _livraisonActive!.copyWith(statut: statut);

        // Mettre à jour aussi dans la liste mes livraisons
        final index = _mesLivraisons.indexWhere((l) => l.id == livraisonId);
        if (index != -1) {
          _mesLivraisons[index] = _mesLivraisons[index].copyWith(
            statut: statut,
          );
        }
        notifyListeners();
      }
    });
  }

  // ─── LIVREUR : mettre à jour le statut ───────────────────────────────────────
  Future<bool> mettreAJourStatut(String id, String statut) async {
    try {
      final reponse = await ApiService.mettreAJourStatut(id, statut);
      if (reponse['success'] == true) {
        // Émettre via Socket pour que le client voie en temps réel
        SocketService.socket.emit('statut_change', {
          'livraisonId': id,
          'statut':      statut,
        });

        // Mettre à jour localement
        _livraisonActive = _livraisonActive?.copyWith(statut: statut);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // ─── Réinitialiser la livraison active ───────────────────────────────────────
  void reinitialiserLivraisonActive() {
    _livraisonActive = null;
    notifyListeners();
  }
}