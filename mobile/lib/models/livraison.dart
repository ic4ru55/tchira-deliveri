class Coordonnees {
  final double lat;
  final double lng;

  Coordonnees({ required this.lat, required this.lng });

  factory Coordonnees.fromJson(Map<String, dynamic> json) {
    return Coordonnees(
      lat: (json['lat'] ?? 0).toDouble(),
      lng: (json['lng'] ?? 0).toDouble(),
    );
  }
}

class Livraison {
  final String id;
  final String adresseDepart;
  final String adresseArrivee;
  final String statut;
  final double prix;
  final String descriptionColis;
  final Coordonnees coordonneesDepart;
  final Coordonnees coordonneesArrivee;
  Coordonnees positionLivreur;  // mutable — change en temps réel
  final Map<String, dynamic>? client;
  final Map<String, dynamic>? livreur;
  final DateTime createdAt;

  Livraison({
    required this.id,
    required this.adresseDepart,
    required this.adresseArrivee,
    required this.statut,
    required this.prix,
    required this.descriptionColis,
    required this.coordonneesDepart,
    required this.coordonneesArrivee,
    required this.positionLivreur,
    this.client,
    this.livreur,
    required this.createdAt,
  });

  factory Livraison.fromJson(Map<String, dynamic> json) {
    return Livraison(
      id:                 json['_id'] ?? '',
      adresseDepart:      json['adresse_depart'] ?? '',
      adresseArrivee:     json['adresse_arrivee'] ?? '',
      statut:             json['statut'] ?? 'en_attente',
      prix:               (json['prix'] ?? 0).toDouble(),
      descriptionColis:   json['description_colis'] ?? '',
      coordonneesDepart:  Coordonnees.fromJson(json['coordonnees_depart'] ?? {}),
      coordonneesArrivee: Coordonnees.fromJson(json['coordonnees_arrivee'] ?? {}),
      positionLivreur:    Coordonnees.fromJson(json['position_livreur'] ?? {}),
      client:             json['client'],
      livreur:            json['livreur'],
      createdAt:          DateTime.parse(
                            json['createdAt'] ?? DateTime.now().toIso8601String()
                          ),
    );
  }

  // Copie avec modification — utile quand la position change en temps réel
  Livraison copyWith({ Coordonnees? positionLivreur, String? statut }) {
    return Livraison(
      id:                 id,
      adresseDepart:      adresseDepart,
      adresseArrivee:     adresseArrivee,
      statut:             statut ?? this.statut,
      prix:               prix,
      descriptionColis:   descriptionColis,
      coordonneesDepart:  coordonneesDepart,
      coordonneesArrivee: coordonneesArrivee,
      positionLivreur:    positionLivreur ?? this.positionLivreur,
      client:             client,
      livreur:            livreur,
      createdAt:          createdAt,
    );
  }
}